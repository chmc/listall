import Foundation
import CoreData
@testable import ListAll

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

    // Item Organization Properties
    @Published var currentSortOption: ItemSortOption = .orderNumber
    @Published var currentSortDirection: SortDirection = .ascending
    @Published var currentFilterOption: ItemFilterOption = .active

    // Search Properties
    @Published var searchText: String = ""

    // Undo Complete Properties
    @Published var recentlyCompletedItem: Item?
    @Published var showUndoButton = false

    // Undo Delete Properties
    @Published var recentlyDeletedItem: Item?
    @Published var showDeleteUndoButton = false

    // Multi-Selection Properties
    @Published var isInSelectionMode = false
    @Published var selectedItems: Set<UUID> = []

    // Watch sync properties
    @Published var isSyncingFromWatch = false

    private let dataManager: TestDataManager
    private let dataRepository: TestDataRepository
    private let list: List
    private var undoTimer: Timer?
    private var deleteUndoTimer: Timer?
    private let undoTimeout: TimeInterval = 5.0 // 5 seconds standard timeout

    init(list: List, dataManager: TestDataManager) {
        self.list = list
        self.dataManager = dataManager
        self.dataRepository = TestDataRepository(dataManager: dataManager)
        loadItems()
        setupWatchConnectivityObserver()
    }

    deinit {
        undoTimer?.invalidate()
        deleteUndoTimer?.invalidate()
        NotificationCenter.default.removeObserver(self)
    }

    // MARK: - Watch Connectivity Integration

    private func setupWatchConnectivityObserver() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleWatchSyncNotification(_:)),
            name: NSNotification.Name("WatchConnectivitySyncReceived"),
            object: nil
        )
    }

    @objc private func handleWatchSyncNotification(_ notification: Notification) {
        refreshItemsFromWatch()
    }

    func refreshItemsFromWatch() {
        // Show sync indicator briefly
        isSyncingFromWatch = true

        // Reload items from DataManager (which already has the updated data from Core Data)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            self.loadItems()

            // Hide sync indicator after brief delay
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                self.isSyncingFromWatch = false
            }
        }
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

    func updateItem(_ item: Item, title: String, description: String, quantity: Int) {
        dataRepository.updateItem(item, title: title, description: description, quantity: quantity)
        loadItems()
    }

    func reorderItems(from sourceIndex: Int, to destinationIndex: Int) {
        dataRepository.reorderItems(in: list, from: sourceIndex, to: destinationIndex)
        loadItems()
    }

    func moveItems(from source: IndexSet, to destination: Int) {
        // Handle the SwiftUI List onMove callback
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

    func toggleSelection(for itemId: UUID) {
        if selectedItems.contains(itemId) {
            selectedItems.remove(itemId)
        } else {
            selectedItems.insert(itemId)
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

    func moveSelectedItems(to destinationList: List) {
        // Get selected items
        let itemsToMove = items.filter { selectedItems.contains($0.id) }

        // Move each item to destination list
        for item in itemsToMove {
            dataRepository.moveItem(item, to: destinationList)
        }

        selectedItems.removeAll()
        loadItems()
    }

    func copySelectedItems(to destinationList: List) {
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
    }
}

/// Test-specific MainViewModel that uses isolated DataManager
class TestMainViewModel: ObservableObject {
    @Published var lists: [List] = []
    @Published var archivedLists: [List] = []
    @Published var selectedLists: Set<UUID> = []
    @Published var isInSelectionMode = false

    // Archive notification properties
    @Published var recentlyArchivedList: List?
    @Published var showArchivedNotification = false

    // Watch sync properties
    @Published var isSyncingFromWatch = false

    private let dataManager: TestDataManager
    private var archiveNotificationTimer: Timer?
    private let archiveNotificationTimeout: TimeInterval = 5.0

    init(dataManager: TestDataManager) {
        self.dataManager = dataManager
        loadLists()
        setupWatchConnectivityObserver()
    }

    deinit {
        archiveNotificationTimer?.invalidate()
        NotificationCenter.default.removeObserver(self)
    }

    // MARK: - Watch Connectivity Integration

    private func setupWatchConnectivityObserver() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleWatchSyncNotification(_:)),
            name: NSNotification.Name("WatchConnectivitySyncReceived"),
            object: nil
        )
    }

    @objc private func handleWatchSyncNotification(_ notification: Notification) {
        refreshFromWatch()
    }

    func refreshFromWatch() {
        // Show sync indicator briefly
        isSyncingFromWatch = true

        // Reload lists from DataManager (which already has the updated data from Core Data)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            self.loadLists()

            // Hide sync indicator after brief delay
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                self.isSyncingFromWatch = false
            }
        }
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

        let newList = List(name: trimmedName)
        dataManager.addList(newList)

        // Refresh lists from dataManager (which already added the list)
        lists = dataManager.lists.sorted { $0.orderNumber < $1.orderNumber }
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

    func archiveList(_ list: List) {
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

    func restoreList(_ list: List) {
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

    func permanentlyDeleteList(_ list: List) {
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

    private func showArchiveNotification(for list: List) {
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
