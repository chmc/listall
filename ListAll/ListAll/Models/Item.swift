import Foundation

// MARK: - Item Sorting Options
enum ItemSortOption: String, CaseIterable, Identifiable, Codable {
    case orderNumber = "Order"
    case title = "Title"
    case createdAt = "Created Date"
    case modifiedAt = "Modified Date"
    case quantity = "Quantity"
    
    var id: String { rawValue }
    
    var systemImage: String {
        switch self {
        case .orderNumber:
            return "list.number"
        case .title:
            return "textformat.abc"
        case .createdAt:
            return "calendar"
        case .modifiedAt:
            return "clock"
        case .quantity:
            return "number"
        }
    }
}

// MARK: - Item Filter Options
enum ItemFilterOption: String, CaseIterable, Identifiable, Codable {
    case all = "All Items"
    case active = "Active Only"
    case completed = "Crossed Out Only"
    case hasDescription = "With Description"
    case hasImages = "With Images"
    
    var id: String { rawValue }
    
    var systemImage: String {
        switch self {
        case .all:
            return "list.bullet"
        case .active:
            return "circle"
        case .completed:
            return "checkmark.circle.fill"
        case .hasDescription:
            return "text.alignleft"
        case .hasImages:
            return "photo"
        }
    }
}

// MARK: - Sort Direction
enum SortDirection: String, CaseIterable, Identifiable, Codable {
    case ascending = "Ascending"
    case descending = "Descending"
    
    var id: String { rawValue }
    
    var systemImage: String {
        switch self {
        case .ascending:
            return "arrow.up"
        case .descending:
            return "arrow.down"
        }
    }
}

// MARK: - Item Model
struct Item: Identifiable, Codable, Equatable, Hashable {
    var id: UUID
    var title: String
    var itemDescription: String?
    var quantity: Int
    var orderNumber: Int
    var isCrossedOut: Bool
    var createdAt: Date
    var modifiedAt: Date
    var listId: UUID?
    var images: [ItemImage]
    
    init(title: String, listId: UUID? = nil) {
        self.id = UUID()
        self.title = title
        self.itemDescription = nil
        self.quantity = 1
        self.orderNumber = 0
        self.isCrossedOut = false
        self.createdAt = Date()
        self.modifiedAt = Date()
        self.listId = listId
        self.images = []
    }
}

// MARK: - Convenience Methods
extension Item {
    
    /// Returns the images as an array sorted by order number
    var sortedImages: [ItemImage] {
        return images.sorted { $0.orderNumber < $1.orderNumber }
    }
    
    /// Returns the count of images for this item
    var imageCount: Int {
        return images.count
    }
    
    /// Returns true if the item has images
    var hasImages: Bool {
        return imageCount > 0
    }
    
    /// Returns the display title or a default value
    var displayTitle: String {
        return title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "Untitled Item" : title
    }
    
    /// Returns the display description or empty string
    var displayDescription: String {
        return itemDescription?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    }
    
    /// Returns true if the item has a description
    var hasDescription: Bool {
        return !displayDescription.isEmpty
    }
    
    /// Updates the modified date
    mutating func updateModifiedDate() {
        modifiedAt = Date()
    }
    
    /// Toggles the crossed out state
    mutating func toggleCrossedOut() {
        isCrossedOut.toggle()
        updateModifiedDate()
    }
    
    /// Validates the item data
    func validate() -> Bool {
        guard !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return false
        }
        guard quantity > 0 else {
            return false
        }
        return true
    }
    
    /// Returns a formatted quantity string
    var formattedQuantity: String {
        if quantity == 1 {
            return ""
        } else {
            return "\(quantity)x"
        }
    }
}