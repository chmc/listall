//
//  CoreDataManaging.swift
//  ListAll
//
//  Protocol abstraction for CoreDataManager to enable dependency injection and testing.
//

import Foundation
import CoreData
import CloudKit

/// Protocol defining the interface for Core Data management.
/// This abstraction allows tests to use mock implementations without triggering App Groups permission dialogs.
protocol CoreDataManaging: AnyObject {
    // MARK: - Properties

    /// Main thread context for UI operations
    var viewContext: NSManagedObjectContext { get }

    /// Factory property that creates a new background context for each access
    var backgroundContext: NSManagedObjectContext { get }

    /// Timestamp of the last successful CloudKit sync
    var lastSyncDate: Date? { get }

    // MARK: - Core Operations

    /// Save changes in the viewContext to the persistent store
    func save()

    /// Save changes in a specific context to the persistent store
    /// - Parameter context: The managed object context to save
    func saveContext(_ context: NSManagedObjectContext)

    // MARK: - Sync Operations

    /// Force a manual refresh of the UI from the viewContext
    func forceRefresh()

    /// Trigger the CloudKit sync engine to wake up and sync
    func triggerCloudKitSync()

    /// Check the current iCloud account status
    /// - Returns: The current CloudKit account status
    func checkCloudKitStatus() async -> CKAccountStatus

    // MARK: - Setup

    /// Set up observers for remote change notifications
    func setupRemoteChangeNotifications()

    /// Migrate data from UserDefaults to Core Data if needed
    func migrateDataIfNeeded()
}

// MARK: - Default Implementations

extension CoreDataManaging {
    /// Default implementation that does nothing for setup
    func setupRemoteChangeNotifications() {
        // Default: no-op for test implementations
    }

    /// Default implementation that does nothing for migration
    func migrateDataIfNeeded() {
        // Default: no-op for test implementations
    }
}
