//
//  MusicController.swift
//  Rota
//
//  The app-side brain: owns Apple Music authorization, loads a browsable list
//  of songs from the user's library, drives playback through `PlaybackEngine`,
//  and keeps a live `NowPlayingSnapshot` for the UI (and, via the engine, the
//  widget).
//

import Foundation
import MusicKit
import Combine
import WidgetKit

@MainActor
final class MusicController: ObservableObject {

    enum Screen { case nowPlaying, library }

    // MARK: Published UI state
    @Published var authorization: MusicAuthorization.Status = MusicAuthorization.currentStatus
    @Published var songs: [Song] = []
    @Published var selection: Int = 0            // highlighted row in the library list
    @Published var screen: Screen = .nowPlaying
    @Published var nowPlaying: NowPlayingSnapshot = SnapshotStore.read()
    @Published var isLoadingLibrary = false
    @Published var lastError: String?

    private var ticker: AnyCancellable?
    private var didBootstrap = false

    var isAuthorized: Bool { authorization == .authorized }

    // MARK: Lifecycle

    func bootstrap() async {
        // The window and the menu-bar scene both call this; only run once.
        guard !didBootstrap else { return }
        didBootstrap = true

        authorization = await MusicAuthorization.request()
        guard authorization == .authorized else {
            lastError = "Apple Music access was not granted."
            return
        }
        await loadLibrary()
        await PlaybackEngine.refreshSnapshot()
        nowPlaying = SnapshotStore.read()
        startTicker()
    }

    /// Polls the player twice a second to keep progress + snapshot fresh while
    /// the app is open. Cheap, and only runs while the window is alive.
    private func startTicker() {
        ticker?.cancel()
        ticker = Timer.publish(every: 0.5, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                Task { await self?.tick() }
            }
    }

    private func tick() async {
        nowPlaying = await PlaybackEngine.refreshSnapshot()
    }

    // MARK: Library

    func loadLibrary() async {
        isLoadingLibrary = true
        defer { isLoadingLibrary = false }
        do {
            var request = MusicLibraryRequest<Song>()
            request.limit = 200
            request.sort(by: \.libraryAddedDate, ascending: false)
            let response = try await request.response()
            songs = Array(response.items)
            // If the library is empty, `LibraryView` shows a friendly empty state
            // prompting the user to add music to Apple Music.
        } catch {
            lastError = "Could not load your library: \(error.localizedDescription)"
        }
    }

    // MARK: Playback

    func playSelected() async {
        guard songs.indices.contains(selection) else { return }
        await play(songs[selection])
        screen = .nowPlaying
    }

    func play(_ song: Song) async {
        let player = ApplicationMusicPlayer.shared
        player.queue = ApplicationMusicPlayer.Queue(for: songs, startingAt: song)
        do {
            try await player.prepareToPlay()
            try await player.play()
        } catch {
            lastError = "Playback failed: \(error.localizedDescription)"
        }
        nowPlaying = await PlaybackEngine.refreshSnapshot()
    }

    func togglePlayPause() async { await PlaybackEngine.togglePlayPause(); await tick() }
    func next() async            { await PlaybackEngine.next();            await tick() }
    func previous() async        { await PlaybackEngine.previous();        await tick() }
    func seek(to fraction: Double) async { await PlaybackEngine.seek(toFraction: fraction); await tick() }

    // MARK: Click-wheel navigation

    /// The wheel emits discrete "steps"; interpret them for the active screen.
    func handleWheelStep(_ direction: Int) {
        switch screen {
        case .library:
            guard !songs.isEmpty else { return }
            selection = (selection + direction).clamped(to: 0...(songs.count - 1))
        case .nowPlaying:
            // Rotating on the Now Playing screen nudges the scrub position.
            let delta = Double(direction) * 0.02
            Task { await seek(to: (nowPlaying.progress + delta).clamped(to: 0...1)) }
        }
    }

    func pressCenter() {
        switch screen {
        case .library:   Task { await playSelected() }
        case .nowPlaying: Task { await togglePlayPause() }
        }
    }

    func pressMenu() {
        screen = (screen == .nowPlaying) ? .library : .nowPlaying
    }
}

extension Comparable {
    func clamped(to range: ClosedRange<Self>) -> Self {
        min(max(self, range.lowerBound), range.upperBound)
    }
}
