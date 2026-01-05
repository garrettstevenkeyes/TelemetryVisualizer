//
//  MetricView.swift
//  TelemetryPipeline
//
//  Created by Garrett Keyes on 12/29/25.
//

import SwiftUI
import Charts
import Combine

struct MetricView: View {
    let metric: Metric

    @StateObject private var stream = MetricStream()

    // Convenience accessors
    private var goodMin: Double { metric.metricGoodRangeMin }
    private var goodMax: Double { metric.metricGoodRangeMax }
    private var okayMin: Double { metric.metricOkayRangeMin }
    private var okayMax: Double { metric.metricOkayRangeMax }
    private var badMin: Double { metric.metricBadRangeMin }
    private var badMax: Double { metric.metricBadRangeMax }

    // Status colors (match your app's MetricStatus colors)
    private var goodFill: Color { MetricStatus.normal.color.opacity(0.25) }
    private var okayFill: Color { MetricStatus.warning.color.opacity(0.25) }
    private var badFill: Color { MetricStatus.alert.color.opacity(0.25) }

    var body: some View {
        ZStack {
            ScrollView {
                VStack(spacing: 18) {
                    // Title
                    Text(metric.metricName)
                        .font(.title2.weight(.semibold))
                        .foregroundStyle(Color.eggshell)
                        .frame(maxWidth: .infinity, alignment: .center)

                    // Global legend under title
                    HStack(spacing: 18) {
                        LegendDot(color: MetricStatus.normal.color, label: "Good")
                        LegendDot(color: MetricStatus.warning.color, label: "Okay")
                        LegendDot(color: MetricStatus.alert.color, label: "Bad")
                        Spacer()
                    }
                    .padding(.top, 2)
                    .padding(.horizontal, 6)

                    // Chart with background bands
                    Chart {
                        ForEach(stream.readings) { reading in
                            LineMark(
                                x: .value("Time", reading.timestamp),
                                y: .value("Value", reading.value)
                            )
                            .interpolationMethod(.catmullRom)
                            .foregroundStyle(Color.eggshell)
                        }
                    }
                    .chartBackground { proxy in
                        MetricBandsBackground(
                            proxy: proxy,
                            goodMin: goodMin,
                            goodMax: goodMax,
                            okayMin: okayMin,
                            okayMax: okayMax,
                            badMin: badMin,
                            badMax: badMax,
                            goodFill: goodFill,
                            okayFill: okayFill,
                            badFill: badFill,
                            openEndedGood: metric.metricGoodRangeMax < metric.metricGoodRangeMin,
                            openEndedBad: metric.metricBadRangeMin > metric.metricBadRangeMax
                        )
                    }
                    .chartXAxis {
                        AxisMarks(values: .automatic(desiredCount: 5)) { _ in
                            AxisGridLine()
                            AxisTick()
                            AxisValueLabel(format: .dateTime.hour().minute().second())
                        }
                    }
                    .chartYAxis { AxisMarks(position: .leading) }
                    .chartYScale(domain: suggestedYDomain())
                    .frame(height: 220)
                    .padding(12)
                    .background(
                        RoundedRectangle(cornerRadius: 24)
                            .fill(Color.white.opacity(0.22))
                    )
                    .squiggleCardBorder()

                    Spacer(minLength: 0)
                }
                .padding(.horizontal, 18)
                .padding(.top, 0)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .paperBackground()
        .navigationBarTitleDisplayMode(.inline)
        .task { stream.start() }
        .onDisappear { stream.stop() }
    }

    // Compute a reasonable Y domain that includes ranges and data
    private func suggestedYDomain() -> ClosedRange<Double> {
        let dataMin = stream.readings.map { $0.value }.min() ?? .infinity
        let dataMax = stream.readings.map { $0.value }.max() ?? -.infinity

        var minY = min(badMin, okayMin, goodMin, dataMin)
        var maxY = max(badMax, okayMax, goodMax, dataMax)

        if metric.metricGoodRangeMax < metric.metricGoodRangeMin {
            let span = max(1, (maxY - minY) * 0.2)
            maxY = max(maxY, goodMin + span)
        }
        if metric.metricBadRangeMin > metric.metricBadRangeMax {
            let span = max(1, (maxY - minY) * 0.2)
            minY = min(minY, badMax - span)
        }

        if minY == maxY { maxY += 1 }
        return minY...maxY
    }
}

private struct MetricBandsBackground: View {
    let proxy: ChartProxy
    let goodMin: Double
    let goodMax: Double
    let okayMin: Double
    let okayMax: Double
    let badMin: Double
    let badMax: Double
    let goodFill: Color
    let okayFill: Color
    let badFill: Color
    let openEndedGood: Bool
    let openEndedBad: Bool

    // Helpers moved out of the ViewBuilder to avoid declaration errors inside result builders
    private func yPos(_ y: Double, in plotFrame: CGRect) -> CGFloat? {
        guard let localY = proxy.position(forY: y) else { return nil }
        // Convert from plot-area local coordinates to the GeometryReader's coordinate space
        return localY + plotFrame.minY
    }

    @ViewBuilder
    private func bandView(yTop: CGFloat?, yBottom: CGFloat?, color: Color, plotFrame: CGRect) -> some View {
        let top = yTop ?? plotFrame.minY
        let bottom = yBottom ?? plotFrame.maxY
        let minY = min(top, bottom)
        let height = abs(bottom - top)
        Rectangle()
            .fill(color)
            .frame(width: plotFrame.width, height: height)
            .position(x: plotFrame.midX, y: minY + height / 2)
    }

    var body: some View {
        GeometryReader { geo in
            if let plotAnchor = proxy.plotFrame {
                let plotFrame = geo[plotAnchor]

                Group {
                    // GOOD band: closed [goodMin, goodMax] or open-ended (>= goodMin)
                    if let yGoodMin = yPos(goodMin, in: plotFrame) {
                        if openEndedGood {
                            bandView(yTop: nil, yBottom: yGoodMin, color: goodFill, plotFrame: plotFrame)
                        } else {
                            let yGoodMax = yPos(goodMax, in: plotFrame)
                            bandView(yTop: yGoodMax, yBottom: yGoodMin, color: goodFill, plotFrame: plotFrame)
                        }
                    }

                    // OKAY band: only if valid closed interval
                    if okayMin <= okayMax, let yOkayMin = yPos(okayMin, in: plotFrame), let yOkayMax = yPos(okayMax, in: plotFrame) {
                        bandView(yTop: yOkayMax, yBottom: yOkayMin, color: okayFill, plotFrame: plotFrame)
                    }

                    // BAD band: closed [badMin, badMax] or open-ended (<= badMax)
                    if openEndedBad {
                        if let yBadMax = yPos(badMax, in: plotFrame) {
                            bandView(yTop: nil, yBottom: yBadMax, color: badFill, plotFrame: plotFrame)
                        }
                    } else if let yBadMin = yPos(badMin, in: plotFrame), let yBadMax = yPos(badMax, in: plotFrame) {
                        bandView(yTop: yBadMin, yBottom: yBadMax, color: badFill, plotFrame: plotFrame)
                    }
                }
            }
        }
    }
}

// MARK: - Streaming support and helpers

struct MetricReading: Identifiable {
    let id = UUID()
    let timestamp: Date
    let value: Double
}

@MainActor
final class MetricStream: ObservableObject {
    @Published private(set) var readings: [MetricReading] = []
    private var timer: Timer?
    private var startDate: Date = Date()

    func start() {
        stop()
        startDate = Date()
        let capturedStartDate = startDate
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            guard let self else { return }
            let t = Date()
            let i = t.timeIntervalSince(capturedStartDate)
            // Simulated reading; replace with real incoming data
            let simulated = 70.0 + sin(i / 3.0) * 15.0 + Double.random(in: -2...2)
            Task { @MainActor in
                self.append(timestamp: t, value: simulated)
            }
        }
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }

    private func append(timestamp: Date, value: Double) {
        readings.append(MetricReading(timestamp: timestamp, value: value))
        if readings.count > 600 { readings.removeFirst(readings.count - 600) }
    }
}

private struct LegendDot: View {
    let color: Color
    let label: String
    var body: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(color)
                .frame(width: 10, height: 10)
            Text(label)
                .font(.footnote)
                .foregroundStyle(Color.eggshell)
        }
    }
}

#Preview {
    let sample = Metric(
        id: UUID(),
        metricName: "Temperature",
        metricIcon: .thermometer,
        metricUnit: "ºC",
        metricGoodRangeMin: 65,
        metricGoodRangeMax: 85, // set < min to preview open-ended good
        metricOkayRangeMin: 55,
        metricOkayRangeMax: 64,
        metricBadRangeMin: 0,   // set > max to preview open-ended bad
        metricBadRangeMax: 54,
        metricZonePercentGood: 0,
        metricZonePercentOkay: 0,
        metricZonePercentBad: 0,
        isActive: true,
        metricValue: 72
    )
    NavigationStack { MetricView(metric: sample) }
}

