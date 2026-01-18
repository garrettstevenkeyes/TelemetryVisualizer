//
//  MachineRepository.swift
//  TelemetryPipeline
//
//  Repository for machine CRUD operations with CoreData caching.
//

import CoreData
import Foundation

@MainActor
final class MachineRepository {
    private let persistenceController: PersistenceController

    init(persistenceController: PersistenceController = .shared) {
        self.persistenceController = persistenceController
    }

    private var viewContext: NSManagedObjectContext {
        persistenceController.viewContext
    }

    // MARK: - Fetch Operations

    /// Fetch all cached machines
    func fetchCachedMachines() -> [BackendMachine] {
        let request = CachedMachine.allMachinesFetchRequest()
        do {
            let cachedMachines = try viewContext.fetch(request)
            return cachedMachines.map { $0.toBackendMachine() }
        } catch {
            print("Failed to fetch cached machines: \(error)")
            return []
        }
    }

    /// Fetch a specific cached machine by ID
    func fetchCachedMachine(id: String) -> CachedMachine? {
        let request = CachedMachine.fetchRequest(machineId: id)
        return try? viewContext.fetch(request).first
    }

    /// Check if cache is valid (not expired)
    func isCacheValid() -> Bool {
        let request: NSFetchRequest<CachedMachine> = CachedMachine.fetchRequest()
        request.fetchLimit = 1
        request.sortDescriptors = [NSSortDescriptor(keyPath: \CachedMachine.lastUpdated, ascending: false)]

        guard let latestMachine = try? viewContext.fetch(request).first,
              let lastUpdated = latestMachine.lastUpdated else {
            return false
        }

        return PersistenceController.isCacheValid(lastUpdated: lastUpdated)
    }

    // MARK: - Save Operations

    /// Cache machines from backend response
    func cacheMachines(_ machines: [BackendMachine]) {
        for machine in machines {
            _ = CachedMachine.fromBackend(machine, in: viewContext)
        }
        persistenceController.save()
    }

    /// Update a single machine in cache
    func updateMachine(_ machine: BackendMachine) {
        _ = CachedMachine.fromBackend(machine, in: viewContext)
        persistenceController.save()
    }

    // MARK: - Delete Operations

    /// Delete all cached machines (useful for cache invalidation)
    func deleteAllMachines() {
        let request: NSFetchRequest<NSFetchRequestResult> = CachedMachine.fetchRequest()
        let deleteRequest = NSBatchDeleteRequest(fetchRequest: request)

        do {
            try viewContext.execute(deleteRequest)
            persistenceController.save()
        } catch {
            print("Failed to delete all machines: \(error)")
        }
    }

    /// Delete a specific machine by ID
    func deleteMachine(id: String) {
        guard let machine = fetchCachedMachine(id: id) else { return }
        viewContext.delete(machine)
        persistenceController.save()
    }

    // MARK: - Cache Validation

    /// Get the last update time for the machine cache
    func lastCacheUpdate() -> Date? {
        let request: NSFetchRequest<CachedMachine> = CachedMachine.fetchRequest()
        request.fetchLimit = 1
        request.sortDescriptors = [NSSortDescriptor(keyPath: \CachedMachine.lastUpdated, ascending: false)]

        return try? viewContext.fetch(request).first?.lastUpdated
    }
}
