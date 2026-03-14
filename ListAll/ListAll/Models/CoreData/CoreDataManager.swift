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
    var remoteChangeDebounceTimer: Timer?
    let remoteChangeDebounceInterval: TimeInterval = 0.5 // 500ms debounce

    // CRITICAL: Track local saves to prevent treating them as "remote" changes
    // This prevents drag-drop operations from triggering reload loops
    var isLocalSave = false

    // MARK: - CloudKit Sync Status Tracking
    /// Timestamp of last successful CloudKit sync (import or export)
    @Published var lastSyncDate: Date?

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

        // Reset local save flag to prevent previous test's save() from causing
        // the next test's remote change notification to be incorrectly ignored
        shared.isLocalSave = false

        // Reset Core Data context to clear cached objects
        shared.viewContext.reset()

        // Re-setup notifications for next test
        shared.setupRemoteChangeNotifications()

        print("🧪 CoreDataManager: Reset for testing completed")
    }
    #endif

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
}

// MARK: - Protocol Conformance

/// CoreDataManager conforms to CoreDataManaging protocol
/// All required methods are already implemented in the class
extension CoreDataManager: CoreDataManaging { }
