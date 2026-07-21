//
//  PlaybackEngine.swift
//  Rota — shared between the app and the widget extension.
//
//  A thin async wrapper around `ApplicationMusicPlayer.shared`. Both the app's
//  `MusicController` (for the UI) and the widget's App Intents (for the
//  interactive buttons) call through here, so playback commands behave
//  identically no matter where they originate.
//
//  ApplicationMusicPlayer.shared is a process-wide singleton that drives your
//  app's Apple Music playback session. Commanding it from a widget intent and
//  from the app hits the same session. After every command we refresh the
//  shared snapshot and ask WidgetKit to reload, so the widget reflects the new
//  state immediately.
//

import Foundation
import MusicKit
import WidgetKit

enum PlaybackEngine {

    private static var player: ApplicationMusicPlayer { .shared }

    // MARK: Commands

    static func togglePlayPause() async {
        let status = player.state.playbackStatus
        if status == .playing {
            player.pause()
        } else {
            try? await player.play()
        }
        await refreshSnapshot()
    }

    static func play() async {
        try? await player.play()
        await refreshSnapshot()
    }

    static func pause() async {
        player.pause()
        await refreshSnapshot()
    }

    static func next() async {
        try? await player.skipToNextEntry()
        await refreshSnapshot()
    }

    static func previous() async {
        // Mirror an iPod: if we're a few seconds in, restart the track first.
        if player.playbackTime > 3 {
            player.restartCurrentEntry()
        } else {
            try? await player.skipToPreviousEntry()
        }
        await refreshSnapshot()
    }

    static func seek(toFraction fraction: Double) async {
        let duration = currentDuration()
        guard duration > 0 else { return }
        player.playbackTime = max(0, min(1, fraction)) * duration
        await refreshSnapshot()
    }

    static func toggleShuffle() async {
        player.state.shuffleMode = (player.state.shuffleMode == .songs) ? .off : .songs
        await refreshSnapshot()
    }

    /// Cycle repeat off → all → one → off, matching the Apple Music control.
    static func cycleRepeat() async {
        switch player.state.repeatMode {
        case nil, .some(.none): player.state.repeatMode = .all
        case .some(.all):       player.state.repeatMode = .one
        default:                player.state.repeatMode = MusicPlayer.RepeatMode.none
        }
        await refreshSnapshot()
    }

    /// Duration of the current entry, derived from the underlying song.
    private static func currentDuration() -> TimeInterval {
        if case let .song(song)? = player.queue.currentEntry?.item {
            return song.duration ?? 0
        }
        return 0
    }

    // MARK: Snapshot bridge

    /// Reads the current player state, builds a `NowPlayingSnapshot`, writes it
    /// to the App Group and reloads the widget timelines.
    @discardableResult
    static func refreshSnapshot() async -> NowPlayingSnapshot {
        let entry = player.queue.currentEntry
        let item = entry?.item

        var title = entry?.title ?? "Not Playing"
        var artist = entry?.subtitle ?? ""
        var album = ""
        var duration: TimeInterval = 0

        if case let .song(song)? = item {
            title = song.title
            artist = song.artistName
            album = song.albumTitle ?? ""
            duration = song.duration ?? 0
        }

        let isPlaying = player.state.playbackStatus == .playing
        let elapsed = player.playbackTime
        let progress = duration > 0 ? min(1, elapsed / duration) : 0

        let shuffle = (player.state.shuffleMode == .songs)
        let repeatState: RepeatState
        switch player.state.repeatMode {
        case .some(.all): repeatState = .all
        case .some(.one): repeatState = .one
        default:          repeatState = .off
        }

        var artworkPNG: Data? = nil
        if let artwork = entry?.artwork {
            artworkPNG = await Artworks.png(from: artwork, size: 240)
        }

        let snapshot = NowPlayingSnapshot(
            title: title,
            artist: artist,
            album: album,
            isPlaying: isPlaying,
            artworkPNG: artworkPNG,
            progress: progress,
            duration: duration,
            shuffle: shuffle,
            repeatState: repeatState,
            updatedAt: Date()
        )

        SnapshotStore.write(snapshot)
        WidgetCenter.shared.reloadTimelines(ofKind: AppGroup.widgetKind)
        return snapshot
    }
}
