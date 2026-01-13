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

    // Backend state
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?
    @Published var machines: [BackendMachine] = []
    @Published var selectedMachineId: String?

    private var pollingTask: Task<Void, Never>?

    // MARK: - Persistence

    private func userDefaultsKey(for machineId: String) -> String {
        "localMetrics_\(machineId)"
    }

    private func saveLocalMetrics() {
        guard let machineId = selectedMachineId else { return }

        // Only save locally-created metrics (those without a backend metricKey from standard set)
        let localMetrics = savedMetrics.filter { metric in
            // Backend metrics have standard keys like "temperature", "pressure", "vibration"
            let backendKeys = ["temperature", "pressure", "vibration"]
            return metric.metricKey == nil || !backendKeys.contains(metric.metricKey ?? "")
        }

        if let encoded = try? JSONEncoder().encode(localMetrics) {
            UserDefaults.standard.set(encoded, forKey: userDefaultsKey(for: machineId))
        }
    }

    private func loadLocalMetrics(for machineId: String) -> [Metric] {
        guard let data = UserDefaults.standard.data(forKey: userDefaultsKey(for: machineId)),
              let metrics = try? JSONDecoder().decode([Metric].self, from: data) else {
            return []
        }
        return metrics
    }

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
        saveLocalMetrics()
    }

    func deleteSelected() {
        savedMetrics.removeAll { selectedMetricIDs.contains($0.id) }
        selectedMetricIDs.removeAll()
        isSelectingForDeletion = false
        saveLocalMetrics()
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

    // MARK: - Backend Integration

    /// Load machines and metrics from the backend service
    func loadFromBackend() async {
        // Skip in preview mode
        guard !TelemetryAPIConfig.isPreview else { return }

        isLoading = true
        errorMessage = nil

        do {
            // Fetch machines and metrics in parallel
            async let machinesTask = TelemetryAPI.shared.fetchMachines()
            async let metricsTask = TelemetryAPI.shared.fetchMetrics()

            let (fetchedMachines, backendMetrics) = try await (machinesTask, metricsTask)

            self.machines = fetchedMachines

            // Select first machine by default if none selected
            if selectedMachineId == nil, let firstMachine = fetchedMachines.first {
                selectedMachineId = firstMachine.machineId
            }

            // Create Metric instances from backend metrics
            guard let machineId = selectedMachineId else {
                isLoading = false
                return
            }

            // Fetch latest readings for the selected machine
            let latestReadings = try await TelemetryAPI.shared.fetchLatestReadings(machineId: machineId)

            // Create metrics with default ranges based on metric type
            let backendMetricsList = backendMetrics.map { backendMetric in
                let latestValue = latestReadings.first { $0.metricKey == backendMetric.metricKey }?.value ?? 0

                return createMetric(
                    from: backendMetric,
                    machineId: machineId,
                    currentValue: latestValue
                )
            }

            // Load locally-persisted metrics and merge with backend metrics
            let localMetrics = loadLocalMetrics(for: machineId)
            withAnimation(.easeIn(duration: 1.0)) {
                savedMetrics = backendMetricsList + localMetrics
            }

            // Start polling for updates
            startPolling()

        } catch TelemetryAPIError.previewMode {
            // Expected in preview mode, ignore
        } catch {
            errorMessage = error.localizedDescription
            print("Backend load error: \(error)")
        }

        isLoading = false
    }

    /// Create a Metric from backend data with sensible default ranges
    private func createMetric(from backend: BackendMetric, machineId: String, currentValue: Double) -> Metric {
        // Set default ranges based on metric type
        let (goodRange, okayRange, badRange) = defaultRanges(for: backend.metricKey)

        let icon: MetricIcon
        switch backend.metricKey {
        case "temperature":
            icon = .thermometer
        case "pressure":
            icon = .gauge
        case "vibration":
            icon = .vibration
        default:
            icon = .gauge
        }

        return Metric(
            id: UUID(),
            metricName: backend.displayName,
            metricIcon: icon,
            metricUnit: backend.unit,
            metricGoodRangeMin: goodRange.min,
            metricGoodRangeMax: goodRange.max,
            metricOkayRangeMin: okayRange.min,
            metricOkayRangeMax: okayRange.max,
            metricBadRangeMin: badRange.min,
            metricBadRangeMax: badRange.max,
            metricZonePercentGood: 0,
            metricZonePercentOkay: 0,
            metricZonePercentBad: 0,
            isActive: true,
            metricValue: currentValue,
            machineId: machineId,
            metricKey: backend.metricKey
        )
    }

    /// Default ranges based on metric type
    private func defaultRanges(for metricKey: String) -> (
        goodRange: (min: Double, max: Double),
        okayRange: (min: Double, max: Double),
        badRange: (min: Double, max: Double)
    ) {
        switch metricKey {
        case "temperature":
            // Temperature: Good 65-75, Okay 55-65 or 75-85, Bad <55 or >85
            return (
                goodRange: (min: 65, max: 75),
                okayRange: (min: 55, max: 85),
                badRange: (min: 86, max: 54) // Open-ended: >85 or <55
            )
        case "pressure":
            // Pressure: Good 100-103, Okay 98-105, Bad <98 or >105
            return (
                goodRange: (min: 100, max: 103),
                okayRange: (min: 98, max: 105),
                badRange: (min: 106, max: 97) // Open-ended
            )
        case "vibration":
            // Vibration: Good 0-3, Okay 3-5, Bad >5
            return (
                goodRange: (min: 0, max: 3),
                okayRange: (min: 3, max: 5),
                badRange: (min: 5, max: -1) // Open-ended: >=5
            )
        default:
            return (
                goodRange: (min: 0, max: 100),
                okayRange: (min: -50, max: 150),
                badRange: (min: 151, max: -51)
            )
        }
    }

    // MARK: - Live Updates

    private func startPolling() {
        stopPolling()

        guard let machineId = selectedMachineId else { return }

        pollingTask = Task { [weak self] in
            while !Task.isCancelled {
                await self?.updateLatestValues(machineId: machineId)
                try? await Task.sleep(nanoseconds: 1_000_000_000) // 1 second
            }
        }
    }

    func stopPolling() {
        pollingTask?.cancel()
        pollingTask = nil
    }

    private func updateLatestValues(machineId: String) async {
        do {
            let latestReadings = try await TelemetryAPI.shared.fetchLatestReadings(machineId: machineId)

            for reading in latestReadings {
                if let index = savedMetrics.firstIndex(where: { $0.metricKey == reading.metricKey }) {
                    savedMetrics[index].metricValue = reading.value
                }
            }
        } catch {
            // Silently fail on polling errors
        }
    }

    /// Switch to a different machine
    func selectMachine(_ machineId: String) async {
        guard machineId != selectedMachineId else { return }

        // Fade out current metrics
        withAnimation(.easeOut(duration: 0.4)) {
            savedMetrics = []
        }

        selectedMachineId = machineId
        await loadFromBackend()
    }
}

