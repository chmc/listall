import Foundation

/// Lightweight versions of List/Item models for WatchConnectivity sync
/// These exclude image data to reduce transfer size (<256KB limit)

// MARK: - Sync Models

struct ListSyncData: Codable {
    let id: UUID
    let name: String
    let orderNumber: Int
    let createdAt: Date
    let modifiedAt: Date
    let isArchived: Bool
    let items: [ItemSyncData]
    
    /// Convert from full List model (strips images)
    init(from list: List) {
        self.id = list.id
        self.name = list.name
        self.orderNumber = list.orderNumber
        self.createdAt = list.createdAt
        self.modifiedAt = list.modifiedAt
        self.isArchived = list.isArchived
        self.items = list.items.map { ItemSyncData(from: $0) }
    }
    
    /// Convert to full List model (without images)
    func toList() -> List {
        var list = List(name: self.name)
        list.id = self.id
        list.orderNumber = self.orderNumber
        list.createdAt = self.createdAt
        list.modifiedAt = self.modifiedAt
        list.isArchived = self.isArchived
        list.items = self.items.map { $0.toItem() }
        return list
    }
}

struct ItemSyncData: Codable {
    let id: UUID
    let title: String
    let itemDescription: String?
    let quantity: Int
    let orderNumber: Int
    let isCrossedOut: Bool
    let createdAt: Date
    let modifiedAt: Date
    let listId: UUID?
    let imageCount: Int // Just track count, not actual images
    
    /// Convert from full Item model (strips image data)
    init(from item: Item) {
        self.id = item.id
        self.title = item.title
        self.itemDescription = item.itemDescription
        self.quantity = item.quantity
        self.orderNumber = item.orderNumber
        self.isCrossedOut = item.isCrossedOut
        self.createdAt = item.createdAt
        self.modifiedAt = item.modifiedAt
        self.listId = item.listId
        self.imageCount = item.images.count
    }
    
    /// Convert to full Item model (without images)
    func toItem() -> Item {
        var item = Item(title: self.title, listId: self.listId)
        item.id = self.id
        item.itemDescription = self.itemDescription
        item.quantity = self.quantity
        item.orderNumber = self.orderNumber
        item.isCrossedOut = self.isCrossedOut
        item.createdAt = self.createdAt
        item.modifiedAt = self.modifiedAt
        item.images = [] // Images not synced via WatchConnectivity
        return item
    }
}

