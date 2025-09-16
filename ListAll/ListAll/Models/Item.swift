//
//  Item.swift
//  ListAll
//
//  Created by Sutela Aleksi on 15.9.2025.
//

import Foundation

// MARK: - Item Model
struct Item: Identifiable, Codable, Equatable {
    let id: UUID
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