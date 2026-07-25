//
//  LyricsView.swift
//  Rota
//
//  Apple Music-style lyrics: big bold lines, the current one lit up,
//  auto-scrolling in sync with playback. Click a line to jump there.
//

import SwiftUI

struct LyricsView: View {

    @EnvironmentObject var store: PlayerStore

    var body: some View {
        LyricsContent(lyrics: store.lyrics)
    }
}

struct LyricsContent: View {

    @EnvironmentObject var store: PlayerStore
    @ObservedObject var lyrics: LyricsController

    var body: some View {
        switch lyrics.state {
        case .idle, .loading:
            statusView {
                ProgressView()
                    .controlSize(.small)
                    .tint(.white.opacity(0.7))
                Text("Looking for lyrics…")
            }
        case .instrumental:
            statusView {
                Image(systemName: "music.note")
                    .font(.system(size: 30, weight: .light))
                Text("Instrumental")
            }
        case .unavailable:
            statusView {
                Image(systemName: "quote.bubble")
                    .font(.system(size: 30, weight: .light))
                Text("No lyrics for this song")
            }
        case .plain(let lines):
            PlainLyricsView(lines: lines)
        case .synced(let lines):
            SyncedLyricsView(lines: lines)
        }
    }

    private func statusView<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        VStack(spacing: 12) {
            content()
        }
        .font(.system(size: 13, weight: .medium))
        .foregroundStyle(.white.opacity(0.55))
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Synced

struct SyncedLyricsView: View {

    @EnvironmentObject var store: PlayerStore
    let lines: [LyricLine]

    private var activeIndex: Int? {
        let now = store.displayPosition + 0.35
        return lines.last(where: { $0.time <= now })?.id
    }

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: 26) {
                    Color.clear.frame(height: 46).id(-1)

                    ForEach(lines) { line in
                        let isActive = line.id == activeIndex
                        Button {
                            store.seek(to: line.time)
                        } label: {
                            Text(line.text)
                                .font(.system(size: 23, weight: .bold))
                                .foregroundStyle(.white.opacity(isActive ? 1.0 : 0.34))
                                .multilineTextAlignment(.leading)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .scaleEffect(isActive ? 1.0 : 0.965, anchor: .leading)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .id(line.id)
                    }

                    Color.clear.frame(height: 130).id(Int.max)
                }
                .padding(.horizontal, 24)
                .animation(.spring(response: 0.45, dampingFraction: 0.9), value: activeIndex)
            }
            .onChange(of: activeIndex) { index in
                guard let index else { return }
                withAnimation(.spring(response: 0.55, dampingFraction: 0.92)) {
                    proxy.scrollTo(index, anchor: UnitPoint(x: 0, y: 0.33))
                }
            }
            .onAppear {
                if let index = activeIndex {
                    proxy.scrollTo(index, anchor: UnitPoint(x: 0, y: 0.33))
                }
            }
        }
        .mask(edgeFade)
    }

    private var edgeFade: some View {
        LinearGradient(
            stops: [
                .init(color: .clear, location: 0.0),
                .init(color: .black, location: 0.08),
                .init(color: .black, location: 0.86),
                .init(color: .clear, location: 1.0)
            ],
            startPoint: .top,
            endPoint: .bottom
        )
    }
}

// MARK: - Plain (unsynced)

struct PlainLyricsView: View {

    let lines: [String]

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading, spacing: 14) {
                Color.clear.frame(height: 40)
                ForEach(Array(lines.enumerated()), id: \.offset) { _, line in
                    if line.isEmpty {
                        Color.clear.frame(height: 6)
                    } else {
                        Text(line)
                            .font(.system(size: 19, weight: .bold))
                            .foregroundStyle(.white.opacity(0.82))
                            .multilineTextAlignment(.leading)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                Color.clear.frame(height: 60)
            }
            .padding(.horizontal, 24)
        }
        .mask(
            LinearGradient(
                stops: [
                    .init(color: .clear, location: 0.0),
                    .init(color: .black, location: 0.08),
                    .init(color: .black, location: 0.9),
                    .init(color: .clear, location: 1.0)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        )
    }
}
