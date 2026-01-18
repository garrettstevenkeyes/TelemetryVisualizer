//
//  CachedMachine+Extensions.swift
//  TelemetryPipeline
//
//  Extensions for converting between CachedMachine (CoreData) and BackendMachine models.
//

import CoreData

extension CachedMachine {
    /// Convert a BackendMachine to CachedMachine, updating existing or creating new
    static func fromBackend(
        _ backend: BackendMachine,
        in context: NSManagedObjectContext
    ) -> CachedMachine {
        // Try to find existing cached machine
        let request: NSFetchRequest<CachedMachine> = CachedMachine.fetchRequest()
        request.predicate = NSPredicate(format: "machineId == %@", backend.machineId)
        request.fetchLimit = 1

        let cached: CachedMachine
        if let existing = try? context.fetch(request).first {
            cached = existing
        } else {
            cached = CachedMachine(context: context)
            cached.machineId = backend.machineId
        }

        cached.name = backend.name
        cached.location = backend.location
        cached.status = backend.status
        cached.lastUpdated = Date()

        return cached
    }

    /// Convert CachedMachine to BackendMachine for use in the UI
    func toBackendMachine() -> BackendMachine {
        BackendMachine(
            machineId: machineId ?? "",
            name: name ?? "",
            location: location,
            status: status ?? "offline"
        )
    }
}

// MARK: - Fetch Requests

extension CachedMachine {
    /// Fetch all cached machines sorted by name
    static func allMachinesFetchRequest() -> NSFetchRequest<CachedMachine> {
        let request: NSFetchRequest<CachedMachine> = CachedMachine.fetchRequest()
        request.sortDescriptors = [NSSortDescriptor(keyPath: \CachedMachine.name, ascending: true)]
        return request
    }

    /// Fetch a specific machine by ID
    static func fetchRequest(machineId: String) -> NSFetchRequest<CachedMachine> {
        let request: NSFetchRequest<CachedMachine> = CachedMachine.fetchRequest()
        request.predicate = NSPredicate(format: "machineId == %@", machineId)
        request.fetchLimit = 1
        return request
    }
}
