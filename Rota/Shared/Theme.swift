//
//  Theme.swift
//  Rota — shared between the app and the widget extension.
//
//  One source of truth for the accent colour so the app and the widget always
//  match.
//

import SwiftUI

extension ShapeStyle where Self == Color {
    /// Rota's accent — a warm coral that reads well on dark glass.
    static var rotaAccent: Color { Color(red: 1.0, green: 0.361, blue: 0.376) }
}
