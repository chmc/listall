//
//  TestHelpers.swift
//  ListAllMacTests
//
//  Created for ListAllMac macOS unit tests.
//

import Foundation
import CoreData
import Combine
import SwiftUI
import CloudKit
#if os(macOS)
import AppKit
#endif
@testable import ListAll

// Resolve ambiguity between SwiftUI.List and ListAll.List
typealias ListModel = ListAll.List

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
    static func createTestListViewModel(with list: ListModel) -> TestListViewModel {
        let testDataManager = createTestDataManager()
        return TestListViewModel(list: list, dataManager: testDataManager)
    }

    /// Creates an isolated test environment for ExportViewModel
    /// CRITICAL: Never instantiate ExportViewModel() directly in tests!
    /// Direct instantiation triggers App Groups access on unsigned builds, causing crashes.
    static func createTestExportViewModel() -> ExportViewModel {
        let testDataManager = createTestDataManager()
        let testDataRepository = TestDataRepository(dataManager: testDataManager)
        let testExportService = ExportService(dataRepository: testDataRepository)
        return ExportViewModel(exportService: testExportService)
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

    // MARK: - Unsigned Build Detection

    /// Returns true if the test build is unsigned (would trigger App Groups permission dialogs)
    /// Use this to skip tests that require signed entitlements
    static var isUnsignedTestBuild: Bool {
        // Check if code signing is valid
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/codesign")
        task.arguments = ["-v", "--deep", Bundle.main.bundlePath]

        let pipe = Pipe()
        task.standardError = pipe
        task.standardOutput = pipe

        do {
            try task.run()
            task.waitUntilExit()
            return task.terminationStatus != 0
        } catch {
            // If we can't check, assume unsigned
            return true
        }
    }

    /// Skip test if running on unsigned build (would trigger permission dialog)
    /// Returns true if test should be skipped
    static func shouldSkipAppGroupsTest() -> Bool {
        if isUnsignedTestBuild {
            print("⚠️ Skipping test: unsigned build would trigger App Groups permission dialog")
            return true
        }
        return false
    }

    #if os(macOS)
    /// macOS-specific helper to create test images
    static func createTestImage(size: CGSize = CGSize(width: 100, height: 100), color: NSColor = .blue) -> NSImage {
        let image = NSImage(size: size)
        image.lockFocus()
        color.drawSwatch(in: NSRect(origin: .zero, size: size))
        image.unlockFocus()
        return image
    }

    /// macOS-specific helper to convert NSImage to Data
    static func imageToData(_ image: NSImage) -> Data? {
        guard let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            return nil
        }
        let bitmapRep = NSBitmapImageRep(cgImage: cgImage)
        return bitmapRep.representation(using: .png, properties: [:])
    }
    #endif
}

/// Test-specific Core Data Manager that uses in-memory storage
/// Conforms to CoreDataManaging protocol for dependency injection
class TestCoreDataManager: ObservableObject, CoreDataManaging {
    let persistentContainer: NSPersistentContainer

    /// Timestamp of the last sync (always nil for test implementations)
    var lastSyncDate: Date? = nil

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

    func saveContext(_ context: NSManagedObjectContext) {
        if context.hasChanges {
            do {
                try context.save()
            } catch {
                print("Failed to save test context: \(error)")
            }
        }
    }

    func forceRefresh() {
        // No-op for tests - no CloudKit to refresh from
    }

    func triggerCloudKitSync() {
        // No-op for tests - no CloudKit
    }

    func checkCloudKitStatus() async -> CKAccountStatus {
        // Always return available for tests
        return .available
    }

    func setupRemoteChangeNotifications() {
        // No-op for tests
    }

    func migrateDataIfNeeded() {
        // No-op for tests
    }
}

/// Test-specific Data Manager that uses isolated Core Data
/// Conforms to DataManaging protocol for dependency injection
class TestDataManager: ObservableObject, DataManaging {
    @Published var lists: [ListModel] = []
    let coreDataManager: TestCoreDataManager  // Made internal for archive test access

    /// Publisher for observing list changes
    var listsPublisher: AnyPublisher<[ListModel], Never> {
        $lists.eraseToAnyPublisher()
    }

    init(coreDataManager: TestCoreDataManager) {
        self.coreDataManager = coreDataManager
        loadData()
    }

    func loadData() {
        // Load from Core Data, excluding archived lists
        let request: NSFetchRequest<ListEntity> = ListEntity.fetchRequest()
        request.predicate = NSPredicate(format: "isArchived == NO OR isArchived == nil")
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

    func getLists() -> [ListModel] {
        let request: NSFetchRequest<ListEntity> = ListEntity.fetchRequest()
        request.predicate = NSPredicate(format: "isArchived == NO OR isArchived == nil")
        request.sortDescriptors = [NSSortDescriptor(keyPath: \ListEntity.orderNumber, ascending: true)]

        do {
            let listEntities = try coreDataManager.viewContext.fetch(request)
            return listEntities.map { $0.toList() }
        } catch {
            print("Failed to fetch lists: \(error)")
            return []
        }
    }

    func saveData() {
        coreDataManager.save()
    }

    // MARK: - ListModel Operations

    func addList(_ list: ListModel) {
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

    func updateList(_ list: ListModel) {
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

    // MARK: - DataManaging Protocol Methods

    func updateListsOrder(_ newOrder: [ListModel]) {
        let context = coreDataManager.viewContext
        let request: NSFetchRequest<ListEntity> = ListEntity.fetchRequest()
        let listIds = newOrder.map { $0.id }
        request.predicate = NSPredicate(format: "id IN %@", listIds)

        do {
            let allEntities = try context.fetch(request)
            var entityById: [UUID: ListEntity] = [:]
            for entity in allEntities {
                if let id = entity.id {
                    entityById[id] = entity
                }
            }

            for list in newOrder {
                if let entity = entityById[list.id] {
                    entity.orderNumber = Int32(list.orderNumber)
                    entity.modifiedAt = list.modifiedAt
                }
            }
        } catch {
            print("Failed to batch update list order: \(error)")
        }

        saveData()
    }

    func synchronizeLists(_ newOrder: [ListModel]) {
        lists = newOrder
    }

    func loadArchivedLists() -> [ListModel] {
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
        let request: NSFetchRequest<ListEntity> = ListEntity.fetchRequest()
        request.predicate = NSPredicate(format: "id == %@", id as CVarArg)

        do {
            let results = try coreDataManager.viewContext.fetch(request)
            if let listEntity = results.first {
                listEntity.isArchived = false
                listEntity.modifiedAt = Date()
                saveData()
                loadData()
            }
        } catch {
            print("Failed to restore list: \(error)")
        }
    }

    func permanentlyDeleteList(withId id: UUID) {
        let listRequest: NSFetchRequest<ListEntity> = ListEntity.fetchRequest()
        listRequest.predicate = NSPredicate(format: "id == %@", id as CVarArg)

        do {
            let results = try coreDataManager.viewContext.fetch(listRequest)
            if let listEntity = results.first {
                // Delete all items in the list first
                if let items = listEntity.items as? Set<ItemEntity> {
                    for itemEntity in items {
                        if let images = itemEntity.images as? Set<ItemImageEntity> {
                            for imageEntity in images {
                                coreDataManager.viewContext.delete(imageEntity)
                            }
                        }
                        coreDataManager.viewContext.delete(itemEntity)
                    }
                }
                coreDataManager.viewContext.delete(listEntity)
                saveData()
            }
        } catch {
            print("Failed to permanently delete list: \(error)")
        }
    }

    func checkCloudKitStatus() async -> CKAccountStatus {
        // Always return available for tests
        return .available
    }

    func removeDuplicateLists() {
        // No-op for tests - no CloudKit sync duplicates
    }

    func removeDuplicateItems() {
        // No-op for tests - no CloudKit sync duplicates
    }
}

/// Test-specific ItemViewModel that uses isolated DataManager
class TestItemViewModel: ObservableObject {
    @Published var item: Item
    @Published var isLoading = false
    @Published var errorMessage: String?

    private let dataManager: TestDataManager
    private let dataRepository: TestDataRepository

    init(item: Item, dataManager: TestDataManager) {
        self.item = item
        self.dataManager = dataManager
        self.dataRepository = TestDataRepository(dataManager: dataManager)
    }

    func save() {
        dataManager.updateItem(item)
    }

    func toggleCrossedOut() {
        var updatedItem = item
        updatedItem.toggleCrossedOut()
        dataManager.updateItem(updatedItem)
        self.item = updatedItem
    }

    func updateItem(title: String, description: String, quantity: Int) {
        var updatedItem = item
        updatedItem.title = title
        updatedItem.itemDescription = description.isEmpty ? nil : description
        updatedItem.quantity = quantity
        updatedItem.updateModifiedDate()
        dataManager.updateItem(updatedItem)
        self.item = updatedItem
    }

    func duplicateItem(in list: ListModel) -> Item? {
        guard item.listId != nil else { return nil }

        let duplicatedItem = dataRepository.createItem(
            in: list,
            title: "\(item.title) (Copy)",
            description: item.itemDescription ?? "",
            quantity: item.quantity
        )

        return duplicatedItem
    }

    func deleteItem() {
        dataRepository.deleteItem(item)
    }

    func validateItem() -> ValidationResult {
        return dataRepository.validateItem(item)
    }

    func refreshItem() {
        if let refreshedItem = dataRepository.getItem(by: item.id) {
            self.item = refreshedItem
        }
    }
}

/// Test-specific ListViewModel that uses isolated DataManager
class TestListViewModel: ObservableObject {
    @Published var items: [Item] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var showCrossedOutItems = true

    // Item Organization Properties
    @Published var currentSortOption: ItemSortOption = .orderNumber
    @Published var currentSortDirection: SortDirection = .ascending
    @Published var currentFilterOption: ItemFilterOption = .active

    // Search Properties
    @Published var searchText: String = ""

    // Undo Complete Properties
    @Published var recentlyCompletedItem: Item?
    @Published var showUndoButton = false

    // Undo Delete Properties (Single Item)
    @Published var recentlyDeletedItem: Item?
    @Published var showDeleteUndoButton = false

    // Undo Bulk Delete Properties (Multiple Items)
    @Published var recentlyDeletedItems: [Item]?
    @Published var showBulkDeleteUndoBanner = false

    // Multi-Selection Properties
    @Published var isInSelectionMode = false
    @Published var selectedItems: Set<UUID> = []
    @Published var lastSelectedItemID: UUID?  // Anchor point for Shift+Click range selection

    private let dataManager: TestDataManager
    private let dataRepository: TestDataRepository
    private let list: ListModel
    private var undoTimer: Timer?
    private var deleteUndoTimer: Timer?
    private var bulkDeleteUndoTimer: Timer?
    private let undoTimeout: TimeInterval = 5.0 // 5 seconds standard timeout
    private let bulkDeleteUndoTimeout: TimeInterval = 10.0 // 10 seconds for bulk delete

    init(list: ListModel, dataManager: TestDataManager) {
        self.list = list
        self.dataManager = dataManager
        self.dataRepository = TestDataRepository(dataManager: dataManager)
        loadItems()
    }

    deinit {
        undoTimer?.invalidate()
        deleteUndoTimer?.invalidate()
        bulkDeleteUndoTimer?.invalidate()
    }

    func loadItems() {
        isLoading = true
        errorMessage = nil

        items = dataManager.getItems(forListId: list.id)

        isLoading = false
    }

    func save() {
        for item in items {
            dataManager.updateItem(item)
        }
    }

    func createItem(title: String, description: String = "", quantity: Int = 1) {
        let _ = dataRepository.createItem(in: list, title: title, description: description, quantity: quantity)
        loadItems()
    }

    func deleteItem(_ item: Item) {
        // Store the item before deleting for undo functionality
        showDeleteUndoForItem(item)

        dataRepository.deleteItem(item)
        loadItems()
    }

    func duplicateItem(_ item: Item) {
        let _ = dataRepository.createItem(
            in: list,
            title: "\(item.title) (Copy)",
            description: item.itemDescription ?? "",
            quantity: item.quantity
        )
        loadItems()
    }

    func toggleItemCrossedOut(_ item: Item) {
        // Check if item is being completed (not already crossed out)
        let wasCompleted = item.isCrossedOut
        let itemId = item.id

        dataRepository.toggleItemCrossedOut(item)
        loadItems()

        // Show undo button only when completing an item (not when uncompleting)
        if !wasCompleted, let refreshedItem = items.first(where: { $0.id == itemId }) {
            showUndoForCompletedItem(refreshedItem)
        }
    }

    // MARK: - Undo Complete Functionality

    private func showUndoForCompletedItem(_ item: Item) {
        // Cancel any existing timer
        undoTimer?.invalidate()

        // Store the completed item
        recentlyCompletedItem = item
        showUndoButton = true

        // Set up timer to hide undo button after timeout
        undoTimer = Timer.scheduledTimer(withTimeInterval: undoTimeout, repeats: false) { [weak self] _ in
            self?.hideUndoButton()
        }
    }

    func undoComplete() {
        guard let item = recentlyCompletedItem else { return }

        // Directly toggle the item back to incomplete without triggering undo logic
        dataRepository.toggleItemCrossedOut(item)

        // Hide undo button immediately BEFORE loading items
        hideUndoButton()

        loadItems() // Refresh the list
    }

    func hideUndoButton() {
        undoTimer?.invalidate()
        undoTimer = nil
        showUndoButton = false
        recentlyCompletedItem = nil
    }

    // MARK: - Undo Delete Functionality

    private func showDeleteUndoForItem(_ item: Item) {
        // Cancel any existing timer
        deleteUndoTimer?.invalidate()

        // Store the deleted item
        recentlyDeletedItem = item
        showDeleteUndoButton = true

        // Set up timer to hide undo button after timeout
        deleteUndoTimer = Timer.scheduledTimer(withTimeInterval: undoTimeout, repeats: false) { [weak self] _ in
            self?.hideDeleteUndoButton()
        }
    }

    func undoDeleteItem() {
        guard let item = recentlyDeletedItem else { return }

        // Re-create the item with all its properties using addItemForImport
        // which preserves all item state including isCrossedOut and orderNumber
        dataRepository.addItemForImport(item, to: list.id)

        // Hide undo button immediately BEFORE loading items
        hideDeleteUndoButton()

        loadItems() // Refresh the list
    }

    func hideDeleteUndoButton() {
        deleteUndoTimer?.invalidate()
        deleteUndoTimer = nil
        showDeleteUndoButton = false
        recentlyDeletedItem = nil
    }

    // MARK: - Undo Bulk Delete Functionality (Task 12.8)

    /// Computed property to get the count of recently deleted items for display
    var deletedItemsCount: Int {
        return recentlyDeletedItems?.count ?? 0
    }

    /// Deletes selected items with undo support.
    /// Instead of showing a confirmation dialog, this method stores items for undo
    /// and shows an undo banner for 10 seconds (per macOS convention).
    func deleteSelectedItemsWithUndo() {
        // Guard against empty selection
        guard !selectedItems.isEmpty else { return }

        // Cancel any existing bulk delete undo timer
        bulkDeleteUndoTimer?.invalidate()

        // Store the items before deleting for undo functionality
        let itemsToDelete = items.filter { selectedItems.contains($0.id) }
        recentlyDeletedItems = itemsToDelete

        // Delete each selected item
        for itemId in selectedItems {
            if let item = items.first(where: { $0.id == itemId }) {
                dataRepository.deleteItem(item)
            }
        }

        // Clear selection and exit selection mode
        selectedItems.removeAll()
        exitSelectionMode()

        // Show undo banner
        showBulkDeleteUndoBanner = true

        // Set up timer to hide undo banner after timeout (10 seconds for bulk delete)
        bulkDeleteUndoTimer = Timer.scheduledTimer(withTimeInterval: bulkDeleteUndoTimeout, repeats: false) { [weak self] _ in
            self?.hideBulkDeleteUndoBanner()
        }

        loadItems() // Refresh the list
    }

    /// Restores all items that were bulk deleted
    func undoBulkDelete() {
        guard let deletedItems = recentlyDeletedItems else { return }

        // Re-create each item with all its properties
        for item in deletedItems {
            dataRepository.addItemForImport(item, to: list.id)
        }

        // Hide undo banner immediately BEFORE loading items
        hideBulkDeleteUndoBanner()

        loadItems() // Refresh the list
    }

    /// Hides the bulk delete undo banner and clears the stored items
    func hideBulkDeleteUndoBanner() {
        bulkDeleteUndoTimer?.invalidate()
        bulkDeleteUndoTimer = nil
        showBulkDeleteUndoBanner = false
        recentlyDeletedItems = nil
    }

    func updateItem(_ item: Item, title: String, description: String, quantity: Int) {
        dataRepository.updateItem(item, title: title, description: description, quantity: quantity)
        loadItems()
    }

    func reorderItems(from sourceIndex: Int, to destinationIndex: Int) {
        dataRepository.reorderItems(in: list, from: sourceIndex, to: destinationIndex)
        loadItems()
    }

    func moveItems(from source: IndexSet, to destination: Int) {
        // Handle the SwiftUI ListModel onMove callback
        // IMPORTANT: source and destination are indices in filteredItems,
        // but we need to map them to indices in the full items array

        guard let filteredSourceIndex = source.first else { return }

        // Get the actual items from filteredItems
        let movedItem = filteredItems[filteredSourceIndex]

        // Calculate destination in filtered array
        let filteredDestIndex = destination > filteredSourceIndex ? destination - 1 : destination
        let destinationItem = filteredDestIndex < filteredItems.count ? filteredItems[filteredDestIndex] : filteredItems.last

        // Find the actual indices in the full items array
        guard let actualSourceIndex = items.firstIndex(where: { $0.id == movedItem.id }) else { return }

        // For destination, we need to find where to insert relative to the destination item
        let actualDestIndex: Int
        if let destItem = destinationItem,
           let destIndex = items.firstIndex(where: { $0.id == destItem.id }) {
            actualDestIndex = destIndex
        } else {
            // If no destination item (moving to end), use the last index
            actualDestIndex = items.count - 1
        }

        reorderItems(from: actualSourceIndex, to: actualDestIndex)
    }

    func refreshItems() {
        loadItems()
    }

    var sortedItems: [Item] {
        return items.sorted { $0.orderNumber < $1.orderNumber }
    }

    var activeItems: [Item] {
        return items.filter { !$0.isCrossedOut }
    }

    var completedItems: [Item] {
        return items.filter { $0.isCrossedOut }
    }

    /// Returns filtered and sorted items based on current organization settings and search text
    var filteredItems: [Item] {
        // First apply filtering
        let filtered = applyFilter(to: items)

        // Then apply search filtering
        let searchFiltered = applySearch(to: filtered)

        // Finally apply sorting
        return applySorting(to: searchFiltered)
    }

    // MARK: - Item Organization Methods

    private func applySearch(to items: [Item]) -> [Item] {
        // If search text is empty, return all items
        guard !searchText.isEmpty else {
            return items
        }

        // Filter items based on search text
        // Search in title and description
        return items.filter { item in
            let titleMatch = item.title.localizedCaseInsensitiveContains(searchText)
            let descriptionMatch = (item.itemDescription ?? "").localizedCaseInsensitiveContains(searchText)
            return titleMatch || descriptionMatch
        }
    }

    private func applyFilter(to items: [Item]) -> [Item] {
        switch currentFilterOption {
        case .all:
            // Respect the showCrossedOutItems setting for the "all" filter
            if showCrossedOutItems {
                return items
            } else {
                return items.filter { !$0.isCrossedOut }
            }
        case .active:
            // For backward compatibility: if showCrossedOutItems is explicitly true, show all items
            if showCrossedOutItems && currentFilterOption == .active {
                return items
            }
            return items.filter { !$0.isCrossedOut }
        case .completed:
            return items.filter { $0.isCrossedOut }
        case .hasDescription:
            return items.filter { $0.hasDescription }
        case .hasImages:
            return items.filter { $0.hasImages }
        }
    }

    private func applySorting(to items: [Item]) -> [Item] {
        let sorted = items.sorted { item1, item2 in
            switch currentSortOption {
            case .orderNumber:
                return item1.orderNumber < item2.orderNumber
            case .title:
                return item1.title.localizedCaseInsensitiveCompare(item2.title) == .orderedAscending
            case .createdAt:
                return item1.createdAt < item2.createdAt
            case .modifiedAt:
                return item1.modifiedAt < item2.modifiedAt
            case .quantity:
                return item1.quantity < item2.quantity
            }
        }

        return currentSortDirection == .ascending ? sorted : sorted.reversed()
    }

    func toggleShowCrossedOutItems() {
        showCrossedOutItems.toggle()

        // Synchronize the filter option with the eye button state
        if showCrossedOutItems {
            currentFilterOption = .all
        } else {
            currentFilterOption = .active
        }
    }

    func updateSortOption(_ sortOption: ItemSortOption) {
        currentSortOption = sortOption
    }

    func updateSortDirection(_ direction: SortDirection) {
        currentSortDirection = direction
    }

    func updateFilterOption(_ filterOption: ItemFilterOption) {
        currentFilterOption = filterOption
        // Update the legacy showCrossedOutItems based on filter
        if filterOption == .completed {
            showCrossedOutItems = true
        } else if filterOption == .active {
            showCrossedOutItems = false
        } else if filterOption == .all {
            showCrossedOutItems = true
        }
    }

    // MARK: - Multi-Selection Methods

    /// Toggle selection for a single item (Cmd+Click behavior)
    /// Updates lastSelectedItemID to serve as anchor for range selection
    func toggleSelection(for itemId: UUID) {
        if selectedItems.contains(itemId) {
            selectedItems.remove(itemId)
            // Don't update anchor on deselection
        } else {
            selectedItems.insert(itemId)
            lastSelectedItemID = itemId  // Update anchor point
        }
    }

    /// Select a range of items from lastSelectedItemID to targetId (Shift+Click behavior)
    /// Uses filteredItems order for range calculation
    func selectRange(to targetId: UUID) {
        guard let anchorId = lastSelectedItemID,
              let anchorIndex = filteredItems.firstIndex(where: { $0.id == anchorId }),
              let targetIndex = filteredItems.firstIndex(where: { $0.id == targetId }) else {
            // No anchor point - treat as single selection
            selectedItems = [targetId]
            lastSelectedItemID = targetId
            return
        }

        // Calculate range bounds (handles both upward and downward selection)
        let startIndex = min(anchorIndex, targetIndex)
        let endIndex = max(anchorIndex, targetIndex)

        // Select all items in the range
        selectedItems = Set(filteredItems[startIndex...endIndex].map { $0.id })

        // Keep anchor unchanged for subsequent Shift+Clicks
    }

    /// Handle click with optional modifiers (for macOS Cmd+Click and Shift+Click)
    /// - Parameters:
    ///   - itemId: The clicked item's ID
    ///   - commandKey: Whether Command key was held
    ///   - shiftKey: Whether Shift key was held
    func handleClick(for itemId: UUID, commandKey: Bool, shiftKey: Bool) {
        if commandKey {
            // Cmd+Click: Toggle this item's selection without affecting others
            toggleSelection(for: itemId)
        } else if shiftKey {
            // Shift+Click: Select range from anchor to clicked item
            selectRange(to: itemId)
        } else {
            // Regular click: Clear selection, select only this item
            selectedItems = [itemId]
            lastSelectedItemID = itemId
        }
    }

    func selectAll() {
        selectedItems = Set(filteredItems.map { $0.id })
    }

    func deselectAll() {
        selectedItems.removeAll()
    }

    func deleteSelectedItems() {
        for itemId in selectedItems {
            if let item = items.first(where: { $0.id == itemId }) {
                dataRepository.deleteItem(item)
            }
        }
        selectedItems.removeAll()
        loadItems()
    }

    func moveSelectedItems(to destinationList: ListModel) {
        // Get selected items
        let itemsToMove = items.filter { selectedItems.contains($0.id) }

        // Move each item to destination list
        for item in itemsToMove {
            dataRepository.moveItem(item, to: destinationList)
        }

        selectedItems.removeAll()
        loadItems()
    }

    func copySelectedItems(to destinationList: ListModel) {
        // Get selected items
        let itemsToCopy = items.filter { selectedItems.contains($0.id) }

        // Copy each item to destination list
        for item in itemsToCopy {
            dataRepository.copyItem(item, to: destinationList)
        }

        selectedItems.removeAll()
        loadItems()
    }

    func enterSelectionMode() {
        isInSelectionMode = true
        selectedItems.removeAll()
    }

    func exitSelectionMode() {
        isInSelectionMode = false
        selectedItems.removeAll()
        lastSelectedItemID = nil
    }
}

/// Test-specific DataRepository that uses isolated DataManager
class TestDataRepository: DataRepository {
    let dataManager: TestDataManager  // Made internal for ImportService access

    override init() {
        // This should not be used - use init(dataManager:) instead
        fatalError("Use init(dataManager:) for test instances")
    }

    init(dataManager: TestDataManager) {
        self.dataManager = dataManager
        super.init()
    }

    override func getAllLists() -> [ListModel] {
        return dataManager.lists
    }

    override func createList(name: String) -> ListModel {
        let newList = ListAll.List(name: name)
        dataManager.addList(newList)
        return newList
    }

    override func updateList(_ list: ListModel, name: String) {
        var updatedList = list
        updatedList.name = name
        updatedList.updateModifiedDate()
        dataManager.updateList(updatedList)
    }

    override func deleteList(_ list: ListModel) {
        dataManager.deleteList(withId: list.id)
    }

    override func getList(by id: UUID) -> ListModel? {
        return dataManager.lists.first { $0.id == id }
    }

    override func createItem(in list: ListModel, title: String, description: String = "", quantity: Int = 1) -> Item {
        var newItem = Item(title: title)
        newItem.itemDescription = description.isEmpty ? nil : description
        newItem.quantity = quantity
        newItem.listId = list.id

        // Set order number based on existing items count
        let existingItems = dataManager.getItems(forListId: list.id)
        newItem.orderNumber = existingItems.count

        dataManager.addItem(newItem, to: list.id)
        return newItem
    }

    override func deleteItem(_ item: Item) {
        if let listId = item.listId {
            dataManager.deleteItem(withId: item.id, from: listId)
        }
    }

    override func updateItem(_ item: Item, title: String, description: String, quantity: Int) {
        var updatedItem = item
        updatedItem.title = title
        updatedItem.itemDescription = description.isEmpty ? nil : description
        updatedItem.quantity = quantity
        updatedItem.updateModifiedDate()
        dataManager.updateItem(updatedItem)
    }

    override func updateItem(_ item: Item) {
        dataManager.updateItem(item)
    }

    override func toggleItemCrossedOut(_ item: Item) {
        var updatedItem = item
        updatedItem.toggleCrossedOut()
        dataManager.updateItem(updatedItem)
    }

    override func getItem(by id: UUID) -> Item? {
        for list in dataManager.lists {
            if let item = list.items.first(where: { $0.id == id }) {
                return item
            }
        }
        return nil
    }

    override func reorderItems(in list: ListModel, from sourceIndex: Int, to destinationIndex: Int) {
        // Get current items for this list
        let currentItems = dataManager.getItems(forListId: list.id)

        // Ensure indices are valid
        guard sourceIndex >= 0,
              destinationIndex >= 0,
              sourceIndex < currentItems.count,
              destinationIndex < currentItems.count,
              sourceIndex != destinationIndex else {
            return
        }

        // Create a mutable copy and reorder
        var reorderedItems = currentItems
        let movedItem = reorderedItems.remove(at: sourceIndex)
        reorderedItems.insert(movedItem, at: destinationIndex)

        // Update order numbers and save each item
        for (index, var item) in reorderedItems.enumerated() {
            item.orderNumber = index
            item.updateModifiedDate()
            dataManager.updateItem(item)
        }
    }

    override func moveItem(_ item: Item, to destinationList: ListModel) {
        // Delete from current list
        if let currentListId = item.listId {
            dataManager.deleteItem(withId: item.id, from: currentListId)
        }

        // Add to destination list
        var movedItem = item
        movedItem.listId = destinationList.id
        movedItem.updateModifiedDate()

        // Get the highest order number in destination list and add 1
        let destinationItems = dataManager.getItems(forListId: destinationList.id)
        let maxOrderNumber = destinationItems.map { $0.orderNumber }.max() ?? -1
        movedItem.orderNumber = maxOrderNumber + 1

        dataManager.addItem(movedItem, to: destinationList.id)
    }

    override func copyItem(_ item: Item, to destinationList: ListModel) {
        // Create a copy with new ID
        var copiedItem = item
        copiedItem.id = UUID()
        copiedItem.listId = destinationList.id
        copiedItem.createdAt = Date()
        copiedItem.modifiedAt = Date()

        // Get the highest order number in destination list and add 1
        let destinationItems = dataManager.getItems(forListId: destinationList.id)
        let maxOrderNumber = destinationItems.map { $0.orderNumber }.max() ?? -1
        copiedItem.orderNumber = maxOrderNumber + 1

        // Copy images with new IDs
        copiedItem.images = item.images.map { image in
            var newImage = image
            newImage.id = UUID()
            newImage.itemId = copiedItem.id
            newImage.createdAt = Date()
            return newImage
        }

        dataManager.addItem(copiedItem, to: destinationList.id)
    }

    override func addExistingItemToList(_ item: Item, listId: UUID) {
        // CRITICAL: Create a copy with new ID to avoid duplicate detection issues
        var newItem = item
        newItem.id = UUID()
        newItem.listId = listId
        newItem.createdAt = Date()
        newItem.modifiedAt = Date()
        newItem.isCrossedOut = false

        // Get the highest order number in destination list and add 1
        let destinationItems = dataManager.getItems(forListId: listId)
        let maxOrderNumber = destinationItems.map { $0.orderNumber }.max() ?? -1
        newItem.orderNumber = maxOrderNumber + 1

        // Copy images with new IDs - CRITICAL for avoiding Core Data conflicts
        newItem.images = item.images.map { image in
            var newImage = image
            newImage.id = UUID()
            newImage.itemId = newItem.id
            newImage.createdAt = Date()
            return newImage
        }

        dataManager.addItem(newItem, to: listId)
    }

    override func validateItem(_ item: Item) -> ValidationResult {
        if item.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return .failure("Item title cannot be empty")
        }

        if item.title.count > 200 {
            return .failure("Item title must be 200 characters or less")
        }

        if let description = item.itemDescription, description.count > 50000 {
            return .failure("Item description must be 50,000 characters or less")
        }

        if item.quantity < 1 {
            return .failure("Item quantity must be at least 1")
        }

        return .success
    }

    // MARK: - Image Operations Override

    override func addImage(to item: Item, imageData: Data) -> ItemImage {
        var itemImage = ItemImage(imageData: imageData, itemId: item.id)
        itemImage.compressImage()

        // Get current item from database to ensure we have latest image count
        let currentItem = getItem(by: item.id) ?? item

        // Set order number based on current image count
        itemImage.orderNumber = currentItem.images.count

        // Update the item with the new image
        var updatedItem = currentItem
        updatedItem.images.append(itemImage)
        updatedItem.updateModifiedDate()
        dataManager.updateItem(updatedItem)

        return itemImage
    }

    override func removeImage(_ image: ItemImage, from item: Item) {
        var updatedItem = item
        updatedItem.images.removeAll { $0.id == image.id }
        updatedItem.updateModifiedDate()
        dataManager.updateItem(updatedItem)
    }

    override func updateImageOrder(for item: Item, images: [ItemImage]) {
        var updatedItem = item
        updatedItem.images = images
        updatedItem.updateModifiedDate()
        dataManager.updateItem(updatedItem)
    }

    // MARK: - Import Operations Override

    override func addListForImport(_ list: ListModel) {
        dataManager.addList(list)
    }

    override func updateListForImport(_ list: ListModel) {
        dataManager.updateList(list)
    }

    override func addItemForImport(_ item: Item, to listId: UUID) {
        dataManager.addItem(item, to: listId)
    }

    override func updateItemForImport(_ item: Item) {
        dataManager.updateItem(item)
    }
}

/// Test-specific MainViewModel that uses isolated DataManager
class TestMainViewModel: ObservableObject {
    @Published var lists: [ListModel] = []
    @Published var archivedLists: [ListModel] = []
    @Published var selectedLists: Set<UUID> = []
    @Published var isInSelectionMode = false

    // Archive notification properties
    @Published var recentlyArchivedList: ListModel?
    @Published var showArchivedNotification = false

    private let dataManager: TestDataManager
    private var archiveNotificationTimer: Timer?
    private let archiveNotificationTimeout: TimeInterval = 5.0

    init(dataManager: TestDataManager) {
        self.dataManager = dataManager
        loadLists()
    }

    deinit {
        archiveNotificationTimer?.invalidate()
    }

    private func loadLists() {
        // FIX: Sort by orderNumber to ensure correct ordering after reorder operations
        lists = dataManager.lists.sorted { $0.orderNumber < $1.orderNumber }
    }

    func loadArchivedLists() {
        // Load archived lists from the test data manager
        let request: NSFetchRequest<ListEntity> = ListEntity.fetchRequest()
        request.predicate = NSPredicate(format: "isArchived == YES")
        request.sortDescriptors = [NSSortDescriptor(keyPath: \ListEntity.modifiedAt, ascending: false)]

        do {
            let listEntities = try dataManager.coreDataManager.viewContext.fetch(request)
            archivedLists = listEntities.map { $0.toList() }
        } catch {
            print("Failed to fetch archived lists: \(error)")
            archivedLists = []
        }
    }

    func addList(name: String) throws {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !trimmedName.isEmpty else {
            throw ValidationError.emptyName
        }

        guard trimmedName.count <= 100 else {
            throw ValidationError.nameTooLong
        }

        let newList = ListAll.List(name: trimmedName)
        dataManager.addList(newList)

        // Refresh lists from dataManager (which already added the list)
        lists = dataManager.lists.sorted { $0.orderNumber < $1.orderNumber }
    }

    func updateList(_ list: ListModel, name: String) throws {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !trimmedName.isEmpty else {
            throw ValidationError.emptyName
        }

        guard trimmedName.count <= 100 else {
            throw ValidationError.nameTooLong
        }

        var updatedList = list
        updatedList.name = trimmedName
        updatedList.updateModifiedDate()
        dataManager.updateList(updatedList)
        if let index = lists.firstIndex(where: { $0.id == list.id }) {
            lists[index] = updatedList
        }
    }

    func deleteList(_ list: ListModel) {
        dataManager.deleteList(withId: list.id)
        lists.removeAll { $0.id == list.id }
    }

    func archiveList(_ list: ListModel) {
        // Archive the list (mark as archived in Core Data)
        let context = dataManager.coreDataManager.viewContext
        let request: NSFetchRequest<ListEntity> = ListEntity.fetchRequest()
        request.predicate = NSPredicate(format: "id == %@", list.id as CVarArg)

        do {
            let results = try context.fetch(request)
            if let listEntity = results.first {
                listEntity.isArchived = true
                listEntity.modifiedAt = Date()
                dataManager.saveData()
            }
        } catch {
            print("Failed to archive list: \(error)")
        }

        // Remove from active lists
        lists.removeAll { $0.id == list.id }

        // Show archive notification
        showArchiveNotification(for: list)
    }

    func restoreList(_ list: ListModel) {
        // Restore an archived list
        let context = dataManager.coreDataManager.viewContext
        let request: NSFetchRequest<ListEntity> = ListEntity.fetchRequest()
        request.predicate = NSPredicate(format: "id == %@", list.id as CVarArg)

        do {
            let results = try context.fetch(request)
            if let listEntity = results.first {
                listEntity.isArchived = false
                listEntity.modifiedAt = Date()
                dataManager.saveData()
                // Reload data to include the restored list
                dataManager.loadData()
            }
        } catch {
            print("Failed to restore list: \(error)")
        }

        // Remove from archived lists
        archivedLists.removeAll { $0.id == list.id }
        // Reload active lists
        lists = dataManager.lists.sorted { $0.orderNumber < $1.orderNumber }
    }

    func permanentlyDeleteList(_ list: ListModel) {
        // Permanently delete a list and all its associated items
        let context = dataManager.coreDataManager.viewContext
        let listRequest: NSFetchRequest<ListEntity> = ListEntity.fetchRequest()
        listRequest.predicate = NSPredicate(format: "id == %@", list.id as CVarArg)

        do {
            let results = try context.fetch(listRequest)
            if let listEntity = results.first {
                // Delete all items in the list first
                if let items = listEntity.items as? Set<ItemEntity> {
                    for itemEntity in items {
                        // Delete all images in the item
                        if let images = itemEntity.images as? Set<ItemImageEntity> {
                            for imageEntity in images {
                                context.delete(imageEntity)
                            }
                        }
                        // Delete the item
                        context.delete(itemEntity)
                    }
                }
                // Delete the list itself
                context.delete(listEntity)
                dataManager.saveData()
            }
        } catch {
            print("Failed to permanently delete list: \(error)")
        }

        // Remove from archived lists
        archivedLists.removeAll { $0.id == list.id }
    }

    private func showArchiveNotification(for list: ListModel) {
        // Cancel any existing timer
        archiveNotificationTimer?.invalidate()

        // Store the archived list
        recentlyArchivedList = list
        showArchivedNotification = true

        // Set up timer to hide notification after timeout
        archiveNotificationTimer = Timer.scheduledTimer(withTimeInterval: archiveNotificationTimeout, repeats: false) { [weak self] _ in
            self?.hideArchiveNotification()
        }
    }

    func undoArchive() {
        guard let list = recentlyArchivedList else { return }

        // Restore the list
        let context = dataManager.coreDataManager.viewContext
        let request: NSFetchRequest<ListEntity> = ListEntity.fetchRequest()
        request.predicate = NSPredicate(format: "id == %@", list.id as CVarArg)

        do {
            let results = try context.fetch(request)
            if let listEntity = results.first {
                listEntity.isArchived = false
                listEntity.modifiedAt = Date()
                dataManager.saveData()
                dataManager.loadData()
            }
        } catch {
            print("Failed to undo archive: \(error)")
        }

        // Hide notification immediately BEFORE reloading lists
        hideArchiveNotification()

        // Reload active lists to include restored list
        lists = dataManager.lists.sorted { $0.orderNumber < $1.orderNumber }
    }

    private func hideArchiveNotification() {
        archiveNotificationTimer?.invalidate()
        archiveNotificationTimer = nil
        showArchivedNotification = false
        recentlyArchivedList = nil
    }

    func duplicateList(_ list: ListModel) throws {
        // Create a duplicate name with "Copy" suffix
        let duplicateName = generateDuplicateName(for: list.name)

        guard duplicateName.count <= 100 else {
            throw ValidationError.nameTooLong
        }

        // Create new list with duplicate name
        let duplicatedList = ListAll.List(name: duplicateName)

        // Get items from the original list
        let originalItems = dataManager.getItems(forListId: list.id)

        // Add the duplicated list first
        dataManager.addList(duplicatedList)

        // Duplicate all items from the original list
        for originalItem in originalItems {
            var duplicatedItem = originalItem
            duplicatedItem.id = UUID() // Generate new ID
            duplicatedItem.listId = duplicatedList.id // Associate with new list
            duplicatedItem.createdAt = Date()
            duplicatedItem.modifiedAt = Date()

            dataManager.addItem(duplicatedItem, to: duplicatedList.id)
        }

        // Refresh lists from dataManager (which already added the list)
        lists = dataManager.lists.sorted { $0.orderNumber < $1.orderNumber }
    }

    private func generateDuplicateName(for originalName: String) -> String {
        let baseName = originalName
        var duplicateNumber = 1
        var candidateName = "\(baseName) Copy"

        // Check if a list with this name already exists
        while lists.contains(where: { $0.name == candidateName }) {
            duplicateNumber += 1
            candidateName = "\(baseName) Copy \(duplicateNumber)"
        }

        return candidateName
    }

    func moveList(from source: IndexSet, to destination: Int) {
        lists.move(fromOffsets: source, toOffset: destination)

        // Update order numbers AND modifiedAt for proper sync
        for (index, list) in lists.enumerated() {
            var updatedList = list
            let oldOrderNumber = updatedList.orderNumber
            updatedList.orderNumber = index
            // FIX: Only update modifiedAt for lists whose order actually changed
            if oldOrderNumber != index {
                updatedList.updateModifiedDate()
            }
            dataManager.updateList(updatedList)
            lists[index] = updatedList
        }
    }

    // MARK: - Multi-Selection Methods

    func toggleSelection(for listId: UUID) {
        if selectedLists.contains(listId) {
            selectedLists.remove(listId)
        } else {
            selectedLists.insert(listId)
        }
    }

    func selectAll() {
        selectedLists = Set(lists.map { $0.id })
    }

    func deselectAll() {
        selectedLists.removeAll()
    }

    func deleteSelectedLists() {
        for listId in selectedLists {
            dataManager.deleteList(withId: listId)
        }
        lists.removeAll { selectedLists.contains($0.id) }
        selectedLists.removeAll()
    }

    func enterSelectionMode() {
        isInSelectionMode = true
        selectedLists.removeAll()
    }

    func exitSelectionMode() {
        isInSelectionMode = false
        selectedLists.removeAll()
    }
}
