//
//  MiniPlayerView.swift
//  Rota
//
//  The Liquid Glass mini-player: the album art fills the card, a frosted glass
//  scrim sits over the lower half for legibility, and the controls float on top
//  — a draggable seek bar and a full transport row (shuffle · ⏮ · play/pause ·
//  ⏭ · repeat). Modelled on the macOS Now Playing mini-player, rebuilt in glass.
//

import SwiftUI

struct MiniPlayerView: View {
    @EnvironmentObject var music: MusicController
    var compact: Bool = false

    private var snap: NowPlayingSnapshot { music.nowPlaying }

    var body: some View {
        ZStack {
            artworkBackground

            // Frosted glass scrim — clear at the top, deep at the bottom.
            LinearGradient(
                colors: [.clear, .black.opacity(0.25), .black.opacity(0.82)],
                startPoint: .top, endPoint: .bottom)

            VStack(spacing: 0) {
                topBar
                Spacer(minLength: 0)
                if music.screen == .library {
                    LibraryView(songs: music.songs, selection: music.selection,
                                isLoading: music.isLoadingLibrary)
                        .padding(.horizontal, 4)
                        .frame(maxHeight: .infinity)
                        .background(.black.opacity(0.35))
                } else {
                    bottomControls
                }
            }
            .padding(compact ? 12 : 16)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .strokeBorder(.white.opacity(0.14), lineWidth: 1)
        }
        .glassEffect(.clear, in: RoundedRectangle(cornerRadius: 26, style: .continuous))
        .shadow(color: .black.opacity(0.5), radius: 24, y: 12)
    }

    // MARK: Artwork

    private var artworkBackground: some View {
        Group {
            if let image = snap.artworkImage {
                image.resizable().aspectRatio(contentMode: .fill)
            } else {
                LinearGradient(colors: [Color(white: 0.28), Color(white: 0.08)],
                               startPoint: .topLeading, endPoint: .bottomTrailing)
            }
        }
    }

    // MARK: Top bar

    private var topBar: some View {
        HStack(spacing: 8) {
            Spacer()
            GlassIconButton(system: music.screen == .library ? "square.stack.fill" : "list.bullet",
                            size: 30) {
                withAnimation(.easeInOut(duration: 0.2)) {
                    music.screen = (music.screen == .library) ? .nowPlaying : .library
                }
            }
            GlassIconButton(system: "dial.min", size: 30) {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                    music.style = .wheel
                }
            }
        }
    }

    // MARK: Bottom controls

    private var bottomControls: some View {
        VStack(spacing: compact ? 8 : 12) {
            VStack(spacing: 2) {
                Text(snap.title)
                    .font(.system(size: compact ? 14 : 16, weight: .semibold))
                    .lineLimit(1)
                Text(snap.artist)
                    .font(.system(size: compact ? 11 : 12))
                    .foregroundStyle(.white.opacity(0.75))
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            SeekBar(progress: snap.progress, duration: snap.duration) { fraction in
                Task { await music.seek(to: fraction) }
            }

            transportRow
        }
        .foregroundStyle(.white)
    }

    private var transportRow: some View {
        HStack {
            TransportIcon(system: "shuffle", active: snap.shuffle, size: 16) {
                Task { await music.toggleShuffle() }
            }
            Spacer()
            TransportIcon(system: "backward.fill", size: 20) {
                Task { await music.previous() }
            }
            Spacer()
            // Big play/pause
            Button {
                Task { await music.togglePlayPause() }
            } label: {
                Image(systemName: snap.isPlaying ? "pause.fill" : "play.fill")
                    .font(.system(size: compact ? 22 : 26, weight: .medium))
                    .frame(width: compact ? 46 : 54, height: compact ? 46 : 54)
                    .contentShape(Circle())
            }
            .buttonStyle(.glass)
            .clipShape(Circle())
            Spacer()
            TransportIcon(system: "forward.fill", size: 20) {
                Task { await music.next() }
            }
            Spacer()
            TransportIcon(system: repeatSymbol, active: snap.repeatState != .off, size: 16) {
                Task { await music.cycleRepeat() }
            }
        }
        .padding(.horizontal, 2)
    }

    private var repeatSymbol: String {
        snap.repeatState == .one ? "repeat.1" : "repeat"
    }
}

// MARK: - Small building blocks

/// A round glass button used for the top-bar controls.
struct GlassIconButton: View {
    let system: String
    var size: CGFloat = 30
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: system)
                .font(.system(size: size * 0.42, weight: .semibold))
                .frame(width: size, height: size)
                .contentShape(Circle())
        }
        .buttonStyle(.glass)
        .tint(.white)
        .clipShape(Circle())
    }
}

/// A transport glyph that highlights in the accent colour when active.
private struct TransportIcon: View {
    let system: String
    var active: Bool = false
    let size: CGFloat
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: system)
                .font(.system(size: size, weight: .semibold))
                .foregroundStyle(active ? Color.rotaAccent : .white)
                .frame(width: size + 16, height: size + 16)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
