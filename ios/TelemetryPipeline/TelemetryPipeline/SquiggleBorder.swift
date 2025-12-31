//
//  SquiggleBorder.swift
//  TelemetryPipeline
//
//  Created by Garrett Keyes on 12/30/25.
//

import Foundation
import SwiftUI

/// A rounded-rect border with subtle hand-drawn "squiggle" edges.
/// Works best as an overlay stroke on a normal rounded-rect fill.
struct SquiggleRoundedRect: Shape {
    var cornerRadius: CGFloat = 22
    var amplitude: CGFloat = 2.8     // squiggle height
    var wavelength: CGFloat = 18     // squiggle spacing
    var inset: CGFloat = 0           // used for insettable stroke alignment

    func path(in rect: CGRect) -> Path {
        let r = rect.insetBy(dx: inset, dy: inset)

        // Clamp corner radius so it never exceeds half size
        let cr = min(cornerRadius, min(r.width, r.height) / 2)

        // Helper to squiggle along a line segment
        func squigglePoints(from start: CGPoint, to end: CGPoint, step: CGFloat) -> [CGPoint] {
            let dx = end.x - start.x
            let dy = end.y - start.y
            let length = max(1, sqrt(dx*dx + dy*dy))
            let ux = dx / length
            let uy = dy / length

            // Perpendicular unit vector
            let px = -uy
            let py = ux

            let count = Int(length / step)
            return (0...count).map { i in
                let t = CGFloat(i) * step
                let phase = (t / wavelength) * 2 * .pi
                let offset = sin(phase) * amplitude

                return CGPoint(
                    x: start.x + ux * t + px * offset,
                    y: start.y + uy * t + py * offset
                )
            }
        }

        // Build path around a rounded rect using 4 squiggly edges + 4 arcs
        var p = Path()
        let step: CGFloat = 6

        // Key points (clockwise)
        let topLeft     = CGPoint(x: r.minX + cr, y: r.minY)
        let topRight    = CGPoint(x: r.maxX - cr, y: r.minY)
        let rightTop    = CGPoint(x: r.maxX, y: r.minY + cr)
        let rightBottom = CGPoint(x: r.maxX, y: r.maxY - cr)
        let bottomRight = CGPoint(x: r.maxX - cr, y: r.maxY)
        let bottomLeft  = CGPoint(x: r.minX + cr, y: r.maxY)
        let leftBottom  = CGPoint(x: r.minX, y: r.maxY - cr)
        let leftTop     = CGPoint(x: r.minX, y: r.minY + cr)

        // Start
        p.move(to: topLeft)

        // Top edge (squiggle)
        for pt in squigglePoints(from: topLeft, to: topRight, step: step).dropFirst() {
            p.addLine(to: pt)
        }
        // Top-right corner arc
        p.addArc(center: CGPoint(x: r.maxX - cr, y: r.minY + cr),
                 radius: cr,
                 startAngle: .degrees(-90),
                 endAngle: .degrees(0),
                 clockwise: false)

        // Right edge (squiggle)
        for pt in squigglePoints(from: rightTop, to: rightBottom, step: step).dropFirst() {
            p.addLine(to: pt)
        }
        // Bottom-right arc
        p.addArc(center: CGPoint(x: r.maxX - cr, y: r.maxY - cr),
                 radius: cr,
                 startAngle: .degrees(0),
                 endAngle: .degrees(90),
                 clockwise: false)

        // Bottom edge (squiggle)
        for pt in squigglePoints(from: bottomRight, to: bottomLeft, step: step).dropFirst() {
            p.addLine(to: pt)
        }
        // Bottom-left arc
        p.addArc(center: CGPoint(x: r.minX + cr, y: r.maxY - cr),
                 radius: cr,
                 startAngle: .degrees(90),
                 endAngle: .degrees(180),
                 clockwise: false)

        // Left edge (squiggle)
        for pt in squigglePoints(from: leftBottom, to: leftTop, step: step).dropFirst() {
            p.addLine(to: pt)
        }
        // Top-left arc
        p.addArc(center: CGPoint(x: r.minX + cr, y: r.minY + cr),
                 radius: cr,
                 startAngle: .degrees(180),
                 endAngle: .degrees(270),
                 clockwise: false)

        p.closeSubpath()
        return p
    }
}

// Nice ergonomic modifier
extension View {
    func squiggleBorder(
        color: Color,
        lineWidth: CGFloat = 3,
        cornerRadius: CGFloat = 22,
        amplitude: CGFloat = 2.8,
        wavelength: CGFloat = 18
    ) -> some View {
        self.overlay(
            SquiggleRoundedRect(
                cornerRadius: cornerRadius,
                amplitude: amplitude,
                wavelength: wavelength,
                inset: lineWidth / 2
            )
            .stroke(color, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round, lineJoin: .round))
        )
    }
}
