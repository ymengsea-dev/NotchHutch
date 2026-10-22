import SwiftUI
import AppKit
import Combine
import QuartzCore

final class NotchWindowController {
    
    static let shared = NotchWindowController()
    
    @ObservedObject var shelfManager = ShelfManager.shared
    
    private var window: NSWindow?
    private var trackingView: TrackingView?
    private var notchSize: CGSize?
    private var isAnimating = false
    private var mouseCheckTimer: Timer?
    private var dragMonitor: Any?
    
    private var isCameraRunning = false
    
    private var tabManager = TabManager.share
    private let settings = SettingsManager.shared
    
    private var pendingExpandWorkItem: DispatchWorkItem?
    private var tabSelectionCancellable: AnyCancellable?

    private init() {
        // When the user switches tabs, recompute the notch window size.
        // This is required because expanded height depends on `selectedTab`.
        tabSelectionCancellable = tabManager.$selectedTab
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.handleSelectedTabChanged()
            }

        // Registered once here (singleton) rather than in createWindow(),
        // so recreating the window can never stack duplicate observers.
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(applicationDidBecomeActive),
            name: NSApplication.didBecomeActiveNotification,
            object: nil
        )

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(applicationDidResignActive),
            name: NSApplication.didResignActiveNotification,
            object: nil
        )

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(cameraStateChanged(_:)),
            name: NSNotification.Name("CameraStateChanged"),
            object: nil
        )
    }

    private func handleSelectedTabChanged() {
        // Only resize if the notch window is currently expanded and visible.
        guard window != nil, trackingView?.isExpanded == true else { return }
        setExpanded(true)
    }

    // Shared by hover-expand (after its dwell delay) and click-to-expand.
    private func performExpand() {
        // Set tab when expanding so shelf tab is correct (e.g. after dragging files out, first hover shows home).
        // Do not override the webcam tab — keeps window at 300pt and avoids flick when re-expanding.
        if tabManager.selectedTab != .webcam {
            if settings.isOpenFileWhenHasItem {
                tabManager.selectedTab = shelfManager.items.isEmpty ? .home : .file
            } else {
                tabManager.selectedTab = .home
            }
        }
        setExpanded(true)
        NotificationCenter.default.post(name: NSNotification.Name("NotchExpanded"), object: true)
    }
    
    func show() {
        if window == nil {
            createWindow()
            startDragMonitor()
        }
        window?.makeKeyAndOrderFront(nil)
    }
    
    private func startDragMonitor() {
            // monitors the mouse even when it's NOT over your window
            dragMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDragged]) { [weak self] event in
                self?.handleGlobalDrag()
            }
        }
    
    private func handleGlobalDrag() {
            guard self.window != nil else { return }

            // Cheap check first: is the mouse even near the notch strip?
            // This runs for every drag event system-wide, so bail out before
            // touching the pasteboard (which is comparatively expensive).
            let mouseLocation = NSEvent.mouseLocation
            guard mouseLocation.y > (NSScreen.main?.frame.height ?? 0) - 20 else { return }

            // Already expanded on the file tab — nothing to do.
            if tabManager.selectedTab == .file, trackingView?.isExpanded == true { return }

            // Check if what is being dragged is actually a file
            let pasteboard = NSPasteboard(name: .drag)
            guard pasteboard.canReadObject(forClasses: [NSURL.self], options: nil) else { return }

            // Always switch to file tab when dragging a file
            DispatchQueue.main.async {
                self.tabManager.selectedTab = .file

                if !(self.trackingView?.isExpanded ?? false) {
                    self.setExpanded(true)
                    NotificationCenter.default.post(name: NSNotification.Name("NotchExpanded"), object: true)
                }
            }
        }
    
    func hide(){
        stopMouseCheckTimer()
        window?.orderOut(nil)
    }
    
    deinit {
        stopMouseCheckTimer()
        NotificationCenter.default.removeObserver(self)
        if let dragMonitor = dragMonitor {
            NSEvent.removeMonitor(dragMonitor)
        }
    }
     
    // create floating window for notch
    private func createWindow(){
        guard let screen = NSScreen.main else {return}
        
        // Initialize notch size: height from the real hardware notch (or a
        // proportional fallback), width from the real hardware notch too —
        // NOT from settingsWidth, which is the *expanded* content width and
        // is unrelated to how wide the physical notch actually is.
        let settingsWidth = CGFloat(settings.notchSize.rawValue)
        if let screenNotchSize = screen.notchSize {
            notchSize = screenNotchSize
        } else {
            // Fallback: use proportional height
            notchSize = CGSize(width: 180, height: settingsWidth * 32 / 100)
        }

        let screenFrame = screen.frame

        let collapsedHeight: CGFloat = (notchSize?.height ?? 42)
        let expandedWidth: CGFloat = settingsWidth // width of notch when it expanded
        let expandedHeight: CGFloat = tabManager.selectedTab == .webcam ? 300 : 140 // height of notch when it expanded
        
        // Always use expanded size for window frame to prevent mouse tracking issues
        let x = (screenFrame.width - expandedWidth) / 2
        let y = screenFrame.height - screen.safeAreaInsets.top + 6 - (expandedHeight - collapsedHeight)
                 
        let frame = NSRect(
            x: x,
            y: y,
            width: expandedWidth,
            height: expandedHeight
        )
        
        let hostingView = NSHostingView(rootView: NotchView {
            NotchTabContainer()
        }.environmentObject(settings))
        
        // Create tracking view wrapper matching window size
        let trackingView = TrackingView(frame: NSRect(x: 0, y: 0, width: expandedWidth, height: expandedHeight))
        self.trackingView = trackingView
        
        // Calculate collapsed notch rect (centered horizontally, at the top).
        // Width is the real hardware notch width, NOT +100. The +100 in
        // NotchView is only drawn while music is playing (artwork + spectrum
        // overflowing past the physical notch) — most of the time (idle,
        // no music) nothing is visibly drawn past the real notch, so the
        // hover-trigger zone must match that narrower idle-state width or
        // moving the mouse near the notch's sides (but not over it) would
        // wrongly trigger expand.
        let collapsedNotchWidth = notchSize?.width ?? 180
        let collapsedNotchHeight = collapsedHeight
        let collapsedNotchX = (expandedWidth - collapsedNotchWidth) / 2
        let collapsedNotchY = expandedHeight - collapsedNotchHeight
        trackingView.collapsedNotchRect = NSRect(
            x: collapsedNotchX,
            y: collapsedNotchY,
            width: collapsedNotchWidth,
            height: collapsedNotchHeight
        )
        
        trackingView.onMouseEntered = { [weak self] in
            guard let self = self, !(self.trackingView?.isExpanded ?? false) else { return }
            // Click-to-expand mode: hovering never auto-expands, a click does.
            guard !self.settings.isClickToExpand else { return }
            self.pendingExpandWorkItem?.cancel()
            let workItem = DispatchWorkItem { [weak self] in
                self?.performExpand()
            }
            self.pendingExpandWorkItem = workItem
            // Respect the user's Extend Sensitivity setting exactly — no
            // added floor. Accidental-hover mitigation is the "Click to
            // expand" toggle above, not a forced minimum delay here.
            DispatchQueue.main
                .asyncAfter(
                    deadline: .now() + settings.expandSensitivity,
                    execute: workItem
                )
        }
        trackingView.onMouseDown = { [weak self] in
            guard let self = self, self.settings.isClickToExpand,
                  !(self.trackingView?.isExpanded ?? false) else { return }
            self.pendingExpandWorkItem?.cancel()
            self.performExpand()
        }
        trackingView.onMouseExited = { [weak self] in
            guard let self = self else { return }
            
            self.pendingExpandWorkItem?.cancel()
            self.pendingExpandWorkItem = nil
            
            // Only handle mouse exit when expanded (to collapse)
            guard let trackingView = self.trackingView, trackingView.isExpanded else { return }
            
            // Add delay from settings to prevent flicker when mouse moves during animation
            let delay = self.settings.expandSensitivity
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
                // The periodic timer will handle checking, but we can also check here
                self?.checkMousePosition()
            }
        }
        
        trackingView.addSubview(hostingView)
        hostingView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            hostingView.topAnchor.constraint(equalTo: trackingView.topAnchor),
            hostingView.leadingAnchor.constraint(equalTo: trackingView.leadingAnchor),
            hostingView.trailingAnchor.constraint(equalTo: trackingView.trailingAnchor),
            hostingView.bottomAnchor.constraint(equalTo: trackingView.bottomAnchor)
        ])
        
        let window = NSWindow(
            contentRect: frame,
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )

        window.contentView = trackingView
        window.isOpaque = false
        window.backgroundColor = .clear
        window.hasShadow = false
        window.registerForDraggedTypes([.fileURL])

        window.level = .statusBar
        window.collectionBehavior = [
            .canJoinAllSpaces,
            .fullScreenAuxiliary,
            .ignoresCycle
        ]

        self.window = window
    }
    
    @objc private func cameraStateChanged(_ notification: Notification) {
        guard let isRunning = notification.object as? Bool else { return }
        isCameraRunning = isRunning

        if settings.keepsNotchExpandedWhenCameraOn {
            if isCameraRunning {
                // Force expand if camera is on
                setExpanded(true)
                NotificationCenter.default.post(name: NSNotification.Name("NotchExpanded"), object: true)
                // Collapse is impossible while pinned — no point polling the
                // mouse 5x/second for the whole camera session.
                stopMouseCheckTimer()
            } else {
                // Camera stopped: resume polling if still expanded, then
                // collapse immediately if the mouse is already outside.
                if trackingView?.isExpanded == true {
                    startMouseCheckTimer()
                }
                checkMousePosition()
            }
        }
    }
    
    @objc private func applicationDidBecomeActive() {
        // When application becomes active, check mouse position
        // This helps recover from Spaces transitions
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            self.checkMousePosition()
        }
    }
    
    @objc private func applicationDidResignActive() {
        // When application loses focus (e.g., during Spaces transition), collapse if expanded
        if trackingView?.isExpanded == true {
            setExpanded(false)
            NotificationCenter.default.post(name: NSNotification.Name("NotchExpanded"), object: false)
        }
    }
    
    private func checkMousePosition() {
        guard let window = window, let trackingView = trackingView else { return }
        
        let mouseLocation = NSEvent.mouseLocation
        let windowFrame = window.frame
        
        if trackingView.isExpanded {
            // If expanded, check if mouse is still in window
            if !windowFrame.contains(mouseLocation) {
                // Check if we should keep it open due to camera
                if settings.keepsNotchExpandedWhenCameraOn && isCameraRunning {
                    return
                }
                if tabManager.selectedTab == .webcam {
                    tabManager.selectedTab = .home
                } else if settings.isOpenFileWhenHasItem {
                    tabManager.selectedTab = shelfManager.items.isEmpty ? .home : .file
                } else {
                    tabManager.selectedTab = .home
                }

                setExpanded(false)
                
                NotificationCenter.default.post(name: NSNotification.Name("NotchExpanded"), object: false)
            }
        } else {
            // If collapsed, check if mouse is over the collapsed notch area
            let windowMouseLocation = NSPoint(
                x: mouseLocation.x - windowFrame.origin.x,
                y: mouseLocation.y - windowFrame.origin.y
            )
            // Convert to view coordinates (flip Y)
            let viewMouseLocation = NSPoint(
                x: windowMouseLocation.x,
                y: windowFrame.height - windowMouseLocation.y
            )
            if !settings.isClickToExpand && trackingView.collapsedNotchRect.contains(viewMouseLocation) {
                setExpanded(true)
                NotificationCenter.default.post(name: NSNotification.Name("NotchExpanded"), object: true)
            }
        }
    }
    
    private func startMouseCheckTimer() {
        stopMouseCheckTimer()
        // Check mouse position periodically when expanded to handle gesture interruptions
        // Timer automatically runs on current run loop (main thread)
        mouseCheckTimer = Timer.scheduledTimer(withTimeInterval: 0.2, repeats: true) { [weak self] _ in
            self?.checkMousePosition()
        }
    }
    
    private func stopMouseCheckTimer() {
        mouseCheckTimer?.invalidate()
        mouseCheckTimer = nil
    }
    
    func setExpanded(_ expanded: Bool){
        // Ignore if already animating
        guard !isAnimating, let window, let screen = NSScreen.main else { return }
        
        // Update tracking view expanded state
        trackingView?.isExpanded = expanded
        
        // Start/stop periodic mouse checking when expanded
        if expanded {
            startMouseCheckTimer()
        } else {
            stopMouseCheckTimer()
        }
        
        // Ensure notch size is initialized: height + width from the real
        // hardware notch (see createWindow for why width isn't settingsWidth).
        let settingsWidth = CGFloat(settings.notchSize.rawValue)
        if let screenNotchSize = screen.notchSize {
            notchSize = screenNotchSize
        } else {
            // Fallback: use proportional height
            notchSize = CGSize(width: 180, height: settingsWidth * 32 / 100)
        }
        
        let safeInsets = screen.safeAreaInsets
        let screenFrame = screen.frame

        // Add extra height to extend below physical notch for displaying content
        let collapsedHeight = (notchSize?.height ?? 42)
        let expandedWidth = settingsWidth
        let expandedHeight: CGFloat = tabManager.selectedTab == .webcam ? 300 : 140
        
        // Window always stays at expanded size, we just animate the visual content
        // This prevents mouse tracking issues
        let width = expandedWidth
        let height = expandedHeight

        let x = (screenFrame.width - width) / 2
        let y = screenFrame.height - safeInsets.top + 6 - (expandedHeight - collapsedHeight)

        let newFrame = NSRect(x: x, y: y, width: width, height: height)
        
        // Mark as animating
        isAnimating = true
        
        // Animate with completion handler.
        // Opening overshoots slightly past target size then settles back —
        // a real visible bounce on the window frame itself (the classic
        // "back-out" cubic-bezier trick: y > 1 control points create
        // overshoot without needing true spring physics on an NSWindow).
        // Closing has no bounce — a crisp, fast snap shut.
        NSAnimationContext.runAnimationGroup({ context in
            context.duration = expanded ? 0.32 : 0.2
            context.timingFunction = expanded
                ? CAMediaTimingFunction(controlPoints: 0.34, 1.56, 0.64, 1)
                : CAMediaTimingFunction(name: .easeIn)
            window.animator().setFrame(newFrame, display: true)
        }, completionHandler: { [weak self] in
            guard let self else { return }
            self.isAnimating = false
            // Update collapsed notch rect after resize so hover-to-expand works on webcam tab.
            // (It was only set in createWindow; after resizing height it was wrong.)
            let collapsedNotchWidth = self.notchSize?.width ?? 180
            let collapsedNotchHeight = self.notchSize?.height ?? 42
            let collapsedNotchX = (expandedWidth - collapsedNotchWidth) / 2
            let collapsedNotchY = expandedHeight - collapsedNotchHeight
            self.trackingView?.collapsedNotchRect = NSRect(
                x: collapsedNotchX,
                y: collapsedNotchY,
                width: collapsedNotchWidth,
                height: collapsedNotchHeight
            )
        })
    }
    
    func showSettingsWindow(){
        NSApplication.shared.activate(ignoringOtherApps: true)
        if let window = NSApp.windows.first(where: { $0.identifier?.rawValue == "SettingsWindow" }) {
                window.makeKeyAndOrderFront(nil)
                return
            }
        let window = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 700, height: 500),
                styleMask: [.titled, .closable, .miniaturizable, .fullSizeContentView],
                backing: .buffered,
                defer: false
            )
        
        window.identifier = NSUserInterfaceItemIdentifier("SettingsWindow")
        window.titleVisibility = .hidden // Hides the title text
        window.titlebarAppearsTransparent = true
        window.toolbarStyle = .unified // Aligns buttons with the sidebar
        
        window.isReleasedWhenClosed = false
        window.center()
        window.contentView = NSHostingView(rootView: SettingsWindowView())
        window.makeKeyAndOrderFront(nil)
    }
    
}
