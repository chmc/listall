import Foundation
import CoreData
import CloudKit
import Combine

// MARK: - Notification Names
// Note: Also defined in Constants.swift for iOS target
// Duplicated here to support watchOS target without requiring Constants.swift
extension Notification.Name {
    static let coreDataRemoteChange = Notification.Name("CoreDataRemoteChange")
}

// MARK: - Core Data Manager
class CoreDataManager: ObservableObject {
    static let shared = CoreDataManager()

    // Debouncing timer for remote changes
    private var remoteChangeDebounceTimer: Timer?
    private let remoteChangeDebounceInterval: TimeInterval = 0.5 // 500ms debounce

    // CRITICAL: Track local saves to prevent treating them as "remote" changes
    // This prevents drag-drop operations from triggering reload loops
    private var isLocalSave = false

    // MARK: - CloudKit Sync Status Tracking
    /// Timestamp of last successful CloudKit sync (import or export)
    @Published private(set) var lastSyncDate: Date?

    /// Track if CloudKit event handler already handled an import to prevent duplicate notifications
    /// Key: Event start date string, Value: true if already processed
    private var processedCloudKitImports: [String: Bool] = [:]
    
    // MARK: - Core Data Stack
    lazy var persistentContainer: NSPersistentContainer = {
        // CRITICAL: Check if running in test environment - use in-memory store to avoid permission dialogs
        let isTestEnvironment = ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil

        // CRITICAL: Check if running UI tests - use separate SQLite database for isolation
        let isUITest = ProcessInfo.processInfo.arguments.contains("UITEST_MODE")

        if isTestEnvironment {
            print("🧪 CoreDataManager: Test environment detected - using SQLite to /dev/null")
            let container = NSPersistentContainer(name: "ListAll")

            // BEST PRACTICE: Use SQLite store writing to /dev/null
            // This provides full SQLite feature support (cascading deletes, constraints, etc.)
            // while still being effectively in-memory for test isolation
            // Source: Apple WWDC recommendations, Donny Wals, Brian Coyner
            let description = NSPersistentStoreDescription()
            description.url = URL(fileURLWithPath: "/dev/null")
            // Note: type defaults to NSSQLiteStoreType - don't set NSInMemoryStoreType
            // Setting both is contradictory and can cause issues
            container.persistentStoreDescriptions = [description]

            container.loadPersistentStores { _, error in
                if let error = error as NSError? {
                    fatalError("Failed to load test store: \(error), \(error.userInfo)")
                }
            }

            container.viewContext.automaticallyMergesChangesFromParent = true
            container.viewContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy

            return container
        }

        // CloudKit container selection based on platform and build configuration
        // - watchOS: CloudKit disabled due to portal configuration issues
        // - UI tests: CloudKit disabled to prevent crashes on unsigned builds
        // - macOS Debug: CloudKit disabled - unsigned Xcode builds lack entitlements
        // - iOS Debug: CloudKit enabled (simulators work with iCloud login)
        // - Release builds: CloudKit always enabled
        let container: NSPersistentContainer

        #if os(watchOS)
        container = NSPersistentContainer(name: "ListAll")
        print("📦 CoreDataManager: Using NSPersistentContainer (watchOS - CloudKit disabled)")
        #elseif os(macOS) && DEBUG
        // macOS Debug builds from Xcode are unsigned and lack CloudKit entitlements
        // Using NSPersistentCloudKitContainer crashes with "must have entitlement" error
        if isUITest {
            container = NSPersistentContainer(name: "ListAll")
            print("🧪 CoreDataManager: Using NSPersistentContainer (UI test mode)")
        } else {
            container = NSPersistentContainer(name: "ListAll")
            print("📦 CoreDataManager: Using NSPersistentContainer (macOS Debug - CloudKit disabled)")
            print("📦 CoreDataManager: Note: CloudKit sync available in Release builds only")
        }
        #else
        // iOS Debug, iOS Release, macOS Release: Use CloudKit
        if isUITest {
            container = NSPersistentContainer(name: "ListAll")
            print("🧪 CoreDataManager: Using NSPersistentContainer (UI test mode)")
        } else {
            container = NSPersistentCloudKitContainer(name: "ListAll")
            #if DEBUG
            print("📦 CoreDataManager: Using NSPersistentCloudKitContainer (Debug - Development environment)")
            #else
            print("📦 CoreDataManager: Using NSPersistentCloudKitContainer (Release - Production environment)")
            #endif
        }
        #endif

        // Configure store description for migration
        guard let storeDescription = container.persistentStoreDescriptions.first else {
            fatalError("Failed to retrieve a persistent store description.")
        }

        // CRITICAL: UI tests must skip App Groups to avoid macOS privacy dialogs
        // App Groups access triggers "wants to use data from other apps" dialogs
        if isUITest {
            // Use app's Documents directory for UI tests - no permissions needed
            if let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first {
                let storeURL = documentsURL.appendingPathComponent("ListAll-UITests.sqlite")
                storeDescription.url = storeURL
                print("🧪 CoreDataManager: UI test mode - using Documents directory (no App Groups)")
                print("🧪 CoreDataManager: Store URL = \(storeURL.path)")
            }
        } else {
            // Configure App Groups shared container URL (normal app operation)
            let appGroupID = "group.io.github.chmc.ListAll"

            // CRITICAL: Use separate database files for Debug vs Release builds
            // - Debug builds use CloudKit Development environment (sandbox data)
            // - Release builds use CloudKit Production environment (live data)
            #if DEBUG
            let databaseFileName = "ListAll-Debug.sqlite"
            #else
            let databaseFileName = "ListAll.sqlite"
            #endif

            // Try App Groups container first, but verify we have write access
            if let containerURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupID),
               FileManager.default.isWritableFile(atPath: containerURL.path) {

                let storeURL = containerURL.appendingPathComponent(databaseFileName)
                #if DEBUG
                print("📦 CoreDataManager: Using DEBUG database (CloudKit Development environment)")
                #else
                print("📦 CoreDataManager: Using RELEASE database (CloudKit Production environment)")
                #endif
                print("📦 CoreDataManager: App Groups container accessible and writable")
                print("📦 CoreDataManager: Store URL = \(storeURL.path)")

                // Migrate from old location if needed (iOS/macOS only - first time after App Groups was added)
                #if os(iOS) || os(macOS)
                migrateToAppGroupsIfNeeded(newStoreURL: storeURL)
                #endif

                storeDescription.url = storeURL
            } else {
                // FALLBACK: When App Groups fails (e.g., unsigned Debug builds),
                // use app's Documents directory as fallback to ensure data persists
                print("⚠️ CoreDataManager: App Groups container NOT accessible or not writable for '\(appGroupID)'")
                print("⚠️ CoreDataManager: Falling back to Documents directory (data will NOT sync with iOS)")

                if let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first {
                    let fallbackURL = documentsURL.appendingPathComponent(databaseFileName)
                    storeDescription.url = fallbackURL
                    print("⚠️ CoreDataManager: Fallback store URL = \(fallbackURL.path)")
                } else {
                    // Ultimate fallback: keep default URL but log error
                    print("❌ CoreDataManager: CRITICAL - Could not access Documents directory!")
                    if let defaultURL = storeDescription.url {
                        print("❌ CoreDataManager: Using default URL = \(defaultURL.path)")
                    }
                }
            }
        }
        
        // Enable automatic migration
        storeDescription.shouldMigrateStoreAutomatically = true
        storeDescription.shouldInferMappingModelAutomatically = true

        // CRITICAL: Enable persistent history tracking for ALL builds (Debug + Release)
        // This prevents "Read Only mode" error when switching between Debug and Release builds
        // NSPersistentCloudKitContainer automatically enables this, so Debug builds must match
        storeDescription.setOption(true as NSNumber, forKey: NSPersistentHistoryTrackingKey)

        // CRITICAL: Enable remote change notifications - MUST BE SET BEFORE loadPersistentStores
        // This is required for NSPersistentStoreRemoteChange notifications to fire
        storeDescription.setOption(true as NSNumber, forKey: NSPersistentStoreRemoteChangeNotificationPostOptionKey)

        // Enable CloudKit sync based on platform and build configuration
        // - watchOS: CloudKit disabled
        // - macOS Debug: CloudKit disabled (unsigned builds lack entitlements)
        // - UI tests: CloudKit disabled
        // - iOS Debug/Release, macOS Release: CloudKit enabled
        #if os(iOS) || (os(macOS) && !DEBUG)
        if !isUITest {
            let cloudKitContainerOptions = NSPersistentCloudKitContainerOptions(containerIdentifier: "iCloud.io.github.chmc.ListAll")
            storeDescription.cloudKitContainerOptions = cloudKitContainerOptions
            #if DEBUG
            print("📦 CoreDataManager: CloudKit container options configured (Development environment)")
            #else
            print("📦 CoreDataManager: CloudKit container options configured (Production environment)")
            #endif
        } else {
            print("🧪 CoreDataManager: Skipping CloudKit container options in UI test mode")
        }
        #elseif os(macOS) && DEBUG
        print("📦 CoreDataManager: Skipping CloudKit options (macOS Debug - unsigned build)")
        #endif

        container.loadPersistentStores { [weak self] storeDescription, error in
            if let error = error as NSError? {
                print("❌ CoreDataManager: Failed to load persistent store: \(error)")
                print("❌ CoreDataManager: Error code: \(error.code), domain: \(error.domain)")
                print("❌ CoreDataManager: UserInfo: \(error.userInfo)")

                // Handle recoverable errors by deleting and recreating the store
                // - 134110: Migration error (schema change)
                // - 256: NSFileReadUnknownError (corrupted store or CloudKit schema mismatch)
                // - 134060: NSPersistentStoreIncompatibleVersionHashError
                // - 513: NSFileWriteNoPermissionError (sandbox permission issue)
                // - 4: NSFileReadNoPermissionError
                let recoverableErrorCodes = [134110, 256, 134060, 513, 4]

                if recoverableErrorCodes.contains(error.code) {
                    print("⚠️ CoreDataManager: Attempting to recover by deleting and recreating store...")
                    self?.deleteAndRecreateStore(container: container, storeDescription: storeDescription)
                } else {
                    // For truly unrecoverable errors, crash with details
                    fatalError("Unresolved Core Data error \(error.code): \(error), \(error.userInfo)")
                }
            }
        }

        // Initialize CloudKit schema in Debug builds (Development environment)
        // This ensures the schema is pushed to CloudKit Development environment
        // Note: Only do this on iOS/macOS where CloudKit is enabled
        // CRITICAL: Skip during UI tests - they use NSPersistentContainer (no CloudKit)
        #if DEBUG && (os(iOS) || os(macOS))
        if !isUITest, let cloudKitContainer = container as? NSPersistentCloudKitContainer {
            do {
                try cloudKitContainer.initializeCloudKitSchema(options: [])
                print("📦 CoreDataManager: CloudKit schema initialized for Development environment")
            } catch {
                // Schema initialization can fail on simulators without iCloud login - this is expected
                print("📦 CoreDataManager: CloudKit schema initialization skipped: \(error.localizedDescription)")
            }
        } else if isUITest {
            print("🧪 CoreDataManager: Skipping CloudKit schema initialization in UI test mode")
        }
        #endif

        // Configure view context
        container.viewContext.automaticallyMergesChangesFromParent = true
        container.viewContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy

        // Set query generation to ensure fetches return current data
        // This helps with real-time sync issues where UI doesn't update when CloudKit syncs
        // CRITICAL: Required for BOTH iOS and macOS to ensure fetch results reflect CloudKit imports
        #if os(iOS) || os(macOS)
        try? container.viewContext.setQueryGenerationFrom(.current)
        print("📦 CoreDataManager: Query generation set to .current")
        #endif

        return container
    }()
    
    // MARK: - Contexts
    var viewContext: NSManagedObjectContext {
        return persistentContainer.viewContext
    }
    
    var backgroundContext: NSManagedObjectContext {
        return persistentContainer.newBackgroundContext()
    }
    
    private init() {
        // Initialize Core Data stack
        // Force load of persistent container
        _ = persistentContainer
        
        // Setup remote change notification observer
        setupRemoteChangeNotifications()
    }
    
    deinit {
        // Clean up observers and timers
        NotificationCenter.default.removeObserver(self)
        remoteChangeDebounceTimer?.invalidate()
    }

    // MARK: - Test Support

    #if DEBUG
    /// Reset singleton state for test isolation
    /// WARNING: Only call from test tearDown() - NOT safe for production use
    /// This helps prevent cross-test contamination when tests share the singleton
    static func resetForTesting() {
        // Only reset in test environment
        guard ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil else {
            print("⚠️ CoreDataManager.resetForTesting() called outside test environment - ignoring")
            return
        }

        // Remove all notification observers
        NotificationCenter.default.removeObserver(shared)

        // Cancel any pending timers
        shared.remoteChangeDebounceTimer?.invalidate()
        shared.remoteChangeDebounceTimer = nil

        // Reset Core Data context to clear cached objects
        shared.viewContext.reset()

        // Re-setup notifications for next test
        shared.setupRemoteChangeNotifications()

        print("🧪 CoreDataManager: Reset for testing completed")
    }
    #endif

    // MARK: - Remote Change Notifications
    
    /// Setup remote change notification observers
    /// Note: Made internal (not private) to allow reset from test support methods
    func setupRemoteChangeNotifications() {
        // Observe remote changes from other processes (e.g., watchOS app, CloudKit sync)
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handlePersistentStoreRemoteChange(_:)),
            name: .NSPersistentStoreRemoteChange,
            object: persistentContainer.persistentStoreCoordinator
        )

        // Observe CloudKit sync events (iOS 14+, macOS 11+) for sync status/errors
        #if os(iOS) || os(macOS)
        if #available(iOS 14.0, macOS 11.0, *) {
            NotificationCenter.default.addObserver(
                self,
                selector: #selector(handleCloudKitEvent(_:)),
                name: NSPersistentCloudKitContainer.eventChangedNotification,
                object: persistentContainer
            )
            print("📦 CoreDataManager: CloudKit event notification observer added")
        }
        #endif

        // iOS + macOS: Observe background context saves (CloudKit imports happen on background context)
        // This catches CloudKit changes even when the app is frontmost and active
        // CRITICAL for iOS: Without this, iOS only receives NSPersistentStoreRemoteChange which may not
        // fire reliably when the app is foregrounded. Background context saves are more reliable.
        #if os(iOS) || os(macOS)
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleContextDidSave(_:)),
            name: .NSManagedObjectContextDidSave,
            object: nil  // Observe ALL contexts, not just viewContext
        )
        print("📦 CoreDataManager: Background context save observer added (CloudKit import detection)")
        #endif
    }
    
    @objc private func handlePersistentStoreRemoteChange(_ notification: Notification) {

        // CRITICAL: Ignore local saves - only process true remote changes
        // Local saves (from drag-drop, item edits) should NOT trigger reload loops
        if isLocalSave {
            print("💾 CoreDataManager: Ignoring local save notification (not a remote change)")
            isLocalSave = false  // Reset flag
            return
        }

        // Ensure we're on the main thread for UI safety
        guard Thread.isMainThread else {
            DispatchQueue.main.async { [weak self] in
                self?.handlePersistentStoreRemoteChange(notification)
            }
            return
        }

        print("🌐 CoreDataManager: Detected REMOTE change from another process")

        // Debounce rapid changes to prevent excessive reloads
        remoteChangeDebounceTimer?.invalidate()
        remoteChangeDebounceTimer = Timer.scheduledTimer(withTimeInterval: remoteChangeDebounceInterval, repeats: false) { [weak self] _ in
            self?.processRemoteChange()
        }
    }
    
    private func processRemoteChange() {
        // CRITICAL: We're already on the main thread (from handlePersistentStoreRemoteChange dispatch)
        // DO NOT use viewContext.perform { } here - it re-dispatches to background queue!
        // This would cause notifications to fire on background thread, breaking @Published updates.

        // Refresh view context synchronously on main thread
        viewContext.refreshAllObjects()

        // Post notification ON MAIN THREAD for DataManager and ViewModels to reload
        NotificationCenter.default.post(
            name: .coreDataRemoteChange,
            object: nil
        )
    }

    // MARK: - Background Context Handling (CloudKit Import Detection)

    #if os(iOS) || os(macOS)
    /// Handles saves from background contexts (including CloudKit import context)
    /// This ensures UI updates in real-time when CloudKit syncs changes from other devices
    /// CRITICAL: We deduplicate by checking if this is a CloudKit import context.
    /// CloudKit imports are better handled by handleCloudKitEvent which has more info about the event.
    @objc private func handleContextDidSave(_ notification: Notification) {
        guard let savedContext = notification.object as? NSManagedObjectContext else { return }

        // Only process saves from OTHER contexts (background contexts)
        // Skip our own viewContext saves to avoid loops
        guard savedContext != viewContext else {
            print("💾 CoreDataManager: Ignoring viewContext save (local)")
            return
        }

        // CRITICAL: Detect CloudKit import contexts to prevent duplicate notifications
        // CloudKit import contexts typically have names like:
        // - "NSCloudKitMirroringDelegate.export" / "NSCloudKitMirroringDelegate.import"
        // - Or contain "CloudKit" in their name
        // Let handleCloudKitEvent handle these instead to prevent double-refresh
        if let contextName = savedContext.name {
            let isCloudKitContext = contextName.contains("CloudKit") ||
                                    contextName.contains("NSCloudKitMirroringDelegate") ||
                                    contextName.contains("import") ||
                                    contextName.contains("export")
            if isCloudKitContext {
                print("☁️ CoreDataManager: Skipping CloudKit context save (handled by eventChangedNotification): \(contextName)")
                return
            }
        }

        // This is a background context save from non-CloudKit source (e.g., watchOS, widget, app extension)
        print("🌐 CoreDataManager: Background context saved (non-CloudKit) - triggering UI refresh")

        // Ensure we're on main thread for UI updates
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }

            // CRITICAL: DO NOT use viewContext.perform { } here - we're already on main thread!
            // viewContext.perform re-dispatches to background queue, causing notifications
            // to fire on background thread, which breaks @Published property updates in SwiftUI.

            // Refresh view context synchronously on main thread
            self.viewContext.refreshAllObjects()

            // Post notification ON MAIN THREAD for DataManager and views to reload
            NotificationCenter.default.post(
                name: .coreDataRemoteChange,
                object: nil
            )
        }
    }
    #endif

    // MARK: - CloudKit Event Handling

    #if os(iOS) || os(macOS)
    @available(iOS 14.0, macOS 11.0, *)
    @objc private func handleCloudKitEvent(_ notification: Notification) {
        guard let cloudEvent = notification.userInfo?[NSPersistentCloudKitContainer.eventNotificationUserInfoKey]
                as? NSPersistentCloudKitContainer.Event else {
            return
        }

        let eventType = cloudEvent.type
        #if os(iOS)
        let platform = "iOS"
        #elseif os(macOS)
        let platform = "macOS"
        #else
        let platform = "unknown"
        #endif

        if cloudEvent.endDate == nil {
            // Event just started
            print("☁️ [\(platform)] CloudKit event STARTED: \(eventType)")
        } else {
            // Event completed (endDate != nil)
            if cloudEvent.succeeded {
                print("✅ [\(platform)] CloudKit event SUCCEEDED: \(eventType)")

                // Update last sync timestamp for successful imports/exports
                if eventType == .import || eventType == .export {
                    DispatchQueue.main.async { [weak self] in
                        self?.lastSyncDate = Date()
                    }
                }

                // Post notification to trigger UI refresh after successful import
                if eventType == .import {
                    DispatchQueue.main.async { [weak self] in
                        guard let self = self else { return }

                        // CRITICAL: DO NOT use viewContext.perform { } here - we're already on main thread!
                        // viewContext.perform re-dispatches to background queue, causing notifications
                        // to fire on background thread, which breaks @Published property updates in SwiftUI.

                        // Reset query generation to ensure fetches see CloudKit-imported data
                        try? self.viewContext.setQueryGenerationFrom(.current)

                        // Refresh view context synchronously on main thread
                        self.viewContext.refreshAllObjects()

                        print("🔄 [\(platform)] CloudKit import complete - refreshed viewContext and posting notification")

                        // Post notification ON MAIN THREAD
                        NotificationCenter.default.post(name: .coreDataRemoteChange, object: nil)
                    }
                }
            } else if let error = cloudEvent.error {
                print("❌ [\(platform)] CloudKit event FAILED: \(eventType) - \(error.localizedDescription)")
            }
        }
    }
    #endif

    // MARK: - Manual Sync Trigger

    /// Force a sync refresh by refreshing the view context and reloading data
    /// Call this from UI when user taps manual refresh button
    func forceRefresh() {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }

            #if os(iOS)
            let platform = "iOS"
            #elseif os(macOS)
            let platform = "macOS"
            #else
            let platform = "unknown"
            #endif

            print("🔄 [\(platform)] Manual refresh triggered")

            // Trigger CloudKit sync engine to check for pending operations
            self.triggerCloudKitSync()

            // Reset query generation to ensure we see latest data
            try? self.viewContext.setQueryGenerationFrom(.current)

            // Refresh all objects in viewContext
            self.viewContext.refreshAllObjects()

            // Update last sync timestamp
            self.lastSyncDate = Date()

            // Post notification for UI to reload
            NotificationCenter.default.post(name: .coreDataRemoteChange, object: nil)
        }
    }

    /// Triggers CloudKit sync engine to wake up and check for pending operations
    /// NSPersistentCloudKitContainer sync is passive (push-notification based), but performing
    /// a background context operation can encourage the sync engine to process pending imports/exports.
    /// Note: This does NOT force CloudKit to fetch from server - that's controlled by Apple's infrastructure.
    /// However, it helps process any data that CloudKit has already received but not yet imported.
    func triggerCloudKitSync() {
        #if os(iOS)
        let platform = "iOS"
        #elseif os(macOS)
        let platform = "macOS"
        #else
        let platform = "unknown"
        #endif

        // Perform a lightweight background context operation
        // This wakes up NSPersistentCloudKitContainer's mirroring delegate which processes pending operations
        persistentContainer.performBackgroundTask { context in
            // Simply processing pending changes is enough to wake up the sync engine
            context.processPendingChanges()
            print("☁️ [\(platform)] Triggered CloudKit sync engine (processPendingChanges)")
        }
    }

    // MARK: - Core Data Operations
    
    func save() {
        let context = persistentContainer.viewContext

        if context.hasChanges {
            do {
                // CRITICAL: Mark this as a local save to prevent treating it as remote change
                isLocalSave = true
                try context.save()
                print("💾 CoreDataManager: Context saved successfully (local save)")
            } catch {
                print("❌ CoreDataManager: Failed to save context: \(error)")
                isLocalSave = false  // Reset on error
            }
        } else {
            print("💾 CoreDataManager: No changes to save")
        }
    }
    
    func saveContext(_ context: NSManagedObjectContext) {
        if context.hasChanges {
            do {
                try context.save()
            } catch {
                print("Failed to save context: \(error)")
            }
        }
    }
    
    // MARK: - CloudKit Status
    
    func checkCloudKitStatus() async -> CKAccountStatus {
        let container = CKContainer(identifier: "iCloud.io.github.chmc.ListAll")
        do {
            return try await container.accountStatus()
        } catch {
            print("Failed to check CloudKit status: \(error)")
            return .couldNotDetermine
        }
    }
    
    // MARK: - Data Migration
    
    /// Migrates Core Data store from old location (app's Documents) to App Groups shared container
    /// This is only needed once when upgrading from pre-App Groups version
    private func migrateToAppGroupsIfNeeded(newStoreURL: URL) {
        let fileManager = FileManager.default
        
        // Check if App Groups store already exists
        if fileManager.fileExists(atPath: newStoreURL.path) {
            return
        }
        
        // Check for old store in app's Documents directory
        guard let documentsURL = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first else {
            return
        }
        
        let oldStoreURL = documentsURL.appendingPathComponent("ListAll.sqlite")
        
        // If old store doesn't exist, nothing to migrate
        guard fileManager.fileExists(atPath: oldStoreURL.path) else {
            return
        }
        
        do {
            // Create App Groups directory if it doesn't exist
            let appGroupsDirectory = newStoreURL.deletingLastPathComponent()
            if !fileManager.fileExists(atPath: appGroupsDirectory.path) {
                try fileManager.createDirectory(at: appGroupsDirectory, withIntermediateDirectories: true, attributes: nil)
            }
            
            // Copy the main database file
            try fileManager.copyItem(at: oldStoreURL, to: newStoreURL)
            
            // Copy associated files (WAL and SHM) if they exist
            let walOldURL = documentsURL.appendingPathComponent("ListAll.sqlite-wal")
            let walNewURL = newStoreURL.deletingLastPathComponent().appendingPathComponent("ListAll.sqlite-wal")
            if fileManager.fileExists(atPath: walOldURL.path) {
                try? fileManager.copyItem(at: walOldURL, to: walNewURL)
            }
            
            let shmOldURL = documentsURL.appendingPathComponent("ListAll.sqlite-shm")
            let shmNewURL = newStoreURL.deletingLastPathComponent().appendingPathComponent("ListAll.sqlite-shm")
            if fileManager.fileExists(atPath: shmOldURL.path) {
                try? fileManager.copyItem(at: shmOldURL, to: shmNewURL)
            }
            
            // Delete old store files to prevent confusion
            try? fileManager.removeItem(at: oldStoreURL)
            try? fileManager.removeItem(at: walOldURL)
            try? fileManager.removeItem(at: shmOldURL)
            
        } catch {
            print("❌ [iOS] Failed to migrate store to App Groups: \(error)")
        }
    }
    
    private func deleteAndRecreateStore(container: NSPersistentContainer, storeDescription: NSPersistentStoreDescription) {
        guard var storeURL = storeDescription.url else {
            print("⚠️ CoreDataManager: No store URL to delete")
            return
        }

        // Check if we can write to the store directory - if not, use Documents fallback
        let storeDirectory = storeURL.deletingLastPathComponent()
        if !FileManager.default.isWritableFile(atPath: storeDirectory.path) {
            print("⚠️ CoreDataManager: No write permission to \(storeDirectory.path)")
            print("⚠️ CoreDataManager: Using Documents directory fallback")

            if let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first {
                #if DEBUG
                storeURL = documentsURL.appendingPathComponent("ListAll-Debug.sqlite")
                #else
                storeURL = documentsURL.appendingPathComponent("ListAll.sqlite")
                #endif
                storeDescription.url = storeURL
            }
        }

        print("🗑️ CoreDataManager: Deleting and recreating store at \(storeURL.path)")

        do {
            // Delete the existing store files
            let fileManager = FileManager.default
            let storeDirectory = storeURL.deletingLastPathComponent()

            // Find all store-related files and directories
            let storeFiles = try fileManager.contentsOfDirectory(at: storeDirectory, includingPropertiesForKeys: nil)
            let storeFileExtensions = ["sqlite", "sqlite-wal", "sqlite-shm"]
            let storeName = storeURL.deletingPathExtension().lastPathComponent

            for file in storeFiles {
                let fileName = file.lastPathComponent
                let fileExtension = file.pathExtension

                // Delete SQLite files
                if storeFileExtensions.contains(fileExtension) && fileName.hasPrefix(storeName) {
                    print("🗑️ CoreDataManager: Deleting \(fileName)")
                    try fileManager.removeItem(at: file)
                }

                // Also delete CloudKit cache directory if it exists (e.g., "ListAll_ckAssets")
                if fileName.hasPrefix(storeName) && fileName.hasSuffix("_ckAssets") {
                    print("🗑️ CoreDataManager: Deleting CloudKit cache \(fileName)")
                    try fileManager.removeItem(at: file)
                }
            }

            // Reload the store with proper options
            let options: [String: Any] = [
                NSMigratePersistentStoresAutomaticallyOption: true,
                NSInferMappingModelAutomaticallyOption: true,
                NSPersistentHistoryTrackingKey: true
            ]

            print("🔄 CoreDataManager: Recreating store...")
            try container.persistentStoreCoordinator.addPersistentStore(
                ofType: NSSQLiteStoreType,
                configurationName: nil,
                at: storeURL,
                options: options
            )
            print("✅ CoreDataManager: Store recreated successfully")

        } catch {
            print("❌ CoreDataManager: Failed to delete and recreate store: \(error)")
            // If we still can't create the store, use in-memory store as fallback
            do {
                print("⚠️ CoreDataManager: Falling back to in-memory store")
                try container.persistentStoreCoordinator.addPersistentStore(
                    ofType: NSInMemoryStoreType,
                    configurationName: nil,
                    at: nil,
                    options: nil
                )
                print("✅ CoreDataManager: In-memory store created (data will not persist)")
            } catch {
                fatalError("Failed to create any persistent store: \(error)")
            }
        }
    }
    
    func migrateDataIfNeeded() {
        // Check if we need to migrate from UserDefaults to Core Data
        if UserDefaults.standard.object(forKey: "saved_lists") != nil {
            migrateFromUserDefaults()
        }
    }
    
    private func migrateFromUserDefaults() {
        guard let data = UserDefaults.standard.data(forKey: "saved_lists"),
              let lists = try? JSONDecoder().decode([List].self, from: data) else {
            return
        }
        
        let context = backgroundContext
        context.perform {
            for listData in lists {
                let list = ListEntity(context: context)
                list.id = listData.id
                list.name = listData.name
                list.orderNumber = Int32(listData.orderNumber)
                list.createdAt = listData.createdAt
                list.modifiedAt = listData.modifiedAt
                list.isArchived = false
                
                for itemData in listData.items {
                    let item = ItemEntity(context: context)
                    item.id = itemData.id
                    item.title = itemData.title
                    item.itemDescription = itemData.itemDescription
                    item.quantity = Int32(itemData.quantity)
                    item.orderNumber = Int32(itemData.orderNumber)
                    item.isCrossedOut = itemData.isCrossedOut
                    item.createdAt = itemData.createdAt
                    item.modifiedAt = itemData.modifiedAt
                    item.list = list
                    
                    for imageData in itemData.images {
                        let image = ItemImageEntity(context: context)
                        image.id = imageData.id
                        image.imageData = imageData.imageData
                        image.orderNumber = Int32(imageData.orderNumber)
                        image.createdAt = imageData.createdAt
                        image.item = item
                    }
                }
            }
            
            self.saveContext(context)
            
            // Clear UserDefaults data after migration
            DispatchQueue.main.async {
                UserDefaults.standard.removeObject(forKey: "saved_lists")
            }
        }
    }
}

// MARK: - Legacy Data Manager (for backward compatibility)
class DataManager: ObservableObject {
    static let shared = DataManager()

    @Published var lists: [List] = []
    private let coreDataManager = CoreDataManager.shared

    private init() {
        loadData()
        
        // Listen for remote changes from other processes (iOS/watchOS)
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleRemoteChange(_:)),
            name: .coreDataRemoteChange,
            object: nil
        )
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    // MARK: - Test Support

    #if DEBUG
    /// Reset singleton state for test isolation
    /// WARNING: Only call from test tearDown() - NOT safe for production use
    static func resetForTesting() {
        // Only reset in test environment
        guard ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil else {
            print("⚠️ DataManager.resetForTesting() called outside test environment - ignoring")
            return
        }

        // Remove notification observers
        NotificationCenter.default.removeObserver(shared)

        // Clear cached data
        shared.lists = []

        // Reset underlying Core Data manager
        CoreDataManager.resetForTesting()

        // Re-register for notifications
        NotificationCenter.default.addObserver(
            shared,
            selector: #selector(shared.handleRemoteChange(_:)),
            name: .coreDataRemoteChange,
            object: nil
        )

        print("🧪 DataManager: Reset for testing completed")
    }
    #endif

    // MARK: - Remote Change Handling

    @objc private func handleRemoteChange(_ notification: Notification) {
        // CRITICAL: @objc selectors can be called from any thread - ensure main thread
        // WITHOUT this guard, loadData() may attempt @Published updates from background thread,
        // causing SwiftUI to silently ignore changes (iOS CloudKit sync appears "delayed")
        guard Thread.isMainThread else {
            DispatchQueue.main.async { [weak self] in
                self?.handleRemoteChange(notification)
            }
            return
        }

        // Reload data from Core Data to reflect changes made by other process
        loadData()
    }
    
    // MARK: - Data Operations
    
    func loadData() {
        // Load from Core Data, excluding archived lists
        let request: NSFetchRequest<ListEntity> = ListEntity.fetchRequest()
        request.predicate = NSPredicate(format: "isArchived == NO OR isArchived == nil")
        request.sortDescriptors = [NSSortDescriptor(keyPath: \ListEntity.orderNumber, ascending: true)]

        // CRITICAL: Eagerly fetch items relationship to avoid empty items arrays
        // Also prefetch items.images to prevent N+1 query when loading images
        request.relationshipKeyPathsForPrefetching = ["items", "items.images"]

        do {
            let listEntities = try coreDataManager.viewContext.fetch(request)
            let newLists = listEntities.map { $0.toList() }

            // CRITICAL FIX: Update @Published property SYNCHRONOUSLY on main thread
            // Using DispatchQueue.main.async with [weak self] BREAKS SwiftUI observation on macOS!
            // The async dispatch causes the change to happen in a deferred RunLoop cycle,
            // which SwiftUI's change detection may miss entirely.
            //
            // Solution: If on main thread, update synchronously. If not, dispatch and update synchronously.
            // Also: Call objectWillChange.send() explicitly BEFORE the change for reliable observation.
            let updateLists = { [self] in
                // Explicitly notify SwiftUI BEFORE the change (required for reliable observation)
                self.objectWillChange.send()
                self.lists = newLists
                print("📱 DataManager: Updated lists array with \(newLists.count) lists (synchronous)")
            }

            if Thread.isMainThread {
                updateLists()
            } else {
                DispatchQueue.main.sync {
                    updateLists()
                }
            }
        } catch {
            print("❌ Failed to fetch lists: \(error)")
            // Fallback to sample data
            if lists.isEmpty {
                createSampleData()
            }
        }
    }
    
    func saveData() {
        coreDataManager.save()
    }

    /// Fresh fetch of active lists from Core Data, sorted by orderNumber
    /// Use this after reordering to get the latest state without affecting the cached lists array
    /// This mirrors the getItems(forListId:) pattern for consistency (DRY)
    func getLists() -> [List] {
        let request: NSFetchRequest<ListEntity> = ListEntity.fetchRequest()
        request.predicate = NSPredicate(format: "isArchived == NO OR isArchived == nil")
        request.sortDescriptors = [NSSortDescriptor(keyPath: \ListEntity.orderNumber, ascending: true)]
        // Prefetch items and their images to prevent N+1 query problems
        request.relationshipKeyPathsForPrefetching = ["items", "items.images"]

        do {
            let listEntities = try coreDataManager.viewContext.fetch(request)
            return listEntities.map { $0.toList() }
        } catch {
            print("❌ Failed to fetch lists: \(error)")
            return []
        }
    }

    // MARK: - List Operations
    
    func addList(_ list: List) {
        let context = coreDataManager.viewContext
        let listEntity = ListEntity(context: context)
        listEntity.id = list.id
        listEntity.name = list.name

        // FIX: Calculate next orderNumber (max + 1) to ensure unique sequential ordering
        let maxOrderNumber = lists.map { $0.orderNumber }.max() ?? -1
        let nextOrderNumber = maxOrderNumber + 1
        listEntity.orderNumber = Int32(nextOrderNumber)

        listEntity.createdAt = list.createdAt
        listEntity.modifiedAt = list.modifiedAt
        listEntity.isArchived = false

        saveData()

        // Update the list struct with the assigned orderNumber before appending
        var updatedList = list
        updatedList.orderNumber = nextOrderNumber
        lists.append(updatedList)
        // No need to sort - new list goes to end with highest orderNumber
    }
    
    func updateList(_ list: List) {
        let request: NSFetchRequest<ListEntity> = ListEntity.fetchRequest()
        request.predicate = NSPredicate(format: "id == %@", list.id as CVarArg)
        
        do {
            let results = try coreDataManager.viewContext.fetch(request)
            if let listEntity = results.first {
                listEntity.name = list.name
                listEntity.orderNumber = Int32(list.orderNumber)
                listEntity.modifiedAt = list.modifiedAt
                listEntity.isArchived = list.isArchived
                saveData()
                // Update local array instead of reloading
                if let index = lists.firstIndex(where: { $0.id == list.id }) {
                    lists[index] = list
                }
            }
        } catch {
            print("Failed to update list: \(error)")
        }
    }
    
    func updateListsOrder(_ newOrder: [List]) {
        // FIX: Batch fetch all entities ONCE instead of N separate fetches (O(n) vs O(n²))
        let context = coreDataManager.viewContext

        // Fetch ALL list entities in a single query
        let request: NSFetchRequest<ListEntity> = ListEntity.fetchRequest()
        let listIds = newOrder.map { $0.id }
        request.predicate = NSPredicate(format: "id IN %@", listIds)

        do {
            let allEntities = try context.fetch(request)

            // Create lookup dictionary for O(1) access
            var entityById: [UUID: ListEntity] = [:]
            for entity in allEntities {
                if let id = entity.id {
                    entityById[id] = entity
                }
            }

            // Update all entities in memory (O(n))
            for list in newOrder {
                if let entity = entityById[list.id] {
                    entity.orderNumber = Int32(list.orderNumber)
                    entity.modifiedAt = list.modifiedAt
                }
            }
        } catch {
            print("Failed to batch update list order: \(error)")
        }

        // Save once after all updates
        saveData()

        // CRITICAL: Ensure Core Data has processed all changes before continuing
        context.processPendingChanges()

        // DON'T update local array here - let caller explicitly call loadData() to refresh
        // This prevents race conditions where cached array gets out of sync with Core Data
        // lists = newOrder  // REMOVED - caller must call loadData() explicitly
    }
    
    func synchronizeLists(_ newOrder: [List]) {
        // Synchronize internal lists array with the provided order
        // This ensures that subsequent reloads maintain the correct order
        lists = newOrder
    }
    
    func deleteList(withId id: UUID) {
        // Archive the list instead of permanently deleting it
        let request: NSFetchRequest<ListEntity> = ListEntity.fetchRequest()
        request.predicate = NSPredicate(format: "id == %@", id as CVarArg)
        
        do {
            let results = try coreDataManager.viewContext.fetch(request)
            if let listEntity = results.first {
                listEntity.isArchived = true
                listEntity.modifiedAt = Date()
                saveData()
                // Remove from local array (archived lists are filtered out)
                lists.removeAll { $0.id == id }
            }
        } catch {
            print("Failed to archive list: \(error)")
        }
    }
    
    func loadArchivedLists() -> [List] {
        // Load archived lists from Core Data
        let request: NSFetchRequest<ListEntity> = ListEntity.fetchRequest()
        request.predicate = NSPredicate(format: "isArchived == YES")
        request.sortDescriptors = [NSSortDescriptor(keyPath: \ListEntity.modifiedAt, ascending: false)]
        
        do {
            let listEntities = try coreDataManager.viewContext.fetch(request)
            return listEntities.map { $0.toList() }
        } catch {
            print("Failed to fetch archived lists: \(error)")
            return []
        }
    }
    
    func restoreList(withId id: UUID) {
        // Restore an archived list
        let request: NSFetchRequest<ListEntity> = ListEntity.fetchRequest()
        request.predicate = NSPredicate(format: "id == %@", id as CVarArg)
        
        do {
            let results = try coreDataManager.viewContext.fetch(request)
            if let listEntity = results.first {
                listEntity.isArchived = false
                listEntity.modifiedAt = Date()
                saveData()
                // Reload data to include the restored list
                loadData()
            }
        } catch {
            print("Failed to restore list: \(error)")
        }
    }
    
    func permanentlyDeleteList(withId id: UUID) {
        // Permanently delete a list and all its associated items
        let listRequest: NSFetchRequest<ListEntity> = ListEntity.fetchRequest()
        listRequest.predicate = NSPredicate(format: "id == %@", id as CVarArg)
        
        do {
            let results = try coreDataManager.viewContext.fetch(listRequest)
            if let listEntity = results.first {
                // Delete all items in the list first
                if let items = listEntity.items as? Set<ItemEntity> {
                    for itemEntity in items {
                        // Delete all images in the item
                        if let images = itemEntity.images as? Set<ItemImageEntity> {
                            for imageEntity in images {
                                coreDataManager.viewContext.delete(imageEntity)
                            }
                        }
                        // Delete the item
                        coreDataManager.viewContext.delete(itemEntity)
                    }
                }
                // Delete the list itself
                coreDataManager.viewContext.delete(listEntity)
                saveData()
            }
        } catch {
            print("Failed to permanently delete list: \(error)")
        }
    }
    
    // MARK: - Item Operations
    
    func addItem(_ item: Item, to listId: UUID) {
        let context = coreDataManager.viewContext
        
        // Check if item already exists (prevent duplicates during sync)
        let itemCheck: NSFetchRequest<ItemEntity> = ItemEntity.fetchRequest()
        itemCheck.predicate = NSPredicate(format: "id == %@", item.id as CVarArg)
        
        do {
            let existingItems = try context.fetch(itemCheck)
            if let existingItem = existingItems.first {
                // Item already exists, update it instead
                existingItem.title = item.title
                existingItem.itemDescription = item.itemDescription
                existingItem.quantity = Int32(item.quantity)
                existingItem.orderNumber = Int32(item.orderNumber)
                existingItem.isCrossedOut = item.isCrossedOut
                existingItem.modifiedAt = item.modifiedAt
                
                saveData()
                // Don't call loadData() here - let the caller handle batching
                return
            }
        } catch {
            print("Failed to check for existing item: \(error)")
        }
        
        // Find the list
        let listRequest: NSFetchRequest<ListEntity> = ListEntity.fetchRequest()
        listRequest.predicate = NSPredicate(format: "id == %@", listId as CVarArg)
        
        do {
            let listResults = try context.fetch(listRequest)
            if let listEntity = listResults.first {
                let itemEntity = ItemEntity(context: context)
                itemEntity.id = item.id
                itemEntity.title = item.title
                itemEntity.itemDescription = item.itemDescription
                itemEntity.quantity = Int32(item.quantity)
                itemEntity.orderNumber = Int32(item.orderNumber)
                itemEntity.isCrossedOut = item.isCrossedOut
                itemEntity.createdAt = item.createdAt
                itemEntity.modifiedAt = item.modifiedAt
                itemEntity.list = listEntity
                
                // Create image entities from the item's images
                // CRITICAL FIX: Check for duplicate image IDs to prevent Core Data conflicts
                for itemImage in item.images {
                    // Check if image entity with this ID already exists
                    let imageCheck: NSFetchRequest<ItemImageEntity> = ItemImageEntity.fetchRequest()
                    imageCheck.predicate = NSPredicate(format: "id == %@", itemImage.id as CVarArg)
                    
                    let existingImages = try context.fetch(imageCheck)
                    if let existingImage = existingImages.first {
                        // Image ID already exists - create a new one with a different ID
                        // This can happen if the same item is added to multiple lists
                        var newImageData = itemImage
                        newImageData.id = UUID() // Force new ID to avoid conflict
                        let imageEntity = ItemImageEntity.fromItemImage(newImageData, context: context)
                        imageEntity.item = itemEntity
                    } else {
                        // Normal case - create image entity with original ID
                        let imageEntity = ItemImageEntity.fromItemImage(itemImage, context: context)
                        imageEntity.item = itemEntity
                    }
                }
                
                saveData()
                // Don't call loadData() here - let the caller handle batching
                
                // Notify after data is saved (but don't reload yet to avoid excessive reloads)
                NotificationCenter.default.post(name: NSNotification.Name("ItemDataChanged"), object: nil)
            }
        } catch {
            print("Failed to add item: \(error)")
        }
    }
    
    func updateItem(_ item: Item) {
        let request: NSFetchRequest<ItemEntity> = ItemEntity.fetchRequest()
        request.predicate = NSPredicate(format: "id == %@", item.id as CVarArg)
        
        do {
            let results = try coreDataManager.viewContext.fetch(request)
            if let itemEntity = results.first {
                // Update basic properties
                itemEntity.title = item.title
                itemEntity.itemDescription = item.itemDescription
                itemEntity.quantity = Int32(item.quantity)
                itemEntity.orderNumber = Int32(item.orderNumber)
                itemEntity.isCrossedOut = item.isCrossedOut
                itemEntity.modifiedAt = item.modifiedAt
                
                // Update images: First delete existing image entities
                if let existingImages = itemEntity.images?.allObjects as? [ItemImageEntity] {
                    for imageEntity in existingImages {
                        coreDataManager.viewContext.delete(imageEntity)
                    }
                }
                
                // Create new image entities from the item's images
                for itemImage in item.images {
                    let imageEntity = ItemImageEntity.fromItemImage(itemImage, context: coreDataManager.viewContext)
                    imageEntity.item = itemEntity
                }
                
                saveData()
                loadData()
                
                // Notify after data is fully loaded
                NotificationCenter.default.post(name: NSNotification.Name("ItemDataChanged"), object: nil)
            }
        } catch {
            print("Failed to update item: \(error)")
        }
    }
    
    func deleteItem(withId id: UUID, from listId: UUID) {
        let request: NSFetchRequest<ItemEntity> = ItemEntity.fetchRequest()
        request.predicate = NSPredicate(format: "id == %@", id as CVarArg)
        
        do {
            let results = try coreDataManager.viewContext.fetch(request)
            for itemEntity in results {
                coreDataManager.viewContext.delete(itemEntity)
            }
            saveData()
            loadData()
            
            // Notify after data is fully loaded
            NotificationCenter.default.post(name: NSNotification.Name("ItemDataChanged"), object: nil)
        } catch {
            print("Failed to delete item: \(error)")
        }
    }
    
    func getItems(forListId listId: UUID) -> [Item] {
        let request: NSFetchRequest<ItemEntity> = ItemEntity.fetchRequest()
        request.predicate = NSPredicate(format: "list.id == %@", listId as CVarArg)
        // Sort by orderNumber to ensure consistent display order
        request.sortDescriptors = [NSSortDescriptor(keyPath: \ItemEntity.orderNumber, ascending: true)]
        
        do {
            let itemEntities = try coreDataManager.viewContext.fetch(request)
            return itemEntities.map { $0.toItem() }
        } catch {
            print("Failed to fetch items: \(error)")
            return []
        }
    }
    
    // MARK: - Sample Data
    
    private func createSampleData() {
        let sampleList1 = List(name: "Grocery Shopping")
        let sampleList2 = List(name: "Home Improvement")
        
        var list1 = sampleList1
        list1.addItem(Item(title: "Milk"))
        list1.addItem(Item(title: "Bread"))
        list1.addItem(Item(title: "Eggs"))
        
        var list2 = sampleList2
        list2.addItem(Item(title: "Paint"))
        list2.addItem(Item(title: "Brushes"))
        
        lists = [list1, list2]
        
        // Save sample data to Core Data
        for list in lists {
            addList(list)
        }
    }
    
    // MARK: - CloudKit Status (Delegated to Core Data Manager)
    
    func checkCloudKitStatus() async -> CKAccountStatus {
        return await coreDataManager.checkCloudKitStatus()
    }
    
    // MARK: - Data Cleanup
    
    /// Remove duplicate lists from Core Data (cleanup for CloudKit sync bug)
    /// This removes lists with duplicate IDs, keeping the most recently modified version
    func removeDuplicateLists() {
        let context = coreDataManager.viewContext
        let request: NSFetchRequest<ListEntity> = ListEntity.fetchRequest()
        
        do {
            let allLists = try context.fetch(request)
            
            // Group lists by ID
            var listsById: [UUID: [ListEntity]] = [:]
            for list in allLists {
                guard let id = list.id else { continue }
                if listsById[id] == nil {
                    listsById[id] = []
                }
                listsById[id]?.append(list)
            }
            
            // Find and remove duplicates
            var duplicatesRemoved = 0
            for (_, lists) in listsById {
                if lists.count > 1 {
                    // Sort by modifiedAt, keep most recent
                    let sorted = lists.sorted { ($0.modifiedAt ?? Date.distantPast) > ($1.modifiedAt ?? Date.distantPast) }
                    let toKeep = sorted.first!
                    let toRemove = sorted.dropFirst()
                    
                    for duplicate in toRemove {
                        // Delete items in duplicate list first
                        if let items = duplicate.items as? Set<ItemEntity> {
                            for item in items {
                                // Transfer items to the list we're keeping
                                item.list = toKeep
                            }
                        }
                        context.delete(duplicate)
                        duplicatesRemoved += 1
                    }
                }
            }
            
            if duplicatesRemoved > 0 {
                saveData()
                loadData() // Reload to reflect changes
            }
        } catch {
            print("❌ Failed to check for duplicate lists: \(error)")
        }
    }
    
    /// Remove duplicate items from Core Data (cleanup for sync bug)
    /// This removes items with duplicate IDs, keeping the most recently modified version
    func removeDuplicateItems() {
        let context = coreDataManager.viewContext
        let request: NSFetchRequest<ItemEntity> = ItemEntity.fetchRequest()
        
        do {
            let allItems = try context.fetch(request)
            
            // Group items by ID
            var itemsById: [UUID: [ItemEntity]] = [:]
            for item in allItems {
                guard let id = item.id else { continue }
                if itemsById[id] == nil {
                    itemsById[id] = []
                }
                itemsById[id]?.append(item)
            }
            
            // Find and remove duplicates
            var duplicatesRemoved = 0
            for (_, items) in itemsById {
                if items.count > 1 {
                    // Sort by modifiedAt, keep most recent
                    let sorted = items.sorted { ($0.modifiedAt ?? Date.distantPast) > ($1.modifiedAt ?? Date.distantPast) }
                    let toKeep = sorted.first!
                    let toRemove = sorted.dropFirst()
                    
                    for duplicate in toRemove {
                        context.delete(duplicate)
                        duplicatesRemoved += 1
                    }
                }
            }
            
            if duplicatesRemoved > 0 {
                saveData()
                loadData() // Reload to reflect changes
            }
        } catch {
            print("❌ Failed to check for duplicate items: \(error)")
        }
    }

    // MARK: - DataManaging Publisher Support

    /// Publisher for observing list changes (required for DataManaging protocol)
    var listsPublisher: AnyPublisher<[List], Never> {
        $lists.eraseToAnyPublisher()
    }
}

// MARK: - Protocol Conformance

/// CoreDataManager conforms to CoreDataManaging protocol
/// All required methods are already implemented in the class
extension CoreDataManager: CoreDataManaging { }

/// DataManager conforms to DataManaging protocol
/// All required methods are already implemented in the class
extension DataManager: DataManaging { }