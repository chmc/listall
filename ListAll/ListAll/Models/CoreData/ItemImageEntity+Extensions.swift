import Foundation
import CoreData

extension ItemImageEntity {
    func toItemImage() -> ItemImage {
        var itemImage = ItemImage()
        itemImage.id = self.id ?? UUID()
        itemImage.imageData = self.imageData
        itemImage.orderNumber = Int(self.orderNumber)
        itemImage.createdAt = self.createdAt ?? Date()
        itemImage.itemId = self.item?.id
        return itemImage
    }
    
    static func fromItemImage(_ itemImage: ItemImage, context: NSManagedObjectContext) -> ItemImageEntity {
        let itemImageEntity = ItemImageEntity(context: context)
        itemImageEntity.id = itemImage.id
        itemImageEntity.imageData = itemImage.imageData
        itemImageEntity.orderNumber = Int32(itemImage.orderNumber)
        itemImageEntity.createdAt = itemImage.createdAt
        return itemImageEntity
    }
}
