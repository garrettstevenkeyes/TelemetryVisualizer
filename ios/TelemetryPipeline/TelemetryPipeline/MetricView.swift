//
//  MetricView.swift
//  TelemetryPipeline
//
//  Created by Garrett Keyes on 12/29/25.
//

import SwiftUI
import Charts
import Combine
import Foundation

struct MetricView: View {
    let metric: Metric
    @Environment(\.dismiss) private var dismiss

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

                    // Zone Distribution
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Zone Distribution")
                            .font(.headline.weight(.semibold))
                            .foregroundStyle(Color.eggshell)

                        HStack(alignment: .center, spacing: 12) {
                            // Percent list
                            VStack(alignment: .leading, spacing: 8) {
                                LegendDot(color: MetricStatus.normal.color, label: "\(goodPercentage())% Good")
                                LegendDot(color: MetricStatus.warning.color, label: "\(okayPercentage())% Okay")
                                LegendDot(color: MetricStatus.alert.color, label: "\(badPercentage())% Bad")
                            }

                            Spacer(minLength: 12)

                            // Pie chart (uses counts; falls back to local when server aggregate is unavailable)
                            let counts = distributionCounts()
                            Chart {
                                SectorMark(
                                    angle: .value("Count", counts.good),
                                    innerRadius: .ratio(0.6)
                                )
                                .foregroundStyle(MetricStatus.normal.color)

                                SectorMark(
                                    angle: .value("Count", counts.okay),
                                    innerRadius: .ratio(0.6)
                                )
                                .foregroundStyle(MetricStatus.warning.color)

                                SectorMark(
                                    angle: .value("Count", counts.bad),
                                    innerRadius: .ratio(0.6)
                                )
                                .foregroundStyle(MetricStatus.alert.color)
                            }
                            .chartLegend(.hidden)
                            .frame(width: 140, height: 140)
                        }
                    }
                    .padding(12)
                    .background(
                        RoundedRectangle(cornerRadius: 24)
                            .fill(Color.white.opacity(0.22))
                    )
                    .squiggleCardBorder()

                    // Summary stats
                    VStack(alignment: .leading, spacing: 10) {
                        StatRow(label: "Current:", value: formattedValue(currentReading()))
                        StatRow(label: "Max:", value: formattedValue(maxReading()))
                        StatRow(label: "Min:", value: formattedValue(minReading()))
                        StatRow(label: "Average:", value: formattedValue(averageReading()))
                    }
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
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button {
                    dismiss()
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "chevron.left")
                        Text("Back")
                    }
                }
            }
        }
        .task {
            // Only stream/poll when the metric is active
            guard metric.isActive else {
                stream.stop()
                stream.stopAggregatesLongPolling()
                return
            }
            stream.start()
            let isPreview = ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] == "1"
            if !isPreview {
                stream.startAggregatesLongPolling(metricID: metric.id)
            }
        }
        .onDisappear {
            stream.stop()
            stream.stopAggregatesLongPolling()
        }
        .onChange(of: metric.isActive) { _, isActive in
            if isActive {
                stream.start()
                let isPreview = ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] == "1"
                if !isPreview {
                    stream.startAggregatesLongPolling(metricID: metric.id)
                }
            } else {
                stream.stop()
                stream.stopAggregatesLongPolling()
            }
        }
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

    // MARK: - Zone classification and percentages
    private func isGood(_ v: Double) -> Bool {
        if metric.metricGoodRangeMax < metric.metricGoodRangeMin {
            return v >= goodMin
        } else {
            return v >= goodMin && v <= goodMax
        }
    }

    private func isBad(_ v: Double) -> Bool {
        if metric.metricBadRangeMin > metric.metricBadRangeMax {
            return v <= badMax
        } else {
            return v >= badMin && v <= badMax
        }
    }

    private func zoneCounts() -> (good: Int, okay: Int, bad: Int) {
        var good = 0, okay = 0, bad = 0
        var values = stream.readings.map { $0.value }
        if values.isEmpty { values = [metric.metricValue] }
        for v in values {
            if isGood(v) {
                good += 1
            } else if isBad(v) {
                bad += 1
            } else {
                // Middle band (or anything not classified above)
                okay += 1
            }
        }
        return (good, okay, bad)
    }

    private func totalSamples() -> Int {
        let count = stream.readings.isEmpty ? 1 : stream.readings.count
        return max(1, count)
    }

    private func distributionCounts() -> (good: Int, okay: Int, bad: Int) {
        if let d = stream.serverDistribution {
            return (d.good, d.okay, d.bad)
        } else {
            let counts = zoneCounts()
            return (counts.good, counts.okay, counts.bad)
        }
    }

    private func percent(_ part: Int, total: Int) -> Int {
        guard total > 0 else { return 0 }
        return Int(round((Double(part) / Double(total)) * 100))
    }

    private func goodPercentage() -> Int {
        let c = distributionCounts()
        let total = c.good + c.okay + c.bad
        return percent(c.good, total: total)
    }

    private func okayPercentage() -> Int {
        let c = distributionCounts()
        let total = c.good + c.okay + c.bad
        return percent(c.okay, total: total)
    }

    private func badPercentage() -> Int {
        let c = distributionCounts()
        let total = c.good + c.okay + c.bad
        return percent(c.bad, total: total)
    }

    // MARK: - Stats helpers
    private func currentReading() -> Double {
        stream.readings.last?.value ?? metric.metricValue
    }

    private func maxReading() -> Double {
        let values = stream.readings.map { $0.value }
        return values.max() ?? currentReading()
    }

    private func minReading() -> Double {
        let values = stream.readings.map { $0.value }
        return values.min() ?? currentReading()
    }

    private func averageReading() -> Double {
        let values = stream.readings.map { $0.value }
        guard !values.isEmpty else { return currentReading() }
        let sum = values.reduce(0, +)
        return sum / Double(values.count)
    }

    private func formattedValue(_ v: Double) -> String {
        let number = v.formatted(.number.precision(.fractionLength(1)))
        return "\(number)\(metric.metricUnit)"
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

struct ZoneDistribution: Codable {
    let good: Int
    let okay: Int
    let bad: Int
    let windowSeconds: Int?
}

@MainActor
final class MetricStream: ObservableObject {
    @Published private(set) var readings: [MetricReading] = []
    @Published private(set) var serverDistribution: ZoneDistribution?
    private var timer: Timer?
    private var startDate: Date = Date()
    private var pollingTask: Task<Void, Never>?

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

    func startAggregatesLongPolling(metricID: UUID) {
        stopAggregatesLongPolling()
        pollingTask = Task { [weak self] in
            await self?.pollAggregates(metricID: metricID)
        }
    }

    func stopAggregatesLongPolling() {
        pollingTask?.cancel()
        pollingTask = nil
    }

    private func pollAggregates(metricID: UUID) async {
        while !Task.isCancelled {
            do {
                let url = URL(string: "https://example.com/api/metrics/\(metricID.uuidString)/distribution")!
                var request = URLRequest(url: url)
                request.timeoutInterval = 35 // long-poll timeout
                let (data, _) = try await URLSession.shared.data(for: request)
                let dist = try JSONDecoder().decode(ZoneDistribution.self, from: data)
                self.serverDistribution = dist
            } catch {
                // Optional: log or handle error; we'll retry after a short delay
            }
            // Backoff to avoid tight loop on quick failures/successes
            try? await Task.sleep(nanoseconds: 500_000_000)
        }
    }

    private func append(timestamp: Date, value: Double) {
        readings.append(MetricReading(timestamp: timestamp, value: value))
        if readings.count > 600 { readings.removeFirst(readings.count - 600) }
    }
}

private struct StatRow: View {
    let label: String
    let value: String
    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text(label)
                .foregroundStyle(Color.eggshell)
            HorizontalDashedLine()
                .stroke(style: StrokeStyle(lineWidth: 1, dash: [3, 4]))
                .foregroundStyle(Color.eggshell.opacity(0.6))
                .frame(maxWidth: .infinity, maxHeight: 1)
            Text(value)
                .foregroundStyle(Color.eggshell)
        }
        .font(.body)
    }
}

private struct HorizontalDashedLine: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: 0, y: rect.midY))
        p.addLine(to: CGPoint(x: rect.width, y: rect.midY))
        return p
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

