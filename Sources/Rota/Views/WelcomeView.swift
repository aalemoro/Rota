//
//  WelcomeView.swift
//  Rota
//
//  Shown on first launch (and from rota://welcome). Rota is an agent app whose
//  widget lives *behind* every window, so without this the first run looks like
//  nothing happened at all.
//

import SwiftUI
import AppKit

// MARK: - Floating notes

private struct NoteSpec {
    let symbol: String
    let x: CGFloat
    let size: CGFloat
    let delay: Double
    let duration: Double
    let drift: CGFloat
    let tilt: Double
}

private struct FloatingNotes: View {

    @State private var animating = false

    private let notes: [NoteSpec] = [
        NoteSpec(symbol: "music.note",         x: -128, size: 20, delay: 0.0, duration: 5.2, drift:  16, tilt: -12),
        NoteSpec(symbol: "music.quarternote.3", x:  118, size: 26, delay: 0.9, duration: 6.4, drift: -20, tilt:  10),
        NoteSpec(symbol: "music.note",         x:   92, size: 16, delay: 2.1, duration: 4.8, drift:  12, tilt:  16),
        NoteSpec(symbol: "music.note",         x: -164, size: 14, delay: 3.2, duration: 6.0, drift: -10, tilt:   8),
        NoteSpec(symbol: "music.quarternote.3", x: -84, size: 18, delay: 4.0, duration: 5.6, drift:  22, tilt: -18),
        NoteSpec(symbol: "music.note",         x:  156, size: 19, delay: 1.6, duration: 6.8, drift: -14, tilt:  -6),
    ]

    var body: some View {
        ZStack {
            ForEach(notes.indices, id: \.self) { index in
                let note = notes[index]
                Image(systemName: note.symbol)
                    .font(.system(size: note.size, weight: .medium))
                    .foregroundStyle(.tint)
                    .rotationEffect(.degrees(animating ? note.tilt : 0))
                    .offset(x: note.x + (animating ? note.drift : 0),
                            y: animating ? -96 : 74)
                    .opacity(animating ? 0 : 0.55)
                    .animation(
                        .easeOut(duration: note.duration)
                            .repeatForever(autoreverses: false)
                            .delay(note.delay),
                        value: animating
                    )
            }
        }
        .frame(height: 180)
        .allowsHitTesting(false)
        .onAppear { animating = true }
    }
}

// MARK: - Welcome

struct WelcomeView: View {

    @AppStorage("showWelcomeAtLaunch") private var showAtLaunch = true
    @State private var revealed = false
    @State private var breathing = false

    /// Read straight from the bundle: `NSApp.applicationIconImage` can serve a
    /// stale icon from the LaunchServices cache after an icon change.
    private var appIcon: NSImage {
        if let url = Bundle.main.url(forResource: "AppIcon", withExtension: "icns"),
           let image = NSImage(contentsOf: url) {
            return image
        }
        return NSApp.applicationIconImage ?? NSImage()
    }

    var body: some View {
        VStack(spacing: 0) {

            ZStack {
                FloatingNotes()

                VStack(spacing: 14) {
                    Image(nsImage: appIcon)
                        .resizable()
                        .frame(width: 88, height: 88)
                        .shadow(color: .black.opacity(0.28), radius: 14, y: 6)
                        .scaleEffect(breathing ? 1.03 : 1.0)
                        .animation(.easeInOut(duration: 2.6).repeatForever(autoreverses: true),
                                   value: breathing)

                    Text("Rota is running")
                        .font(.system(size: 24, weight: .semibold))

                    Text("Your music now lives on the desktop.")
                        .font(.system(size: 13))
                        .foregroundStyle(.secondary)
                }
            }
            .frame(height: 216)
            .clipped()
            .padding(.top, 18)
            .padding(.bottom, 20)

            VStack(alignment: .leading, spacing: 18) {
                row("music.note",
                    "Play something in Music",
                    "Rota mirrors whatever the Music app is playing — cover, title, lyrics.")
                row("square.on.square",
                    "The widget sits on your desktop",
                    "Like the built-in widgets, it stays behind your windows. Use the button below to bring it forward.")
                row("cursorarrow.click",
                    "Right-click it for everything",
                    "Size, lyrics, keep on top, launch at login.")
            }
            .padding(.horizontal, 30)

            Spacer(minLength: 18)

            HStack(spacing: 10) {
                Toggle("Show this window at launch", isOn: $showAtLaunch)
                    .toggleStyle(.checkbox)
                    .font(.system(size: 12))

                Spacer()

                Button("Open Music") {
                    AppDelegate.shared?.openMusic()
                }

                Button(revealed ? "Widget shown" : "Show the widget") {
                    AppDelegate.shared?.revealWidget()
                    revealed = true
                }
                .keyboardShortcut(.defaultAction)
                .disabled(revealed)
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 20)
        }
        .frame(width: 480, height: 520)
        .background(.background)
        .onAppear { breathing = true }
    }

    private func row(_ symbol: String, _ title: String, _ detail: String) -> some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: symbol)
                .font(.system(size: 17, weight: .medium))
                .frame(width: 26, height: 22)
                .foregroundStyle(.tint)

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.system(size: 13, weight: .semibold))
                Text(detail)
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
    }
}
