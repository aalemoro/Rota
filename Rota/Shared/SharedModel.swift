//
//  SharedModel.swift
//  Rota — shared between the app and the widget extension.
//
//  `NowPlayingSnapshot` is the small, Codable value that the app writes to the
//  shared App Group whenever playback changes. The widget reads it back to draw
//  its timeline. Keeping it tiny (artwork is a pre-scaled thumbnail) keeps the
//  widget refreshes cheap.
//

import Foundation
import SwiftUI

/// How the current track repeats. Raw values are stable for App Group storage.
enum RepeatState: Int, Codable { case off = 0, all = 1, one = 2 }

struct NowPlayingSnapshot: Codable, Equatable {
    var title: String
    var artist: String
    var album: String
    var isPlaying: Bool
    /// Small PNG thumbnail of the artwork (≈ 240 px). Optional — may be nil.
    var artworkPNG: Data?
    /// 0…1 fraction of the track elapsed, if known.
    var progress: Double
    /// Track length in seconds, if known.
    var duration: TimeInterval
    /// Shuffle and repeat state, mirrored for the UI and widget.
    var shuffle: Bool = false
    var repeatState: RepeatState = .off
    /// When this snapshot was produced — lets the widget age progress locally.
    var updatedAt: Date

    static let placeholder = NowPlayingSnapshot(
        title: "Not Playing",
        artist: "Open Rota to start",
        album: "",
        isPlaying: false,
        artworkPNG: nil,
        progress: 0,
        duration: 0,
        shuffle: false,
        repeatState: .off,
        updatedAt: Date(timeIntervalSince1970: 0)
    )

    static let sample = NowPlayingSnapshot(
        title: "Dancin (Krono Remix)",
        artist: "Aaron Smith · feat. Luvli",
        album: "Dancin (Krono Remix) - Single",
        isPlaying: true,
        artworkPNG: nil,
        progress: 0.1,
        duration: 198,
        shuffle: false,
        repeatState: .off,
        updatedAt: Date(timeIntervalSince1970: 0)
    )

    #if canImport(UIKit)
    var artworkImage: Image? {
        guard let data = artworkPNG, let ui = UIImage(data: data) else { return nil }
        return Image(uiImage: ui)
    }
    #elseif canImport(AppKit)
    var artworkImage: Image? {
        guard let data = artworkPNG, let ns = NSImage(data: data) else { return nil }
        return Image(nsImage: ns)
    }
    #endif
}

/// Reads and writes the snapshot to the shared App Group defaults.
enum SnapshotStore {
    static func write(_ snapshot: NowPlayingSnapshot) {
        guard let data = try? JSONEncoder().encode(snapshot) else { return }
        AppGroup.defaults.set(data, forKey: AppGroup.Key.nowPlaying)
    }

    static func read() -> NowPlayingSnapshot {
        guard
            let data = AppGroup.defaults.data(forKey: AppGroup.Key.nowPlaying),
            let snapshot = try? JSONDecoder().decode(NowPlayingSnapshot.self, from: data)
        else { return .placeholder }
        return snapshot
    }
}
