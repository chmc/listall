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
    let dataManager = DataManager.shared

    init() {
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
        // Check if running in UI test mode
        guard ProcessInfo.processInfo.arguments.contains("UI_TESTING") else {
            return
        }

        print("🧪 UI Test mode detected - setting up deterministic test data")

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
    private func clearAllData() {
        let context = CoreDataManager.shared.viewContext

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
        // Create sample test lists for macOS UI tests
        let testList1 = List(name: "Shopping List")
        var list1 = testList1
        list1.addItem(Item(title: "Milk"))
        list1.addItem(Item(title: "Bread"))
        list1.addItem(Item(title: "Eggs"))

        let testList2 = List(name: "Tasks")
        var list2 = testList2
        list2.addItem(Item(title: "Review documents"))
        list2.addItem(Item(title: "Send email"))

        // Add lists using DataManager
        dataManager.addList(list1)
        for item in list1.items {
            dataManager.addItem(item, to: list1.id)
        }

        dataManager.addList(list2)
        for item in list2.items {
            dataManager.addItem(item, to: list2.id)
        }

        // Force reload to ensure UI shows the test data
        dataManager.loadData()

        print("🧪 Populated 2 test lists with deterministic data")
    }
}
