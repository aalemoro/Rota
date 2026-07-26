//
//  Shared.swift
//  RotaKit — shared between the Rota app and its WidgetKit extension.
//
//  The app publishes a now-playing snapshot (JSON + cover JPEGs) into the
//  app-group container; the widget renders it and sends commands back
//  through a small command file + distributed notification.
//

import Foundation
import AppKit

public struct SharedNowPlaying: Codable {
    public var title: String
    public var artist: String
    public var album: String
    public var playing: Bool
    public var favorited: Bool
    public var duration: Double
    public var position: Double
    public var updatedAt: Date
    public var persistentID: String?

    public init(title: String, artist: String, album: String,
                playing: Bool, favorited: Bool,
                duration: Double, position: Double, updatedAt: Date,
                persistentID: String? = nil) {
        self.title = title
        self.artist = artist
        self.album = album
        self.playing = playing
        self.favorited = favorited
        self.duration = duration
        self.position = position
        self.updatedAt = updatedAt
        self.persistentID = persistentID
    }

    public var hasTrack: Bool { !title.isEmpty }
}

public enum SharedStore {

    public static let groupID = "group.io.github.aalemoro.rota"
    public static let widgetKind = "RotaNowPlaying"
    public static let commandNotification = Notification.Name("io.github.aalemoro.rota.command")

    // MARK: Container

    public static var containerURL: URL {
        let fm = FileManager.default
        let url: URL
        if let container = fm.containerURL(forSecurityApplicationGroupIdentifier: groupID) {
            url = container
        } else {
            url = fm.homeDirectoryForCurrentUser
                .appendingPathComponent("Library/Group Containers/\(groupID)", isDirectory: true)
        }
        try? fm.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    private static var nowPlayingURL: URL { containerURL.appendingPathComponent("nowplaying.json") }
    private static var coverURL: URL { containerURL.appendingPathComponent("cover.jpg") }
    private static var coverBlurURL: URL { containerURL.appendingPathComponent("cover_blur.jpg") }
    private static var commandURL: URL { containerURL.appendingPathComponent("command.txt") }

    // MARK: Now playing

    public static func writeNowPlaying(_ info: SharedNowPlaying) {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .secondsSince1970
        guard let data = try? encoder.encode(info) else { return }
        try? data.write(to: nowPlayingURL, options: .atomic)
    }

    public static func readNowPlaying() -> SharedNowPlaying? {
        guard let data = try? Data(contentsOf: nowPlayingURL) else { return nil }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .secondsSince1970
        return try? decoder.decode(SharedNowPlaying.self, from: data)
    }

    // MARK: Covers

    public static func writeCover(_ data: Data) {
        try? data.write(to: coverURL, options: .atomic)
    }

    public static func writeCoverBlurred(_ data: Data) {
        try? data.write(to: coverBlurURL, options: .atomic)
    }

    public static func readCover() -> NSImage? {
        NSImage(contentsOf: coverURL)
    }

    public static func readCoverBlurred() -> NSImage? {
        NSImage(contentsOf: coverBlurURL)
    }

    /// JPEG data, downscaled so the longest side is `maxDimension`.
    public static func jpegData(from image: NSImage, maxDimension: CGFloat) -> Data? {
        guard let tiff = image.tiffRepresentation,
              let rep = NSBitmapImageRep(data: tiff)
        else { return nil }

        let width = CGFloat(rep.pixelsWide)
        let height = CGFloat(rep.pixelsHigh)
        let scale = min(1, maxDimension / max(width, height))

        if scale >= 1 {
            return rep.representation(using: .jpeg, properties: [.compressionFactor: 0.85])
        }

        let targetSize = NSSize(width: floor(width * scale), height: floor(height * scale))
        let target = NSImage(size: targetSize)
        target.lockFocus()
        NSGraphicsContext.current?.imageInterpolation = .high
        image.draw(in: NSRect(origin: .zero, size: targetSize),
                   from: .zero, operation: .copy, fraction: 1)
        target.unlockFocus()

        guard let scaledTiff = target.tiffRepresentation,
              let scaledRep = NSBitmapImageRep(data: scaledTiff)
        else { return nil }
        return scaledRep.representation(using: .jpeg, properties: [.compressionFactor: 0.85])
    }

    // MARK: Commands (widget → app)

    public static func sendCommand(_ command: String) {
        let payload = "\(command)|\(Date().timeIntervalSince1970)"
        try? payload.write(to: commandURL, atomically: true, encoding: .utf8)
        DistributedNotificationCenter.default().post(name: commandNotification, object: nil)
    }

    public static func readCommand() -> (command: String, stamp: TimeInterval)? {
        guard let raw = try? String(contentsOf: commandURL, encoding: .utf8) else { return nil }
        let parts = raw.split(separator: "|")
        guard parts.count == 2, let stamp = TimeInterval(parts[1]) else { return nil }
        return (String(parts[0]), stamp)
    }
}
