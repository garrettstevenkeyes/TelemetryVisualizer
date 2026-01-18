//
//  CachedMetric+Extensions.swift
//  TelemetryPipeline
//
//  Extensions for converting between CachedMetric (CoreData) and Metric models.
//

import CoreData
import Foundation

extension CachedMetric {
    /// Convert a Metric to CachedMetric, updating existing or creating new
    static func fromMetric(
        _ metric: Metric,
        machine: CachedMachine,
        in context: NSManagedObjectContext
    ) -> CachedMetric {
        // For local metrics, use localId; for backend metrics, use metricKey
        let request: NSFetchRequest<CachedMetric> = CachedMetric.fetchRequest()

        if let metricKey = metric.metricKey, !metricKey.isEmpty {
            request.predicate = NSPredicate(
                format: "metricKey == %@ AND machine == %@",
                metricKey,
                machine
            )
        } else {
            request.predicate = NSPredicate(
                format: "localId == %@ AND machine == %@",
                metric.id as CVarArg,
                machine
            )
        }
        request.fetchLimit = 1

        let cached: CachedMetric
        if let existing = try? context.fetch(request).first {
            cached = existing
        } else {
            cached = CachedMetric(context: context)
            cached.metricKey = metric.metricKey ?? metric.id.uuidString
            cached.localId = metric.id
        }

        cached.displayName = metric.metricName
        cached.unit = metric.metricUnit
        cached.iconType = metric.metricIcon.rawValue.lowercased()
        cached.goodRangeMin = metric.metricGoodRangeMin
        cached.goodRangeMax = metric.metricGoodRangeMax
        cached.okayRangeMin = metric.metricOkayRangeMin
        cached.okayRangeMax = metric.metricOkayRangeMax
        cached.badRangeMin = metric.metricBadRangeMin
        cached.badRangeMax = metric.metricBadRangeMax
        cached.zonePercentGood = metric.metricZonePercentGood
        cached.zonePercentOkay = metric.metricZonePercentOkay
        cached.zonePercentBad = metric.metricZonePercentBad
        cached.isActive = metric.isActive
        cached.isLocalOnly = metric.metricKey == nil
        cached.lastValue = metric.metricValue
        cached.lastUpdated = Date()
        cached.machine = machine

        return cached
    }

    /// Convert CachedMetric to Metric for use in the UI
    func toMetric() -> Metric {
        let icon: MetricIcon
        switch iconType?.lowercased() {
        case "thermometer":
            icon = .thermometer
        case "vibration":
            icon = .vibration
        default:
            icon = .gauge
        }

        // For backend metrics, use stable UUID; for local metrics, use stored localId
        let metricId: UUID
        if isLocalOnly {
            metricId = localId ?? UUID()
        } else if let machineId = machine?.machineId, let key = metricKey {
            metricId = Self.stableUUID(for: machineId, metricKey: key)
        } else {
            metricId = localId ?? UUID()
        }

        return Metric(
            id: metricId,
            metricName: displayName ?? "",
            metricIcon: icon,
            metricUnit: unit ?? "",
            metricGoodRangeMin: goodRangeMin,
            metricGoodRangeMax: goodRangeMax,
            metricOkayRangeMin: okayRangeMin,
            metricOkayRangeMax: okayRangeMax,
            metricBadRangeMin: badRangeMin,
            metricBadRangeMax: badRangeMax,
            metricZonePercentGood: zonePercentGood,
            metricZonePercentOkay: zonePercentOkay,
            metricZonePercentBad: zonePercentBad,
            isActive: isActive,
            metricValue: lastValue,
            machineId: machine?.machineId,
            metricKey: isLocalOnly ? nil : metricKey
        )
    }

    /// Generate a stable UUID from machineId and metricKey for consistent identity
    static func stableUUID(for machineId: String, metricKey: String) -> UUID {
        let combined = "\(machineId)_\(metricKey)"
        let hash = combined.utf8.reduce(into: [UInt8](repeating: 0, count: 16)) { result, byte in
            for i in 0..<16 {
                result[i] = result[i] &+ byte &+ UInt8(i)
            }
        }
        return UUID(uuid: (hash[0], hash[1], hash[2], hash[3], hash[4], hash[5], hash[6], hash[7],
                          hash[8], hash[9], hash[10], hash[11], hash[12], hash[13], hash[14], hash[15]))
    }
}

// MARK: - Fetch Requests

extension CachedMetric {
    /// Fetch all metrics for a specific machine (backend first, then local, each sorted by name)
    static func fetchRequest(forMachine machine: CachedMachine) -> NSFetchRequest<CachedMetric> {
        let request: NSFetchRequest<CachedMetric> = CachedMetric.fetchRequest()
        request.predicate = NSPredicate(format: "machine == %@", machine)
        // Sort by isLocalOnly first (false < true), then by displayName
        request.sortDescriptors = [
            NSSortDescriptor(keyPath: \CachedMetric.isLocalOnly, ascending: true),
            NSSortDescriptor(keyPath: \CachedMetric.displayName, ascending: true)
        ]
        return request
    }

    /// Fetch all local-only metrics for a specific machine
    static func fetchLocalMetrics(forMachine machine: CachedMachine) -> NSFetchRequest<CachedMetric> {
        let request: NSFetchRequest<CachedMetric> = CachedMetric.fetchRequest()
        request.predicate = NSPredicate(format: "machine == %@ AND isLocalOnly == YES", machine)
        request.sortDescriptors = [NSSortDescriptor(keyPath: \CachedMetric.displayName, ascending: true)]
        return request
    }

    /// Fetch a specific metric by key for a machine
    static func fetchRequest(metricKey: String, machine: CachedMachine) -> NSFetchRequest<CachedMetric> {
        let request: NSFetchRequest<CachedMetric> = CachedMetric.fetchRequest()
        request.predicate = NSPredicate(format: "metricKey == %@ AND machine == %@", metricKey, machine)
        request.fetchLimit = 1
        return request
    }
}
