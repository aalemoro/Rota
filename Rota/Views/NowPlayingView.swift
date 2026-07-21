//
//  NowPlayingView.swift
//  Rota
//
//  The "screen" content when the iPod is showing the current track: artwork,
//  title/artist, and a slim progress bar. Mirrors the classic iPod now-playing
//  layout, updated for glass.
//

import SwiftUI

struct NowPlayingView: View {
    let snapshot: NowPlayingSnapshot

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

            progressBar
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
        .frame(width: 150, height: 150)
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .strokeBorder(.white.opacity(0.12), lineWidth: 1)
        }
        .shadow(color: .black.opacity(0.4), radius: 8, y: 4)
    }

    private var progressBar: some View {
        VStack(spacing: 3) {
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(.white.opacity(0.18))
                    Capsule().fill(Color.rotaAccent)
                        .frame(width: max(2, geo.size.width * snapshot.progress))
                }
            }
            .frame(height: 4)

            HStack {
                Text(timeString(snapshot.progress * snapshot.duration))
                Spacer()
                Text("-" + timeString(max(0, snapshot.duration - snapshot.progress * snapshot.duration)))
            }
            .font(.system(size: 9, design: .monospaced))
            .foregroundStyle(.secondary)
        }
    }

    private func timeString(_ seconds: TimeInterval) -> String {
        guard seconds.isFinite, seconds >= 0 else { return "0:00" }
        let s = Int(seconds)
        return String(format: "%d:%02d", s / 60, s % 60)
    }
}
