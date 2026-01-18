//
//  MetricRepository.swift
//  TelemetryPipeline
//
//  Repository for metric CRUD operations with CoreData caching.
//

import CoreData
import Foundation

@MainActor
final class MetricRepository {
    private let persistenceController: PersistenceController
    private let machineRepository: MachineRepository

    init(
        persistenceController: PersistenceController = .shared,
        machineRepository: MachineRepository? = nil
    ) {
        self.persistenceController = persistenceController
        self.machineRepository = machineRepository ?? MachineRepository(persistenceController: persistenceController)
    }

    private var viewContext: NSManagedObjectContext {
        persistenceController.viewContext
    }

    // MARK: - Fetch Operations

    /// Fetch all cached metrics for a machine
    func fetchCachedMetrics(forMachineId machineId: String) -> [Metric] {
        guard let machine = machineRepository.fetchCachedMachine(id: machineId) else {
            return []
        }

        let request = CachedMetric.fetchRequest(forMachine: machine)
        do {
            let cachedMetrics = try viewContext.fetch(request)
            return cachedMetrics.map { $0.toMetric() }
        } catch {
            print("Failed to fetch cached metrics: \(error)")
            return []
        }
    }

    /// Fetch only local metrics for a machine
    func fetchLocalMetrics(forMachineId machineId: String) -> [Metric] {
        guard let machine = machineRepository.fetchCachedMachine(id: machineId) else {
            return []
        }

        let request = CachedMetric.fetchLocalMetrics(forMachine: machine)
        do {
            let cachedMetrics = try viewContext.fetch(request)
            return cachedMetrics.map { $0.toMetric() }
        } catch {
            print("Failed to fetch local metrics: \(error)")
            return []
        }
    }

    /// Check if metrics cache is valid for a machine
    func isCacheValid(forMachineId machineId: String) -> Bool {
        guard let machine = machineRepository.fetchCachedMachine(id: machineId) else {
            return false
        }

        let request: NSFetchRequest<CachedMetric> = CachedMetric.fetchRequest()
        request.predicate = NSPredicate(format: "machine == %@ AND isLocalOnly == NO", machine)
        request.fetchLimit = 1
        request.sortDescriptors = [NSSortDescriptor(keyPath: \CachedMetric.lastUpdated, ascending: false)]

        guard let latestMetric = try? viewContext.fetch(request).first,
              let lastUpdated = latestMetric.lastUpdated else {
            return false
        }

        return PersistenceController.isCacheValid(lastUpdated: lastUpdated)
    }

    // MARK: - Save Operations

    /// Cache metrics from backend for a machine
    func cacheMetrics(_ metrics: [Metric], forMachineId machineId: String) {
        // Ensure machine exists in cache
        guard let machine = machineRepository.fetchCachedMachine(id: machineId) else {
            print("Cannot cache metrics: machine \(machineId) not found in cache")
            return
        }

        for metric in metrics {
            _ = CachedMetric.fromMetric(metric, machine: machine, in: viewContext)
        }
        persistenceController.save()
    }

    /// Save a single metric (local or backend)
    func saveMetric(_ metric: Metric, forMachineId machineId: String) {
        guard let machine = machineRepository.fetchCachedMachine(id: machineId) else {
            print("Cannot save metric: machine \(machineId) not found in cache")
            return
        }

        _ = CachedMetric.fromMetric(metric, machine: machine, in: viewContext)
        persistenceController.save()
    }

    /// Update the latest value for a metric
    func updateMetricValue(metricKey: String, machineId: String, value: Double) {
        guard let machine = machineRepository.fetchCachedMachine(id: machineId) else {
            return
        }

        let request = CachedMetric.fetchRequest(metricKey: metricKey, machine: machine)
        guard let cached = try? viewContext.fetch(request).first else {
            return
        }

        cached.lastValue = value
        cached.lastUpdated = Date()
        persistenceController.save()
    }

    // MARK: - Delete Operations

    /// Delete a metric by its ID
    func deleteMetric(id: UUID, machineId: String) {
        guard let machine = machineRepository.fetchCachedMachine(id: machineId) else {
            return
        }

        let request: NSFetchRequest<CachedMetric> = CachedMetric.fetchRequest()
        request.predicate = NSPredicate(format: "localId == %@ AND machine == %@", id as CVarArg, machine)
        request.fetchLimit = 1

        guard let cached = try? viewContext.fetch(request).first else {
            return
        }

        viewContext.delete(cached)
        persistenceController.save()
    }

    /// Delete metrics by their IDs
    func deleteMetrics(ids: Set<UUID>, machineId: String) {
        guard let machine = machineRepository.fetchCachedMachine(id: machineId) else {
            return
        }

        for id in ids {
            let request: NSFetchRequest<CachedMetric> = CachedMetric.fetchRequest()
            request.predicate = NSPredicate(format: "localId == %@ AND machine == %@", id as CVarArg, machine)
            request.fetchLimit = 1

            if let cached = try? viewContext.fetch(request).first {
                viewContext.delete(cached)
            }
        }
        persistenceController.save()
    }

    /// Delete all backend metrics for a machine (keeps local metrics)
    func deleteBackendMetrics(forMachineId machineId: String) {
        guard let machine = machineRepository.fetchCachedMachine(id: machineId) else {
            return
        }

        let request: NSFetchRequest<NSFetchRequestResult> = CachedMetric.fetchRequest()
        request.predicate = NSPredicate(format: "machine == %@ AND isLocalOnly == NO", machine)

        let deleteRequest = NSBatchDeleteRequest(fetchRequest: request)

        do {
            try viewContext.execute(deleteRequest)
            persistenceController.save()
        } catch {
            print("Failed to delete backend metrics: \(error)")
        }
    }

    // MARK: - Cache Validation

    /// Get the last update time for metrics cache
    func lastCacheUpdate(forMachineId machineId: String) -> Date? {
        guard let machine = machineRepository.fetchCachedMachine(id: machineId) else {
            return nil
        }

        let request: NSFetchRequest<CachedMetric> = CachedMetric.fetchRequest()
        request.predicate = NSPredicate(format: "machine == %@", machine)
        request.fetchLimit = 1
        request.sortDescriptors = [NSSortDescriptor(keyPath: \CachedMetric.lastUpdated, ascending: false)]

        return try? viewContext.fetch(request).first?.lastUpdated
    }
}
