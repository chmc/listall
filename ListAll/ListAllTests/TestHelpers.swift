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

/// Test-specific Core Data Manager that uses in-memory storage
class TestCoreDataManager: ObservableObject {
    let persistentContainer: NSPersistentContainer

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
}

/// Test-specific Data Manager that uses isolated Core Data
class TestDataManager: ObservableObject {
    @Published var lists: [List] = []
    @Published var archivedLists: [List] = []
    let coreDataManager: TestCoreDataManager  // Made internal for archive test access

    init(coreDataManager: TestCoreDataManager) {
        self.coreDataManager = coreDataManager
        loadData()
    }

    func loadData() {
        // Load from Core Data
        let request: NSFetchRequest<ListEntity> = ListEntity.fetchRequest()
        request.sortDescriptors = [NSSortDescriptor(keyPath: \ListEntity.orderNumber, ascending: true)]

        do {
            let listEntities = try coreDataManager.viewContext.fetch(request)
            lists = listEntities.map { $0.toList() }
        } catch {
            print("Failed to fetch lists: \(error)")
            // Start with empty lists for tests
            lists = []
        }
    }

    func saveData() {
        coreDataManager.save()
    }

    func loadArchivedLists() -> [List] {
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

    /// Loads archived lists into the @Published archivedLists property for SwiftUI observation.
    func loadArchivedData() {
        archivedLists = loadArchivedLists()
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
        let context = coreDataManager.viewContext
        let request: NSFetchRequest<ListEntity> = ListEntity.fetchRequest()
        request.predicate = NSPredicate(format: "id == %@", list.id as CVarArg)

        do {
            let listEntities = try context.fetch(request)
            if let listEntity = listEntities.first {
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

    func deleteList(withId id: UUID) {
        let context = coreDataManager.viewContext
        let request: NSFetchRequest<ListEntity> = ListEntity.fetchRequest()
        request.predicate = NSPredicate(format: "id == %@", id as CVarArg)

        do {
            let listEntities = try context.fetch(request)
            for listEntity in listEntities {
                context.delete(listEntity)
            }

            saveData()
            // Remove from local array instead of reloading
            lists.removeAll { $0.id == id }
        } catch {
            print("Failed to delete list: \(error)")
        }
    }

    /// Mirrors CoreDataManager.synchronizeLists(_:) — sets the internal lists array
    func synchronizeLists(_ newOrder: [List]) {
        lists = newOrder
    }

    func clearAll() {
        let context = coreDataManager.viewContext

        // Delete all items
        let itemRequest: NSFetchRequest<ItemEntity> = ItemEntity.fetchRequest()
        do {
            let items = try context.fetch(itemRequest)
            for item in items {
                context.delete(item)
            }
        } catch {
            print("Failed to delete items: \(error)")
        }

        // Delete all lists
        let listRequest: NSFetchRequest<ListEntity> = ListEntity.fetchRequest()
        do {
            let lists = try context.fetch(listRequest)
            for list in lists {
                context.delete(list)
            }
        } catch {
            print("Failed to delete lists: \(error)")
        }

        saveData()
        loadData()
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

                // Re-associate with target list (item may have been orphaned)
                let listRequest: NSFetchRequest<ListEntity> = ListEntity.fetchRequest()
                listRequest.predicate = NSPredicate(format: "id == %@", listId as CVarArg)
                if let listEntity = try context.fetch(listRequest).first {
                    existingItem.list = listEntity
                }

                // Update images: First delete existing image entities
                if let existingImages = existingItem.images?.allObjects as? [ItemImageEntity] {
                    for imageEntity in existingImages {
                        context.delete(imageEntity)
                    }
                }

                // Create new image entities
                for itemImage in item.images {
                    let imageEntity = ItemImageEntity.fromItemImage(itemImage, context: context)
                    imageEntity.item = existingItem
                }

                saveData()
                loadData()
                return
            }
        } catch {
            print("Failed to check for existing item: \(error)")
        }

        // Item doesn't exist, create new one
        let itemEntity = ItemEntity(context: context)
        itemEntity.id = item.id
        itemEntity.itemDescription = item.itemDescription
        itemEntity.isCrossedOut = item.isCrossedOut
        itemEntity.orderNumber = Int32(item.orderNumber)
        itemEntity.quantity = Int32(item.quantity)
        itemEntity.title = item.title
        itemEntity.createdAt = item.createdAt
        itemEntity.modifiedAt = item.modifiedAt

        // Find the list entity
        let listRequest: NSFetchRequest<ListEntity> = ListEntity.fetchRequest()
        listRequest.predicate = NSPredicate(format: "id == %@", listId as CVarArg)

        do {
            let listEntities = try context.fetch(listRequest)
            if let listEntity = listEntities.first {
                itemEntity.list = listEntity
            }
        } catch {
            print("Failed to find list for item: \(error)")
        }

        // Create image entities from the item's images
        for itemImage in item.images {
            let imageEntity = ItemImageEntity.fromItemImage(itemImage, context: context)
            imageEntity.item = itemEntity
        }

        saveData()
        loadData()
    }

    func updateItem(_ item: Item) {
        let context = coreDataManager.viewContext
        let request: NSFetchRequest<ItemEntity> = ItemEntity.fetchRequest()
        request.predicate = NSPredicate(format: "id == %@", item.id as CVarArg)

        do {
            let itemEntities = try context.fetch(request)
            if let itemEntity = itemEntities.first {
                itemEntity.title = item.title
                itemEntity.itemDescription = item.itemDescription
                itemEntity.quantity = Int32(item.quantity)
                itemEntity.isCrossedOut = item.isCrossedOut
                itemEntity.orderNumber = Int32(item.orderNumber)
                itemEntity.modifiedAt = item.modifiedAt

                // Update images: First delete existing image entities
                if let existingImages = itemEntity.images?.allObjects as? [ItemImageEntity] {
                    for imageEntity in existingImages {
                        context.delete(imageEntity)
                    }
                }

                // Create new image entities from the item's images
                for itemImage in item.images {
                    let imageEntity = ItemImageEntity.fromItemImage(itemImage, context: context)
                    imageEntity.item = itemEntity
                }

                saveData()
                loadData()
            }
        } catch {
            print("Failed to update item: \(error)")
        }
    }

    func deleteItem(withId id: UUID, from listId: UUID) {
        let context = coreDataManager.viewContext
        let request: NSFetchRequest<ItemEntity> = ItemEntity.fetchRequest()
        request.predicate = NSPredicate(format: "id == %@", id as CVarArg)

        do {
            let itemEntities = try context.fetch(request)
            for itemEntity in itemEntities {
                context.delete(itemEntity)
            }

            saveData()
            loadData()
        } catch {
            print("Failed to delete item: \(error)")
        }
    }

    func getItems(forListId listId: UUID) -> [Item] {
        let context = coreDataManager.viewContext
        let request: NSFetchRequest<ItemEntity> = ItemEntity.fetchRequest()
        request.predicate = NSPredicate(format: "list.id == %@", listId as CVarArg)
        request.sortDescriptors = [NSSortDescriptor(keyPath: \ItemEntity.orderNumber, ascending: true)]

        do {
            let itemEntities = try context.fetch(request)
            return itemEntities.map { $0.toItem() }
        } catch {
            print("Failed to fetch items: \(error)")
            return []
        }
    }
}
