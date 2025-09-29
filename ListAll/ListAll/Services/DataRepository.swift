import Foundation
import CoreData

class DataRepository: ObservableObject {
    private let coreDataManager = CoreDataManager.shared
    private let dataManager = DataManager.shared
    
    // MARK: - List Operations
    
    func createList(name: String) -> List {
        let newList = List(name: name)
        dataManager.addList(newList)
        return newList
    }
    
    func deleteList(_ list: List) {
        dataManager.deleteList(withId: list.id)
    }
    
    func updateList(_ list: List, name: String) {
        var updatedList = list
        updatedList.name = name
        updatedList.updateModifiedDate()
        dataManager.updateList(updatedList)
    }
    
    func getAllLists() -> [List] {
        return dataManager.lists
    }
    
    func getList(by id: UUID) -> List? {
        return dataManager.lists.first { $0.id == id }
    }
    
    // MARK: - Item Operations
    
    func createItem(in list: List, title: String, description: String = "", quantity: Int = 1) -> Item {
        var newItem = Item(title: title)
        newItem.itemDescription = description.isEmpty ? nil : description
        newItem.quantity = quantity
        newItem.listId = list.id
        dataManager.addItem(newItem, to: list.id)
        
        // Notification is now sent from DataManager after loadData() completes
        
        return newItem
    }
    
    func deleteItem(_ item: Item) {
        if let listId = item.listId {
            dataManager.deleteItem(withId: item.id, from: listId)
            
            // Notification is now sent from DataManager after loadData() completes
        }
    }
    
    func updateItem(_ item: Item, title: String, description: String, quantity: Int) {
        var updatedItem = item
        updatedItem.title = title
        updatedItem.itemDescription = description.isEmpty ? nil : description
        updatedItem.quantity = quantity
        updatedItem.updateModifiedDate()
        dataManager.updateItem(updatedItem)
        
        // Notification is now sent from DataManager after loadData() completes
    }
    
    func toggleItemCrossedOut(_ item: Item) {
        var updatedItem = item
        updatedItem.toggleCrossedOut()
        dataManager.updateItem(updatedItem)
        
        // Notification is now sent from DataManager after loadData() completes
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
    }
    
    func updateItemOrderNumbers(for list: List, items: [Item]) {
        for (index, var item) in items.enumerated() {
            item.orderNumber = index
            item.updateModifiedDate()
            dataManager.updateItem(item)
        }
    }
    
    // MARK: - Image Operations
    
    func addImage(to item: Item, imageData: Data) -> ItemImage {
        var itemImage = ItemImage(imageData: imageData, itemId: item.id)
        itemImage.compressImage()
        
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
            print("Failed to fetch user data: \(error)")
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
                let userEntity = UserDataEntity.fromUserData(newUser, context: coreDataManager.viewContext)
                coreDataManager.save()
                return newUser
            }
        } catch {
            print("Failed to create/update user: \(error)")
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
            print("Failed to update user preferences: \(error)")
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
            print("Failed to search lists: \(error)")
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
            print("Failed to search items: \(error)")
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
}
