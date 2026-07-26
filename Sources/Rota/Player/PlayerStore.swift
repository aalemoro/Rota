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
import WidgetKit
import RotaKit

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
    /// True while we're launching Music and nudging it to resume playback.
    @Published private(set) var isResuming = false

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

    /// When locked, dragging the cover does nothing (move with ⌘-drag or the
    /// menu). Off by default: drags snap into the native widget grid anyway.
    @Published var positionLocked: Bool = UserDefaults.standard.object(forKey: "positionLocked") as? Bool ?? false {
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

    // WidgetKit companion
    private var lastPublishedSignature: String?
    private var lastCoverPublishedID: String?
    private var lastCommandStamp: TimeInterval = Date().timeIntervalSince1970

    // MARK: - Lifecycle

    func start() {
        artworkCache.countLimit = 12

        // Ghost mode: with Music closed, resurrect the last track and cover
        // from the shared container so the widget never goes blank.
        if !bridge.isMusicRunning {
            loadGhost()
        }

        let dnc = DistributedNotificationCenter.default()
        for name in ["com.apple.Music.playerInfo", "com.spotify.client.PlaybackStateChanged"] {
            observers.append(dnc.addObserver(
                forName: NSNotification.Name(name),
                object: nil, queue: .main
            ) { [weak self] _ in
                self?.pollNow()
            })
        }

        let wnc = NSWorkspace.shared.notificationCenter
        for name in [NSWorkspace.didLaunchApplicationNotification,
                     NSWorkspace.didTerminateApplicationNotification] {
            observers.append(wnc.addObserver(forName: name, object: nil, queue: .main) { [weak self] note in
                let app = note.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication
                if let bid = app?.bundleIdentifier, bid == MediaSource.appleMusic.bundleID || bid == MediaSource.spotify.bundleID {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { self?.pollNow() }
                }
            })
        }

        // Commands coming back from the WidgetKit widget's buttons.
        observers.append(DistributedNotificationCenter.default().addObserver(
            forName: SharedStore.commandNotification,
            object: nil, queue: .main
        ) { [weak self] _ in
            self?.handleWidgetCommand()
        })

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
        handleWidgetCommand() // fallback path in case the notification is missed
        guard bridge.isMusicRunning else {
            if availability != .musicNotRunning {
                availability = .musicNotRunning
                // Ghost mode: keep the last track and artwork on screen —
                // the widget stays a beautiful cover even with Music closed.
                snapshot.state = .stopped
                artworkTrackID = nil
                if artwork == nil { loadGhost() }
                publishWidgetState(force: true)
            }
            return
        }
        guard !polling else { return }
        polling = true

        bridge.snapshot(preferring: snapshot.source) { [weak self] result in
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
            loadArtwork(for: snap)
        } else if !snap.hasTrack {
            // Empty queue: fall back to the ghost cover so the widget stays
            // an album card with a resume button rather than a blank state.
            artworkTrackID = nil
            if artwork == nil { loadGhost(includeInfo: false) }
        }

        if trackChanged {
            lyrics.trackDidChange(for: snap, loadNow: showLyrics)
        }

        publishWidgetState()
    }

    // MARK: - WidgetKit companion

    /// Mirrors the player state into the shared container and asks
    /// WidgetKit to redraw. Cheap: only fires when something visible changed
    /// (or every ~30 s of playback for the progress bar).
    private func publishWidgetState(force: Bool = false) {
        let s = snapshot
        let ready = availability == .ready
        let signature = [
            s.persistentID,
            "\(s.state == .playing)",
            "\(s.favorited)",
            "\(Int(displayPosition / 30))",
            "\(ready)"
        ].joined(separator: "|")

        guard force || signature != lastPublishedSignature else { return }
        lastPublishedSignature = signature

        let info = SharedNowPlaying(
            title: s.title,
            artist: s.artist,
            album: s.album,
            playing: ready && s.state == .playing,
            favorited: s.favorited,
            duration: s.duration,
            position: displayPosition,
            updatedAt: Date(),
            persistentID: s.persistentID,
            source: s.source.rawValue
        )
        // Never clobber a remembered track with emptiness — the ghost (and
        // the gallery widget) should always have something to show/resume.
        if info.hasTrack {
            SharedStore.writeNowPlaying(info)
        }
        WidgetCenter.shared.reloadTimelines(ofKind: SharedStore.widgetKind)
    }

    private func handleWidgetCommand() {
        guard let (command, stamp) = SharedStore.readCommand(), stamp > lastCommandStamp else { return }
        lastCommandStamp = stamp
        switch command {
        case "playpause": togglePlayPause()
        case "next": nextTrack()
        case "previous": previousTrack()
        case "favorite": toggleFavorite()
        default: break
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.7) { [weak self] in
            self?.publishWidgetState(force: true)
        }
    }

    /// Smoothly advances the progress bar between polls.
    private func tick() {
        guard snapshot.state == .playing, !isScrubbing else { return }
        let projected = snapshot.position + Date().timeIntervalSince(lastPollDate)
        displayPosition = snapshot.duration > 0 ? min(projected, snapshot.duration) : projected
    }

    private func loadArtwork(for snap: MusicSnapshot) {
        let id = snap.persistentID
        if let cached = artworkCache.object(forKey: id as NSString) {
            artwork = cached
            artworkBlurred = blurredCache.object(forKey: id as NSString)
            if artworkBlurred == nil { bakeBlur(for: cached, id: id) }
            return
        }
        switch snap.source {
        case .spotify:
            // Spotify hands us the cover URL directly.
            downloadArtwork(from: snap.artworkURL, for: id)
        case .appleMusic:
            bridge.musicArtwork { [weak self] image in
                guard let self else { return }
                // Ignore stale replies after further track changes.
                guard self.artworkTrackID == id else { return }
                if let image {
                    self.applyArtwork(image, for: id)
                } else {
                    // Streaming tracks often expose no artwork via scripting —
                    // resolve the cover from Apple's catalogue instead.
                    self.artwork = nil
                    self.artworkBlurred = nil
                    self.fetchArtworkOnline(for: id)
                }
            }
        }
    }

    private func downloadArtwork(from urlString: String, for id: String) {
        guard let url = URL(string: urlString), !urlString.isEmpty else {
            artwork = nil
            artworkBlurred = nil
            fetchArtworkOnline(for: id)
            return
        }
        Task { [weak self] in
            let image: NSImage?
            if let (data, response) = try? await URLSession.shared.data(from: url),
               (response as? HTTPURLResponse)?.statusCode == 200 {
                image = NSImage(data: data)
            } else {
                image = nil
            }
            await MainActor.run { [weak self] in
                guard let self, self.artworkTrackID == id else { return }
                if let image {
                    self.applyArtwork(image, for: id)
                } else {
                    self.fetchArtworkOnline(for: id)
                }
            }
        }
    }

    private func applyArtwork(_ image: NSImage, for id: String) {
        artwork = image
        artworkBlurred = nil
        artworkCache.setObject(image, forKey: id as NSString)
        bakeBlur(for: image, id: id)
    }

    private func fetchArtworkOnline(for id: String) {
        let snap = snapshot
        guard snap.persistentID == id, snap.hasTrack else { return }
        Task { [weak self] in
            let image = await ITunesArtworkService.fetch(
                artist: snap.artist, album: snap.album, title: snap.title
            )
            await MainActor.run { [weak self] in
                guard let self, self.artworkTrackID == id, let image else { return }
                self.applyArtwork(image, for: id)
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
                self.publishCovers(for: id, cover: image, blurred: blurred)
            }
        }
    }

    /// Ships downscaled JPEG covers to the shared container for the widget.
    private func publishCovers(for id: String, cover: NSImage, blurred: NSImage?) {
        guard lastCoverPublishedID != id else { return }
        lastCoverPublishedID = id
        DispatchQueue.global(qos: .utility).async {
            let coverData = SharedStore.jpegData(from: cover, maxDimension: 800)
            let blurData = blurred.flatMap { SharedStore.jpegData(from: $0, maxDimension: 800) }
            DispatchQueue.main.async {
                if let coverData { SharedStore.writeCover(coverData) }
                if let blurData { SharedStore.writeCoverBlurred(blurData) }
                WidgetCenter.shared.reloadTimelines(ofKind: SharedStore.widgetKind)
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
            resumePlayback()
            return
        }
        // Stopped or empty queue: go through the smart resume chain — a bare
        // `playpause` would silently do nothing with an empty queue.
        if !snapshot.hasTrack || snapshot.state == .stopped {
            resumePlayback()
            return
        }
        snapshot.state = snapshot.state == .playing ? .paused : .playing
        bridge.playPause()
        pollSoon()
    }

    /// What the ghost would resume (from the persisted snapshot).
    @Published private(set) var ghostTitle = ""
    @Published private(set) var ghostArtist = ""
    private var ghostPersistentID = ""
    private(set) var ghostSource: MediaSource = .appleMusic

    /// Loads the persisted last-track snapshot + covers (ghost mode).
    /// With `includeInfo` the live snapshot fields are populated too —
    /// only safe while Music isn't running.
    private func loadGhost(includeInfo: Bool = true) {
        guard let saved = SharedStore.readNowPlaying(), saved.hasTrack else { return }
        ghostTitle = saved.title
        ghostArtist = saved.artist
        ghostPersistentID = saved.persistentID ?? ""
        ghostSource = MediaSource(rawValue: saved.source ?? "") ?? .appleMusic
        if includeInfo {
            snapshot.title = saved.title
            snapshot.artist = saved.artist
            snapshot.album = saved.album
            snapshot.duration = saved.duration
            snapshot.position = saved.position
            snapshot.favorited = saved.favorited
            displayPosition = saved.position
        }
        if artwork == nil, let cover = SharedStore.readCover() {
            artwork = cover
            artworkBlurred = SharedStore.readCoverBlurred()
        }
    }

    /// Launches Music if needed and keeps nudging it until it actually
    /// plays. Freshly launched Music ignores scripting for a second or two,
    /// and often comes up with an empty queue where a bare `play` does
    /// nothing — so some attempts target the remembered track directly.
    func resumePlayback() {
        guard !isResuming else { return }
        isResuming = true
        if snapshot.hasTrack {
            resumeTarget = (snapshot.persistentID, snapshot.title, snapshot.artist)
            resumeSource = snapshot.source
        } else {
            loadGhost(includeInfo: false)
            resumeTarget = (ghostPersistentID, ghostTitle, ghostArtist)
            resumeSource = ghostSource
        }
        if !resumeSource.isRunning {
            openApp(resumeSource)
        }
        attemptPlay(remaining: 12)
    }

    private var resumeTarget: (id: String, title: String, artist: String) = ("", "", "")
    private var resumeSource: MediaSource = .appleMusic

    private func attemptPlay(remaining: Int) {
        guard remaining > 0 else {
            isResuming = false
            return
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
            guard let self else { return }
            if self.availability == .ready, self.snapshot.state == .playing {
                self.isResuming = false
                return
            }
            if self.resumeSource.isRunning {
                // The targeted script ends in "play the library" — it's the
                // right move even with no remembered track (empty queue).
                let targeted = (remaining == 10 || remaining == 6) && self.resumeSource == .appleMusic
                if targeted {
                    self.bridge.resumeSpecificTrack(
                        persistentID: self.resumeTarget.id,
                        title: self.resumeTarget.title,
                        artist: self.resumeTarget.artist
                    ) { [weak self] in self?.pollNow() }
                } else {
                    self.bridge.play(on: self.resumeSource) { [weak self] in self?.pollNow() }
                }
            }
            self.attemptPlay(remaining: remaining - 1)
        }
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
        snapshot.repeatMode = snapshot.repeatMode.next(for: snapshot.source)
        bridge.setRepeat(snapshot.repeatMode)
        pollSoon()
    }

    func toggleFavorite() {
        guard snapshot.source.supportsFavorite else { return }
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

    func openApp(_ source: MediaSource) {
        guard let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: source.bundleID) else { return }
        NSWorkspace.shared.openApplication(at: url, configuration: NSWorkspace.OpenConfiguration()) { _, _ in
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { [weak self] in
                self?.pollNow()
            }
        }
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
