import Foundation
import CoreData

extension ItemEntity {
    func toItem() -> Item {
        var item = Item(title: self.title ?? "Untitled Item")
        item.id = self.id ?? UUID()
        item.itemDescription = self.itemDescription
        item.quantity = Int(self.quantity)
        item.orderNumber = Int(self.orderNumber)
        item.isCrossedOut = self.isCrossedOut
        item.createdAt = self.createdAt ?? Date()
        item.modifiedAt = self.modifiedAt ?? Date()
        item.listId = self.list?.id
        item.images = (self.images?.allObjects as? [ItemImageEntity])?.map { $0.toItemImage() }.sorted { $0.orderNumber < $1.orderNumber } ?? []
        return item
    }
    
    static func fromItem(_ item: Item, context: NSManagedObjectContext) -> ItemEntity {
        let itemEntity = ItemEntity(context: context)
        itemEntity.id = item.id
        itemEntity.title = item.title
        itemEntity.itemDescription = item.itemDescription
        itemEntity.quantity = Int32(item.quantity)
        itemEntity.orderNumber = Int32(item.orderNumber)
        itemEntity.isCrossedOut = item.isCrossedOut
        itemEntity.createdAt = item.createdAt
        itemEntity.modifiedAt = item.modifiedAt
        return itemEntity
    }
}
