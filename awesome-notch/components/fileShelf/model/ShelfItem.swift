import SwiftUI
import UniformTypeIdentifiers
import ImageIO

struct ShelfItem: Identifiable{
    let id = UUID()
    let url: URL
    // Decoded once at init (call ShelfItem(url:) off the main thread).
    // Previously this was a computed property doing a full-resolution
    // NSImage(contentsOf:) disk decode on every SwiftUI render.
    let displayImage: NSImage

    init(url: URL) {
        self.url = url
        self.displayImage = ShelfItem.makeThumbnail(for: url)
    }

    private static func makeThumbnail(for url: URL, maxPixelSize: CGFloat = 168) -> NSImage {
        if let type = UTType(filenameExtension: url.pathExtension),
           type.conforms(to: .image),
           let source = CGImageSourceCreateWithURL(url as CFURL, nil) {
            let options: [CFString: Any] = [
                kCGImageSourceCreateThumbnailFromImageAlways: true,
                kCGImageSourceThumbnailMaxPixelSize: maxPixelSize,
                kCGImageSourceCreateThumbnailWithTransform: true
            ]
            if let cgImage = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) {
                return NSImage(cgImage: cgImage, size: NSSize(width: cgImage.width, height: cgImage.height))
            }
        }
        // Non-image files (and failed decodes) fall back to the Finder icon.
        return NSWorkspace.shared.icon(forFile: url.path)
    }
}
