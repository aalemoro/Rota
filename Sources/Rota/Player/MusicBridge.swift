//
//  MusicBridge.swift
//  Rota
//
//  A thin, reliable Apple Events bridge to the Music app.
//  No MusicKit, no private APIs — the same approach used by
//  battle-tested third-party mini players.
//

import AppKit

// MARK: - Model

enum RepeatMode: String, CaseIterable, Equatable {
    case off, all, one

    var next: RepeatMode {
        switch self {
        case .off: return .all
        case .all: return .one
        case .one: return .off
        }
    }
}

/// A snapshot of what the Music app is doing right now.
struct MusicSnapshot: Equatable {

    enum PlaybackState: Equatable {
        case playing, paused, stopped
    }

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

    var isMusicRunning: Bool {
        !NSRunningApplication.runningApplications(withBundleIdentifier: Self.musicBundleID).isEmpty
    }

    // MARK: Snapshot

    /// One round-trip that returns the full player state as an AppleScript list.
    private static let snapshotSource = """
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
            return {ps, (name of t) as text, (artist of t) as text, (album of t) as text, (duration of t) as real, pos as real, (persistent ID of t) as text, sh, rp, vol as integer, fav}
        on error
            return {ps, "", "", "", 0.0, pos as real, "", sh, rp, vol as integer, false}
        end try
    end tell
    """

    func snapshot(_ completion: @escaping (Result<MusicSnapshot, Error>) -> Void) {
        guard isMusicRunning else {
            completion(.failure(BridgeError.musicNotRunning))
            return
        }
        queue.async { [weak self] in
            guard let self else { return }
            do {
                let reply = try self.execute(cached: "snapshot", source: Self.snapshotSource)
                let snap = Self.parseSnapshot(reply)
                DispatchQueue.main.async { completion(.success(snap)) }
            } catch {
                DispatchQueue.main.async { completion(.failure(error)) }
            }
        }
    }

    private static func parseSnapshot(_ d: NSAppleEventDescriptor) -> MusicSnapshot {
        var snap = MusicSnapshot()
        guard d.numberOfItems >= 11 else { return snap }

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
        snap.repeatMode = RepeatMode(rawValue: d.atIndex(9)?.stringValue ?? "off") ?? .off
        snap.volume = Double(d.atIndex(10)?.int32Value ?? 50)
        snap.favorited = d.atIndex(11)?.booleanValue ?? false
        return snap
    }

    // MARK: Artwork

    private static let artworkSource = """
    tell application "Music"
        try
            return raw data of artwork 1 of current track
        on error
            return ""
        end try
    end tell
    """

    func artwork(_ completion: @escaping (NSImage?) -> Void) {
        guard isMusicRunning else {
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

    // MARK: Commands

    func playPause(then: (() -> Void)? = nil) {
        fire("tell application \"Music\" to playpause", then: then)
    }

    /// Unconditional "start playing" — resumes the last queue. Used when
    /// Music has just been launched or is stopped with nothing queued.
    func play(then: (() -> Void)? = nil) {
        fire("tell application \"Music\" to play", then: then)
    }

    /// Freshly launched Music often has an empty queue, where a bare `play`
    /// does nothing. This finds the remembered track in the library (by ID,
    /// then by name+artist) and plays it, falling back to the library itself.
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
        fire(source, then: then)
    }

    func nextTrack(then: (() -> Void)? = nil) {
        fire("tell application \"Music\" to next track", then: then)
    }

    func previousTrack(then: (() -> Void)? = nil) {
        fire("tell application \"Music\" to previous track", then: then)
    }

    func setPosition(_ seconds: Double, then: (() -> Void)? = nil) {
        let clamped = max(0, seconds)
        fire("tell application \"Music\" to set player position to \(String(format: "%.2f", clamped))", then: then)
    }

    func setShuffle(_ on: Bool, then: (() -> Void)? = nil) {
        fire("tell application \"Music\" to set shuffle enabled to \(on ? "true" : "false")", then: then)
    }

    func setRepeat(_ mode: RepeatMode, then: (() -> Void)? = nil) {
        fire("tell application \"Music\" to set song repeat to \(mode.rawValue)", then: then)
    }

    func setVolume(_ volume: Int, then: (() -> Void)? = nil) {
        let clamped = min(100, max(0, volume))
        fire("tell application \"Music\" to set sound volume to \(clamped)", then: then)
    }

    /// Sets the favourite state explicitly (no read-modify-write — cloud
    /// tracks report a stale value for a few seconds after a change).
    func setFavorite(_ value: Bool, then: (() -> Void)? = nil) {
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
        fire(source, then: then)
    }

    /// Fire-and-forget command.
    private func fire(_ source: String, then: (() -> Void)? = nil) {
        guard isMusicRunning else { return }
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

    /// Runs a cached, precompiled script on the bridge queue.
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
