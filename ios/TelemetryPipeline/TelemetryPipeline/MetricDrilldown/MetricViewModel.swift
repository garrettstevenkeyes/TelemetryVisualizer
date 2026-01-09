import SwiftUI
import Combine
import Foundation

@MainActor
final class MetricViewModel: ObservableObject {
    // Input model
    let metric: Metric

    // Stream source
    private let stream = MetricStream()
    private var cancellables = Set<AnyCancellable>()

    // Outputs for the View
    @Published private(set) var readings: [MetricReading] = []
    @Published private(set) var serverDistribution: ZoneDistribution?

    // Convenience accessors for ranges and colors
    var goodMin: Double { metric.metricGoodRangeMin }
    var goodMax: Double { metric.metricGoodRangeMax }
    var okayMin: Double { metric.metricOkayRangeMin }
    var okayMax: Double { metric.metricOkayRangeMax }
    var badMin: Double { metric.metricBadRangeMin }
    var badMax: Double { metric.metricBadRangeMax }

    var goodFill: Color { MetricStatus.normal.color.opacity(0.25) }
    var okayFill: Color { MetricStatus.warning.color.opacity(0.25) }
    var badFill: Color { MetricStatus.alert.color.opacity(0.25) }

    init(metric: Metric) {
        self.metric = metric
        bind()
    }

    private func bind() {
        stream.$readings
            .receive(on: RunLoop.main)
            .assign(to: &self.$readings)

        stream.$serverDistribution
            .receive(on: RunLoop.main)
            .assign(to: &self.$serverDistribution)
    }

    // Lifecycle controls
    func startIfNeeded() {
        guard metric.isActive else {
            stopAll()
            return
        }
        stream.start()
        let isPreview = ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] == "1"
        if !isPreview {
            stream.startAggregatesLongPolling(metricID: metric.id)
        }
    }

    func stopAll() {
        stream.stop()
        stream.stopAggregatesLongPolling()
    }

    func handleActiveChange(_ isActive: Bool) {
        if isActive {
            stream.start()
            let isPreview = ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] == "1"
            if !isPreview {
                stream.startAggregatesLongPolling(metricID: metric.id)
            }
        } else {
            stopAll()
        }
    }

    // MARK: - Derived data for the View
    func suggestedYDomain() -> ClosedRange<Double> {
        let dataMin = readings.map { $0.value }.min() ?? .infinity
        let dataMax = readings.map { $0.value }.max() ?? -.infinity

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
        var values = readings.map { $0.value }
        if values.isEmpty { values = [metric.metricValue] }
        for v in values {
            if isGood(v) {
                good += 1
            } else if isBad(v) {
                bad += 1
            } else {
                okay += 1
            }
        }
        return (good, okay, bad)
    }

    private func distributionCounts() -> (good: Int, okay: Int, bad: Int) {
        if let d = serverDistribution {
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

    func goodPercentage() -> Int {
        let c = distributionCounts()
        let total = c.good + c.okay + c.bad
        return percent(c.good, total: total)
    }

    func okayPercentage() -> Int {
        let c = distributionCounts()
        let total = c.good + c.okay + c.bad
        return percent(c.okay, total: total)
    }

    func badPercentage() -> Int {
        let c = distributionCounts()
        let total = c.good + c.okay + c.bad
        return percent(c.bad, total: total)
    }

    // Stats helpers
    func currentReading() -> Double {
        readings.last?.value ?? metric.metricValue
    }

    func maxReading() -> Double {
        let values = readings.map { $0.value }
        return values.max() ?? currentReading()
    }

    func minReading() -> Double {
        let values = readings.map { $0.value }
        return values.min() ?? currentReading()
    }

    func averageReading() -> Double {
        let values = readings.map { $0.value }
        guard !values.isEmpty else { return currentReading() }
        let sum = values.reduce(0, +)
        return sum / Double(values.count)
    }

    func formattedValue(_ v: Double) -> String {
        let number = v.formatted(.number.precision(.fractionLength(1)))
        return "\(number)\(metric.metricUnit)"
    }
}
