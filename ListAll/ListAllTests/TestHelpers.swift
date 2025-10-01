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
    private let coreDataManager: TestCoreDataManager
    
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
    
    // MARK: - List Operations
    
    func addList(_ list: List) {
        let context = coreDataManager.viewContext
        let listEntity = ListEntity(context: context)
        listEntity.id = list.id
        listEntity.name = list.name
        listEntity.orderNumber = Int32(list.orderNumber)
        listEntity.createdAt = list.createdAt
        listEntity.modifiedAt = list.modifiedAt
        listEntity.isArchived = false
        
        saveData()
        // Add to local array and sort instead of reloading
        lists.append(list)
        lists.sort { $0.orderNumber < $1.orderNumber }
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
    
    func duplicateItem(in list: List) -> Item? {
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
    
    // Undo Complete Properties
    @Published var recentlyCompletedItem: Item?
    @Published var showUndoButton = false
    
    private let dataManager: TestDataManager
    private let dataRepository: TestDataRepository
    private let list: List
    private var undoTimer: Timer?
    private let undoTimeout: TimeInterval = 5.0 // 5 seconds standard timeout
    
    init(list: List, dataManager: TestDataManager) {
        self.list = list
        self.dataManager = dataManager
        self.dataRepository = TestDataRepository(dataManager: dataManager)
        loadItems()
    }
    
    deinit {
        undoTimer?.invalidate()
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
    
    private func hideUndoButton() {
        undoTimer?.invalidate()
        undoTimer = nil
        showUndoButton = false
        recentlyCompletedItem = nil
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
        guard let sourceIndex = source.first else { return }
        let destinationIndex = destination > sourceIndex ? destination - 1 : destination
        reorderItems(from: sourceIndex, to: destinationIndex)
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
    
    /// Returns filtered items based on the showCrossedOutItems setting
    var filteredItems: [Item] {
        if showCrossedOutItems {
            return items
        } else {
            return activeItems
        }
    }
    
    func toggleShowCrossedOutItems() {
        showCrossedOutItems.toggle()
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
    
    override func getAllLists() -> [List] {
        return dataManager.lists
    }
    
    override func deleteList(_ list: List) {
        dataManager.deleteList(withId: list.id)
    }
    
    override func createItem(in list: List, title: String, description: String = "", quantity: Int = 1) -> Item {
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
    
    override func reorderItems(in list: List, from sourceIndex: Int, to destinationIndex: Int) {
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
    
    // MARK: - Import Operations Override
    
    override func addListForImport(_ list: List) {
        dataManager.addList(list)
    }
    
    override func updateListForImport(_ list: List) {
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
    @Published var lists: [List] = []
    private let dataManager: TestDataManager
    
    init(dataManager: TestDataManager) {
        self.dataManager = dataManager
        loadLists()
    }
    
    private func loadLists() {
        lists = dataManager.lists
    }
    
    func addList(name: String) throws {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        
        guard !trimmedName.isEmpty else {
            throw ValidationError.emptyName
        }
        
        guard trimmedName.count <= 100 else {
            throw ValidationError.nameTooLong
        }
        
        let newList = List(name: trimmedName)
        dataManager.addList(newList)
        lists.append(newList)
    }
    
    func updateList(_ list: List, name: String) throws {
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
    
    func deleteList(_ list: List) {
        dataManager.deleteList(withId: list.id)
        lists.removeAll { $0.id == list.id }
    }
    
    func duplicateList(_ list: List) throws {
        // Create a duplicate name with "Copy" suffix
        let duplicateName = generateDuplicateName(for: list.name)
        
        guard duplicateName.count <= 100 else {
            throw ValidationError.nameTooLong
        }
        
        // Create new list with duplicate name
        let duplicatedList = List(name: duplicateName)
        
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
        
        // Add to local lists array and sort
        lists.append(duplicatedList)
        lists.sort { $0.orderNumber < $1.orderNumber }
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
        
        // Update order numbers for all lists
        for (index, list) in lists.enumerated() {
            var updatedList = list
            updatedList.orderNumber = Int(index)
            dataManager.updateList(updatedList)
            lists[index] = updatedList
        }
    }
}
