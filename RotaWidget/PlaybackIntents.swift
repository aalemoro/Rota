//
//  PlaybackIntents.swift
//  RotaWidget
//
//  App Intents that back the widget's interactive buttons. Tapping a control in
//  the widget runs one of these; each drives the shared `PlaybackEngine` (the
//  same one the app uses) and then refreshes the snapshot + widget timeline.
//
//  Interactive widgets require iOS 17 / macOS 14 or later. The buttons in
//  `RotaWidget` bind to these via `Button(intent:)`.
//

import AppIntents
import WidgetKit

struct PlayPauseIntent: AppIntent {
    static var title: LocalizedStringResource = "Play / Pause"
    static var description = IntentDescription("Toggle playback in Rota.")

    func perform() async throws -> some IntentResult {
        await PlaybackEngine.togglePlayPause()
        return .result()
    }
}

struct NextTrackIntent: AppIntent {
    static var title: LocalizedStringResource = "Next Track"

    func perform() async throws -> some IntentResult {
        await PlaybackEngine.next()
        return .result()
    }
}

struct PreviousTrackIntent: AppIntent {
    static var title: LocalizedStringResource = "Previous Track"

    func perform() async throws -> some IntentResult {
        await PlaybackEngine.previous()
        return .result()
    }
}

struct ShuffleIntent: AppIntent {
    static var title: LocalizedStringResource = "Toggle Shuffle"

    func perform() async throws -> some IntentResult {
        await PlaybackEngine.toggleShuffle()
        return .result()
    }
}

struct RepeatIntent: AppIntent {
    static var title: LocalizedStringResource = "Cycle Repeat"

    func perform() async throws -> some IntentResult {
        await PlaybackEngine.cycleRepeat()
        return .result()
    }
}
