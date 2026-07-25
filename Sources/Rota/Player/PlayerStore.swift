//
//  PlayerStore.swift
//  Rota
//
//  Single source of truth for the UI. Polls the Music app, listens for
//  its distributed notifications, and exposes optimistic actions.
//

import AppKit
import SwiftUI
import Combine
import CoreImage

final class PlayerStore: ObservableObject {

    enum Availability: Equatable {
        case ready
        case musicNotRunning
        case needsAutomationPermission
    }

    // MARK: Published state

    @Published private(set) var snapshot = MusicSnapshot()
    @Published private(set) var availability: Availability = .musicNotRunning
    @Published private(set) var artwork: NSImage?
    /// Pre-blurred + saturated variant of the artwork, baked once with
    /// CoreImage so every rendering path (screen, snapshots) looks identical.
    @Published private(set) var artworkBlurred: NSImage?
    @Published private(set) var displayPosition: Double = 0
    @Published var isScrubbing = false
    @Published var scrubPosition: Double = 0

    @Published var showLyrics = false {
        didSet {
            guard showLyrics else { return }
            lyrics.ensureLoaded(for: snapshot)
        }
    }

    /// `false` (default) = true desktop widget, pinned just above the
    /// wallpaper. `true` = floats above every window.
    @Published var keepOnTop: Bool = UserDefaults.standard.object(forKey: "keepOnTop") as? Bool ?? false {
        didSet {
            UserDefaults.standard.set(keepOnTop, forKey: "keepOnTop")
            onKeepOnTopChanged?(keepOnTop)
        }
    }

    /// Native-widget behaviour: when locked (default) the widget stays put —
    /// dragging the cover does nothing. Move it with ⌘-drag or the menu.
    @Published var positionLocked: Bool = UserDefaults.standard.object(forKey: "positionLocked") as? Bool ?? true {
        didSet {
            UserDefaults.standard.set(positionLocked, forKey: "positionLocked")
            onPositionLockChanged?(positionLocked)
        }
    }

    let lyrics = LyricsController()

    /// Wired by the AppDelegate.
    var onHide: (() -> Void)?
    var onKeepOnTopChanged: ((Bool) -> Void)?
    var onPositionLockChanged: ((Bool) -> Void)?

    // MARK: Private

    private let bridge = MusicBridge()
    private var pollTimer: Timer?
    private var tickTimer: Timer?
    private var lastPollDate = Date()
    private var artworkTrackID: String?
    private var artworkCache = NSCache<NSString, NSImage>()
    private var blurredCache = NSCache<NSString, NSImage>()
    private var observers: [NSObjectProtocol] = []
    private var polling = false
    private var volumeWork: DispatchWorkItem?
    /// While set, polled `favorited` values are ignored — Apple Music's cloud
    /// state lags a few seconds behind a local change.
    private var favoriteHoldUntil = Date.distantPast

    // MARK: - Lifecycle

    func start() {
        artworkCache.countLimit = 12

        let dnc = DistributedNotificationCenter.default()
        observers.append(dnc.addObserver(
            forName: NSNotification.Name("com.apple.Music.playerInfo"),
            object: nil, queue: .main
        ) { [weak self] _ in
            self?.pollNow()
        })

        let wnc = NSWorkspace.shared.notificationCenter
        for name in [NSWorkspace.didLaunchApplicationNotification,
                     NSWorkspace.didTerminateApplicationNotification] {
            observers.append(wnc.addObserver(forName: name, object: nil, queue: .main) { [weak self] note in
                let app = note.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication
                if app?.bundleIdentifier == MusicBridge.musicBundleID {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { self?.pollNow() }
                }
            })
        }

        pollTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.pollNow()
        }
        tickTimer = Timer.scheduledTimer(withTimeInterval: 0.25, repeats: true) { [weak self] _ in
            self?.tick()
        }

        pollNow()
    }

    // MARK: - Polling

    func pollNow() {
        guard bridge.isMusicRunning else {
            if availability != .musicNotRunning {
                availability = .musicNotRunning
                snapshot = MusicSnapshot()
                artwork = nil
                artworkTrackID = nil
                displayPosition = 0
            }
            return
        }
        guard !polling else { return }
        polling = true

        bridge.snapshot { [weak self] result in
            guard let self else { return }
            self.polling = false
            switch result {
            case .success(let snap):
                self.apply(snap)
            case .failure(let error):
                switch error {
                case BridgeError.notAuthorized:
                    self.availability = .needsAutomationPermission
                case BridgeError.musicNotRunning:
                    self.availability = .musicNotRunning
                default:
                    break // transient — keep the last good state
                }
            }
        }
    }

    private func apply(_ snap: MusicSnapshot) {
        let trackChanged = snap.persistentID != snapshot.persistentID
        let localFavorite = snapshot.favorited

        availability = .ready
        snapshot = snap
        if !trackChanged, Date() < favoriteHoldUntil {
            snapshot.favorited = localFavorite
        }
        lastPollDate = Date()
        if !isScrubbing {
            displayPosition = snap.position
        }

        if snap.hasTrack, artworkTrackID != snap.persistentID {
            artworkTrackID = snap.persistentID
            loadArtwork(for: snap.persistentID)
        } else if !snap.hasTrack, artwork != nil {
            artwork = nil
            artworkBlurred = nil
            artworkTrackID = nil
        }

        if trackChanged {
            lyrics.trackDidChange(for: snap, loadNow: showLyrics)
        }
    }

    /// Smoothly advances the progress bar between polls.
    private func tick() {
        guard snapshot.state == .playing, !isScrubbing else { return }
        let projected = snapshot.position + Date().timeIntervalSince(lastPollDate)
        displayPosition = snapshot.duration > 0 ? min(projected, snapshot.duration) : projected
    }

    private func loadArtwork(for id: String) {
        if let cached = artworkCache.object(forKey: id as NSString) {
            artwork = cached
            artworkBlurred = blurredCache.object(forKey: id as NSString)
            if artworkBlurred == nil { bakeBlur(for: cached, id: id) }
            return
        }
        bridge.artwork { [weak self] image in
            guard let self else { return }
            // Ignore stale replies after further track changes.
            guard self.artworkTrackID == id else { return }
            self.artwork = image
            self.artworkBlurred = nil
            if let image {
                self.artworkCache.setObject(image, forKey: id as NSString)
                self.bakeBlur(for: image, id: id)
            }
        }
    }

    private func bakeBlur(for image: NSImage, id: String) {
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let blurred = Self.blurredVariant(of: image)
            DispatchQueue.main.async {
                guard let self, self.artworkTrackID == id else { return }
                self.artworkBlurred = blurred
                if let blurred {
                    self.blurredCache.setObject(blurred, forKey: id as NSString)
                }
            }
        }
    }

    /// Downscales, saturates and gaussian-blurs the artwork with CoreImage.
    private static func blurredVariant(of image: NSImage) -> NSImage? {
        guard let tiff = image.tiffRepresentation,
              let input = CIImage(data: tiff)
        else { return nil }

        let maxDimension = max(input.extent.width, input.extent.height)
        guard maxDimension > 0 else { return nil }
        let scale = min(1, 720 / maxDimension)
        let scaled = input.transformed(by: CGAffineTransform(scaleX: scale, y: scale))

        guard let colorFilter = CIFilter(name: "CIColorControls"),
              let blurFilter = CIFilter(name: "CIGaussianBlur")
        else { return nil }

        colorFilter.setValue(scaled, forKey: kCIInputImageKey)
        colorFilter.setValue(1.35, forKey: kCIInputSaturationKey)
        guard let saturated = colorFilter.outputImage else { return nil }

        blurFilter.setValue(saturated.clampedToExtent(), forKey: kCIInputImageKey)
        blurFilter.setValue(32.0, forKey: kCIInputRadiusKey)
        guard let output = blurFilter.outputImage else { return nil }

        let context = CIContext(options: [.useSoftwareRenderer: false])
        guard let cg = context.createCGImage(output, from: scaled.extent) else { return nil }
        return NSImage(cgImage: cg, size: NSSize(width: scaled.extent.width, height: scaled.extent.height))
    }

    private func pollSoon(after delay: TimeInterval = 0.18) {
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
            self?.pollNow()
        }
    }

    // MARK: - Actions (optimistic where it matters)

    func togglePlayPause() {
        guard bridge.isMusicRunning else {
            openMusicApp()
            return
        }
        snapshot.state = snapshot.state == .playing ? .paused : .playing
        bridge.playPause()
        pollSoon()
    }

    func nextTrack() {
        bridge.nextTrack()
        pollSoon(after: 0.3)
    }

    func previousTrack() {
        bridge.previousTrack()
        pollSoon(after: 0.3)
    }

    func seek(to seconds: Double) {
        let clamped = min(max(0, seconds), max(0, snapshot.duration))
        snapshot.position = clamped
        displayPosition = clamped
        lastPollDate = Date()
        bridge.setPosition(clamped)
        pollSoon(after: 0.3)
    }

    func toggleShuffle() {
        snapshot.shuffle.toggle()
        bridge.setShuffle(snapshot.shuffle)
        pollSoon()
    }

    func cycleRepeat() {
        snapshot.repeatMode = snapshot.repeatMode.next
        bridge.setRepeat(snapshot.repeatMode)
        pollSoon()
    }

    func toggleFavorite() {
        snapshot.favorited.toggle()
        favoriteHoldUntil = Date().addingTimeInterval(6)
        bridge.setFavorite(snapshot.favorited) { [weak self] in
            self?.pollSoon(after: 0.4)
        }
    }

    func setVolume(_ value: Double) {
        let clamped = min(100, max(0, value))
        snapshot.volume = clamped
        volumeWork?.cancel()
        let work = DispatchWorkItem { [weak self] in
            self?.bridge.setVolume(Int(clamped.rounded()))
        }
        volumeWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.08, execute: work)
    }

    func adjustVolume(by delta: Double) {
        setVolume(snapshot.volume + delta)
    }

    func openMusicApp() {
        guard let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: MusicBridge.musicBundleID) else { return }
        NSWorkspace.shared.openApplication(at: url, configuration: NSWorkspace.OpenConfiguration()) { _, _ in
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { [weak self] in
                self?.pollNow()
            }
        }
    }

    func openAutomationSettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Automation") {
            NSWorkspace.shared.open(url)
        }
    }
}
