//
//  TestDataRepository.swift
//  ListAllMacTests
//
//  Test-specific DataRepository extracted from TestHelpers.swift
//

import Foundation
@testable import ListAll

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
