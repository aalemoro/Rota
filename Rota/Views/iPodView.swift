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
                            NowPlayingView(snapshot: music.nowPlaying)
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
                    LinearGradient(colors: [Color(white: 0.20), Color(white: 0.07)],
                                   startPoint: .top, endPoint: .bottom))
                .overlay {
                    RoundedRectangle(cornerRadius: 34, style: .continuous)
                        .strokeBorder(.white.opacity(0.10), lineWidth: 1)
                }
                .shadow(color: .black.opacity(0.5), radius: 20, y: 10)
        }
        .clipShape(RoundedRectangle(cornerRadius: 34, style: .continuous))
    }
}
