//
//  MusicBridge.swift
//  Rota
//
//  A thin, reliable Apple Events bridge to the player apps.
//  Supports Apple Music and Spotify with automatic source detection.
//

import AppKit

// MARK: - Sources

enum MediaSource: String, Codable, CaseIterable {
    case appleMusic
    case spotify

    var bundleID: String {
        switch self {
        case .appleMusic: return "com.apple.Music"
        case .spotify: return "com.spotify.client"
        }
    }

    /// Name used in AppleScript `tell application` blocks.
    var scriptName: String {
        switch self {
        case .appleMusic: return "Music"
        case .spotify: return "Spotify"
        }
    }

    var displayName: String {
        switch self {
        case .appleMusic: return "Apple Music"
        case .spotify: return "Spotify"
        }
    }

    var isRunning: Bool {
        !NSRunningApplication.runningApplications(withBundleIdentifier: bundleID).isEmpty
    }

    var isInstalled: Bool {
        NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) != nil
    }

    /// Spotify has no favourite/loved API over AppleScript.
    var supportsFavorite: Bool { self == .appleMusic }
    /// Spotify's `repeating` is a plain bool — no "repeat one".
    var supportsRepeatOne: Bool { self == .appleMusic }
}

// MARK: - Model

enum RepeatMode: String, CaseIterable, Equatable {
    case off, all, one

    func next(for source: MediaSource) -> RepeatMode {
        switch self {
        case .off: return .all
        case .all: return source.supportsRepeatOne ? .one : .off
        case .one: return .off
        }
    }
}

/// A snapshot of what the active player is doing right now.
struct MusicSnapshot: Equatable {

    enum PlaybackState: Equatable {
        case playing, paused, stopped
    }

    var source: MediaSource = .appleMusic
    var state: PlaybackState = .stopped
    var title: String = ""
    var artist: String = ""
    var album: String = ""
    var duration: Double = 0
    var position: Double = 0
    var persistentID: String = ""
    var shuffle: Bool = false
    var repeatMode: RepeatMode = .off
    var volume: Double = 50
    var favorited: Bool = false
    /// Spotify hands the cover straight to us as a URL.
    var artworkURL: String = ""

    var hasTrack: Bool { !title.isEmpty || !persistentID.isEmpty }
}

enum BridgeError: Error {
    case musicNotRunning
    case notAuthorized
    case scriptFailure(String)
}

// MARK: - Bridge

final class MusicBridge {

    static let musicBundleID = "com.apple.Music"

    /// All Apple Events run off the main thread, serially.
    private let queue = DispatchQueue(label: "app.rota.musicbridge", qos: .userInitiated)
    private var compiledScripts: [String: NSAppleScript] = [:]

    /// The source the bridge is currently talking to.
    private(set) var activeSource: MediaSource = .appleMusic

    /// True when at least one supported player is running.
    var isMusicRunning: Bool {
        MediaSource.appleMusic.isRunning || MediaSource.spotify.isRunning
    }

    // MARK: Snapshot scripts

    private static func snapshotSource(for source: MediaSource) -> String {
        switch source {
        case .appleMusic:
            return """
            tell application "Music"
                set ps to (get player state) as text
                set sh to shuffle enabled
                set rp to (get song repeat) as text
                set vol to sound volume
                set pos to 0.0
                try
                    set rawPos to player position
                    if rawPos is not missing value then set pos to rawPos
                end try
                try
                    set t to current track
                    set fav to false
                    try
                        set fav to favorited of t
                    on error
                        try
                            set fav to loved of t
                        end try
                    end try
                    return {ps, (name of t) as text, (artist of t) as text, (album of t) as text, (duration of t) as real, pos as real, (persistent ID of t) as text, sh, rp, vol as integer, fav, ""}
                on error
                    return {ps, "", "", "", 0.0, pos as real, "", sh, rp, vol as integer, false, ""}
                end try
            end tell
            """
        case .spotify:
            return """
            tell application "Spotify"
                set ps to (player state as text)
                set sh to shuffling
                set rp to repeating
                set vol to sound volume
                set pos to 0.0
                try
                    set rawPos to player position
                    if rawPos is not missing value then set pos to rawPos
                end try
                try
                    set t to current track
                    return {ps, (name of t) as text, (artist of t) as text, (album of t) as text, ((duration of t) / 1000) as real, pos as real, (id of t) as text, sh, rp, vol as integer, false, (artwork url of t) as text}
                on error
                    return {ps, "", "", "", 0.0, pos as real, "", sh, rp, vol as integer, false, ""}
                end try
            end tell
            """
        }
    }

    /// One round-trip returning the full player state. When both players run,
    /// polls both and prefers whichever is actually playing (ties keep
    /// `previous`).
    func snapshot(preferring previous: MediaSource, _ completion: @escaping (Result<MusicSnapshot, Error>) -> Void) {
        let musicUp = MediaSource.appleMusic.isRunning
        let spotifyUp = MediaSource.spotify.isRunning
        guard musicUp || spotifyUp else {
            completion(.failure(BridgeError.musicNotRunning))
            return
        }

        queue.async { [weak self] in
            guard let self else { return }
            do {
                let result: MusicSnapshot
                if musicUp && spotifyUp {
                    let music = try self.fetchSnapshot(.appleMusic)
                    let spotify = try self.fetchSnapshot(.spotify)
                    if music.state == .playing && spotify.state != .playing {
                        result = music
                    } else if spotify.state == .playing && music.state != .playing {
                        result = spotify
                    } else {
                        result = previous == .spotify ? spotify : music
                    }
                } else if spotifyUp {
                    result = try self.fetchSnapshot(.spotify)
                } else {
                    result = try self.fetchSnapshot(.appleMusic)
                }
                self.activeSource = result.source
                DispatchQueue.main.async { completion(.success(result)) }
            } catch {
                DispatchQueue.main.async { completion(.failure(error)) }
            }
        }
    }

    private func fetchSnapshot(_ source: MediaSource) throws -> MusicSnapshot {
        let reply = try execute(cached: "snapshot-\(source.rawValue)",
                                source: Self.snapshotSource(for: source))
        return Self.parseSnapshot(reply, source: source)
    }

    private static func parseSnapshot(_ d: NSAppleEventDescriptor, source: MediaSource) -> MusicSnapshot {
        var snap = MusicSnapshot()
        snap.source = source
        guard d.numberOfItems >= 12 else { return snap }

        let stateText = d.atIndex(1)?.stringValue ?? "stopped"
        switch stateText {
        case "playing", "fast forwarding", "rewinding":
            snap.state = .playing
        case "paused":
            snap.state = .paused
        default:
            snap.state = .stopped
        }

        snap.title = d.atIndex(2)?.stringValue ?? ""
        snap.artist = d.atIndex(3)?.stringValue ?? ""
        snap.album = d.atIndex(4)?.stringValue ?? ""
        snap.duration = d.atIndex(5)?.doubleValue ?? 0
        snap.position = d.atIndex(6)?.doubleValue ?? 0
        snap.persistentID = d.atIndex(7)?.stringValue ?? ""
        snap.shuffle = d.atIndex(8)?.booleanValue ?? false

        switch source {
        case .appleMusic:
            snap.repeatMode = RepeatMode(rawValue: d.atIndex(9)?.stringValue ?? "off") ?? .off
        case .spotify:
            snap.repeatMode = (d.atIndex(9)?.booleanValue ?? false) ? .all : .off
        }

        snap.volume = Double(d.atIndex(10)?.int32Value ?? 50)
        snap.favorited = d.atIndex(11)?.booleanValue ?? false
        snap.artworkURL = d.atIndex(12)?.stringValue ?? ""
        return snap
    }

    // MARK: Artwork (Apple Music hands raw bytes; Spotify hands a URL)

    private static let artworkSource = """
    tell application "Music"
        try
            return raw data of artwork 1 of current track
        on error
            return ""
        end try
    end tell
    """

    func musicArtwork(_ completion: @escaping (NSImage?) -> Void) {
        guard MediaSource.appleMusic.isRunning else {
            completion(nil)
            return
        }
        queue.async { [weak self] in
            guard let self else { return }
            let reply = try? self.execute(cached: "artwork", source: Self.artworkSource)
            let data = reply?.data
            var image: NSImage?
            if let data, data.count > 64 {
                image = NSImage(data: data)
            }
            let result = image
            DispatchQueue.main.async { completion(result) }
        }
    }

    // MARK: Commands (routed to the active source)

    private func tellActive(_ command: String, then: (() -> Void)? = nil) {
        let source = activeSource
        fire("tell application \"\(source.scriptName)\" to \(command)", requires: source, then: then)
    }

    func playPause(then: (() -> Void)? = nil) {
        tellActive("playpause", then: then)
    }

    /// Unconditional "start playing" on a given source (default: active).
    func play(on source: MediaSource? = nil, then: (() -> Void)? = nil) {
        let target = source ?? activeSource
        fire("tell application \"\(target.scriptName)\" to play", requires: target, then: then)
    }

    func nextTrack(then: (() -> Void)? = nil) {
        tellActive("next track", then: then)
    }

    func previousTrack(then: (() -> Void)? = nil) {
        tellActive("previous track", then: then)
    }

    func setPosition(_ seconds: Double, then: (() -> Void)? = nil) {
        let clamped = max(0, seconds)
        tellActive("set player position to \(String(format: "%.2f", clamped))", then: then)
    }

    func setShuffle(_ on: Bool, then: (() -> Void)? = nil) {
        switch activeSource {
        case .appleMusic:
            tellActive("set shuffle enabled to \(on ? "true" : "false")", then: then)
        case .spotify:
            tellActive("set shuffling to \(on ? "true" : "false")", then: then)
        }
    }

    func setRepeat(_ mode: RepeatMode, then: (() -> Void)? = nil) {
        switch activeSource {
        case .appleMusic:
            tellActive("set song repeat to \(mode.rawValue)", then: then)
        case .spotify:
            tellActive("set repeating to \(mode == .off ? "false" : "true")", then: then)
        }
    }

    func setVolume(_ volume: Int, then: (() -> Void)? = nil) {
        let clamped = min(100, max(0, volume))
        tellActive("set sound volume to \(clamped)", then: then)
    }

    /// Apple Music only — explicit set, never read-modify-write (cloud lag).
    func setFavorite(_ value: Bool, then: (() -> Void)? = nil) {
        guard activeSource == .appleMusic else { return }
        let flag = value ? "true" : "false"
        let source = """
        tell application "Music"
            try
                set favorited of current track to \(flag)
            on error
                try
                    set loved of current track to \(flag)
                end try
            end try
        end tell
        """
        fire(source, requires: .appleMusic, then: then)
    }

    /// Apple Music: freshly launched with an empty queue, a bare `play` does
    /// nothing — find the remembered track in the library and play it.
    func resumeSpecificTrack(persistentID: String, title: String, artist: String, then: (() -> Void)? = nil) {
        func escaped(_ text: String) -> String {
            text
                .replacingOccurrences(of: "\\", with: "\\\\")
                .replacingOccurrences(of: "\"", with: "\\\"")
        }
        let source = """
        tell application "Music"
            try
                play (first track of library playlist 1 whose persistent ID is "\(escaped(persistentID))")
            on error
                try
                    play (first track of library playlist 1 whose name is "\(escaped(title))" and artist is "\(escaped(artist))")
                on error
                    try
                        play library playlist 1
                    on error
                        play
                    end try
                end try
            end try
        end tell
        """
        fire(source, requires: .appleMusic, then: then)
    }

    /// Fire-and-forget command.
    private func fire(_ source: String, requires app: MediaSource, then: (() -> Void)? = nil) {
        guard app.isRunning else { return }
        queue.async {
            var errorInfo: NSDictionary?
            NSAppleScript(source: source)?.executeAndReturnError(&errorInfo)
            if let errorInfo {
                NSLog("Rota bridge command error: \(errorInfo)")
            }
            if let then {
                DispatchQueue.main.async { then() }
            }
        }
    }

    // MARK: Execution

    private func execute(cached key: String, source: String) throws -> NSAppleEventDescriptor {
        let script: NSAppleScript
        if let existing = compiledScripts[key] {
            script = existing
        } else {
            guard let fresh = NSAppleScript(source: source) else {
                throw BridgeError.scriptFailure("could not create script \(key)")
            }
            var compileError: NSDictionary?
            fresh.compileAndReturnError(&compileError)
            if let compileError {
                throw BridgeError.scriptFailure("compile \(key): \(compileError)")
            }
            compiledScripts[key] = fresh
            script = fresh
        }

        var errorInfo: NSDictionary?
        let reply = script.executeAndReturnError(&errorInfo)
        if let errorInfo {
            let code = (errorInfo[NSAppleScript.errorNumber] as? Int) ?? 0
            // -1743: not authorized to send Apple Events; -10004: privilege violation.
            if code == -1743 || code == -10004 {
                throw BridgeError.notAuthorized
            }
            throw BridgeError.scriptFailure("\(errorInfo)")
        }
        return reply
    }
}
