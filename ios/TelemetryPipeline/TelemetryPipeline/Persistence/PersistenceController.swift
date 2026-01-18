//
//  PersistenceController.swift
//  TelemetryPipeline
//
//  CoreData stack for local caching of machines and metrics.
//

import CoreData

struct PersistenceController {
    static let shared = PersistenceController()

    /// Preview instance with in-memory store for SwiftUI previews
    static var preview: PersistenceController = {
        let controller = PersistenceController(inMemory: true)
        let viewContext = controller.container.viewContext

        // Create sample data for previews
        let machine = CachedMachine(context: viewContext)
        machine.machineId = "preview-machine-1"
        machine.name = "Preview Machine"
        machine.location = "Test Location"
        machine.status = "online"
        machine.lastUpdated = Date()

        let metric = CachedMetric(context: viewContext)
        metric.metricKey = "temperature"
        metric.displayName = "Temperature"
        metric.unit = "°C"
        metric.iconType = "thermometer"
        metric.goodRangeMin = 65
        metric.goodRangeMax = 75
        metric.okayRangeMin = 55
        metric.okayRangeMax = 85
        metric.badRangeMin = 86
        metric.badRangeMax = 54
        metric.isActive = true
        metric.isLocalOnly = false
        metric.lastValue = 70.5
        metric.lastUpdated = Date()
        metric.machine = machine

        do {
            try viewContext.save()
        } catch {
            let nsError = error as NSError
            fatalError("Unresolved error \(nsError), \(nsError.userInfo)")
        }

        return controller
    }()

    let container: NSPersistentContainer

    /// Cache time-to-live in seconds (1 hour)
    static let cacheTTL: TimeInterval = 3600

    init(inMemory: Bool = false) {
        container = NSPersistentContainer(name: "TelemetryCache")

        if inMemory {
            container.persistentStoreDescriptions.first?.url = URL(fileURLWithPath: "/dev/null")
        }

        container.loadPersistentStores { description, error in
            if let error = error as NSError? {
                // In production, handle this more gracefully
                print("CoreData failed to load: \(error), \(error.userInfo)")
            }
        }

        container.viewContext.automaticallyMergesChangesFromParent = true
        container.viewContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
    }

    /// Main view context for UI operations
    var viewContext: NSManagedObjectContext {
        container.viewContext
    }

    /// Create a background context for heavy operations
    func newBackgroundContext() -> NSManagedObjectContext {
        let context = container.newBackgroundContext()
        context.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
        return context
    }

    /// Save the view context if there are changes
    func save() {
        let context = viewContext
        if context.hasChanges {
            do {
                try context.save()
            } catch {
                let nsError = error as NSError
                print("CoreData save error: \(nsError), \(nsError.userInfo)")
            }
        }
    }

    /// Check if cached data is still valid based on TTL
    static func isCacheValid(lastUpdated: Date?) -> Bool {
        guard let lastUpdated = lastUpdated else { return false }
        return Date().timeIntervalSince(lastUpdated) < cacheTTL
    }
}
