//
//  AppGroup.swift
//  Rota — shared between the app and the widget extension.
//
//  A single place for the App Group identifier and the shared UserDefaults
//  suite the two processes use to exchange the "now playing" snapshot.
//
//  ⚠️  IMPORTANT: replace `group.com.yourteam.rota` below with the App Group
//  you create in the Apple Developer portal (and enable on BOTH targets in
//  Signing & Capabilities). It must match the string in the two
//  `.entitlements` files exactly.
//

import Foundation

enum AppGroup {
    /// The shared App Group identifier. Keep this in sync with the entitlements.
    static let identifier = "group.com.yourteam.rota"

    /// Shared defaults used to pass the playback snapshot to the widget.
    static var defaults: UserDefaults {
        UserDefaults(suiteName: identifier) ?? .standard
    }

    enum Key {
        static let nowPlaying = "rota.nowPlaying.v1"
    }

    /// The widget kind identifier used by WidgetKit and `WidgetCenter`.
    static let widgetKind = "RotaWidget"
}
