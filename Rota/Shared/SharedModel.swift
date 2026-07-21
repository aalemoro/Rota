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
        updatedAt: Date(timeIntervalSince1970: 0)
    )

    static let sample = NowPlayingSnapshot(
        title: "Midnight City",
        artist: "M83",
        album: "Hurry Up, We're Dreaming",
        isPlaying: true,
        artworkPNG: nil,
        progress: 0.42,
        duration: 244,
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
