import Foundation
import CoreData
@testable import ListAll


/// Test helper for setting up isolated test environments
class TestHelpers {

    /// Creates an in-memory Core Data stack for testing
    static func createInMemoryCoreDataStack() -> NSPersistentContainer {
        let container = NSPersistentContainer(name: "ListAll")

        // Configure for in-memory storage
        let description = NSPersistentStoreDescription()
        description.type = NSInMemoryStoreType
        description.url = URL(fileURLWithPath: "/dev/null")
        container.persistentStoreDescriptions = [description]

        container.loadPersistentStores { _, error in
            if let error = error {
                fatalError("Failed to load in-memory store: \(error)")
            }
        }

        // Configure view context
        container.viewContext.automaticallyMergesChangesFromParent = true
        container.viewContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy

        return container
    }

    /// Creates a test DataManager with isolated Core Data
    static func createTestDataManager() -> TestDataManager {
        let coreDataStack = createInMemoryCoreDataStack()
        let testCoreDataManager = TestCoreDataManager(container: coreDataStack)
        return TestDataManager(coreDataManager: testCoreDataManager)
    }

    /// Creates an isolated test environment for MainViewModel
    static func createTestMainViewModel() -> TestMainViewModel {
        let testDataManager = createTestDataManager()
        return TestMainViewModel(dataManager: testDataManager)
    }

    /// Creates an isolated test environment for ItemViewModel
    static func createTestItemViewModel(with item: Item) -> TestItemViewModel {
        let testDataManager = createTestDataManager()
        return TestItemViewModel(item: item, dataManager: testDataManager)
    }

    /// Creates an isolated test environment for ListViewModel
    static func createTestListViewModel(with list: List) -> TestListViewModel {
        let testDataManager = createTestDataManager()
        return TestListViewModel(list: list, dataManager: testDataManager)
    }

    /// Resets UserDefaults for test isolation
    static func resetUserDefaults() {
        // Clear UserDefaults keys that might affect tests
        UserDefaults.standard.removeObject(forKey: "saved_lists")

        // Clear any other UserDefaults keys used by the app
        let keys = ["showCrossedOutItems", "exportFormat", "lastSyncDate"]
        for key in keys {
            UserDefaults.standard.removeObject(forKey: key)
        }
    }

    /// WARNING: This method is deprecated and should not be used
    /// Use createTestMainViewModel() instead for proper test isolation
    @available(*, deprecated, message: "Use createTestMainViewModel() for proper test isolation")
    static func resetSharedSingletons() {
        resetUserDefaults()

        // Note: Resetting shared singletons doesn't provide proper test isolation
        // because Core Data contexts are still shared. Use isolated test instances instead.
        DataManager.shared.lists = []
    }

    // MARK: - Sync Simulation Helpers

    /// Simulates the sync logic from MainViewModel.updateCoreDataWithLists
    /// Reference: MainViewModel.swift lines 175-244
    /// Use this to test sync behavior without requiring App Groups entitlements
    static func simulateSyncFromWatch(receivedLists: [List], dataManager: TestDataManager) {
        for receivedList in receivedLists {
            let existingList = dataManager.lists.first(where: { $0.id == receivedList.id })

            if let existingList = existingList {
                // Update list if received version is STRICTLY newer
                if receivedList.modifiedAt > existingList.modifiedAt {
                    dataManager.updateList(receivedList)
                }
                // CRITICAL: Always sync items regardless of list modifiedAt (this is the bug fix!)
                syncItemsForList(receivedList, existingList: existingList, dataManager: dataManager)
            } else {
                // Add new list
                dataManager.addList(receivedList)
                for item in receivedList.items {
                    dataManager.addItem(item, to: receivedList.id)
                }
            }
        }

        // CRITICAL: Remove lists not in received data (production behavior)
        // This handles the case where a list was deleted on the Watch
        if !receivedLists.isEmpty {
            let receivedListIds = Set(receivedLists.map { $0.id })
            let localActiveListIds = Set(dataManager.lists.filter { !$0.isArchived }.map { $0.id })
            for listIdToRemove in localActiveListIds.subtracting(receivedListIds) {
                dataManager.deleteList(withId: listIdToRemove)
            }
        }

        dataManager.loadData()
    }

    private static func syncItemsForList(_ receivedList: List, existingList: List, dataManager: TestDataManager) {
        let receivedItemIds = Set(receivedList.items.map { $0.id })
        let existingItemIds = Set(existingList.items.map { $0.id })

        for receivedItem in receivedList.items {
            if existingItemIds.contains(receivedItem.id) {
                // Update existing item if newer
                if let existingItem = existingList.items.first(where: { $0.id == receivedItem.id }),
                   receivedItem.modifiedAt > existingItem.modifiedAt {
                    dataManager.updateItem(receivedItem)
                }
            } else {
                // Add new item
                dataManager.addItem(receivedItem, to: receivedList.id)
            }
        }

        // Remove deleted items
        for itemIdToRemove in existingItemIds.subtracting(receivedItemIds) {
            dataManager.deleteItem(withId: itemIdToRemove, from: receivedList.id)
        }
    }
}
