//
//  TestDataManager.swift
//  ListAllMacTests
//
//  Test-specific Data Manager extracted from TestHelpers.swift
//

import Foundation
import CoreData
import Combine
import CloudKit
@testable import ListAll

/// Test-specific Data Manager that uses isolated Core Data
/// Conforms to DataManaging protocol for dependency injection
class TestDataManager: ObservableObject, DataManaging {
    @Published var lists: [ListModel] = []
    @Published var archivedLists: [ListModel] = []
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

    /// Loads archived lists into the @Published archivedLists property for SwiftUI observation.
    func loadArchivedData() {
        archivedLists = loadArchivedLists()
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
                loadArchivedData()
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
                loadArchivedData()
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
