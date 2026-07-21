//
//  Provider.swift
//  RotaWidget
//
//  Feeds the widget its timeline. There's no prediction to do here — we simply
//  read the latest `NowPlayingSnapshot` the app wrote to the App Group and show
//  it. The app calls `WidgetCenter.reloadTimelines` whenever playback changes,
//  so the widget stays in step; the short refresh policy is just a safety net.
//

import WidgetKit
import SwiftUI

struct NowPlayingEntry: TimelineEntry {
    let date: Date
    let snapshot: NowPlayingSnapshot
}

struct RotaProvider: TimelineProvider {
    func placeholder(in context: Context) -> NowPlayingEntry {
        NowPlayingEntry(date: Date(), snapshot: .sample)
    }

    func getSnapshot(in context: Context, completion: @escaping (NowPlayingEntry) -> Void) {
        let snap = context.isPreview ? .sample : SnapshotStore.read()
        completion(NowPlayingEntry(date: Date(), snapshot: snap))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<NowPlayingEntry>) -> Void) {
        let snap = SnapshotStore.read()
        let entry = NowPlayingEntry(date: Date(), snapshot: snap)
        // Refresh again shortly as a fallback; live updates come from the app's
        // explicit reloadTimelines call after each command.
        let next = Calendar.current.date(byAdding: .minute, value: 1, to: Date()) ?? Date().addingTimeInterval(60)
        completion(Timeline(entries: [entry], policy: .after(next)))
    }
}
