import Foundation
import AppKit
import Combine
import ImageIO

enum MediaCommand: UInt32 {
    case togglePlayPause = 2
    case nextTrack = 4
    case previousTrack = 5
}

final class MusicManager: ObservableObject {
    
    static let shared = MusicManager()

    @Published var title: String = "Not Playing"
    @Published var artist: String = ""
    @Published var artwork: NSImage? = nil
    @Published var isPlaying = false

    private let bundle: CFBundle?
    private var observerTokens: [NSObjectProtocol] = []
    private var lastArtworkData: Data?

    init() {
            self.bundle = CFBundleCreate(kCFAllocatorDefault, NSURL(fileURLWithPath: "/System/Library/PrivateFrameworks/MediaRemote.framework"))
            
            // 1. Mandatory: Register for notifications
            registerForNotifications()
            
            // 2. Setup local observers
            setupNotifications()
            
            // 3. Initial fetch
            fetchNowPlaying()
        }
    
    private func registerForNotifications() {
            guard let bundle = bundle,
                  let ptr = CFBundleGetFunctionPointerForName(bundle, "MRMediaRemoteRegisterForNowPlayingNotifications" as CFString) else { return }
            
            typealias RegisterFunction = @convention(c) (DispatchQueue) -> Void
            let register = unsafeBitCast(ptr, to: RegisterFunction.self)
            register(DispatchQueue.main)
        }
    
    // listening for change track the audio
    func setupNotifications() {
            // Idempotent: observers registered once for the app lifetime.
            guard observerTokens.isEmpty else { return }

            let nc = NotificationCenter.default
            let songChange = NSNotification.Name("kMRMediaRemoteNowPlayingInfoDidChangeNotification")
            let stateChange = NSNotification.Name("kMRPlaybackStateDidChangeNotification")

            // Trigger fetch whenever song or play/pause state changes
            observerTokens.append(nc.addObserver(forName: songChange, object: nil, queue: .main) { [weak self] _ in
                self?.fetchNowPlaying()
            })
            observerTokens.append(nc.addObserver(forName: stateChange, object: nil, queue: .main) { [weak self] _ in
                self?.fetchNowPlaying()
            })
        }

    deinit {
        observerTokens.forEach { NotificationCenter.default.removeObserver($0) }
    }

    // control center
    func sendCommand(_ command: MediaCommand) {
        guard let bundle = bundle,
            let pointer = CFBundleGetFunctionPointerForName(
                bundle,
                "MRMediaRemoteSendCommand" as CFString
            )
        else { return }

        // Command signature: (CommandID, OptionsDictionary) -> Bool
        typealias MRMediaRemoteSendCommandFunction =
            @convention(c) (UInt32, AnyObject?) -> Bool
        let MRMediaRemoteSendCommand = unsafeBitCast(
            pointer,
            to: MRMediaRemoteSendCommandFunction.self
        )

        _ = MRMediaRemoteSendCommand(command.rawValue, nil)
    }

    func fetchNowPlaying() {
        guard let bundle = bundle,
            let getInfoPtr = CFBundleGetFunctionPointerForName(bundle, "MRMediaRemoteGetNowPlayingInfo" as CFString) else { return }

        typealias MRMediaRemoteGetNowPlayingInfoFunction = @convention(c) (DispatchQueue, @escaping ([String: Any]) -> Void) -> Void
        let MRMediaRemoteGetNowPlayingInfo = unsafeBitCast(getInfoPtr, to: MRMediaRemoteGetNowPlayingInfoFunction.self)

        MRMediaRemoteGetNowPlayingInfo(DispatchQueue.main) { [weak self] info in
            guard let self = self else { return }

            DispatchQueue.main.async {
                // An empty info dict means nothing is playing anywhere — MediaRemote
                // often omits the playback-rate key entirely in that case, which
                // previously left `isPlaying` stuck at its last value (spectrum kept
                // animating with no music playing). Reset explicitly.
                guard !info.isEmpty else {
                    self.title = "Not Playing"
                    self.artist = ""
                    self.isPlaying = false
                    if self.lastArtworkData != nil {
                        self.lastArtworkData = nil
                        self.artwork = nil
                    }
                    return
                }

                self.title = info["kMRMediaRemoteNowPlayingInfoTitle"] as? String ?? "Unknown Title"
                self.artist = info["kMRMediaRemoteNowPlayingInfoArtist"] as? String ?? "Unknown Artist"

                // Track playing state (Rate 1.0 = playing, 0.0 = paused)
                self.isPlaying = ((info["kMRMediaRemoteNowPlayingInfoPlaybackRate"] as? Double) ?? 0) > 0

                // Only decode + publish artwork when the bytes actually changed.
                // (Previously: artwork was nil-ed then re-decoded full-size on
                // every fetch, causing flicker and redundant renders.)
                let artworkData = info["kMRMediaRemoteNowPlayingInfoArtworkData"] as? Data
                if artworkData != self.lastArtworkData {
                    self.lastArtworkData = artworkData
                    self.artwork = artworkData.flatMap { MusicManager.downsampledImage(from: $0) }
                }
            }
        }
    }

    // Artwork arrives full-size (often 1000px+) but is displayed at 24–70pt.
    // Downsample once to ~2x display size to keep the published NSImage small.
    private static func downsampledImage(from data: Data, maxPixelSize: CGFloat = 280) -> NSImage? {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil) else {
            return NSImage(data: data)
        }
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceThumbnailMaxPixelSize: maxPixelSize,
            kCGImageSourceCreateThumbnailWithTransform: true
        ]
        guard let cgImage = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else {
            return NSImage(data: data)
        }
        return NSImage(cgImage: cgImage, size: NSSize(width: cgImage.width, height: cgImage.height))
    }

}
