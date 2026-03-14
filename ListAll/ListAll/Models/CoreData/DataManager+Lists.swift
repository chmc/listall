import Foundation
import CoreData
import Combine

// MARK: - List Operations

extension DataManager {

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
        listEntity.isArchived = list.isArchived

        saveData()

        // Update the list struct with the assigned orderNumber before appending
        var updatedList = list
        updatedList.orderNumber = nextOrderNumber

        // Append to the correct array based on archived status
        if list.isArchived {
            archivedLists.append(updatedList)
        } else {
            lists.append(updatedList)
        }
        // No need to sort - new list goes to end with highest orderNumber
    }

    func updateList(_ list: List) {
        let request: NSFetchRequest<ListEntity> = ListEntity.fetchRequest()
        request.predicate = NSPredicate(format: "id == %@", list.id as CVarArg)

        do {
            let results = try coreDataManager.viewContext.fetch(request)
            if let listEntity = results.first {
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

    func updateListsOrder(_ newOrder: [List]) {
        // FIX: Batch fetch all entities ONCE instead of N separate fetches (O(n) vs O(n²))
        let context = coreDataManager.viewContext

        // Fetch ALL list entities in a single query
        let request: NSFetchRequest<ListEntity> = ListEntity.fetchRequest()
        let listIds = newOrder.map { $0.id }
        request.predicate = NSPredicate(format: "id IN %@", listIds)

        do {
            let allEntities = try context.fetch(request)

            // Create lookup dictionary for O(1) access
            var entityById: [UUID: ListEntity] = [:]
            for entity in allEntities {
                if let id = entity.id {
                    entityById[id] = entity
                }
            }

            // Update all entities in memory (O(n))
            for list in newOrder {
                if let entity = entityById[list.id] {
                    entity.orderNumber = Int32(list.orderNumber)
                    entity.modifiedAt = list.modifiedAt
                }
            }
        } catch {
            print("Failed to batch update list order: \(error)")
        }

        // Save once after all updates
        saveData()

        // CRITICAL: Ensure Core Data has processed all changes before continuing
        context.processPendingChanges()

        // DON'T update local array here - let caller explicitly call loadData() to refresh
        // This prevents race conditions where cached array gets out of sync with Core Data
        // lists = newOrder  // REMOVED - caller must call loadData() explicitly
    }

    func synchronizeLists(_ newOrder: [List]) {
        // Synchronize internal lists array with the provided order
        // This ensures that subsequent reloads maintain the correct order
        lists = newOrder
    }

    func deleteList(withId id: UUID) {
        // Archive the list instead of permanently deleting it
        let request: NSFetchRequest<ListEntity> = ListEntity.fetchRequest()
        request.predicate = NSPredicate(format: "id == %@", id as CVarArg)

        do {
            let results = try coreDataManager.viewContext.fetch(request)
            if let listEntity = results.first {
                listEntity.isArchived = true
                listEntity.modifiedAt = Date()
                saveData()
                // Remove from local array (archived lists are filtered out)
                lists.removeAll { $0.id == id }
                // Refresh archived lists cache to include the newly archived list
                loadArchivedData()
            }
        } catch {
            print("Failed to archive list: \(error)")
        }
    }

    func loadArchivedLists() -> [List] {
        // Load archived lists from Core Data
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
    /// Call this when toggling to archived lists view or after restore/delete operations.
    func loadArchivedData() {
        let fetchedArchived = loadArchivedLists()

        let updateArchivedLists = { [self] in
            self.objectWillChange.send()
            self.archivedLists = fetchedArchived
            print("📦 DataManager: Updated archivedLists array with \(fetchedArchived.count) lists")
        }

        if Thread.isMainThread {
            updateArchivedLists()
        } else {
            DispatchQueue.main.sync {
                updateArchivedLists()
            }
        }
    }

    func restoreList(withId id: UUID) {
        // Restore an archived list
        let request: NSFetchRequest<ListEntity> = ListEntity.fetchRequest()
        request.predicate = NSPredicate(format: "id == %@", id as CVarArg)

        do {
            let results = try coreDataManager.viewContext.fetch(request)
            if let listEntity = results.first {
                listEntity.isArchived = false
                listEntity.modifiedAt = Date()
                saveData()
                // Reload data to include the restored list in active lists
                loadData()
                // Refresh archived lists cache to remove the restored list
                loadArchivedData()
            }
        } catch {
            print("Failed to restore list: \(error)")
        }
    }

    func permanentlyDeleteList(withId id: UUID) {
        // Permanently delete a list and all its associated items
        let listRequest: NSFetchRequest<ListEntity> = ListEntity.fetchRequest()
        listRequest.predicate = NSPredicate(format: "id == %@", id as CVarArg)

        do {
            let results = try coreDataManager.viewContext.fetch(listRequest)
            if let listEntity = results.first {
                // Delete all items in the list first
                if let items = listEntity.items as? Set<ItemEntity> {
                    for itemEntity in items {
                        // Delete all images in the item
                        if let images = itemEntity.images as? Set<ItemImageEntity> {
                            for imageEntity in images {
                                coreDataManager.viewContext.delete(imageEntity)
                            }
                        }
                        // Delete the item
                        coreDataManager.viewContext.delete(itemEntity)
                    }
                }
                // Delete the list itself
                coreDataManager.viewContext.delete(listEntity)
                saveData()
                // Refresh archived lists cache to remove the deleted list
                loadArchivedData()
            }
        } catch {
            print("Failed to permanently delete list: \(error)")
        }
    }
}
