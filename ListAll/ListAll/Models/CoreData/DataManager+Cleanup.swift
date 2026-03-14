import Foundation
import CoreData

// MARK: - Data Cleanup

extension DataManager {

    /// Remove duplicate lists from Core Data (cleanup for CloudKit sync bug)
    /// This removes lists with duplicate IDs, keeping the most recently modified version
    func removeDuplicateLists() {
        let context = coreDataManager.viewContext
        let request: NSFetchRequest<ListEntity> = ListEntity.fetchRequest()

        do {
            let allLists = try context.fetch(request)

            // Group lists by ID
            var listsById: [UUID: [ListEntity]] = [:]
            for list in allLists {
                guard let id = list.id else { continue }
                if listsById[id] == nil {
                    listsById[id] = []
                }
                listsById[id]?.append(list)
            }

            // Find and remove duplicates
            var duplicatesRemoved = 0
            for (_, lists) in listsById {
                if lists.count > 1 {
                    // Sort by modifiedAt, keep most recent
                    let sorted = lists.sorted { ($0.modifiedAt ?? Date.distantPast) > ($1.modifiedAt ?? Date.distantPast) }
                    let toKeep = sorted.first!
                    let toRemove = sorted.dropFirst()

                    for duplicate in toRemove {
                        // Delete items in duplicate list first
                        if let items = duplicate.items as? Set<ItemEntity> {
                            for item in items {
                                // Transfer items to the list we're keeping
                                item.list = toKeep
                            }
                        }
                        context.delete(duplicate)
                        duplicatesRemoved += 1
                    }
                }
            }

            if duplicatesRemoved > 0 {
                saveData()
                loadData() // Reload to reflect changes
            }
        } catch {
            print("❌ Failed to check for duplicate lists: \(error)")
        }
    }

    /// Remove duplicate items from Core Data (cleanup for sync bug)
    /// This removes items with duplicate IDs, keeping the most recently modified version
    func removeDuplicateItems() {
        let context = coreDataManager.viewContext
        let request: NSFetchRequest<ItemEntity> = ItemEntity.fetchRequest()

        do {
            let allItems = try context.fetch(request)

            // Group items by ID
            var itemsById: [UUID: [ItemEntity]] = [:]
            for item in allItems {
                guard let id = item.id else { continue }
                if itemsById[id] == nil {
                    itemsById[id] = []
                }
                itemsById[id]?.append(item)
            }

            // Find and remove duplicates
            var duplicatesRemoved = 0
            for (_, items) in itemsById {
                if items.count > 1 {
                    // Sort by modifiedAt, keep most recent
                    let sorted = items.sorted { ($0.modifiedAt ?? Date.distantPast) > ($1.modifiedAt ?? Date.distantPast) }
                    // Keep the most recent, remove the rest
                    let toRemove = sorted.dropFirst()

                    for duplicate in toRemove {
                        context.delete(duplicate)
                        duplicatesRemoved += 1
                    }
                }
            }

            if duplicatesRemoved > 0 {
                saveData()
                loadData() // Reload to reflect changes
            }
        } catch {
            print("❌ Failed to check for duplicate items: \(error)")
        }
    }
}
