//
//  ClickWheel.swift
//  Rota
//
//  The interactive click wheel. It reproduces the iPod feel on the Mac:
//   • drag around the ring to scroll / scrub (emits discrete steps)
//   • tap the four cardinal zones for Menu, Prev, Next and Play/Pause
//   • tap the centre button to select / toggle playback
//
//  It's rendered in Liquid Glass so it sits naturally on the iPod body. Haptic-
//  style step feedback is simulated with a light scale animation on the centre.
//

import SwiftUI

struct ClickWheel: View {
    var onStep: (Int) -> Void          // +1 clockwise, -1 counter-clockwise
    var onCenter: () -> Void
    var onMenu: () -> Void
    var onPrevious: () -> Void
    var onNext: () -> Void
    var onPlayPause: () -> Void

    @State private var lastAngle: Double? = nil
    @State private var accumulated: Double = 0
    @State private var centerPressed = false

    /// Degrees of rotation that make one scroll "step".
    private let stepDegrees: Double = 18

    var body: some View {
        GeometryReader { geo in
            let side = min(geo.size.width, geo.size.height)
            let center = CGPoint(x: geo.size.width / 2, y: geo.size.height / 2)
            let ringWidth = side * 0.30
            let centerRadius = side * 0.19

            ZStack {
                // The glass wheel ring
                Circle()
                    .fill(.clear)
                    .frame(width: side, height: side)
                    .glassEffect(.regular, in: .circle)
                    .overlay {
                        Circle()
                            .strokeBorder(.white.opacity(0.10), lineWidth: 1)
                            .frame(width: side, height: side)
                    }

                // Cardinal labels / controls
                wheelLabel("MENU", angle: .top, side: side).onTapGesture { onMenu() }
                wheelIcon("backward.fill", angle: .leading, side: side).onTapGesture { onPrevious() }
                wheelIcon("forward.fill", angle: .trailing, side: side).onTapGesture { onNext() }
                wheelIcon("playpause.fill", angle: .bottom, side: side).onTapGesture { onPlayPause() }

                // Centre select button
                Circle()
                    .fill(.clear)
                    .frame(width: centerRadius * 2, height: centerRadius * 2)
                    .glassEffect(.regular, in: .circle)
                    .overlay {
                        Circle().strokeBorder(.white.opacity(0.12), lineWidth: 1)
                            .frame(width: centerRadius * 2, height: centerRadius * 2)
                    }
                    .scaleEffect(centerPressed ? 0.92 : 1)
                    .contentShape(Circle())
                    .onTapGesture {
                        withAnimation(.spring(response: 0.18, dampingFraction: 0.5)) { centerPressed = true }
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
                            withAnimation(.spring(response: 0.2, dampingFraction: 0.6)) { centerPressed = false }
                        }
                        onCenter()
                    }
            }
            .frame(width: geo.size.width, height: geo.size.height)
            .contentShape(Circle())
            // Rotation gesture on the ring (ignores the centre button area).
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        let dx = value.location.x - center.x
                        let dy = value.location.y - center.y
                        let dist = (dx * dx + dy * dy).squareRoot()
                        guard dist > centerRadius + 4 else { return } // don't scrub on the button
                        let angle = atan2(dy, dx) * 180 / .pi
                        if let last = lastAngle {
                            var delta = angle - last
                            if delta > 180 { delta -= 360 }
                            if delta < -180 { delta += 360 }
                            accumulated += delta
                            while accumulated >= stepDegrees { accumulated -= stepDegrees; onStep(+1) }
                            while accumulated <= -stepDegrees { accumulated += stepDegrees; onStep(-1) }
                        }
                        lastAngle = angle
                    }
                    .onEnded { _ in lastAngle = nil; accumulated = 0 }
            )
        }
        .aspectRatio(1, contentMode: .fit)
    }

    private enum Cardinal { case top, bottom, leading, trailing }

    private func position(_ c: Cardinal, side: CGFloat) -> CGPoint {
        let r = side * 0.5
        let inset = side * 0.135
        switch c {
        case .top:      return CGPoint(x: r, y: inset)
        case .bottom:   return CGPoint(x: r, y: side - inset)
        case .leading:  return CGPoint(x: inset, y: r)
        case .trailing: return CGPoint(x: side - inset, y: r)
        }
    }

    private func wheelLabel(_ text: String, angle: Cardinal, side: CGFloat) -> some View {
        Text(text)
            .font(.system(size: side * 0.055, weight: .bold, design: .rounded))
            .foregroundStyle(.secondary)
            .position(position(angle, side: side))
    }

    private func wheelIcon(_ name: String, angle: Cardinal, side: CGFloat) -> some View {
        Image(systemName: name)
            .font(.system(size: side * 0.07, weight: .semibold))
            .foregroundStyle(.secondary)
            .position(position(angle, side: side))
    }
}
