import Foundation
import CoreData

extension ListEntity {
    func toList() -> List {
        var list = List(name: self.name ?? "Untitled List")
        list.id = self.id ?? UUID()
        list.orderNumber = Int(self.orderNumber)
        list.createdAt = self.createdAt ?? Date()
        list.modifiedAt = self.modifiedAt ?? Date()
        list.items = (self.items?.allObjects as? [ItemEntity])?.map { $0.toItem() }.sorted { $0.orderNumber < $1.orderNumber } ?? []
        return list
    }
    
    static func fromList(_ list: List, context: NSManagedObjectContext) -> ListEntity {
        let listEntity = ListEntity(context: context)
        listEntity.id = list.id
        listEntity.name = list.name
        listEntity.orderNumber = Int32(list.orderNumber)
        listEntity.createdAt = list.createdAt
        listEntity.modifiedAt = list.modifiedAt
        listEntity.isArchived = false
        return listEntity
    }
}
