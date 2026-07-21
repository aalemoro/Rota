//
//  NowPlayingView.swift
//  Rota
//
//  The "screen" content when the iPod is showing the current track: artwork,
//  title/artist, and the draggable Liquid Glass seek bar. Mirrors the classic
//  iPod now-playing layout, updated for glass.
//

import SwiftUI

struct NowPlayingView: View {
    let snapshot: NowPlayingSnapshot
    var onSeek: (Double) -> Void = { _ in }

    var body: some View {
        VStack(spacing: 10) {
            artwork
                .frame(maxWidth: .infinity)

            VStack(spacing: 2) {
                Text(snapshot.title)
                    .font(.system(size: 14, weight: .semibold))
                    .lineLimit(1)
                Text(snapshot.artist)
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                if !snapshot.album.isEmpty {
                    Text(snapshot.album)
                        .font(.system(size: 11))
                        .foregroundStyle(.tertiary)
                        .lineLimit(1)
                }
            }
            .multilineTextAlignment(.center)

            SeekBar(progress: snapshot.progress, duration: snapshot.duration, onSeek: onSeek)
        }
        .foregroundStyle(.white)
    }

    private var artwork: some View {
        Group {
            if let image = snapshot.artworkImage {
                image.resizable().aspectRatio(contentMode: .fill)
            } else {
                ZStack {
                    LinearGradient(colors: [.gray.opacity(0.5), .black.opacity(0.6)],
                                   startPoint: .topLeading, endPoint: .bottomTrailing)
                    Image(systemName: "music.note")
                        .font(.system(size: 34))
                        .foregroundStyle(.white.opacity(0.7))
                }
            }
        }
        .frame(width: 148, height: 148)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        // Liquid Glass sheen over the artwork
        .overlay {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(LinearGradient(
                    colors: [.white.opacity(0.22), .clear, .clear],
                    startPoint: .topLeading, endPoint: .bottomTrailing))
                .blendMode(.plusLighter)
        }
        .overlay {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(.white.opacity(0.16), lineWidth: 1)
        }
        .shadow(color: .black.opacity(0.45), radius: 10, y: 5)
    }
}
