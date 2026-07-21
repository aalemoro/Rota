//
//  RotaApp.swift
//  Rota
//
//  Entry point. Rota lives in two places on the Mac: a compact main window that
//  looks like an iPod, and a menu-bar item that drops the same player down from
//  the status bar. Both share one `MusicController`.
//

import SwiftUI

@main
struct RotaApp: App {
    @StateObject private var music = MusicController()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(music)
                .frame(width: 340, height: 560)
                .task { await music.bootstrap() }
        }
        .windowStyle(.hiddenTitleBar)
        .windowResizability(.contentSize)

        // A menu-bar drop-down with the same iPod player.
        MenuBarExtra {
            ContentView(compact: true)
                .environmentObject(music)
                .frame(width: 300, height: 480)
                .task { await music.bootstrap() }
        } label: {
            Image(systemName: music.nowPlaying.isPlaying ? "play.circle.fill" : "circle.circle")
        }
        .menuBarExtraStyle(.window)
    }
}
