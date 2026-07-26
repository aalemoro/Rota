//
//  AppDelegate.swift
//  Rota
//
//  Owns the floating panel and app lifecycle. No Dock icon, no menu bar
//  item: everything lives in the widget's right-click menu, and reopening
//  the app (Spotlight, Launchpad) brings the widget back.
//

import AppKit
import SwiftUI
import Combine
import ServiceManagement

// MARK: - Widget sizes (the three official desktop-widget footprints)

enum WidgetSize: String, CaseIterable {
    case small, medium, large

    var dimensions: NSSize {
        switch self {
        case .small: return NSSize(width: 180, height: 180)
        case .medium: return NSSize(width: 360, height: 180)
        case .large: return NSSize(width: 360, height: 360)
        }
    }

    var label: String {
        switch self {
        case .small: return "Small"
        case .medium: return "Medium"
        case .large: return "Large"
        }
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {

    static private(set) var shared: AppDelegate!

    let store = PlayerStore()

    private var panel: RotaPanel!
    private var cancellables = Set<AnyCancellable>()
    private var snapWork: DispatchWorkItem?
    private var suppressSnap = false

    /// The native desktop-widget grid, measured from macOS's own widgets:
    /// slots start 8 pt from the left, 41 pt from the top, on a 180 pt pitch.
    private let gridOrigin = NSPoint(x: 8, y: 41)
    private let gridPitch: CGFloat = 180

    override init() {
        super.init()
        AppDelegate.shared = self
    }

    // MARK: - Lifecycle

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)

        store.onHide = { [weak self] in self?.hideWidget() }
        store.onKeepOnTopChanged = { [weak self] onTop in
            self?.applyPlacement(floating: onTop)
        }
        store.onPositionLockChanged = { [weak self] locked in
            self?.panel?.isMovableByWindowBackground = !locked
        }

        setUpPanel()
        store.start()

        // First run: register as a login item, so the widget is simply
        // *there* after every reboot, like a native desktop widget.
        if UserDefaults.standard.object(forKey: "didSetupLoginItem") == nil {
            UserDefaults.standard.set(true, forKey: "didSetupLoginItem")
            try? SMAppService.mainApp.register()
        }

        // Keep the window shadow in sync with the artwork-driven content.
        store.$artwork
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in self?.panel?.invalidateShadow() }
            .store(in: &cancellables)
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }

    /// Launching Rota again (Spotlight, Launchpad, `open -a Rota`) while it's
    /// running brings the widget back — the recovery path now that there is
    /// no menu bar icon.
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        showWidget()
        return false
    }

    // MARK: - rota:// URL scheme (scripting & automation)

    func application(_ application: NSApplication, open urls: [URL]) {
        for url in urls { handle(url) }
    }

    private func handle(_ url: URL) {
        guard url.scheme?.lowercased() == "rota" else { return }
        switch url.host?.lowercased() {
        case "show":
            showWidget()
        case "hide":
            hideWidget()
        case "toggle":
            toggleWidget()
        case "lyrics":
            store.showLyrics = true
            if !panel.isVisible { showWidget() }
        case "player":
            store.showLyrics = false
        case "playpause":
            store.togglePlayPause()
        case "next":
            store.nextTrack()
        case "previous", "prev":
            store.previousTrack()
        case "favorite":
            store.toggleFavorite()
        case "lock":
            store.positionLocked = true
        case "unlock":
            store.positionLocked = false
        case "size":
            if let value = URLComponents(url: url, resolvingAgainstBaseURL: false)?
                .queryItems?.first(where: { $0.name.lowercased() == "value" })?.value,
               let size = WidgetSize(rawValue: value.lowercased()) {
                setWidgetSize(size)
            }
        case "dump":
            dumpState()
        case "snapshot":
            snapshotWidget()
        case "move":
            moveWidget(url)
        default:
            break
        }
    }

    // MARK: - Panel

    private func setUpPanel() {
        let size = currentWidgetSize.dimensions
        panel = RotaPanel(
            contentRect: NSRect(origin: .zero, size: size),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.store = store
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.isMovableByWindowBackground = !store.positionLocked
        panel.hidesOnDeactivate = false
        panel.becomesKeyOnlyIfNeeded = false
        panel.acceptsMouseMovedEvents = true
        panel.isReleasedWhenClosed = false
        panel.animationBehavior = .utilityWindow
        applyPlacement(floating: store.keepOnTop)

        let host = NSHostingView(rootView: RootView().environmentObject(store))
        host.frame = NSRect(origin: .zero, size: size)
        panel.contentView = host

        panel.setFrameAutosaveName("RotaPanelSquare")
        let visibleSomewhere = NSScreen.screens.contains { $0.visibleFrame.intersects(panel.frame) }
        if !visibleSomewhere || panel.frame.origin == .zero {
            placeDefault()
        }

        // Enforce the chosen fixed size and settle into the native grid.
        applyWidgetSize(currentWidgetSize, animate: false)

        // Snap into the grid whenever a drag ends, like real widgets do.
        NotificationCenter.default.addObserver(
            forName: NSWindow.didMoveNotification, object: panel, queue: .main
        ) { [weak self] _ in
            self?.scheduleSnap()
        }

        panel.orderFrontRegardless()
    }

    func toggleWidget() {
        if panel.isVisible {
            hideWidget()
        } else {
            showWidget()
        }
    }

    func showWidget() {
        panel.orderFrontRegardless()
        store.pollNow()
    }

    func hideWidget() {
        panel.orderOut(nil)
    }

    /// Desktop-widget placement: above macOS's own desktop widgets (+3;
    /// they sit at +2) yet far below every normal window. With `floating`
    /// the widget rides above all windows instead.
    private func applyPlacement(floating: Bool) {
        guard let panel else { return }
        if floating {
            panel.level = .floating
            panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        } else {
            panel.level = NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.desktopIconWindow)) + 3)
            panel.collectionBehavior = [.canJoinAllSpaces, .stationary]
        }
    }

    /// Default home: bottom-left region of the desktop.
    private func placeDefault() {
        guard let screen = panel.screen ?? NSScreen.main else { return }
        let visible = screen.visibleFrame
        panel.setFrameOrigin(NSPoint(x: visible.minX + 24, y: visible.minY + 24))
    }

    // MARK: - Fixed sizes

    var currentWidgetSize: WidgetSize {
        WidgetSize(rawValue: UserDefaults.standard.string(forKey: "widgetSize") ?? "") ?? .large
    }

    func setWidgetSize(_ size: WidgetSize) {
        UserDefaults.standard.set(size.rawValue, forKey: "widgetSize")
        applyWidgetSize(size, animate: true)
    }

    private func applyWidgetSize(_ size: WidgetSize, animate: Bool) {
        let dims = size.dimensions
        var frame = panel.frame
        let topY = frame.maxY
        frame.size = dims
        frame.origin.y = topY - dims.height
        setFrameQuietly(snappedToGrid(frame), animate: animate)
    }

    // MARK: - Native grid snapping

    private func snappedToGrid(_ frame: NSRect) -> NSRect {
        guard let screen = panel.screen ?? NSScreen.main else { return frame }
        let originX = screen.frame.minX + gridOrigin.x
        let fromTop = screen.frame.maxY - frame.maxY

        let column = max(0, round((frame.origin.x - originX) / gridPitch))
        let row = max(0, round((fromTop - gridOrigin.y) / gridPitch))

        var snapped = frame
        snapped.origin.x = originX + column * gridPitch
        snapped.origin.y = screen.frame.maxY - (gridOrigin.y + row * gridPitch) - frame.height

        // Never off the right edge (vertically the grid itself stays on
        // screen — macOS's own bottom row tucks slightly behind the Dock).
        if snapped.maxX > screen.frame.maxX - gridOrigin.x {
            snapped.origin.x = originX + max(0, floor((screen.frame.width - 2 * gridOrigin.x - frame.width) / gridPitch)) * gridPitch
        }
        return snapped
    }

    private func scheduleSnap() {
        guard !suppressSnap else { return }
        snapWork?.cancel()
        let work = DispatchWorkItem { [weak self] in self?.snapNow() }
        snapWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3, execute: work)
    }

    private func snapNow() {
        let target = snappedToGrid(panel.frame)
        guard target != panel.frame else { return }
        setFrameQuietly(target, animate: true)
    }

    private func setFrameQuietly(_ frame: NSRect, animate: Bool) {
        suppressSnap = true
        panel.setFrame(frame, display: true, animate: animate)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) { [weak self] in
            self?.suppressSnap = false
        }
    }

    // MARK: - Launch at login

    var launchesAtLogin: Bool {
        SMAppService.mainApp.status == .enabled
    }

    func toggleLaunchAtLogin() {
        do {
            if SMAppService.mainApp.status == .enabled {
                try SMAppService.mainApp.unregister()
            } else {
                try SMAppService.mainApp.register()
            }
        } catch {
            NSLog("Rota: launch-at-login toggle failed: \(error)")
        }
    }

    func openMusic() {
        store.openMusicApp()
    }

    // MARK: - rota://move

    /// rota://move?corner=topleft|topright|bottomleft|bottomright|center&margin=32
    /// rota://move?x=40&y=60          (from the visible area's top-left)
    /// rota://move?gx=8&gy=581&w=360&h=360   (global CGWindow-style frame)
    private func moveWidget(_ url: URL) {
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              let screen = panel.screen ?? NSScreen.main
        else { return }

        var params: [String: String] = [:]
        for item in components.queryItems ?? [] {
            params[item.name.lowercased()] = item.value ?? ""
        }

        let visible = screen.visibleFrame
        var size = panel.frame.size
        let margin = CGFloat(Double(params["margin"] ?? "") ?? 32)
        var origin = panel.frame.origin

        if let wText = params["w"], let w = Double(wText), w >= 100 {
            size.width = CGFloat(w)
        }
        if let hText = params["h"], let h = Double(hText), h >= 100 {
            size.height = CGFloat(h)
        }

        if let corner = params["corner"]?.lowercased() {
            switch corner {
            case "topleft":
                origin = NSPoint(x: visible.minX + margin, y: visible.maxY - size.height - margin)
            case "topright":
                origin = NSPoint(x: visible.maxX - size.width - margin, y: visible.maxY - size.height - margin)
            case "bottomleft":
                origin = NSPoint(x: visible.minX + margin, y: visible.minY + margin)
            case "bottomright":
                origin = NSPoint(x: visible.maxX - size.width - margin, y: visible.minY + margin)
            case "center":
                origin = NSPoint(x: visible.midX - size.width / 2, y: visible.midY - size.height / 2)
            default:
                break
            }
        }
        if let xText = params["x"], let x = Double(xText) {
            origin.x = visible.minX + CGFloat(x)
        }
        if let yText = params["y"], let y = Double(yText) {
            origin.y = visible.maxY - size.height - CGFloat(y)
        }

        if let primary = NSScreen.screens.first {
            if let gxText = params["gx"], let gx = Double(gxText) {
                origin.x = CGFloat(gx)
            }
            if let gyText = params["gy"], let gy = Double(gyText) {
                origin.y = primary.frame.maxY - CGFloat(gy) - size.height
            }
        }

        setFrameQuietly(NSRect(origin: origin, size: size), animate: false)
        panel.orderFrontRegardless()
    }

    // MARK: - Debug / scripting helpers

    private func dumpState() {
        let s = store.snapshot
        let lyricsDescription: String
        switch store.lyrics.state {
        case .idle: lyricsDescription = "idle"
        case .loading: lyricsDescription = "loading"
        case .synced(let lines): lyricsDescription = "synced(\(lines.count))"
        case .plain(let lines): lyricsDescription = "plain(\(lines.count))"
        case .instrumental: lyricsDescription = "instrumental"
        case .unavailable: lyricsDescription = "unavailable"
        }
        let payload: [String: Any] = [
            "availability": "\(store.availability)",
            "playback": "\(s.state)",
            "title": s.title,
            "artist": s.artist,
            "album": s.album,
            "duration": s.duration,
            "position": store.displayPosition,
            "shuffle": s.shuffle,
            "repeat": s.repeatMode.rawValue,
            "volume": s.volume,
            "favorited": s.favorited,
            "hasArtwork": store.artwork != nil,
            "lyrics": lyricsDescription,
            "widgetVisible": panel.isVisible,
            "lyricsMode": store.showLyrics,
            "widgetSize": currentWidgetSize.rawValue,
            "source": s.source.rawValue,
            "captureRect": captureRect()
        ]
        if let data = try? JSONSerialization.data(withJSONObject: payload, options: [.prettyPrinted, .sortedKeys]) {
            try? data.write(to: URL(fileURLWithPath: "/tmp/rota_state.json"))
        }
    }

    /// Renders the widget's own view hierarchy to /tmp/rota_snapshot.png
    /// (retina scale, transparent rounded corners). No screen-recording
    /// permission needed — the app draws itself.
    private func snapshotWidget() {
        guard let view = panel.contentView,
              let rep = view.bitmapImageRepForCachingDisplay(in: view.bounds)
        else { return }
        view.cacheDisplay(in: view.bounds, to: rep)
        guard let data = rep.representation(using: .png, properties: [:]) else { return }
        try? data.write(to: URL(fileURLWithPath: "/tmp/rota_snapshot.png"))
    }

    /// The widget's frame in top-left-origin screen coordinates,
    /// ready for `screencapture -R`.
    private func captureRect() -> [Double] {
        guard let screen = panel.screen ?? NSScreen.screens.first else { return [] }
        let frame = panel.frame
        let x = frame.origin.x - screen.frame.origin.x
        let y = screen.frame.maxY - frame.maxY
        return [x, y, frame.width, frame.height]
    }
}

// MARK: - Panel

/// Borderless, non-activating panel that hosts the widget.
final class RotaPanel: NSPanel {

    weak var store: PlayerStore?

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }

    /// With the position locked, ⌘-drag still moves the widget —
    /// the same "explicit gesture" idea as macOS's widget edit mode.
    override func mouseDown(with event: NSEvent) {
        if let store, store.positionLocked, event.modifierFlags.contains(.command) {
            performDrag(with: event)
            return
        }
        super.mouseDown(with: event)
    }

    override func keyDown(with event: NSEvent) {
        guard let store else { return super.keyDown(with: event) }
        switch event.keyCode {
        case 49:  // space
            store.togglePlayPause()
        case 123: // ←
            store.previousTrack()
        case 124: // →
            store.nextTrack()
        case 126: // ↑
            store.adjustVolume(by: 6)
        case 125: // ↓
            store.adjustVolume(by: -6)
        case 37:  // L
            store.showLyrics.toggle()
        case 3:   // F
            store.toggleFavorite()
        case 53:  // esc
            if store.showLyrics {
                store.showLyrics = false
            } else {
                orderOut(nil)
            }
        default:
            super.keyDown(with: event)
        }
    }
}
