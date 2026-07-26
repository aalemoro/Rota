//
//  PlayerView.swift
//  Rota
//
//  The player face, adaptive to the three widget sizes.
//  Idle = pure album art; everything below fades in on hover.
//

import SwiftUI

struct PlayerView: View {

    @EnvironmentObject var store: PlayerStore
    var hovering: Bool
    var mode: WidgetSizeMode

    private var titleSize: CGFloat {
        switch mode { case .large: return 19; case .wide: return 15; case .small: return 12.5 }
    }
    private var artistSize: CGFloat {
        switch mode { case .large: return 13.5; case .wide: return 11.5; case .small: return 10 }
    }
    private var horizontalPadding: CGFloat {
        switch mode { case .large: return 22; case .wide: return 16; case .small: return 12 }
    }
    private var bottomPadding: CGFloat {
        switch mode { case .large: return 16; case .wide: return 12; case .small: return 10 }
    }

    var body: some View {
        let visible = hovering || store.isScrubbing
        VStack(spacing: 0) {
            Spacer()

            VStack(alignment: .leading, spacing: mode == .large ? 10 : 6) {
                titleRow
                SeekBar(compact: mode != .large)
                ControlsRow(mode: mode)
            }
            .padding(.horizontal, horizontalPadding)
            .padding(.bottom, bottomPadding)
            .shadow(color: .black.opacity(0.35), radius: 10, y: 2)
            // Mouse away → the album cover stands alone.
            .opacity(visible ? 1 : 0)
            .offset(y: visible ? 0 : 8)
            .allowsHitTesting(visible)
        }
    }

    private var titleRow: some View {
        HStack(alignment: .center, spacing: 8) {
            VStack(alignment: .leading, spacing: 1) {
                Text(store.snapshot.title)
                    .font(.system(size: titleSize, weight: .bold))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                Text(subtitle)
                    .font(.system(size: artistSize, weight: .regular))
                    .foregroundStyle(.white.opacity(0.55))
                    .lineLimit(1)
            }
            Spacer(minLength: 6)
            if mode != .small {
                FavoriteButton(diameter: mode == .large ? 32 : 26)
            }
        }
    }

    private var subtitle: String {
        let artist = store.snapshot.artist
        let album = store.snapshot.album
        if artist.isEmpty { return album }
        if album.isEmpty || album == artist { return artist }
        if mode == .small { return artist }
        return "\(artist) — \(album)"
    }
}

// MARK: - Ghost mode (Music closed, last cover on screen)

struct GhostPlayerView: View {

    @EnvironmentObject var store: PlayerStore
    var hovering: Bool
    var mode: WidgetSizeMode

    var body: some View {
        ZStack {
            // Centre: one big resume button.
            VStack(spacing: 8) {
                Button {
                    store.resumePlayback()
                } label: {
                    ZStack {
                        Circle()
                            .fill(.ultraThinMaterial)
                        Circle()
                            .strokeBorder(Color.white.opacity(0.22), lineWidth: 0.5)
                        if store.isResuming {
                            ProgressView()
                                .controlSize(.small)
                                .tint(.white)
                        } else {
                            Image(systemName: "play.fill")
                                .font(.system(size: mode == .small ? 18 : 24, weight: .bold))
                                .foregroundStyle(.white)
                                .offset(x: 1.5)
                        }
                    }
                    .frame(width: mode == .small ? 46 : 58, height: mode == .small ? 46 : 58)
                    .contentShape(Circle())
                }
                .buttonStyle(PressableStyle())
                .help("Resume playback")

                if mode != .small {
                    Text(store.isResuming ? "Opening Music…" : "Resume")
                        .font(.system(size: 11.5, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.75))
                }
            }

            // Bottom: what will play.
            if mode != .small {
                VStack {
                    Spacer()
                    VStack(alignment: .leading, spacing: 1) {
                        Text(store.snapshot.title.isEmpty ? store.ghostTitle : store.snapshot.title)
                            .font(.system(size: mode == .large ? 15 : 13, weight: .bold))
                            .foregroundStyle(.white.opacity(0.9))
                            .lineLimit(1)
                        Text(store.snapshot.artist.isEmpty ? store.ghostArtist : store.snapshot.artist)
                            .font(.system(size: mode == .large ? 11.5 : 10.5))
                            .foregroundStyle(.white.opacity(0.5))
                            .lineLimit(1)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, mode == .large ? 22 : 16)
                    .padding(.bottom, mode == .large ? 16 : 12)
                }
            }
        }
        .shadow(color: .black.opacity(0.35), radius: 10, y: 2)
        // At rest the cover stands alone, exactly like the live player.
        .opacity(hovering || store.isResuming ? 1 : 0)
        .allowsHitTesting(hovering || store.isResuming)
    }
}

// MARK: - Favourite

struct FavoriteButton: View {

    @EnvironmentObject var store: PlayerStore
    var diameter: CGFloat = 32

    var body: some View {
        Button {
            store.toggleFavorite()
        } label: {
            Image(systemName: store.snapshot.favorited ? "star.fill" : "star")
                .font(.system(size: diameter * 0.42, weight: .semibold))
                .foregroundStyle(.white.opacity(store.snapshot.favorited ? 1.0 : 0.85))
                .frame(width: diameter, height: diameter)
                .background(Circle().fill(.ultraThinMaterial))
                .overlay(Circle().strokeBorder(Color.white.opacity(0.14), lineWidth: 0.5))
                .contentShape(Circle())
        }
        .buttonStyle(PressableStyle())
        .help("Favourite (F)")
    }
}

// MARK: - Seek bar

struct SeekBar: View {

    @EnvironmentObject var store: PlayerStore
    var compact: Bool = false

    @State private var hover = false
    @State private var dragging = false

    private var duration: Double { store.snapshot.duration }

    private var position: Double {
        store.isScrubbing ? store.scrubPosition : store.displayPosition
    }

    var body: some View {
        VStack(spacing: 3) {
            GeometryReader { geo in
                let width = geo.size.width
                let progress = duration > 0 ? max(0, min(1, position / duration)) : 0
                let restingHeight: CGFloat = compact ? 3.5 : 4
                let raisedHeight: CGFloat = compact ? 5.5 : 7
                let barHeight: CGFloat = (hover || dragging) ? raisedHeight : restingHeight

                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.white.opacity(0.25))
                        .frame(height: barHeight)
                    Capsule()
                        .fill(Color.white.opacity(0.92))
                        .frame(width: max(barHeight, width * progress), height: barHeight)
                }
                .frame(width: width, height: geo.size.height)
                .animation(.easeOut(duration: 0.15), value: hover || dragging)
                .contentShape(Rectangle())
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { value in
                            guard duration > 0 else { return }
                            dragging = true
                            store.isScrubbing = true
                            let fraction = max(0, min(1, value.location.x / width))
                            store.scrubPosition = fraction * duration
                        }
                        .onEnded { value in
                            guard duration > 0 else { return }
                            let fraction = max(0, min(1, value.location.x / width))
                            store.seek(to: fraction * duration)
                            dragging = false
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                                store.isScrubbing = false
                            }
                        }
                )
            }
            .frame(height: compact ? 12 : 18)
            .onHover { hover = $0 }

            if !compact {
                HStack {
                    Text(formatTime(position))
                    Spacer()
                    Text(duration > 0 ? "−" + formatTime(max(0, duration - position)) : "")
                }
                .font(.system(size: 10.5, weight: .medium).monospacedDigit())
                .foregroundStyle(.white.opacity(0.55))
            }
        }
    }
}

// MARK: - Transport controls

struct ControlsRow: View {

    @EnvironmentObject var store: PlayerStore
    var mode: WidgetSizeMode

    var body: some View {
        if mode == .small {
            HStack(spacing: 26) {
                TransportButton(symbol: "backward.fill", size: 15, help: "Previous (←)") {
                    store.previousTrack()
                }
                TransportButton(
                    symbol: store.snapshot.state == .playing ? "pause.fill" : "play.fill",
                    size: 21,
                    help: "Play / Pause (space)"
                ) {
                    store.togglePlayPause()
                }
                TransportButton(symbol: "forward.fill", size: 15, help: "Next (→)") {
                    store.nextTrack()
                }
            }
            .frame(maxWidth: .infinity)
        } else {
            let skipSize: CGFloat = mode == .large ? 20 : 16
            let playSize: CGFloat = mode == .large ? 29 : 22
            let toggleSize: CGFloat = mode == .large ? 14 : 12

            HStack(spacing: 0) {
                SmallToggleButton(
                    symbol: "shuffle",
                    active: store.snapshot.shuffle,
                    size: toggleSize,
                    help: "Shuffle"
                ) {
                    store.toggleShuffle()
                }

                Spacer()

                TransportButton(symbol: "backward.fill", size: skipSize, help: "Previous (←)") {
                    store.previousTrack()
                }

                Spacer()

                TransportButton(
                    symbol: store.snapshot.state == .playing ? "pause.fill" : "play.fill",
                    size: playSize,
                    help: "Play / Pause (space)"
                ) {
                    store.togglePlayPause()
                }
                .frame(width: mode == .large ? 44 : 36)

                Spacer()

                TransportButton(symbol: "forward.fill", size: skipSize, help: "Next (→)") {
                    store.nextTrack()
                }

                Spacer()

                SmallToggleButton(
                    symbol: store.snapshot.repeatMode == .one ? "repeat.1" : "repeat",
                    active: store.snapshot.repeatMode != .off,
                    size: toggleSize,
                    help: "Repeat"
                ) {
                    store.cycleRepeat()
                }
            }
            .padding(.horizontal, 2)
            .padding(.top, mode == .large ? 2 : 0)
        }
    }
}

struct TransportButton: View {

    let symbol: String
    let size: CGFloat
    var help: String = ""
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: size, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: max(30, size + 14), height: max(30, size + 12))
                .contentShape(Rectangle())
        }
        .buttonStyle(PressableStyle())
        .help(help)
    }
}

struct SmallToggleButton: View {

    let symbol: String
    let active: Bool
    var size: CGFloat = 14
    var help: String = ""
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: size, weight: .semibold))
                .foregroundStyle(.white.opacity(active ? 1.0 : 0.45))
                .frame(width: size + 18, height: size + 16)
                .background(
                    Capsule()
                        .fill(Color.white.opacity(active ? 0.16 : 0.0))
                )
                .contentShape(Rectangle())
        }
        .buttonStyle(PressableStyle())
        .help(help)
    }
}

// MARK: - Helpers

func formatTime(_ seconds: Double) -> String {
    guard seconds.isFinite, seconds >= 0 else { return "0:00" }
    let total = Int(seconds.rounded())
    return String(format: "%d:%02d", total / 60, total % 60)
}
