//
//  SeekBar.swift
//  Rota
//
//  A draggable, Liquid Glass progress bar. The track and thumb are real glass;
//  the fill glows in the accent colour. Drag the thumb (or tap anywhere on the
//  track) to scrub — while dragging we show the local position for a smooth
//  feel, then commit the seek on release.
//

import SwiftUI

struct SeekBar: View {
    let progress: Double            // 0…1 from the current snapshot
    let duration: TimeInterval
    let onSeek: (Double) -> Void

    @State private var dragging = false
    @State private var dragFraction: Double = 0

    private var fraction: Double { dragging ? dragFraction : progress }

    var body: some View {
        VStack(spacing: 5) {
            GeometryReader { geo in
                let w = geo.size.width
                let f = CGFloat(fraction)                 // 0…1 as CGFloat for layout
                let thumb: CGFloat = dragging ? 18 : 13
                ZStack(alignment: .leading) {
                    // Glass track
                    Capsule()
                        .fill(.white.opacity(0.12))
                        .frame(height: 6)
                        .glassEffect(.clear, in: Capsule())
                        .overlay {
                            Capsule().strokeBorder(.white.opacity(0.10), lineWidth: 1)
                                .frame(height: 6)
                        }

                    // Glowing accent fill
                    Capsule()
                        .fill(LinearGradient(
                            colors: [Color.rotaAccent.opacity(0.85), Color.rotaAccent],
                            startPoint: .leading, endPoint: .trailing))
                        .frame(width: max(6, w * f), height: 6)
                        .shadow(color: Color.rotaAccent.opacity(dragging ? 0.8 : 0.5),
                                radius: dragging ? 8 : 4)

                    // Draggable glass thumb
                    Circle()
                        .fill(.white.opacity(0.9))
                        .frame(width: thumb, height: thumb)
                        .glassEffect(.regular, in: .circle)
                        .overlay(Circle().strokeBorder(Color.rotaAccent, lineWidth: 2))
                        .shadow(color: .black.opacity(0.45), radius: 3, y: 1)
                        .offset(x: (w * f).clamped(to: 0...w) - thumb / 2)
                        .animation(.spring(response: 0.25, dampingFraction: 0.7), value: dragging)
                }
                .frame(height: 22)
                .contentShape(Rectangle())
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { value in
                            dragging = true
                            dragFraction = Double(value.location.x / w).clamped(to: 0...1)
                        }
                        .onEnded { value in
                            let frac = Double(value.location.x / w).clamped(to: 0...1)
                            onSeek(frac)
                            dragging = false
                        }
                )
            }
            .frame(height: 22)

            HStack {
                Text(timeString(fraction * duration))
                Spacer()
                Text("-" + timeString(max(0, duration - fraction * duration)))
            }
            .font(.system(size: 9, design: .monospaced))
            .foregroundStyle(.secondary)
        }
    }

    private func timeString(_ seconds: TimeInterval) -> String {
        guard seconds.isFinite, seconds >= 0 else { return "0:00" }
        let s = Int(seconds)
        return String(format: "%d:%02d", s / 60, s % 60)
    }
}
