//
//  TestCoreDataManager.swift
//  ListAllMacTests
//
//  Test-specific Core Data Manager extracted from TestHelpers.swift
//

import Foundation
import CoreData
import CloudKit
@testable import ListAll

/// Test-specific Core Data Manager that uses in-memory storage
/// Conforms to CoreDataManaging protocol for dependency injection
class TestCoreDataManager: ObservableObject, CoreDataManaging {
    let persistentContainer: NSPersistentContainer

    /// Timestamp of the last sync (always nil for test implementations)
    var lastSyncDate: Date? = nil

    init(container: NSPersistentContainer) {
        self.persistentContainer = container
    }

    var viewContext: NSManagedObjectContext {
        return persistentContainer.viewContext
    }

    var backgroundContext: NSManagedObjectContext {
        return persistentContainer.newBackgroundContext()
    }

    func save() {
        let context = persistentContainer.viewContext

        if context.hasChanges {
            do {
                try context.save()
            } catch {
                print("Failed to save test context: \(error)")
            }
        }
    }

    func saveContext(_ context: NSManagedObjectContext) {
        if context.hasChanges {
            do {
                try context.save()
            } catch {
                print("Failed to save test context: \(error)")
            }
        }
    }

    func forceRefresh() {
        // No-op for tests - no CloudKit to refresh from
    }

    func triggerCloudKitSync() {
        // No-op for tests - no CloudKit
    }

    func checkCloudKitStatus() async -> CKAccountStatus {
        // Always return available for tests
        return .available
    }

    func setupRemoteChangeNotifications() {
        // No-op for tests
    }

    func migrateDataIfNeeded() {
        // No-op for tests
    }
}
