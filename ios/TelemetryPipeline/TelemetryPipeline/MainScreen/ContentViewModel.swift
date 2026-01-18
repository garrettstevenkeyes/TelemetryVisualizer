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

    // MARK: - Repositories

    private let machineRepository = MachineRepository()
    private let metricRepository = MetricRepository()

    // MARK: - Legacy Migration Support

    private func userDefaultsKey(for machineId: String) -> String {
        "localMetrics_\(machineId)"
    }

    /// JSON decoder for reading legacy UserDefaults data during migration
    private static let jsonDecoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.nonConformingFloatDecodingStrategy = .convertFromString(
            positiveInfinity: "inf",
            negativeInfinity: "-inf",
            nan: "nan"
        )
        return decoder
    }()

    private func loadLegacyLocalMetrics(for machineId: String) -> [Metric] {
        guard let data = UserDefaults.standard.data(forKey: userDefaultsKey(for: machineId)),
              let metrics = try? Self.jsonDecoder.decode([Metric].self, from: data) else {
            return []
        }
        return metrics
    }

    private func clearLegacyLocalMetrics(for machineId: String) {
        UserDefaults.standard.removeObject(forKey: userDefaultsKey(for: machineId))
    }

    private static let migrationCompletedKey = "CoreDataMigrationCompleted_v1"

    private var isMigrationCompleted: Bool {
        get { UserDefaults.standard.bool(forKey: Self.migrationCompletedKey) }
        set { UserDefaults.standard.set(newValue, forKey: Self.migrationCompletedKey) }
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
        if let machineId = selectedMachineId {
            metricRepository.saveMetric(metric, forMachineId: machineId)
        }
    }

    func deleteSelected() {
        if let machineId = selectedMachineId {
            metricRepository.deleteMetrics(ids: selectedMetricIDs, machineId: machineId)
        }
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

    // MARK: - Cache-First Loading

    /// Load data from cache first for immediate display
    func loadFromCache() {
        // Load cached machines
        let cachedMachines = machineRepository.fetchCachedMachines()
        if !cachedMachines.isEmpty {
            self.machines = cachedMachines

            // Select first machine by default if none selected
            if selectedMachineId == nil, let firstMachine = cachedMachines.first {
                selectedMachineId = firstMachine.machineId
            }

            // Load cached metrics for selected machine
            if let machineId = selectedMachineId {
                let cachedMetrics = metricRepository.fetchCachedMetrics(forMachineId: machineId)
                if !cachedMetrics.isEmpty {
                    savedMetrics = cachedMetrics
                }
            }
        }
    }

    // MARK: - Backend Integration

    /// Load machines and metrics from the backend service with cache-first strategy
    func loadFromBackend() async {
        // Skip in preview mode
        guard !TelemetryAPIConfig.isPreview else { return }

        // Step 1: Load from cache immediately for fast startup
        loadFromCache()

        // Step 2: Perform one-time migration from UserDefaults if needed
        await performMigrationIfNeeded()

        // Step 3: Fetch fresh data from backend in background
        isLoading = savedMetrics.isEmpty  // Only show loading if no cached data
        errorMessage = nil

        do {
            // Fetch machines and metrics in parallel
            async let machinesTask = TelemetryAPI.shared.fetchMachines()
            async let metricsTask = TelemetryAPI.shared.fetchMetrics()

            let (fetchedMachines, backendMetrics) = try await (machinesTask, metricsTask)

            // Cache machines
            machineRepository.cacheMachines(fetchedMachines)
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

            // Create metrics with default ranges based on metric type, sorted by name
            let backendMetricsList = backendMetrics.map { backendMetric in
                let latestValue = latestReadings.first { $0.metricKey == backendMetric.metricKey }?.value ?? 0

                return createMetric(
                    from: backendMetric,
                    machineId: machineId,
                    currentValue: latestValue
                )
            }.sorted { $0.metricName < $1.metricName }

            // Cache backend metrics
            metricRepository.cacheMetrics(backendMetricsList, forMachineId: machineId)

            // Load local metrics from cache (already migrated), sorted by name
            let localMetrics = metricRepository.fetchLocalMetrics(forMachineId: machineId)
                .sorted { $0.metricName < $1.metricName }

            // Update UI with fresh data (backend first, then local - matches cache sort order)
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

    /// Perform one-time migration from UserDefaults to CoreData
    private func performMigrationIfNeeded() async {
        guard !isMigrationCompleted else { return }

        // We need machines to be cached first before we can migrate metrics
        // Wait for machines to be cached
        let cachedMachines = machineRepository.fetchCachedMachines()

        // For each machine, migrate local metrics from UserDefaults
        for machine in cachedMachines {
            let legacyMetrics = loadLegacyLocalMetrics(for: machine.machineId)
            if !legacyMetrics.isEmpty {
                for metric in legacyMetrics {
                    metricRepository.saveMetric(metric, forMachineId: machine.machineId)
                }
                // Clear legacy data after successful migration
                clearLegacyLocalMetrics(for: machine.machineId)
            }
        }

        isMigrationCompleted = true
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

        // Use a deterministic UUID based on machineId + metricKey for stable identity
        let stableId = stableUUID(for: machineId, metricKey: backend.metricKey)

        return Metric(
            id: stableId,
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

    /// Generate a stable UUID from machineId and metricKey for consistent identity
    private func stableUUID(for machineId: String, metricKey: String) -> UUID {
        let combined = "\(machineId)_\(metricKey)"
        let hash = combined.utf8.reduce(into: [UInt8](repeating: 0, count: 16)) { result, byte in
            for i in 0..<16 {
                result[i] = result[i] &+ byte &+ UInt8(i)
            }
        }
        return UUID(uuid: (hash[0], hash[1], hash[2], hash[3], hash[4], hash[5], hash[6], hash[7],
                          hash[8], hash[9], hash[10], hash[11], hash[12], hash[13], hash[14], hash[15]))
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

        // Stop polling for the old machine
        stopPolling()

        // Fade out current metrics
        withAnimation(.easeOut(duration: 0.4)) {
            savedMetrics = []
        }

        selectedMachineId = machineId

        // Load cached metrics immediately for fast switch
        let cachedMetrics = metricRepository.fetchCachedMetrics(forMachineId: machineId)
        if !cachedMetrics.isEmpty {
            withAnimation(.easeIn(duration: 0.3)) {
                savedMetrics = cachedMetrics
            }
        }

        // Fetch fresh data from backend
        await loadMetricsFromBackend(machineId: machineId)
    }

    /// Load metrics for a specific machine from backend
    private func loadMetricsFromBackend(machineId: String) async {
        guard !TelemetryAPIConfig.isPreview else { return }

        isLoading = savedMetrics.isEmpty
        errorMessage = nil

        do {
            // Fetch metrics and latest readings
            async let metricsTask = TelemetryAPI.shared.fetchMetrics()
            async let readingsTask = TelemetryAPI.shared.fetchLatestReadings(machineId: machineId)

            let (backendMetrics, latestReadings) = try await (metricsTask, readingsTask)

            // Create metrics with current values, sorted by name
            let backendMetricsList = backendMetrics.map { backendMetric in
                let latestValue = latestReadings.first { $0.metricKey == backendMetric.metricKey }?.value ?? 0
                return createMetric(from: backendMetric, machineId: machineId, currentValue: latestValue)
            }.sorted { $0.metricName < $1.metricName }

            // Cache and update UI
            metricRepository.cacheMetrics(backendMetricsList, forMachineId: machineId)
            let localMetrics = metricRepository.fetchLocalMetrics(forMachineId: machineId)
                .sorted { $0.metricName < $1.metricName }

            // Backend metrics first, then local metrics (matches cache sort order)
            withAnimation(.easeIn(duration: 0.5)) {
                savedMetrics = backendMetricsList + localMetrics
            }

            // Start polling for the new machine
            startPolling()

        } catch TelemetryAPIError.previewMode {
            // Expected in preview mode
        } catch {
            errorMessage = error.localizedDescription
            print("Failed to load metrics for machine \(machineId): \(error)")
        }

        isLoading = false
    }
}

