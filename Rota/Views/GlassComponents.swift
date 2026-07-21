//
//  GlassComponents.swift
//  Rota
//
//  Small reusable pieces built on the iOS/macOS 26 Liquid Glass APIs
//  (`glassEffect`, `GlassEffectContainer`, `.buttonStyle(.glass)`). Centralising
//  them keeps the player views clean and the material consistent.
//

import SwiftUI

// The accent colour lives in Shared/Theme.swift so the widget can use it too.

/// A rounded panel with a regular Liquid Glass material. Used for the iPod body
/// and the widget-style cards inside the app.
struct GlassPanel<Content: View>: View {
    var cornerRadius: CGFloat = 28
    @ViewBuilder var content: Content

    var body: some View {
        content
            .glassEffect(.regular, in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
    }
}

/// A circular glass control button (used for the tap zones around the wheel and
/// the widget transport). Interactive glass on platforms that support it.
struct GlassCircleButton: View {
    let systemName: String
    var size: CGFloat = 44
    var tint: Color? = nil
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: size * 0.42, weight: .semibold))
                .frame(width: size, height: size)
                .contentShape(Circle())
        }
        .buttonStyle(.glass)
        .tint(tint ?? .primary)
        .clipShape(Circle())
    }
}

/// The recessed "screen" of the iPod — a subtly glassy dark rectangle with an
/// inner highlight, so content sits in a little window.
struct ScreenBezel<Content: View>: View {
    @ViewBuilder var content: Content

    var body: some View {
        content
            .padding(14)
            .background {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color.black.opacity(0.55))
                    .overlay {
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .strokeBorder(
                                LinearGradient(
                                    colors: [.white.opacity(0.18), .white.opacity(0.02)],
                                    startPoint: .top, endPoint: .bottom),
                                lineWidth: 1)
                    }
            }
            .glassEffect(.clear, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}
