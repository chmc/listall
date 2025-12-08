//
//  ListAllMacApp.swift
//  ListAllMac
//
//  Created by Aleksi Sutela on 5.12.2025.
//

import SwiftUI
import CoreData

@main
struct ListAllMacApp: App {
    /// Check if running in unit test environment (not UI tests)
    private static let isUnitTesting: Bool = {
        // XCTestConfigurationFilePath is set for unit tests but we also check we're NOT in UI test mode
        ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil &&
        !ProcessInfo.processInfo.arguments.contains("UITEST_MODE")
    }()

    // Note: DataManager.shared is accessed during property initialization.
    // In unit test mode, CoreDataManager will use /dev/null store for isolation.
    @StateObject private var dataManager = DataManager.shared

    init() {
        // CRITICAL: Skip full app initialization during UNIT tests
        // Unit tests inject their own Core Data stacks and don't need the full app lifecycle
        // This prevents singleton initialization issues and memory corruption from
        // repeated test host launches
        if ListAllMacApp.isUnitTesting {
            print("🧪 ListAllMacApp: Unit test mode - skipping full app initialization")
            return
        }

        // CRITICAL: Force CoreDataManager initialization FIRST to ensure UITEST_MODE is detected
        // before any data operations. The isUITest flag is evaluated during lazy initialization.
        _ = CoreDataManager.shared.persistentContainer

        // Setup UI test environment if needed
        setupUITestEnvironment()
    }

    var body: some Scene {
        WindowGroup {
            MacMainView()
                .environmentObject(dataManager)
                .environment(\.managedObjectContext, CoreDataManager.shared.viewContext)
        }
        .commands {
            // Add macOS-specific menu commands
            AppCommands()
        }

        #if os(macOS)
        Settings {
            MacSettingsView()
                .environmentObject(dataManager)
        }
        #endif
    }

    // MARK: - UI Test Environment Setup

    /// Configure the app for UI testing with deterministic data
    private func setupUITestEnvironment() {
        // Check if running in UI test mode using UITEST_MODE (same as iOS)
        guard UITestDataService.isUITesting else {
            return
        }

        print("🧪 UI Test mode detected - UI tests using isolated database")

        // CRITICAL: AppleLanguages is already set by Fastlane's localize_simulator(true)
        // before app launch. We should NOT override it here.
        // Just log what it's set to for debugging purposes.
        if let appleLanguages = UserDefaults.standard.array(forKey: "AppleLanguages") as? [String] {
            print("🧪 AppleLanguages already set by simulator: \(appleLanguages)")
        } else {
            // Fallback: If for some reason AppleLanguages isn't set, default to English
            UserDefaults.standard.set(["en"], forKey: "AppleLanguages")
            UserDefaults.standard.synchronize()
            print("🧪 Set AppleLanguages to [en] (fallback default)")
        }

        // Disable iCloud sync during UI tests to prevent interference
        UserDefaults.standard.set(false, forKey: "iCloudSyncEnabled")

        // Clear existing data to ensure clean state
        clearAllData()

        // Only populate test data if not skipped (for empty state screenshots)
        if !ProcessInfo.processInfo.arguments.contains("SKIP_TEST_DATA") {
            populateTestData()
        } else {
            print("🧪 Skipping test data population for empty state screenshot")
        }
    }

    /// Clear all existing data from the data store
    /// SAFETY: This method verifies we're using the isolated test database before clearing
    private func clearAllData() {
        let coreDataManager = CoreDataManager.shared
        let context = coreDataManager.viewContext

        // CRITICAL SAFETY CHECK: Verify we're using the test database before clearing
        if let storeURL = coreDataManager.persistentContainer.persistentStoreDescriptions.first?.url {
            let storeFileName = storeURL.lastPathComponent
            guard storeFileName.contains("UITests") || storeURL.absoluteString.contains("/dev/null") else {
                print("🛑 SAFETY: Refusing to clear data - not using test database!")
                print("🛑 Current database: \(storeFileName)")
                fatalError("Attempted to clear production data during UI tests. Database file: \(storeFileName)")
            }
            print("✅ Safety verified: Using test database '\(storeFileName)'")
        }

        // Delete all existing lists (which will cascade delete items and images)
        let listRequest: NSFetchRequest<NSFetchRequestResult> = ListEntity.fetchRequest()
        let listDeleteRequest = NSBatchDeleteRequest(fetchRequest: listRequest)

        do {
            try context.execute(listDeleteRequest)
            try context.save()
            print("🧪 Cleared existing data for UI tests")
        } catch {
            print("❌ Failed to clear data for UI tests: \(error)")
        }
    }

    /// Populate the data store with deterministic test data
    private func populateTestData() {
        let testLists = UITestDataService.generateTestData()

        // Add each test list to the data manager
        for list in testLists {
            dataManager.addList(list)

            // Add items for each list
            for item in list.items {
                dataManager.addItem(item, to: list.id)
            }
        }

        // Force reload to ensure UI shows the test data
        dataManager.loadData()

        print("🧪 Populated \(testLists.count) test lists with deterministic data")
    }
}
