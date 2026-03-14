import Foundation
import CoreData

// MARK: - Item Operations

extension DataManager {

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

                // Create new image entities (with duplicate ID protection)
                for itemImage in item.images {
                    let imageCheck: NSFetchRequest<ItemImageEntity> = ItemImageEntity.fetchRequest()
                    imageCheck.predicate = NSPredicate(format: "id == %@", itemImage.id as CVarArg)

                    let existingImageEntities = try context.fetch(imageCheck)
                    if existingImageEntities.first != nil {
                        // Image ID already exists elsewhere - create with new ID
                        var newImageData = itemImage
                        newImageData.id = UUID()
                        let imageEntity = ItemImageEntity.fromItemImage(newImageData, context: context)
                        imageEntity.item = existingItem
                    } else {
                        let imageEntity = ItemImageEntity.fromItemImage(itemImage, context: context)
                        imageEntity.item = existingItem
                    }
                }

                saveData()
                // Don't call loadData() here - let the caller handle batching
                return
            }
        } catch {
            print("Failed to check for existing item: \(error)")
        }

        // Find the list
        let listRequest: NSFetchRequest<ListEntity> = ListEntity.fetchRequest()
        listRequest.predicate = NSPredicate(format: "id == %@", listId as CVarArg)

        do {
            let listResults = try context.fetch(listRequest)
            if let listEntity = listResults.first {
                let itemEntity = ItemEntity(context: context)
                itemEntity.id = item.id
                itemEntity.title = item.title
                itemEntity.itemDescription = item.itemDescription
                itemEntity.quantity = Int32(item.quantity)
                itemEntity.orderNumber = Int32(item.orderNumber)
                itemEntity.isCrossedOut = item.isCrossedOut
                itemEntity.createdAt = item.createdAt
                itemEntity.modifiedAt = item.modifiedAt
                itemEntity.list = listEntity

                // Create image entities from the item's images
                // CRITICAL FIX: Check for duplicate image IDs to prevent Core Data conflicts
                for itemImage in item.images {
                    // Check if image entity with this ID already exists
                    let imageCheck: NSFetchRequest<ItemImageEntity> = ItemImageEntity.fetchRequest()
                    imageCheck.predicate = NSPredicate(format: "id == %@", itemImage.id as CVarArg)

                    let existingImages = try context.fetch(imageCheck)
                    if existingImages.first != nil {
                        // Image ID already exists - create a new one with a different ID
                        // This can happen if the same item is added to multiple lists
                        var newImageData = itemImage
                        newImageData.id = UUID() // Force new ID to avoid conflict
                        let imageEntity = ItemImageEntity.fromItemImage(newImageData, context: context)
                        imageEntity.item = itemEntity
                    } else {
                        // Normal case - create image entity with original ID
                        let imageEntity = ItemImageEntity.fromItemImage(itemImage, context: context)
                        imageEntity.item = itemEntity
                    }
                }

                saveData()
                loadData()

                // Notify after data is fully loaded (matches updateItem/deleteItem pattern)
                NotificationCenter.default.post(name: NSNotification.Name("ItemDataChanged"), object: nil)
            }
        } catch {
            print("Failed to add item: \(error)")
        }
    }

    func updateItem(_ item: Item) {
        let request: NSFetchRequest<ItemEntity> = ItemEntity.fetchRequest()
        request.predicate = NSPredicate(format: "id == %@", item.id as CVarArg)

        do {
            let results = try coreDataManager.viewContext.fetch(request)
            if let itemEntity = results.first {
                // Update basic properties
                itemEntity.title = item.title
                itemEntity.itemDescription = item.itemDescription
                itemEntity.quantity = Int32(item.quantity)
                itemEntity.orderNumber = Int32(item.orderNumber)
                itemEntity.isCrossedOut = item.isCrossedOut
                itemEntity.modifiedAt = item.modifiedAt

                // Update images: First delete existing image entities
                if let existingImages = itemEntity.images?.allObjects as? [ItemImageEntity] {
                    for imageEntity in existingImages {
                        coreDataManager.viewContext.delete(imageEntity)
                    }
                }

                // Create new image entities from the item's images
                for itemImage in item.images {
                    let imageEntity = ItemImageEntity.fromItemImage(itemImage, context: coreDataManager.viewContext)
                    imageEntity.item = itemEntity
                }

                saveData()
                loadData()

                // Notify after data is fully loaded
                NotificationCenter.default.post(name: NSNotification.Name("ItemDataChanged"), object: nil)
            }
        } catch {
            print("Failed to update item: \(error)")
        }
    }

    func deleteItem(withId id: UUID, from listId: UUID) {
        let request: NSFetchRequest<ItemEntity> = ItemEntity.fetchRequest()
        request.predicate = NSPredicate(format: "id == %@", id as CVarArg)

        do {
            let results = try coreDataManager.viewContext.fetch(request)
            for itemEntity in results {
                coreDataManager.viewContext.delete(itemEntity)
            }
            saveData()
            loadData()

            // Notify after data is fully loaded
            NotificationCenter.default.post(name: NSNotification.Name("ItemDataChanged"), object: nil)
        } catch {
            print("Failed to delete item: \(error)")
        }
    }

    func getItems(forListId listId: UUID) -> [Item] {
        let request: NSFetchRequest<ItemEntity> = ItemEntity.fetchRequest()
        request.predicate = NSPredicate(format: "list.id == %@", listId as CVarArg)
        // Sort by orderNumber to ensure consistent display order
        request.sortDescriptors = [NSSortDescriptor(keyPath: \ItemEntity.orderNumber, ascending: true)]

        do {
            let itemEntities = try coreDataManager.viewContext.fetch(request)
            return itemEntities.map { $0.toItem() }
        } catch {
            print("Failed to fetch items: \(error)")
            return []
        }
    }
}
