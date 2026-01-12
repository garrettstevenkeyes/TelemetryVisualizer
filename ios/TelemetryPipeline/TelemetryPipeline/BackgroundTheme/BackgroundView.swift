//
//  BackgroundView.swift
//  TelemetryPipeline
//
//  Created by Garrett Keyes on 12/30/25.
//

import SwiftUI

struct PaperBackground: View {
    var dotColor: Color = Color(red: 0.11, green: 0.18, blue: 0.31) // navy-ish
    var baseColor: Color = Color(red: 0.95, green: 0.91, blue: 0.84) // beige
    var dotCount: Int = 90
    var dotSizeRange: ClosedRange<CGFloat> = 2...5
    var seed: UInt64 = 42

    var body: some View {
        GeometryReader { geo in
            ZStack {
                // Base "paper"
                baseColor
                    .overlay(paperVignette(in: geo.size).blendMode(.multiply).opacity(0.18))
                    .overlay(paperGrain(in: geo.size).opacity(0.08))

                // Speckles
                DotsLayer(
                    size: geo.size,
                    dotColor: dotColor.opacity(0.65),
                    dotCount: dotCount,
                    dotSizeRange: dotSizeRange,
                    seed: seed
                )
            }
            .ignoresSafeArea()
        }
    }

    private func paperVignette(in size: CGSize) -> some View {
        RadialGradient(
            gradient: Gradient(colors: [Color.black.opacity(0.0), Color.black.opacity(0.35)]),
            center: .center,
            startRadius: min(size.width, size.height) * 0.2,
            endRadius: max(size.width, size.height) * 0.8
        )
    }

    private func paperGrain(in size: CGSize) -> some View {
        // Subtle soft blobs to fake "paper texture" without images
        Canvas { context, canvasSize in
            let blobs = 14
            for i in 0..<blobs {
                var rng = SeededGenerator(seed: seed &+ UInt64(i) &* 99991)
                let x = CGFloat.random(in: 0...canvasSize.width, using: &rng)
                let y = CGFloat.random(in: 0...canvasSize.height, using: &rng)
                let r = CGFloat.random(in: 80...180, using: &rng)

                let rect = CGRect(x: x - r/2, y: y - r/2, width: r, height: r)
                context.fill(
                    Path(ellipseIn: rect),
                    with: .color(Color.black.opacity(0.06))
                )
            }
        }
    }
}

private struct DotsLayer: View {
    let size: CGSize
    let dotColor: Color
    let dotCount: Int
    let dotSizeRange: ClosedRange<CGFloat>
    let seed: UInt64

    var body: some View {
        Canvas { context, canvasSize in
            var rng = SeededGenerator(seed: seed)

            for _ in 0..<dotCount {
                let x = CGFloat.random(in: 0...canvasSize.width, using: &rng)
                let y = CGFloat.random(in: 0...canvasSize.height, using: &rng)
                let d = CGFloat.random(in: dotSizeRange, using: &rng)
                let a = Double.random(in: 0.35...0.85, using: &rng)

                let rect = CGRect(x: x, y: y, width: d, height: d)
                context.fill(Path(ellipseIn: rect), with: .color(dotColor.opacity(a)))
            }
        }
    }
}

/// Deterministic RNG so dots don’t move on redraw
private struct SeededGenerator: RandomNumberGenerator {
    var state: UInt64
    init(seed: UInt64) { self.state = seed == 0 ? 0xdeadbeef : seed }

    mutating func next() -> UInt64 {
        // xorshift64*
        state &+= 0x9E3779B97F4A7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58476D1CE4E5B9
        z = (z ^ (z >> 27)) &* 0x94D049BB133111EB
        return z ^ (z >> 31)
    }
}

// Make Extension method for applying background
extension View {
    func paperBackground() -> some View {
        self.background(PaperBackground())
    }
}
