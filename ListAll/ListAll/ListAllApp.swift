import SwiftUI
import UIKit
import CoreData

@main
struct ListAllApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    let dataManager = DataManager.shared

    init() {
        // CRITICAL: Force CoreDataManager initialization FIRST to ensure UITEST_MODE is detected
        // before any data operations. The isUITest flag is evaluated during lazy initialization.
        _ = CoreDataManager.shared.persistentContainer

        // Setup deterministic data for UI tests
        setupUITestEnvironment()
    }
    
    var body: some Scene {
        WindowGroup {
            // Root content view. Force light mode during UI tests when requested.
            let forceLight = ProcessInfo.processInfo.arguments.contains("FORCE_LIGHT_MODE")
            ContentView()
                .environmentObject(dataManager)
                .preferredColorScheme(forceLight ? .light : nil)
        }
    }
    
    /// Configure the app for UI testing with deterministic data
    private func setupUITestEnvironment() {
        // Check if running in UI test mode
        guard UITestDataService.isUITesting else {
            return
        }

        print("🧪 UI Test mode detected - setting up deterministic test data")
        print("🧪 CoreDataManager will use ISOLATED database (ListAll-UITests.sqlite) - production data is safe")

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

        // Disable tooltips if requested (for clean screenshots)
        if ProcessInfo.processInfo.arguments.contains("DISABLE_TOOLTIPS") {
            print("🧪 Disabling feature tips for UI tests")
            // Mark all tooltips as already shown so they won't appear
            let allTooltipKeys = [
                "tooltip_add_list",
                "tooltip_item_suggestions",
                "tooltip_search",
                "tooltip_sort_filter",
                "tooltip_swipe_actions",
                "tooltip_archive"
            ]
            UserDefaults.standard.set(allTooltipKeys, forKey: "shownTooltips")
        }

        // Clear existing data to ensure clean state
        // NOTE: This only clears the UI test database (ListAll-UITests.sqlite), not production data
        // CoreDataManager automatically uses a separate database file when UITEST_MODE is detected
        clearAllData()
        
        // Only populate test data if not skipped (for empty state screenshots)
        if !ProcessInfo.processInfo.arguments.contains("SKIP_TEST_DATA") {
            // Populate with deterministic test data
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

// MARK: - AppDelegate for test-time orientation control
final class AppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication, supportedInterfaceOrientationsFor window: UIWindow?) -> UIInterfaceOrientationMask {
        // During UI tests, lock to portrait to make screenshots consistent across devices
        let env = ProcessInfo.processInfo.environment
        if UITestDataService.isUITesting || env["UITEST_FORCE_PORTRAIT"] == "1" {
            return .portrait
        }

        // Normal app behavior (support all orientations as configured by Info.plist)
        #if targetEnvironment(macCatalyst)
        return .all
        #else
        return .all
        #endif
    }
}
