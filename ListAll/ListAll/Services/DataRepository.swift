import Foundation
import CoreData
import Combine

class DataRepository: ObservableObject {
    private let coreDataManager = CoreDataManager.shared
    private let dataManager = DataManager.shared
    private let watchConnectivityService = WatchConnectivityService.shared
    
    // MARK: - Initialization
    
    init() {
        // Observe incoming sync notifications from paired device
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleSyncRequest),
            name: NSNotification.Name("WatchConnectivitySyncReceived"),
            object: nil
        )
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    // MARK: - List Operations
    
    func createList(name: String) -> List {
        let newList = List(name: name)
        dataManager.addList(newList)
        
        // Send updated data to paired device
        watchConnectivityService.sendListsData(dataManager.lists)
        
        return newList
    }
    
    func deleteList(_ list: List) {
        dataManager.deleteList(withId: list.id)
        
        // Send updated data to paired device
        watchConnectivityService.sendListsData(dataManager.lists)
    }
    
    func updateList(_ list: List, name: String) {
        var updatedList = list
        updatedList.name = name
        updatedList.updateModifiedDate()
        dataManager.updateList(updatedList)
        
        // Send updated data to paired device
        watchConnectivityService.sendListsData(dataManager.lists)
    }
    
    func getAllLists() -> [List] {
        return dataManager.lists
    }
    
    func reloadData() {
        dataManager.loadData()
    }
    
    func getList(by id: UUID) -> List? {
        return dataManager.lists.first { $0.id == id }
    }
    
    // MARK: - Item Operations
    
    func createItem(in list: List, title: String, description: String = "", quantity: Int = 1) -> Item {
        let normalizedDescription = description.isEmpty ? nil : description
        
        // Smart duplicate detection: Check if an item with same title AND metadata already exists
        let existingItems = dataManager.getItems(forListId: list.id)
        if let existingItem = existingItems.first(where: { item in
            item.title == title &&
            item.itemDescription == normalizedDescription &&
            item.quantity == quantity
        }) {
            // Found item with exact same metadata
            if existingItem.isCrossedOut {
                // Uncross the existing item instead of creating duplicate
                var uncrossedItem = existingItem
                uncrossedItem.isCrossedOut = false
                uncrossedItem.updateModifiedDate()
                dataManager.updateItem(uncrossedItem)
                
                // Send updated data to paired device
                watchConnectivityService.sendListsData(dataManager.lists)
                
                return uncrossedItem
            } else {
                // Item already exists and is not crossed out - just return it
                return existingItem
            }
        }
        
        // No matching item found or metadata differs - create new item
        var newItem = Item(title: title)
        newItem.itemDescription = normalizedDescription
        newItem.quantity = quantity
        newItem.listId = list.id
        dataManager.addItem(newItem, to: list.id)
        
        // Send updated data to paired device
        watchConnectivityService.sendListsData(dataManager.lists)
        
        return newItem
    }
    
    /// Add an existing item from another list to the current list
    /// This is used when user selects a suggestion without making changes
    func addExistingItemToList(_ item: Item, listId: UUID) {
        // CRITICAL: Create a copy with new ID to avoid duplicate detection issues
        // The item might exist in another list with the same ID, and ID-based
        // duplicate detection would update the existing item instead of creating a new one
        var newItem = item
        newItem.id = UUID() // New ID for the copy
        newItem.listId = listId
        newItem.createdAt = Date()
        newItem.modifiedAt = Date()
        newItem.isCrossedOut = false // Always add suggested items as active (uncrossed)
        
        // Get the highest order number in destination list and add 1
        let destinationItems = dataManager.getItems(forListId: listId)
        let maxOrderNumber = destinationItems.map { $0.orderNumber }.max() ?? -1
        newItem.orderNumber = maxOrderNumber + 1
        
        // Copy images with new IDs
        newItem.images = item.images.map { image in
            var newImage = image
            newImage.id = UUID()
            newImage.itemId = newItem.id
            newImage.createdAt = Date()
            return newImage
        }
        
        dataManager.addItem(newItem, to: listId)
        
        // Send updated data to paired device
        watchConnectivityService.sendListsData(dataManager.lists)
    }
    
    func deleteItem(_ item: Item) {
        if let listId = item.listId {
            dataManager.deleteItem(withId: item.id, from: listId)
            
            // Send updated data to paired device
            watchConnectivityService.sendListsData(dataManager.lists)
        }
    }
    
    func updateItem(_ item: Item, title: String, description: String, quantity: Int) {
        var updatedItem = item
        updatedItem.title = title
        updatedItem.itemDescription = description.isEmpty ? nil : description
        updatedItem.quantity = quantity
        updatedItem.updateModifiedDate()
        dataManager.updateItem(updatedItem)
        
        // Send updated data to paired device
        watchConnectivityService.sendListsData(dataManager.lists)
    }
    
    /// Updates an item with all its properties including images
    func updateItem(_ item: Item) {
        dataManager.updateItem(item)
        
        // Send updated data to paired device
        watchConnectivityService.sendListsData(dataManager.lists)
    }
    
    func toggleItemCrossedOut(_ item: Item) {
        var updatedItem = item
        updatedItem.toggleCrossedOut()
        dataManager.updateItem(updatedItem)
        
        // Send updated data to paired device
        watchConnectivityService.sendListsData(dataManager.lists)
    }
    
    func getItems(for list: List) -> [Item] {
        return list.sortedItems
    }
    
    func getItem(by id: UUID) -> Item? {
        for list in dataManager.lists {
            if let item = list.items.first(where: { $0.id == id }) {
                return item
            }
        }
        return nil
    }
    
    func reorderItems(in list: List, from sourceIndex: Int, to destinationIndex: Int) {
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
        
        // Send updated data to paired device
        watchConnectivityService.sendListsData(dataManager.lists)
    }
    
    func reorderMultipleItems(in list: List, itemsToMove: [Item], to insertionIndex: Int) {
        // Get current items for this list
        var currentItems = dataManager.getItems(forListId: list.id)
        
        // Ensure we have items to move
        guard !itemsToMove.isEmpty else { return }
        
        // Get IDs of items being moved for quick lookup
        let movingItemIds = Set(itemsToMove.map { $0.id })
        
        // Remove all items that are being moved from the current list
        var itemsBeingMoved: [Item] = []
        currentItems.removeAll { item in
            if movingItemIds.contains(item.id) {
                itemsBeingMoved.append(item)
                return true
            }
            return false
        }
        
        // Sort items being moved by their original order to maintain relative positioning
        itemsBeingMoved.sort { $0.orderNumber < $1.orderNumber }
        
        // Calculate the actual insertion point after removing the moved items
        // If we're inserting after where items were removed from, adjust the index
        let adjustedInsertionIndex = min(insertionIndex, currentItems.count)
        
        // Insert all moved items at the adjusted insertion point
        currentItems.insert(contentsOf: itemsBeingMoved, at: adjustedInsertionIndex)
        
        // Update order numbers for all items and save
        for (index, var item) in currentItems.enumerated() {
            item.orderNumber = index
            item.updateModifiedDate()
            dataManager.updateItem(item)
        }
        
        // Send updated data to paired device
        watchConnectivityService.sendListsData(dataManager.lists)
    }
    
    func updateItemOrderNumbers(for list: List, items: [Item]) {
        for (index, var item) in items.enumerated() {
            item.orderNumber = index
            item.updateModifiedDate()
            dataManager.updateItem(item)
        }
        
        // Send updated data to paired device
        watchConnectivityService.sendListsData(dataManager.lists)
    }
    
    func moveItem(_ item: Item, to destinationList: List) {
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
        
        // Send updated data to paired device
        watchConnectivityService.sendListsData(dataManager.lists)
    }
    
    func copyItem(_ item: Item, to destinationList: List) {
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
        
        // Send updated data to paired device
        watchConnectivityService.sendListsData(dataManager.lists)
    }
    
    // MARK: - Image Operations
    
    func addImage(to item: Item, imageData: Data) -> ItemImage {
        var itemImage = ItemImage(imageData: imageData, itemId: item.id)
        #if canImport(UIKit) && !os(watchOS)
        itemImage.compressImage()
        #endif
        
        // Update the item with the new image
        var updatedItem = item
        updatedItem.images.append(itemImage)
        updatedItem.updateModifiedDate()
        dataManager.updateItem(updatedItem)
        
        return itemImage
    }
    
    func removeImage(_ image: ItemImage, from item: Item) {
        var updatedItem = item
        updatedItem.images.removeAll { $0.id == image.id }
        updatedItem.updateModifiedDate()
        dataManager.updateItem(updatedItem)
    }
    
    func updateImageOrder(for item: Item, images: [ItemImage]) {
        var updatedItem = item
        updatedItem.images = images
        updatedItem.updateModifiedDate()
        dataManager.updateItem(updatedItem)
    }
    
    // MARK: - User Data Operations
    
    func getCurrentUser() -> UserData? {
        let request: NSFetchRequest<UserDataEntity> = UserDataEntity.fetchRequest()
        request.fetchLimit = 1
        
        do {
            let results = try coreDataManager.viewContext.fetch(request)
            return results.first?.toUserData()
        } catch {
            return nil
        }
    }
    
    func createOrUpdateUser(userID: String) -> UserData {
        let request: NSFetchRequest<UserDataEntity> = UserDataEntity.fetchRequest()
        request.predicate = NSPredicate(format: "userID == %@", userID)
        
        do {
            let results = try coreDataManager.viewContext.fetch(request)
            if let existingUser = results.first {
                return existingUser.toUserData()
            } else {
                let newUser = UserData(userID: userID)
                _ = UserDataEntity.fromUserData(newUser, context: coreDataManager.viewContext)
                coreDataManager.save()
                return newUser
            }
        } catch {
            return UserData(userID: userID)
        }
    }
    
    func updateUserPreferences(_ userData: UserData) {
        let request: NSFetchRequest<UserDataEntity> = UserDataEntity.fetchRequest()
        request.predicate = NSPredicate(format: "id == %@", userData.id as CVarArg)
        
        do {
            let results = try coreDataManager.viewContext.fetch(request)
            if let userEntity = results.first {
                userEntity.showCrossedOutItems = userData.showCrossedOutItems
                userEntity.exportPreferences = userData.exportPreferences
                userEntity.lastSyncDate = userData.lastSyncDate
                coreDataManager.save()
            }
        } catch {
        }
    }
    
    // MARK: - Data Validation
    
    func validateList(_ list: List) -> ValidationResult {
        if list.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return .failure("List name cannot be empty")
        }
        
        if list.name.count > 100 {
            return .failure("List name must be 100 characters or less")
        }
        
        return .success
    }
    
    func validateItem(_ item: Item) -> ValidationResult {
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
    
    func validateImage(_ image: ItemImage) -> ValidationResult {
        guard let imageData = image.imageData else {
            return .failure("Image data is required")
        }
        
        if imageData.count > 5 * 1024 * 1024 { // 5MB limit
            return .failure("Image size must be 5MB or less")
        }
        
        return .success
    }
    
    // MARK: - Search Operations
    
    func searchLists(query: String) -> [List] {
        let request: NSFetchRequest<ListEntity> = ListEntity.fetchRequest()
        request.predicate = NSPredicate(format: "name CONTAINS[cd] %@", query)
        request.sortDescriptors = [NSSortDescriptor(keyPath: \ListEntity.orderNumber, ascending: true)]
        
        do {
            let listEntities = try coreDataManager.viewContext.fetch(request)
            return listEntities.map { $0.toList() }
        } catch {
            return []
        }
    }
    
    func searchItems(query: String) -> [Item] {
        let request: NSFetchRequest<ItemEntity> = ItemEntity.fetchRequest()
        request.predicate = NSPredicate(format: "title CONTAINS[cd] %@ OR itemDescription CONTAINS[cd] %@", query, query)
        request.sortDescriptors = [NSSortDescriptor(keyPath: \ItemEntity.createdAt, ascending: false)]
        
        do {
            let itemEntities = try coreDataManager.viewContext.fetch(request)
            return itemEntities.map { $0.toItem() }
        } catch {
            return []
        }
    }
    
    // MARK: - Convenience Methods for User Data
    
    func getUserData() -> UserData? {
        return getCurrentUser()
    }
    
    func saveUserData(_ userData: UserData) {
        updateUserPreferences(userData)
    }
    
    // MARK: - Data Migration
    
    func performDataMigration() {
        coreDataManager.migrateDataIfNeeded()
    }
    
    // MARK: - Import Operations
    
    /// Adds a fully-configured list (for import operations)
    func addListForImport(_ list: List) {
        dataManager.addList(list)
    }
    
    /// Updates a fully-configured list (for import operations)
    func updateListForImport(_ list: List) {
        dataManager.updateList(list)
    }
    
    /// Adds a fully-configured item (for import operations)
    func addItemForImport(_ item: Item, to listId: UUID) {
        dataManager.addItem(item, to: listId)
    }
    
    /// Updates a fully-configured item (for import operations)
    func updateItemForImport(_ item: Item) {
        dataManager.updateItem(item)
    }
    
    // MARK: - Sync Operations
    
    /// Handles incoming sync requests from paired device
    /// This is called when the other device makes data changes and notifies us to reload
    @objc private func handleSyncRequest(_ notification: Notification) {
        // Reload data from Core Data to reflect changes made by paired device
        reloadData()
    }
}
