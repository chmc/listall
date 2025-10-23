import Foundation
import CoreData

extension ListEntity {
    func toList() -> List {
        var list = List(name: self.name ?? "Untitled List")
        list.id = self.id ?? UUID()
        list.orderNumber = Int(self.orderNumber)
        list.createdAt = self.createdAt ?? Date()
        list.modifiedAt = self.modifiedAt ?? Date()
        list.isArchived = self.isArchived
        
        // CRITICAL FIX: Query items directly instead of relying on relationship
        // The relationship might be empty if CloudKit is still importing items in background
        guard let listId = self.id, let context = self.managedObjectContext else {
            list.items = []
            return list
        }
        
        let itemRequest: NSFetchRequest<ItemEntity> = ItemEntity.fetchRequest()
        itemRequest.predicate = NSPredicate(format: "list.id == %@", listId as CVarArg)
        itemRequest.sortDescriptors = [NSSortDescriptor(keyPath: \ItemEntity.orderNumber, ascending: true)]
        
        do {
            let itemEntities = try context.fetch(itemRequest)
            list.items = itemEntities.map { $0.toItem() }
            
            // Log if relationship count differs from query count (CloudKit sync timing issue)
            #if DEBUG
            let relationshipCount = self.items?.count ?? 0
            let queryCount = itemEntities.count
            if relationshipCount != queryCount {
                print("⚠️ List '\(self.name ?? "Unknown")': Relationship has \(relationshipCount) items, but query found \(queryCount) items")
                print("   → This indicates CloudKit is still syncing or relationship is broken")
            }
            #endif
        } catch {
            print("❌ Failed to fetch items for list '\(self.name ?? "Unknown")': \(error)")
            // Fallback to relationship if query fails
            let itemEntities = self.items?.allObjects as? [ItemEntity]
            list.items = itemEntities?.map { $0.toItem() }.sorted { $0.orderNumber < $1.orderNumber } ?? []
        }
        
        return list
    }
    
    static func fromList(_ list: List, context: NSManagedObjectContext) -> ListEntity {
        let listEntity = ListEntity(context: context)
        listEntity.id = list.id
        listEntity.name = list.name
        listEntity.orderNumber = Int32(list.orderNumber)
        listEntity.createdAt = list.createdAt
        listEntity.modifiedAt = list.modifiedAt
        listEntity.isArchived = list.isArchived
        return listEntity
    }
}
