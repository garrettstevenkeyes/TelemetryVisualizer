import SwiftUI
import Foundation
import Combine

@MainActor
final class AddMetricViewModel: ObservableObject {
    @Published var name: String = ""
    @Published var description: String = ""
    @Published var unit: String = ""
    @Published var icon: MetricSymbol
    @Published var goodMin: Float = 0
    @Published var goodMax: Float = 0
    @Published var okayMin: Float = 0
    @Published var okayMax: Float = 0
    @Published var badMin: Float = 0
    @Published var badMax: Float = 0
    @Published var percentBadThreshold: Float = 0
    @Published var goodOpenEnded: Bool = false
    @Published var badOpenEnded: Bool = false

    private let onSave: (Metric) -> Void

    init(icon: MetricSymbol = .none, onSave: @escaping (Metric) -> Void = { _ in }) {
        self.icon = icon
        self.onSave = onSave
    }

    var canSave: Bool {
        // Basic validation: require name and unit, and ensure ranges are valid when not open-ended
        let hasBasics = !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !unit.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        let goodOK = goodOpenEnded || goodMin <= goodMax
        let badOK = badOpenEnded || badMin <= badMax
        let okayOK = okayMin <= okayMax
        let percentOK = percentBadThreshold >= 0 && percentBadThreshold <= 100
        return hasBasics && goodOK && badOK && okayOK && percentOK
    }

    func save() {
        // Construct a Metric using the current state and pass to onSave
        let metric = Metric(
            id: UUID(),
            metricName: name,
            metricIcon: MetricIcon(rawValue: icon.rawValue) ?? .thermometer,
            metricUnit: unit,
            metricGoodRangeMin: Double(goodMin),
            metricGoodRangeMax: goodOpenEnded ? -Double.infinity : Double(goodMax),
            metricOkayRangeMin: Double(okayMin),
            metricOkayRangeMax: Double(okayMax),
            metricBadRangeMin: badOpenEnded ? Double.infinity : Double(badMin),
            metricBadRangeMax: Double(badMax),
            metricZonePercentGood: 0,
            metricZonePercentOkay: 0,
            metricZonePercentBad: 0,
            isActive: false,
            metricValue: 0
        )
        onSave(metric)
    }
}
