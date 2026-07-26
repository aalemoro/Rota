//
//  RootView.swift
//  Rota
//
//  The widget shell: artwork background, hover chrome, size-aware layout.
//

import SwiftUI

/// Layout class derived from the actual widget footprint.
enum WidgetSizeMode {
    case small   // 180 × 180
    case wide    // 360 × 180
    case large   // 360 × 360
}

struct RootView: View {

    @EnvironmentObject var store: PlayerStore
    @State private var hovering = false

    private let cornerRadius: CGFloat = 22

    var body: some View {
        GeometryReader { geo in
            let mode = sizeMode(for: geo.size)
            ZStack {
                ArtworkBackground(
                    artwork: store.artwork,
                    blurred: store.artworkBlurred,
                    dimmed: store.showLyrics,
                    chrome: hovering || store.isScrubbing
                )

                content(mode: mode)
                    .frame(width: geo.size.width, height: geo.size.height)

                TopBar(hovering: hovering, mode: mode)
            }
            .frame(width: geo.size.width, height: geo.size.height)
        }
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .strokeBorder(Color.white.opacity(0.10), lineWidth: 1)
        )
        .onHover { inside in
            withAnimation(.easeOut(duration: 0.18)) { hovering = inside }
        }
        .animation(.spring(response: 0.42, dampingFraction: 0.86), value: store.showLyrics)
        .animation(.easeInOut(duration: 0.35), value: store.availability)
        .preferredColorScheme(.dark)
        .contextMenu { menuItems }
    }

    private func sizeMode(for size: CGSize) -> WidgetSizeMode {
        if size.width < 240 { return .small }
        if size.height < 240 { return .wide }
        return .large
    }

    @ViewBuilder
    private func content(mode: WidgetSizeMode) -> some View {
        switch store.availability {
        case .musicNotRunning:
            if store.artwork != nil || store.snapshot.hasTrack {
                // Ghost mode — the last cover stays on the desktop; hovering
                // reveals a resume button that brings Music back to life.
                GhostPlayerView(hovering: hovering, mode: mode)
            } else {
                IdleView(
                    symbol: "music.note",
                    title: "Music isn't running",
                    caption: "One click and it starts playing again.",
                    buttonLabel: "Play",
                    compact: mode != .large,
                    action: { store.resumePlayback() }
                )
            }
        case .needsAutomationPermission:
            IdleView(
                symbol: "lock.shield",
                title: "Permission needed",
                caption: "Allow Rota to control Music in\nSystem Settings → Privacy & Security → Automation.",
                buttonLabel: "Open Settings",
                compact: mode != .large,
                action: { store.openAutomationSettings() }
            )
        case .ready:
            if store.showLyrics {
                LyricsView(mode: mode)
                    .transition(.opacity.combined(with: .move(edge: .bottom)))
            } else if store.snapshot.hasTrack {
                PlayerView(hovering: hovering, mode: mode)
                    .transition(.opacity)
            } else if store.artwork != nil {
                GhostPlayerView(hovering: hovering, mode: mode)
            } else {
                IdleView(
                    symbol: "music.note.list",
                    title: "Nothing playing",
                    caption: "Resume the last song, or pick one in Music.",
                    buttonLabel: "Play",
                    compact: mode != .large,
                    action: { store.togglePlayPause() }
                )
            }
        }
    }

    // MARK: - Right-click menu (the widget's control centre)

    @ViewBuilder
    private var menuItems: some View {
        Button(store.snapshot.state == .playing ? "Pause" : "Play") { store.togglePlayPause() }
        Button("Next Track") { store.nextTrack() }
        Button("Previous Track") { store.previousTrack() }
        Divider()
        Button(store.showLyrics ? "Hide Lyrics" : "Show Lyrics") { store.showLyrics.toggle() }
        Divider()
        Menu("Widget Size") {
            ForEach(WidgetSize.allCases, id: \.self) { size in
                Toggle(size.label, isOn: Binding(
                    get: { AppDelegate.shared?.currentWidgetSize == size },
                    set: { _ in AppDelegate.shared?.setWidgetSize(size) }
                ))
            }
        }
        Button(store.keepOnTop ? "Stick to Desktop" : "Float Above Windows") { store.keepOnTop.toggle() }
        Button(store.positionLocked ? "Unlock Position" : "Lock Position") { store.positionLocked.toggle() }
        Toggle("Start at Login", isOn: Binding(
            get: { AppDelegate.shared?.launchesAtLogin ?? false },
            set: { _ in AppDelegate.shared?.toggleLaunchAtLogin() }
        ))
        Divider()
        Button("Open Apple Music") { store.openApp(.appleMusic) }
        if MediaSource.spotify.isInstalled {
            Button("Open Spotify") { store.openApp(.spotify) }
        }
        Button("Hide Rota") { store.onHide?() }
        Divider()
        Button("Quit Rota") { NSApp.terminate(nil) }
    }
}

// MARK: - Background

struct ArtworkBackground: View {

    let artwork: NSImage?
    let blurred: NSImage?
    var dimmed: Bool
    /// When false (mouse away), the cover stands alone — no blur band,
    /// no scrim — exactly like a photo widget.
    var chrome: Bool = true

    var body: some View {
        GeometryReader { geo in
            ZStack {
                if let artwork {
                    if dimmed {
                        Image(nsImage: blurred ?? artwork)
                            .resizable()
                            .scaledToFill()
                            .frame(width: geo.size.width, height: geo.size.height)
                            .clipped()
                            .overlay(Color.black.opacity(0.42))
                    } else {
                        Image(nsImage: artwork)
                            .resizable()
                            .interpolation(.high)
                            .scaledToFill()
                            .frame(width: geo.size.width, height: geo.size.height)
                            .clipped()

                        Group {
                            if let blurred {
                                Image(nsImage: blurred)
                                    .resizable()
                                    .scaledToFill()
                                    .frame(width: geo.size.width, height: geo.size.height)
                                    .clipped()
                                    .mask(
                                        LinearGradient(
                                            stops: [
                                                .init(color: .clear, location: 0.30),
                                                .init(color: .black, location: 0.60)
                                            ],
                                            startPoint: .top,
                                            endPoint: .bottom
                                        )
                                    )
                            }

                            LinearGradient(
                                stops: [
                                    .init(color: .black.opacity(0.0), location: 0.35),
                                    .init(color: .black.opacity(0.52), location: 1.0)
                                ],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        }
                        .opacity(chrome ? 1 : 0)
                    }
                } else {
                    LinearGradient(
                        colors: [
                            Color(red: 0.13, green: 0.15, blue: 0.27),
                            Color(red: 0.07, green: 0.07, blue: 0.15)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                    if dimmed { Color.black.opacity(0.3) }
                }
            }
            .frame(width: geo.size.width, height: geo.size.height)
        }
    }
}

// MARK: - Top chrome

struct TopBar: View {

    @EnvironmentObject var store: PlayerStore
    var hovering: Bool
    var mode: WidgetSizeMode

    @State private var volumeOpen = false

    var body: some View {
        VStack {
            HStack(spacing: 10) {
                Spacer(minLength: 0)

                if store.availability == .ready, mode != .small {
                    HStack(spacing: 4) {
                        GlassIconButton(
                            symbol: store.showLyrics ? "quote.bubble.fill" : "quote.bubble",
                            active: store.showLyrics,
                            help: "Lyrics (L)"
                        ) {
                            store.showLyrics.toggle()
                        }

                        GlassIconButton(
                            symbol: volumeSymbol,
                            active: volumeOpen,
                            help: "Volume"
                        ) {
                            withAnimation(.spring(response: 0.32, dampingFraction: 0.8)) {
                                volumeOpen.toggle()
                            }
                        }

                        if volumeOpen {
                            VolumeBar()
                                .transition(.opacity.combined(with: .scale(scale: 0.6, anchor: .trailing)))
                        }

                        GlassIconButton(
                            symbol: store.keepOnTop ? "pin.fill" : "pin",
                            active: store.keepOnTop,
                            help: store.keepOnTop ? "Floating — click to stick to the desktop" : "On the desktop — click to float above windows"
                        ) {
                            store.keepOnTop.toggle()
                        }
                    }
                    .padding(.horizontal, 6)
                    .padding(.vertical, 4)
                    .background(Capsule().fill(.ultraThinMaterial))
                    .overlay(Capsule().strokeBorder(Color.white.opacity(0.12), lineWidth: 0.5))
                }
            }
            .padding(.horizontal, 10)
            .padding(.top, 10)

            Spacer()
        }
        .opacity(hovering ? 1 : 0)
        .allowsHitTesting(hovering)
    }

    private var volumeSymbol: String {
        let v = store.snapshot.volume
        if v <= 0 { return "speaker.slash.fill" }
        if v < 34 { return "speaker.wave.1.fill" }
        if v < 67 { return "speaker.wave.2.fill" }
        return "speaker.wave.3.fill"
    }
}

struct GlassIconButton: View {

    let symbol: String
    var active: Bool = false
    var help: String = ""
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.white.opacity(active ? 1.0 : 0.62))
                .frame(width: 26, height: 22)
                .contentShape(Rectangle())
        }
        .buttonStyle(PressableStyle())
        .help(help)
    }
}

struct VolumeBar: View {

    @EnvironmentObject var store: PlayerStore

    var body: some View {
        GeometryReader { geo in
            let width = geo.size.width
            let fraction = max(0, min(1, store.snapshot.volume / 100))
            ZStack(alignment: .leading) {
                Capsule().fill(Color.white.opacity(0.28)).frame(height: 4)
                Capsule().fill(Color.white.opacity(0.95))
                    .frame(width: max(4, width * fraction), height: 4)
            }
            .frame(width: width, height: geo.size.height)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        store.setVolume(Double(value.location.x / width) * 100)
                    }
            )
        }
        .frame(width: 74, height: 22)
    }
}

// MARK: - Idle / empty states

struct IdleView: View {

    let symbol: String
    let title: String
    let caption: String
    let buttonLabel: String
    var compact: Bool = false
    let action: () -> Void

    var body: some View {
        VStack(spacing: compact ? 6 : 10) {
            Image(systemName: symbol)
                .font(.system(size: compact ? 24 : 34, weight: .light))
                .foregroundStyle(.white.opacity(0.45))
                .padding(.bottom, 2)

            Text(title)
                .font(.system(size: compact ? 13 : 16, weight: .semibold))
                .foregroundStyle(.white.opacity(0.92))

            if !compact {
                Text(caption)
                    .font(.system(size: 11.5))
                    .foregroundStyle(.white.opacity(0.5))
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Button(action: action) {
                Text(buttonLabel)
                    .font(.system(size: compact ? 11 : 12.5, weight: .semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, compact ? 12 : 16)
                    .padding(.vertical, compact ? 5 : 7)
                    .background(Capsule().fill(.white.opacity(0.14)))
                    .overlay(Capsule().strokeBorder(Color.white.opacity(0.2), lineWidth: 0.5))
            }
            .buttonStyle(PressableStyle())
            .padding(.top, compact ? 2 : 8)
        }
        .padding(compact ? 12 : 24)
    }
}

// MARK: - Shared button style

struct PressableStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.86 : 1.0)
            .opacity(configuration.isPressed ? 0.8 : 1.0)
            .animation(.spring(response: 0.25, dampingFraction: 0.6), value: configuration.isPressed)
    }
}
