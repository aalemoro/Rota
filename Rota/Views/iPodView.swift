//
//  iPodView.swift
//  Rota
//
//  Assembles the whole device: a Liquid Glass body holding the screen up top
//  and the click wheel below. This is the piece that reads as "an iPod" while
//  everything underneath is real Apple Music playback.
//

import SwiftUI

struct iPodView: View {
    @EnvironmentObject var music: MusicController
    var compact: Bool = false

    var body: some View {
        GlassEffectContainer(spacing: 18) {
            VStack(spacing: compact ? 16 : 22) {
                // Screen
                ScreenBezel {
                    Group {
                        switch music.screen {
                        case .nowPlaying:
                            NowPlayingView(snapshot: music.nowPlaying) { fraction in
                                Task { await music.seek(to: fraction) }
                            }
                        case .library:
                            LibraryView(songs: music.songs,
                                        selection: music.selection,
                                        isLoading: music.isLoadingLibrary)
                        }
                    }
                    .frame(height: compact ? 210 : 240)
                    .frame(maxWidth: .infinity)
                }

                // Click wheel
                ClickWheel(
                    onStep:      { music.handleWheelStep($0) },
                    onCenter:    { music.pressCenter() },
                    onMenu:      { music.pressMenu() },
                    onPrevious:  { Task { await music.previous() } },
                    onNext:      { Task { await music.next() } },
                    onPlayPause: { Task { await music.togglePlayPause() } }
                )
                .frame(width: compact ? 190 : 220, height: compact ? 190 : 220)
            }
            .padding(compact ? 18 : 24)
        }
        .background {
            RoundedRectangle(cornerRadius: 34, style: .continuous)
                .fill(
                    LinearGradient(colors: [Color(white: 0.22), Color(white: 0.06)],
                                   startPoint: .top, endPoint: .bottom))
                // Specular sheen across the top edge of the body.
                .overlay(alignment: .top) {
                    RoundedRectangle(cornerRadius: 34, style: .continuous)
                        .fill(LinearGradient(
                            colors: [.white.opacity(0.18), .clear],
                            startPoint: .top, endPoint: .center))
                        .blendMode(.plusLighter)
                        .padding(1)
                }
                .overlay {
                    RoundedRectangle(cornerRadius: 34, style: .continuous)
                        .strokeBorder(
                            LinearGradient(colors: [.white.opacity(0.20), .white.opacity(0.04)],
                                           startPoint: .top, endPoint: .bottom),
                            lineWidth: 1)
                }
                .shadow(color: .black.opacity(0.55), radius: 22, y: 12)
        }
        .clipShape(RoundedRectangle(cornerRadius: 34, style: .continuous))
        .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 34, style: .continuous))
        // Switch back to the glass mini-player.
        .overlay(alignment: .topLeading) {
            GlassIconButton(system: "rectangle.on.rectangle", size: 28) {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                    music.style = .player
                }
            }
            .padding(compact ? 14 : 18)
        }
    }
}
