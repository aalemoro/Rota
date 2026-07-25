//
//  ITunesArtwork.swift
//  Rota
//
//  Fallback artwork: streaming tracks sometimes expose no artwork through
//  the Music app's scripting interface, so we resolve the cover from
//  Apple's public iTunes Search API instead (no key, HTTPS, metadata only).
//

import AppKit

enum ITunesArtworkService {

    private struct SearchResponse: Codable {
        struct Item: Codable {
            var artworkUrl100: String?
        }
        var results: [Item]
    }

    /// Song search first (much better hit rate), album as fallback.
    /// Returns a ~600 px cover.
    static func fetch(artist: String, album: String, title: String) async -> NSImage? {
        let country = Locale.current.region?.identifier ?? "US"
        if !artist.isEmpty, !title.isEmpty,
           let image = await search(term: "\(artist) \(title)", entity: "song", country: country) {
            return image
        }
        if !artist.isEmpty, !album.isEmpty,
           let image = await search(term: "\(artist) \(album)", entity: "album", country: country) {
            return image
        }
        return nil
    }

    private static func search(term: String, entity: String, country: String) async -> NSImage? {
        var components = URLComponents(string: "https://itunes.apple.com/search")!
        components.queryItems = [
            URLQueryItem(name: "term", value: term),
            URLQueryItem(name: "entity", value: entity),
            URLQueryItem(name: "country", value: country),
            URLQueryItem(name: "limit", value: "3")
        ]
        guard let url = components.url else { return nil }

        var request = URLRequest(url: url)
        request.timeoutInterval = 10

        guard let (data, response) = try? await URLSession.shared.data(for: request),
              (response as? HTTPURLResponse)?.statusCode == 200,
              let decoded = try? JSONDecoder().decode(SearchResponse.self, from: data)
        else { return nil }

        for item in decoded.results {
            guard let thumb = item.artworkUrl100 else { continue }
            let hiRes = thumb
                .replacingOccurrences(of: "100x100", with: "600x600")
            guard let artURL = URL(string: hiRes),
                  let (imageData, imageResponse) = try? await URLSession.shared.data(from: artURL),
                  (imageResponse as? HTTPURLResponse)?.statusCode == 200,
                  let image = NSImage(data: imageData)
            else { continue }
            return image
        }
        return nil
    }
}
