//
//  AppDelegate.swift
//  Rota
//
//  Owns the floating panel, the menu bar item and app lifecycle.
//

import AppKit
import SwiftUI
import Combine
import ServiceManagement

final class AppDelegate: NSObject, NSApplicationDelegate {

    static private(set) var shared: AppDelegate!

    let store = PlayerStore()

    private var panel: RotaPanel!
    private var statusItem: NSStatusItem!
    private var cancellables = Set<AnyCancellable>()

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

        setUpPanel()
        setUpStatusItem()
        store.start()

        // Keep the window shadow in sync with the artwork-driven content.
        store.$artwork
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in self?.panel?.invalidateShadow() }
            .store(in: &cancellables)
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
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

    /// rota://move?corner=topleft|topright|bottomleft|bottomright|center&margin=32
    /// rota://move?x=40&y=60   (coordinates from the screen's top-left corner)
    private func moveWidget(_ url: URL) {
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              let screen = panel.screen ?? NSScreen.main
        else { return }

        var params: [String: String] = [:]
        for item in components.queryItems ?? [] {
            params[item.name.lowercased()] = item.value ?? ""
        }

        let visible = screen.visibleFrame
        let size = panel.frame.size
        let margin = CGFloat(Double(params["margin"] ?? "") ?? 32)
        var origin = panel.frame.origin

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

        panel.setFrameOrigin(origin)
        panel.orderFrontRegardless()
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

    /// Writes a small JSON state snapshot to /tmp/rota_state.json —
    /// handy for scripting and for debugging.
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
            "captureRect": captureRect()
        ]
        if let data = try? JSONSerialization.data(withJSONObject: payload, options: [.prettyPrinted, .sortedKeys]) {
            try? data.write(to: URL(fileURLWithPath: "/tmp/rota_state.json"))
        }
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

    // MARK: - Panel

    private func setUpPanel() {
        let size = NSSize(width: 320, height: 358)
        panel = RotaPanel(
            contentRect: NSRect(origin: .zero, size: size),
            styleMask: [.borderless, .nonactivatingPanel, .resizable],
            backing: .buffered,
            defer: false
        )
        panel.store = store
        panel.minSize = NSSize(width: 272, height: 304)
        panel.maxSize = NSSize(width: 600, height: 671)
        panel.contentAspectRatio = size
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.isMovableByWindowBackground = true
        panel.hidesOnDeactivate = false
        panel.becomesKeyOnlyIfNeeded = false
        panel.acceptsMouseMovedEvents = true
        panel.isReleasedWhenClosed = false
        panel.animationBehavior = .utilityWindow
        applyPlacement(floating: store.keepOnTop)

        let host = NSHostingView(rootView: RootView().environmentObject(store))
        host.frame = NSRect(origin: .zero, size: size)
        panel.contentView = host

        panel.setFrameAutosaveName("RotaPanel")
        let visibleSomewhere = NSScreen.screens.contains { $0.visibleFrame.intersects(panel.frame) }
        if !visibleSomewhere { panel.center() }

        panel.orderFrontRegardless()
    }

    /// Desktop-widget placement: just above the desktop icons, below every
    /// normal window — exactly where macOS's own desktop widgets live.
    /// With `floating` the widget rides above all windows instead.
    private func applyPlacement(floating: Bool) {
        guard let panel else { return }
        if floating {
            panel.level = .floating
            panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        } else {
            panel.level = NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.desktopIconWindow)) + 1)
            panel.collectionBehavior = [.canJoinAllSpaces, .stationary]
        }
    }

    @objc func toggleWidget() {
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

    // MARK: - Menu bar

    private func setUpStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: "waveform.circle.fill",
                                   accessibilityDescription: "Rota")
        }

        let menu = NSMenu()
        menu.addItem(item("Show / Hide Rota", #selector(toggleWidget)))
        menu.addItem(item("Lyrics", #selector(toggleLyrics)))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(item("Float Above Windows", #selector(toggleKeepOnTop)))
        menu.addItem(item("Launch at Login", #selector(toggleLaunchAtLogin)))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(item("Open Apple Music", #selector(openMusic)))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(item("About Rota", #selector(showAbout)))
        menu.addItem(item("Quit Rota", #selector(quit), key: "q"))
        menu.delegate = self
        statusItem.menu = menu
    }

    private func item(_ title: String, _ action: Selector, key: String = "") -> NSMenuItem {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: key)
        item.target = self
        return item
    }

    // MARK: - Actions

    @objc private func toggleLyrics() {
        store.showLyrics.toggle()
        if !panel.isVisible { showWidget() }
    }

    @objc private func toggleKeepOnTop() {
        store.keepOnTop.toggle()
    }

    @objc private func toggleLaunchAtLogin() {
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

    @objc private func openMusic() {
        store.openMusicApp()
    }

    @objc private func showAbout() {
        NSApp.activate(ignoringOtherApps: true)
        NSApp.orderFrontStandardAboutPanel(options: [
            .applicationName: "Rota",
            .credits: NSAttributedString(
                string: "A floating Apple Music widget with synced lyrics.\nrota • latin for “wheel”",
                attributes: [.font: NSFont.systemFont(ofSize: 11)]
            )
        ])
    }

    @objc private func quit() {
        NSApp.terminate(nil)
    }
}

// MARK: - Menu validation (checkmarks)

extension AppDelegate: NSMenuDelegate {
    func menuNeedsUpdate(_ menu: NSMenu) {
        for item in menu.items {
            switch item.action {
            case #selector(toggleLyrics):
                item.state = store.showLyrics ? .on : .off
            case #selector(toggleKeepOnTop):
                item.state = store.keepOnTop ? .on : .off
            case #selector(toggleLaunchAtLogin):
                item.state = SMAppService.mainApp.status == .enabled ? .on : .off
            default:
                break
            }
        }
    }
}

// MARK: - Panel

/// Borderless, non-activating floating panel that hosts the widget.
final class RotaPanel: NSPanel {

    weak var store: PlayerStore?

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }

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
