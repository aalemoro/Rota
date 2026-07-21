//
//  ContentView.swift
//  Rota
//
//  Top-level view. Shows the iPod once Apple Music access is granted, or a
//  friendly authorization prompt otherwise. The soft ambient background lets
//  the glass body read as a real object sitting on a surface.
//

import SwiftUI
import MusicKit

struct ContentView: View {
    @EnvironmentObject var music: MusicController
    var compact: Bool = false

    var body: some View {
        ZStack {
            ambientBackground

            switch music.authorization {
            case .authorized:
                Group {
                    switch music.style {
                    case .player:
                        MiniPlayerView(compact: compact).environmentObject(music)
                    case .wheel:
                        iPodView(compact: compact).environmentObject(music)
                    }
                }
                .padding(compact ? 8 : 12)
                .transition(.opacity)
            case .notDetermined:
                loading
            default:
                authPrompt
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var ambientBackground: some View {
        LinearGradient(
            colors: [Color(red: 0.12, green: 0.12, blue: 0.14),
                     Color(red: 0.04, green: 0.04, blue: 0.06)],
            startPoint: .topLeading, endPoint: .bottomTrailing)
        .overlay {
            RadialGradient(colors: [Color.rotaAccent.opacity(0.14), .clear],
                           center: .topTrailing, startRadius: 0, endRadius: 320)
        }
        .ignoresSafeArea()
    }

    private var loading: some View {
        VStack(spacing: 12) {
            ProgressView().tint(.white)
            Text("Connecting to Apple Music…")
                .font(.system(size: 12)).foregroundStyle(.secondary)
        }
    }

    private var authPrompt: some View {
        VStack(spacing: 14) {
            Image(systemName: "music.note.house.fill")
                .font(.system(size: 40)).foregroundStyle(Color.rotaAccent)
            Text("Rota needs Apple Music")
                .font(.system(size: 15, weight: .semibold)).foregroundStyle(.white)
            Text("Allow access so Rota can play from your library and drive the widget.")
                .font(.system(size: 12)).foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Button("Grant Access") { Task { await music.bootstrap() } }
                .buttonStyle(.glassProminent)
                .tint(Color.rotaAccent)
        }
        .padding(28)
        .frame(maxWidth: 280)
    }
}
