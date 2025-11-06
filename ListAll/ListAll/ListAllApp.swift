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
        
        // Clear existing data to ensure clean state
        clearAllData()
        
        // Populate with deterministic test data
        populateTestData()
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
