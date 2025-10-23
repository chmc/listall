import Foundation

// MARK: - List Model
struct List: Identifiable, Codable, Equatable, Hashable {
    var id: UUID
    var name: String
    var orderNumber: Int
    var createdAt: Date
    var modifiedAt: Date
    var isArchived: Bool
    var items: [Item]
    
    init(name: String) {
        self.id = UUID()
        self.name = name
        self.orderNumber = 0
        self.createdAt = Date()
        self.modifiedAt = Date()
        self.isArchived = false
        self.items = []
    }
}

// MARK: - Convenience Methods
extension List {
    
    /// Returns the items as an array sorted by order number
    var sortedItems: [Item] {
        return items.sorted { $0.orderNumber < $1.orderNumber }
    }
    
    /// Returns the count of items in this list
    var itemCount: Int {
        return items.count
    }
    
    /// Returns the count of crossed out items
    var crossedOutItemCount: Int {
        return items.filter { $0.isCrossedOut }.count
    }
    
    /// Returns the count of active (not crossed out) items
    var activeItemCount: Int {
        return itemCount - crossedOutItemCount
    }
    
    /// Updates the modified date
    mutating func updateModifiedDate() {
        modifiedAt = Date()
    }
    
    /// Validates the list data
    func validate() -> Bool {
        guard !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return false
        }
        return true
    }
    
    /// Adds an item to the list
    mutating func addItem(_ item: Item) {
        var newItem = item
        newItem.listId = id
        newItem.orderNumber = itemCount
        items.append(newItem)
        updateModifiedDate()
    }
    
    /// Removes an item from the list
    mutating func removeItem(withId itemId: UUID) {
        items.removeAll { $0.id == itemId }
        updateModifiedDate()
    }
    
    /// Updates an item in the list
    mutating func updateItem(_ updatedItem: Item) {
        if let index = items.firstIndex(where: { $0.id == updatedItem.id }) {
            items[index] = updatedItem
            updateModifiedDate()
        }
    }
}

// MARK: - Sync Data Model (for WatchConnectivity)

/// Lightweight version of List for WatchConnectivity sync (excludes image data to reduce size)
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