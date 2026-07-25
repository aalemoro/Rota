//
//  Lyrics.swift
//  Rota
//
//  Synced lyrics from LRCLIB (lrclib.net) — a free, keyless lyrics API.
//  Only track title / artist / album / duration ever leave the machine.
//

import Foundation

// MARK: - Model

struct LyricLine: Equatable, Identifiable {
    let id: Int
    let time: Double
    let text: String
}

// MARK: - Controller

final class LyricsController: ObservableObject {

    enum State: Equatable {
        case idle
        case loading
        case synced([LyricLine])
        case plain([String])
        case instrumental
        case unavailable
    }

    @Published private(set) var state: State = .idle

    private var loadedForID: String?
    private var currentTask: Task<Void, Never>?

    func trackDidChange(for snapshot: MusicSnapshot, loadNow: Bool) {
        currentTask?.cancel()
        loadedForID = nil
        state = .idle
        if loadNow {
            ensureLoaded(for: snapshot)
        }
    }

    func ensureLoaded(for snapshot: MusicSnapshot) {
        guard snapshot.hasTrack else {
            state = .unavailable
            return
        }
        guard loadedForID != snapshot.persistentID else { return }

        loadedForID = snapshot.persistentID
        state = .loading
        currentTask?.cancel()

        let request = LyricsRequest(
            title: snapshot.title,
            artist: snapshot.artist,
            album: snapshot.album,
            duration: snapshot.duration,
            cacheKey: snapshot.persistentID
        )
        let expectedID = snapshot.persistentID

        currentTask = Task { [weak self] in
            let result = await LyricsService.fetch(request)
            guard !Task.isCancelled else { return }
            await MainActor.run { [weak self] in
                guard let self, self.loadedForID == expectedID else { return }
                self.state = result
            }
        }
    }
}

// MARK: - Service

struct LyricsRequest {
    let title: String
    let artist: String
    let album: String
    let duration: Double
    let cacheKey: String
}

enum LyricsService {

    struct LRCRecord: Codable {
        var trackName: String?
        var artistName: String?
        var duration: Double?
        var instrumental: Bool?
        var plainLyrics: String?
        var syncedLyrics: String?
    }

    private static let userAgent = "Rota/2.0 (macOS; +https://github.com/aalemoro/Rota)"

    static func fetch(_ request: LyricsRequest) async -> LyricsController.State {
        // 1. Disk cache
        if let cached = DiskCache.read(key: request.cacheKey) {
            return interpret(cached)
        }

        // 2. Exact match endpoint
        if let record = await getExact(request) {
            DiskCache.write(record, key: request.cacheKey)
            return interpret(record)
        }

        // 3. Fuzzy search fallback
        if let record = await search(request) {
            DiskCache.write(record, key: request.cacheKey)
            return interpret(record)
        }

        return .unavailable
    }

    private static func interpret(_ record: LRCRecord) -> LyricsController.State {
        if record.instrumental == true {
            return .instrumental
        }
        if let synced = record.syncedLyrics, !synced.isEmpty {
            let lines = parseLRC(synced)
            if !lines.isEmpty { return .synced(lines) }
        }
        if let plain = record.plainLyrics, !plain.isEmpty {
            let lines = plain
                .components(separatedBy: .newlines)
                .map { $0.trimmingCharacters(in: .whitespaces) }
            if lines.contains(where: { !$0.isEmpty }) { return .plain(lines) }
        }
        return .unavailable
    }

    // MARK: Endpoints

    private static func getExact(_ request: LyricsRequest) async -> LRCRecord? {
        var components = URLComponents(string: "https://lrclib.net/api/get")!
        components.queryItems = [
            URLQueryItem(name: "track_name", value: request.title),
            URLQueryItem(name: "artist_name", value: request.artist),
            URLQueryItem(name: "album_name", value: request.album),
            URLQueryItem(name: "duration", value: String(Int(request.duration.rounded())))
        ]
        guard let url = components.url,
              let (data, response) = try? await perform(url),
              response.statusCode == 200,
              let record = try? JSONDecoder().decode(LRCRecord.self, from: data)
        else { return nil }
        return record
    }

    private static func search(_ request: LyricsRequest) async -> LRCRecord? {
        var components = URLComponents(string: "https://lrclib.net/api/search")!
        components.queryItems = [
            URLQueryItem(name: "track_name", value: request.title),
            URLQueryItem(name: "artist_name", value: request.artist)
        ]
        guard let url = components.url,
              let (data, response) = try? await perform(url),
              response.statusCode == 200,
              let records = try? JSONDecoder().decode([LRCRecord].self, from: data),
              !records.isEmpty
        else { return nil }

        // Prefer synced lyrics whose duration matches within 4 seconds.
        let scored = records.sorted { a, b in
            let aSynced = (a.syncedLyrics?.isEmpty == false) ? 0 : 1
            let bSynced = (b.syncedLyrics?.isEmpty == false) ? 0 : 1
            if aSynced != bSynced { return aSynced < bSynced }
            let aDelta = abs((a.duration ?? 0) - request.duration)
            let bDelta = abs((b.duration ?? 0) - request.duration)
            return aDelta < bDelta
        }
        if let best = scored.first {
            let delta = abs((best.duration ?? 0) - request.duration)
            if best.syncedLyrics?.isEmpty == false && delta > 4 {
                // Timing likely off for a different edit of the song —
                // keep the words, drop the sync.
                var demoted = best
                demoted.syncedLyrics = nil
                return demoted
            }
            return best
        }
        return nil
    }

    private static func perform(_ url: URL) async throws -> (Data, HTTPURLResponse) {
        var request = URLRequest(url: url)
        request.setValue(userAgent, forHTTPHeaderField: "User-Agent")
        request.timeoutInterval = 12
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw URLError(.badServerResponse)
        }
        return (data, http)
    }

    // MARK: LRC parsing

    /// Parses "[mm:ss.xx] line" (multiple timestamps per line supported).
    static func parseLRC(_ text: String) -> [LyricLine] {
        guard let regex = try? NSRegularExpression(
            pattern: "\\[(\\d{1,2}):(\\d{1,2})(?:[.:](\\d{1,3}))?\\]"
        ) else { return [] }

        var entries: [(Double, String)] = []

        for rawLine in text.components(separatedBy: .newlines) {
            let ns = rawLine as NSString
            let matches = regex.matches(in: rawLine, range: NSRange(location: 0, length: ns.length))
            guard !matches.isEmpty else { continue }

            let lastRange = matches[matches.count - 1].range
            let content = ns.substring(from: lastRange.location + lastRange.length)
                .trimmingCharacters(in: .whitespaces)
            guard !content.isEmpty else { continue }

            for match in matches {
                let minutes = Double(ns.substring(with: match.range(at: 1))) ?? 0
                let seconds = Double(ns.substring(with: match.range(at: 2))) ?? 0
                var fraction = 0.0
                if match.range(at: 3).location != NSNotFound {
                    let fracString = ns.substring(with: match.range(at: 3))
                    if let value = Double(fracString) {
                        fraction = value / pow(10, Double(fracString.count))
                    }
                }
                entries.append((minutes * 60 + seconds + fraction, content))
            }
        }

        entries.sort { $0.0 < $1.0 }
        return entries.enumerated().map { LyricLine(id: $0.offset, time: $0.element.0, text: $0.element.1) }
    }
}

// MARK: - Disk cache

private enum DiskCache {

    private static var directory: URL? {
        guard let base = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first
        else { return nil }
        let dir = base.appendingPathComponent("Rota/Lyrics", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    private static func fileURL(for key: String) -> URL? {
        let safe = key.replacingOccurrences(of: "[^A-Za-z0-9_-]", with: "_", options: .regularExpression)
        guard !safe.isEmpty else { return nil }
        return directory?.appendingPathComponent(safe + ".json")
    }

    static func read(key: String) -> LyricsService.LRCRecord? {
        guard let url = fileURL(for: key),
              let data = try? Data(contentsOf: url)
        else { return nil }
        return try? JSONDecoder().decode(LyricsService.LRCRecord.self, from: data)
    }

    static func write(_ record: LyricsService.LRCRecord, key: String) {
        guard let url = fileURL(for: key),
              let data = try? JSONEncoder().encode(record)
        else { return }
        try? data.write(to: url, options: .atomic)
    }
}
