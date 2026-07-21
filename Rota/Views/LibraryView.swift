//
//  LibraryView.swift
//  Rota
//
//  The "screen" content when browsing the library. A scrolling list you move
//  through with the click wheel; the highlighted row is what the centre button
//  plays. Auto-scrolls to keep the selection visible.
//

import SwiftUI
import MusicKit

struct LibraryView: View {
    let songs: [Song]
    let selection: Int
    let isLoading: Bool

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider().overlay(.white.opacity(0.1))
            if isLoading {
                Spacer()
                ProgressView().controlSize(.small).tint(.white)
                Spacer()
            } else if songs.isEmpty {
                emptyState
            } else {
                list
            }
        }
        .foregroundStyle(.white)
    }

    private var header: some View {
        Text("Library")
            .font(.system(size: 12, weight: .semibold))
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.bottom, 6)
            .foregroundStyle(Color.rotaAccent)
    }

    private var list: some View {
        ScrollViewReader { proxy in
            ScrollView(showsIndicators: false) {
                LazyVStack(spacing: 0) {
                    ForEach(Array(songs.enumerated()), id: \.offset) { index, song in
                        row(song, isSelected: index == selection)
                            .id(index)
                    }
                }
            }
            .onChange(of: selection) { _, new in
                withAnimation(.easeOut(duration: 0.15)) { proxy.scrollTo(new, anchor: .center) }
            }
        }
    }

    private func row(_ song: Song, isSelected: Bool) -> some View {
        HStack(spacing: 8) {
            VStack(alignment: .leading, spacing: 1) {
                Text(song.title)
                    .font(.system(size: 12, weight: isSelected ? .semibold : .regular))
                    .lineLimit(1)
                Text(song.artistName)
                    .font(.system(size: 10))
                    .foregroundStyle(isSelected ? .white.opacity(0.85) : .secondary)
                    .lineLimit(1)
            }
            Spacer(minLength: 4)
            if isSelected {
                Image(systemName: "play.fill").font(.system(size: 9))
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background {
            if isSelected {
                RoundedRectangle(cornerRadius: 7)
                    .fill(Color.rotaAccent.opacity(0.9))
            }
        }
        .foregroundStyle(isSelected ? .white : .primary)
    }

    private var emptyState: some View {
        VStack(spacing: 8) {
            Spacer()
            Image(systemName: "music.note.list").font(.system(size: 28)).foregroundStyle(.secondary)
            Text("No songs found")
                .font(.system(size: 12, weight: .medium))
            Text("Add music to your Apple Music library, then reopen Rota.")
                .font(.system(size: 10))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Spacer()
        }
        .padding(.horizontal, 12)
    }
}
