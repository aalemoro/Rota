//
//  RotaWidgets.swift
//  Rota — WidgetKit extension
//
//  The real, gallery-installable desktop widget. It renders the snapshot
//  the Rota app publishes into the shared container, and its buttons send
//  commands back to the app.
//

import WidgetKit
import SwiftUI
import AppIntents
import RotaKit

@main
struct RotaWidgets: WidgetBundle {
    var body: some Widget {
        RotaNowPlayingWidget()
    }
}

// MARK: - Timeline

struct NowPlayingEntry: TimelineEntry {
    let date: Date
    let info: SharedNowPlaying?
    let cover: NSImage?
    let coverBlurred: NSImage?
}

struct NowPlayingProvider: TimelineProvider {

    func placeholder(in context: Context) -> NowPlayingEntry {
        NowPlayingEntry(date: Date(), info: nil, cover: nil, coverBlurred: nil)
    }

    func getSnapshot(in context: Context, completion: @escaping (NowPlayingEntry) -> Void) {
        completion(currentEntry())
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<NowPlayingEntry>) -> Void) {
        // The app pushes reloads whenever something changes.
        completion(Timeline(entries: [currentEntry()], policy: .never))
    }

    private func currentEntry() -> NowPlayingEntry {
        NowPlayingEntry(
            date: Date(),
            info: SharedStore.readNowPlaying(),
            cover: SharedStore.readCover(),
            coverBlurred: SharedStore.readCoverBlurred()
        )
    }
}

// MARK: - Intents (widget buttons → app)

struct RotaPlayPauseIntent: AppIntent {
    static var title: LocalizedStringResource = "Play / Pause"
    static var description = IntentDescription("Toggles Apple Music playback via Rota.")
    func perform() async throws -> some IntentResult {
        SharedStore.sendCommand("playpause")
        return .result()
    }
}

struct RotaNextIntent: AppIntent {
    static var title: LocalizedStringResource = "Next Track"
    static var description = IntentDescription("Skips to the next track via Rota.")
    func perform() async throws -> some IntentResult {
        SharedStore.sendCommand("next")
        return .result()
    }
}

struct RotaPreviousIntent: AppIntent {
    static var title: LocalizedStringResource = "Previous Track"
    static var description = IntentDescription("Goes back a track via Rota.")
    func perform() async throws -> some IntentResult {
        SharedStore.sendCommand("previous")
        return .result()
    }
}

struct RotaFavoriteIntent: AppIntent {
    static var title: LocalizedStringResource = "Favourite"
    static var description = IntentDescription("Favourites the current song via Rota.")
    func perform() async throws -> some IntentResult {
        SharedStore.sendCommand("favorite")
        return .result()
    }
}

// MARK: - Widget

struct RotaNowPlayingWidget: Widget {

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: SharedStore.widgetKind, provider: NowPlayingProvider()) { entry in
            NowPlayingView(entry: entry)
                .containerBackground(for: .widget) {
                    WidgetBackground(entry: entry)
                }
                .widgetURL(URL(string: "rota://show"))
        }
        .configurationDisplayName("Now Playing")
        .description("Apple Music at a glance — cover, track and controls.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
        .contentMarginsDisabled()
    }
}

// MARK: - Views

struct WidgetBackground: View {

    let entry: NowPlayingEntry

    var body: some View {
        GeometryReader { geo in
            ZStack {
                if let cover = entry.cover {
                    Image(nsImage: cover)
                        .resizable()
                        .interpolation(.high)
                        .scaledToFill()
                        .frame(width: geo.size.width, height: geo.size.height)
                        .clipped()
                    if let blurred = entry.coverBlurred {
                        Image(nsImage: blurred)
                            .resizable()
                            .scaledToFill()
                            .frame(width: geo.size.width, height: geo.size.height)
                            .clipped()
                            .mask(
                                LinearGradient(
                                    stops: [
                                        .init(color: .clear, location: 0.35),
                                        .init(color: .black, location: 0.68)
                                    ],
                                    startPoint: .top, endPoint: .bottom
                                )
                            )
                    }
                    LinearGradient(
                        stops: [
                            .init(color: .black.opacity(0.0), location: 0.4),
                            .init(color: .black.opacity(0.5), location: 1.0)
                        ],
                        startPoint: .top, endPoint: .bottom
                    )
                } else {
                    LinearGradient(
                        colors: [
                            Color(red: 0.13, green: 0.15, blue: 0.27),
                            Color(red: 0.07, green: 0.07, blue: 0.15)
                        ],
                        startPoint: .topLeading, endPoint: .bottomTrailing
                    )
                }
            }
        }
    }
}

struct NowPlayingView: View {

    @Environment(\.widgetFamily) private var family
    let entry: NowPlayingEntry

    private var info: SharedNowPlaying? { entry.info }
    private var hasTrack: Bool { info?.hasTrack == true }

    var body: some View {
        switch family {
        case .systemSmall:
            smallView
        case .systemMedium:
            mediumView
        default:
            largeView
        }
    }

    // MARK: Small — cover + title + state

    private var smallView: some View {
        VStack(alignment: .leading, spacing: 2) {
            Spacer()
            if hasTrack {
                Text(info?.title ?? "")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                Text(info?.artist ?? "")
                    .font(.system(size: 10.5))
                    .foregroundStyle(.white.opacity(0.65))
                    .lineLimit(1)
            } else {
                emptyLabel
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .shadow(color: .black.opacity(0.4), radius: 5, y: 1)
    }

    // MARK: Medium — info + transport

    private var mediumView: some View {
        VStack(alignment: .leading, spacing: 8) {
            Spacer(minLength: 0)
            if hasTrack {
                VStack(alignment: .leading, spacing: 1) {
                    Text(info?.title ?? "")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                    Text(info?.artist ?? "")
                        .font(.system(size: 11.5))
                        .foregroundStyle(.white.opacity(0.65))
                        .lineLimit(1)
                }
                controls(size: 15, spacing: 22)
            } else {
                emptyLabel
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .shadow(color: .black.opacity(0.4), radius: 5, y: 1)
    }

    // MARK: Large — the full card

    private var largeView: some View {
        VStack(alignment: .leading, spacing: 10) {
            Spacer(minLength: 0)
            if hasTrack {
                HStack(alignment: .center) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(info?.title ?? "")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundStyle(.white)
                            .lineLimit(1)
                        Text(info?.artist ?? "")
                            .font(.system(size: 13))
                            .foregroundStyle(.white.opacity(0.65))
                            .lineLimit(1)
                    }
                    Spacer(minLength: 8)
                    if entry.info?.source != "spotify" {
                        favoriteButton
                    }
                }
                progressBar
                controls(size: 19, spacing: 34)
                    .frame(maxWidth: .infinity)
            } else {
                emptyLabel
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(18)
        .shadow(color: .black.opacity(0.4), radius: 6, y: 1)
    }

    private var favoriteButton: some View {
        Button(intent: RotaFavoriteIntent()) {
            Image(systemName: info?.favorited == true ? "star.fill" : "star")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.white.opacity(0.9))
                .frame(width: 28, height: 28)
                .background(Circle().fill(.black.opacity(0.25)))
        }
        .buttonStyle(.plain)
    }

    private var progressBar: some View {
        let duration = info?.duration ?? 0
        let position = info?.position ?? 0
        let fraction = duration > 0 ? max(0, min(1, position / duration)) : 0
        return GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(.white.opacity(0.28)).frame(height: 3.5)
                Capsule().fill(.white.opacity(0.92))
                    .frame(width: max(3.5, geo.size.width * fraction), height: 3.5)
            }
            .frame(height: geo.size.height)
        }
        .frame(height: 8)
    }

    private func controls(size: CGFloat, spacing: CGFloat) -> some View {
        HStack(spacing: spacing) {
            Button(intent: RotaPreviousIntent()) {
                Image(systemName: "backward.fill")
                    .font(.system(size: size, weight: .semibold))
            }
            .buttonStyle(.plain)

            Button(intent: RotaPlayPauseIntent()) {
                Image(systemName: info?.playing == true ? "pause.fill" : "play.fill")
                    .font(.system(size: size + 7, weight: .semibold))
            }
            .buttonStyle(.plain)

            Button(intent: RotaNextIntent()) {
                Image(systemName: "forward.fill")
                    .font(.system(size: size, weight: .semibold))
            }
            .buttonStyle(.plain)
        }
        .foregroundStyle(.white)
    }

    private var emptyLabel: some View {
        VStack(alignment: .leading, spacing: 4) {
            Image(systemName: "music.note")
                .font(.system(size: 20, weight: .light))
                .foregroundStyle(.white.opacity(0.6))
            Text("Rota")
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(.white.opacity(0.9))
            Text("Play something in Music")
                .font(.system(size: 10.5))
                .foregroundStyle(.white.opacity(0.55))
        }
    }
}
