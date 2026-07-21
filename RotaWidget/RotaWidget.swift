//
//  RotaWidget.swift
//  RotaWidget
//
//  The widget itself, in all three sizes (small / medium / large). Each size is
//  a different density of the same idea: what's playing, plus interactive
//  transport controls wired to the App Intents. Rendered on a dark glassy
//  container so it feels of a piece with the app.
//

import WidgetKit
import SwiftUI
import AppIntents

struct RotaWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: AppGroup.widgetKind, provider: RotaProvider()) { entry in
            RotaWidgetView(snapshot: entry.snapshot)
                .containerBackground(for: .widget) {
                    LinearGradient(colors: [Color(white: 0.12), Color(white: 0.04)],
                                   startPoint: .top, endPoint: .bottom)
                }
        }
        .configurationDisplayName("Rota")
        .description("Control your Apple Music from a tiny iPod on your desktop.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}

struct RotaWidgetView: View {
    @Environment(\.widgetFamily) var family
    let snapshot: NowPlayingSnapshot

    var body: some View {
        switch family {
        case .systemSmall:  SmallWidget(snapshot: snapshot)
        case .systemLarge:  LargeWidget(snapshot: snapshot)
        default:            MediumWidget(snapshot: snapshot)
        }
    }
}

// MARK: - Small

private struct SmallWidget: View {
    let snapshot: NowPlayingSnapshot

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Artwork(snapshot: snapshot, size: 56)
            VStack(alignment: .leading, spacing: 1) {
                Text(snapshot.title).font(.system(size: 12, weight: .semibold)).lineLimit(1)
                Text(snapshot.artist).font(.system(size: 10)).foregroundStyle(.secondary).lineLimit(1)
            }
            Spacer(minLength: 0)
            HStack {
                ProgressLine(progress: snapshot.progress)
                TransportButton(kind: .playPause, isPlaying: snapshot.isPlaying, size: 30)
            }
        }
        .padding(12)
        .foregroundStyle(.white)
    }
}

// MARK: - Medium

private struct MediumWidget: View {
    let snapshot: NowPlayingSnapshot

    var body: some View {
        HStack(spacing: 14) {
            Artwork(snapshot: snapshot, size: 92)
            VStack(alignment: .leading, spacing: 4) {
                VStack(alignment: .leading, spacing: 1) {
                    Text(snapshot.title).font(.system(size: 15, weight: .semibold)).lineLimit(1)
                    Text(snapshot.artist).font(.system(size: 12)).foregroundStyle(.secondary).lineLimit(1)
                    if !snapshot.album.isEmpty {
                        Text(snapshot.album).font(.system(size: 11)).foregroundStyle(.tertiary).lineLimit(1)
                    }
                }
                Spacer(minLength: 2)
                ProgressLine(progress: snapshot.progress)
                HStack(spacing: 18) {
                    TransportButton(kind: .previous, isPlaying: snapshot.isPlaying, size: 30)
                    TransportButton(kind: .playPause, isPlaying: snapshot.isPlaying, size: 40)
                    TransportButton(kind: .next, isPlaying: snapshot.isPlaying, size: 30)
                }
                .frame(maxWidth: .infinity)
            }
        }
        .padding(14)
        .foregroundStyle(.white)
    }
}

// MARK: - Large

private struct LargeWidget: View {
    let snapshot: NowPlayingSnapshot

    var body: some View {
        VStack(spacing: 14) {
            Artwork(snapshot: snapshot, size: 150)
                .frame(maxWidth: .infinity)
            VStack(spacing: 2) {
                Text(snapshot.title).font(.system(size: 17, weight: .bold)).lineLimit(1)
                Text(snapshot.artist).font(.system(size: 13)).foregroundStyle(.secondary).lineLimit(1)
                if !snapshot.album.isEmpty {
                    Text(snapshot.album).font(.system(size: 12)).foregroundStyle(.tertiary).lineLimit(1)
                }
            }
            ProgressLine(progress: snapshot.progress)
            HStack(spacing: 26) {
                TransportButton(kind: .previous, isPlaying: snapshot.isPlaying, size: 34)
                TransportButton(kind: .playPause, isPlaying: snapshot.isPlaying, size: 52)
                TransportButton(kind: .next, isPlaying: snapshot.isPlaying, size: 34)
            }
            .padding(.top, 2)
        }
        .padding(18)
        .foregroundStyle(.white)
    }
}

// MARK: - Shared widget pieces

private struct Artwork: View {
    let snapshot: NowPlayingSnapshot
    let size: CGFloat

    var body: some View {
        Group {
            if let image = snapshot.artworkImage {
                image.resizable().aspectRatio(contentMode: .fill)
            } else {
                ZStack {
                    LinearGradient(colors: [.gray.opacity(0.5), .black.opacity(0.6)],
                                   startPoint: .topLeading, endPoint: .bottomTrailing)
                    Image(systemName: "music.note").font(.system(size: size * 0.32)).foregroundStyle(.white.opacity(0.7))
                }
            }
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: size * 0.14, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: size * 0.14, style: .continuous)
                .strokeBorder(.white.opacity(0.12), lineWidth: 1)
        }
    }
}

private struct ProgressLine: View {
    let progress: Double
    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(.white.opacity(0.18))
                Capsule().fill(Color.rotaAccent)
                    .frame(width: max(2, geo.size.width * progress))
            }
        }
        .frame(height: 4)
    }
}

private struct TransportButton: View {
    enum Kind { case previous, playPause, next }
    let kind: Kind
    let isPlaying: Bool
    let size: CGFloat

    var body: some View {
        // `Button(intent:)` needs a *concrete* AppIntent, so build each case
        // with its own intent type.
        Group {
            switch kind {
            case .previous:
                Button(intent: PreviousTrackIntent()) { label }
            case .next:
                Button(intent: NextTrackIntent()) { label }
            case .playPause:
                Button(intent: PlayPauseIntent()) { label }
            }
        }
        .buttonStyle(.plain)
        .foregroundStyle(kind == .playPause ? Color.rotaAccent : .white)
    }

    private var label: some View {
        Image(systemName: symbol)
            .font(.system(size: size * 0.42, weight: .semibold))
            .frame(width: size, height: size)
            .background(Circle().fill(.white.opacity(0.10)))
            .overlay(Circle().strokeBorder(.white.opacity(0.14), lineWidth: 1))
    }

    private var symbol: String {
        switch kind {
        case .previous:  return "backward.fill"
        case .next:      return "forward.fill"
        case .playPause: return isPlaying ? "pause.fill" : "play.fill"
        }
    }
}
