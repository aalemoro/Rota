//
//  Artworks.swift
//  Rota — shared helper for turning a MusicKit `Artwork` into PNG data.
//
//  MusicKit exposes artwork as a templated URL; we ask for a modest square,
//  download it, and re-encode a small PNG suitable for stashing in the App
//  Group. Kept deliberately small so widget payloads stay light.
//

import Foundation
import MusicKit

#if canImport(AppKit)
import AppKit
#elseif canImport(UIKit)
import UIKit
#endif

enum Artworks {
    static func png(from artwork: Artwork, size: Int) async -> Data? {
        guard let url = artwork.url(width: size, height: size) else { return nil }
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            return reencodePNG(data, maxDimension: size)
        } catch {
            return nil
        }
    }

    private static func reencodePNG(_ data: Data, maxDimension: Int) -> Data? {
        #if canImport(AppKit)
        guard let image = NSImage(data: data) else { return data }
        guard let tiff = image.tiffRepresentation,
              let rep = NSBitmapImageRep(data: tiff) else { return data }
        return rep.representation(using: .png, properties: [:])
        #elseif canImport(UIKit)
        guard let image = UIImage(data: data) else { return data }
        return image.pngData()
        #else
        return data
        #endif
    }
}
