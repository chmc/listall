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