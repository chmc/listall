import SwiftUI
import CoreData

@main
struct ListAllApp: App {
    let dataManager = DataManager.shared
    
    init() {
        // Setup deterministic data for UI tests
        setupUITestEnvironment()
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(dataManager)
        }
    }
    
    /// Configure the app for UI testing with deterministic data
    private func setupUITestEnvironment() {
        // Check if running in UI test mode
        guard UITestDataService.isUITesting else {
            return
        }
        
        print("🧪 UI Test mode detected - setting up deterministic test data")
        
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
    private func clearAllData() {
        let coreDataManager = CoreDataManager.shared
        let context = coreDataManager.viewContext
        
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
