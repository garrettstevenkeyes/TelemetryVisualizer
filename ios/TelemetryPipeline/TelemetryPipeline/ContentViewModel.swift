import SwiftUI
import Combine
import Foundation

@MainActor
final class ContentViewModel: ObservableObject {
    
    // View state
    @Published var isSelectingForDeletion: Bool = false
    @Published var showingAddMetric: Bool = false
    @Published var savedMetrics: [Metric] = []
    @Published var selectedMetricIDs: Set<UUID> = []
    @Published var showingDeleteConfirmation: Bool = false

    // Derived data for overview
    var metricSummaries: [MetricSummary] {
        savedMetrics.map { metric in
            let s: MetricStatus = metric.isActive ? status(for: metric) : .inactive
            return MetricSummary(name: metric.metricName, status: s)
        }
    }

    // MARK: - Intents

    func toggleSelectionMode() {
        isSelectingForDeletion.toggle()
        if !isSelectingForDeletion { selectedMetricIDs.removeAll() }
    }

    func addMetric(_ metric: Metric) {
        savedMetrics.append(metric)
    }

    func deleteSelected() {
        savedMetrics.removeAll { selectedMetricIDs.contains($0.id) }
        selectedMetricIDs.removeAll()
        isSelectingForDeletion = false
    }

    // MARK: - Business logic

    func status(for metric: Metric) -> MetricStatus {
        let v = metric.metricValue

        // BAD
        if metric.metricBadRangeMin > metric.metricBadRangeMax {
            if v <= metric.metricBadRangeMax { return .alert }
        } else {
            if v >= metric.metricBadRangeMin && v <= metric.metricBadRangeMax { return .alert }
        }

        // GOOD
        if metric.metricGoodRangeMax < metric.metricGoodRangeMin {
            if v >= metric.metricGoodRangeMin { return .normal }
        } else {
            if v >= metric.metricGoodRangeMin && v <= metric.metricGoodRangeMax { return .normal }
        }

        // OKAY
        if metric.metricOkayRangeMin <= metric.metricOkayRangeMax &&
            v >= metric.metricOkayRangeMin && v <= metric.metricOkayRangeMax {
            return .warning
        }

        // Default
        return .warning
    }
}

