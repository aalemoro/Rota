//
//  PlayerView.swift
//  Rota
//
//  The main player face: title, favourite, seek bar, transport controls.
//

import SwiftUI

struct PlayerView: View {

    @EnvironmentObject var store: PlayerStore
    var hovering: Bool

    var body: some View {
        let visible = hovering || store.isScrubbing
        VStack(spacing: 0) {
            Spacer()

            VStack(alignment: .leading, spacing: 10) {
                titleRow
                SeekBar()
                ControlsRow()
            }
            .padding(.horizontal, 22)
            .padding(.bottom, 16)
            .shadow(color: .black.opacity(0.35), radius: 10, y: 2)
            // Mouse away → the album cover stands alone.
            .opacity(visible ? 1 : 0)
            .offset(y: visible ? 0 : 8)
            .allowsHitTesting(visible)
        }
    }

    private var titleRow: some View {
        HStack(alignment: .center, spacing: 10) {
            VStack(alignment: .leading, spacing: 1) {
                Text(store.snapshot.title)
                    .font(.system(size: 19, weight: .bold))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                Text(subtitle)
                    .font(.system(size: 13.5, weight: .regular))
                    .foregroundStyle(.white.opacity(0.55))
                    .lineLimit(1)
            }
            Spacer(minLength: 6)
            FavoriteButton()
        }
    }

    private var subtitle: String {
        let artist = store.snapshot.artist
        let album = store.snapshot.album
        if artist.isEmpty { return album }
        if album.isEmpty || album == artist { return artist }
        return "\(artist) — \(album)"
    }
}

// MARK: - Favourite

struct FavoriteButton: View {

    @EnvironmentObject var store: PlayerStore

    var body: some View {
        Button {
            store.toggleFavorite()
        } label: {
            Image(systemName: store.snapshot.favorited ? "star.fill" : "star")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.white.opacity(store.snapshot.favorited ? 1.0 : 0.85))
                .frame(width: 32, height: 32)
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
                let barHeight: CGFloat = (hover || dragging) ? 7 : 4

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
            .frame(height: 18)
            .onHover { hover = $0 }

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

// MARK: - Transport controls

struct ControlsRow: View {

    @EnvironmentObject var store: PlayerStore

    var body: some View {
        HStack(spacing: 0) {
            SmallToggleButton(
                symbol: "shuffle",
                active: store.snapshot.shuffle,
                help: "Shuffle"
            ) {
                store.toggleShuffle()
            }

            Spacer()

            TransportButton(symbol: "backward.fill", size: 20, help: "Previous (←)") {
                store.previousTrack()
            }

            Spacer()

            TransportButton(
                symbol: store.snapshot.state == .playing ? "pause.fill" : "play.fill",
                size: 29,
                help: "Play / Pause (space)"
            ) {
                store.togglePlayPause()
            }
            .frame(width: 44)

            Spacer()

            TransportButton(symbol: "forward.fill", size: 20, help: "Next (→)") {
                store.nextTrack()
            }

            Spacer()

            SmallToggleButton(
                symbol: store.snapshot.repeatMode == .one ? "repeat.1" : "repeat",
                active: store.snapshot.repeatMode != .off,
                help: "Repeat"
            ) {
                store.cycleRepeat()
            }
        }
        .padding(.horizontal, 2)
        .padding(.top, 2)
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
                .frame(width: max(38, size + 16), height: 38)
                .contentShape(Rectangle())
        }
        .buttonStyle(PressableStyle())
        .help(help)
    }
}

struct SmallToggleButton: View {

    let symbol: String
    let active: Bool
    var help: String = ""
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(.white.opacity(active ? 1.0 : 0.45))
                .frame(width: 32, height: 30)
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
