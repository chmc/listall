import Foundation
import UIKit

struct ValidationHelper {
    
    /// Validates a list name
    static func validateListName(_ name: String) -> ValidationResult {
        let trimmedName = name.trimmed
        
        if trimmedName.isEmpty {
            return .failure("List name cannot be empty")
        }
        
        if trimmedName.count > 100 {
            return .failure("List name must be 100 characters or less")
        }
        
        return .success
    }
    
    /// Validates an item title
    static func validateItemTitle(_ title: String) -> ValidationResult {
        let trimmedTitle = title.trimmed
        
        if trimmedTitle.isEmpty {
            return .failure("Item title cannot be empty")
        }
        
        if trimmedTitle.count > 200 {
            return .failure("Item title must be 200 characters or less")
        }
        
        return .success
    }
    
    /// Validates an item description
    static func validateItemDescription(_ description: String?) -> ValidationResult {
        guard let description = description else { return .success }
        
        if description.count > 1000 {
            return .failure("Item description must be 1000 characters or less")
        }
        
        return .success
    }
    
    /// Validates an item quantity
    static func validateItemQuantity(_ quantity: Int32) -> ValidationResult {
        if quantity < 1 {
            return .failure("Quantity must be at least 1")
        }
        
        if quantity > 9999 {
            return .failure("Quantity must be 9999 or less")
        }
        
        return .success
    }
    
    /// Validates image data
    static func validateImageData(_ imageData: Data?) -> ValidationResult {
        guard let imageData = imageData else {
            return .failure("Image data is required")
        }
        
        if imageData.isEmpty {
            return .failure("Image data cannot be empty")
        }
        
        if imageData.count > 5 * 1024 * 1024 { // 5MB limit
            return .failure("Image size must be 5MB or less")
        }
        
        // Validate that it's actually image data
        guard UIImage(data: imageData) != nil else {
            return .failure("Invalid image format")
        }
        
        return .success
    }
    
    /// Validates image count per item
    static func validateImageCount(_ count: Int) -> ValidationResult {
        if count > 10 {
            return .failure("Maximum 10 images per item")
        }
        
        return .success
    }
    
    /// Validates user ID
    static func validateUserID(_ userID: String) -> ValidationResult {
        if userID.isEmpty {
            return .failure("User ID cannot be empty")
        }
        
        if userID.count > 100 {
            return .failure("User ID must be 100 characters or less")
        }
        
        return .success
    }
    
    /// Validates order numbers
    static func validateOrderNumber(_ orderNumber: Int) -> ValidationResult {
        if orderNumber < 0 {
            return .failure("Order number must be non-negative")
        }
        
        return .success
    }
    
    /// Validates export preferences data
    static func validateExportPreferences(_ data: Data?) -> ValidationResult {
        guard let data = data else { return .success }
        
        // Validate that it's valid JSON
        do {
            _ = try JSONSerialization.jsonObject(with: data)
            return .success
        } catch {
            return .failure("Invalid export preferences format")
        }
    }
    
    // MARK: - Combined Validation
    
    /// Validates a complete list
    static func validateList(_ list: List) -> [ValidationResult] {
        var results: [ValidationResult] = []
        
        results.append(validateListName(list.name))
        results.append(validateOrderNumber(list.orderNumber))
        
        return results
    }
    
    /// Validates a complete item
    static func validateItem(_ item: Item) -> [ValidationResult] {
        var results: [ValidationResult] = []
        
        results.append(validateItemTitle(item.title))
        results.append(validateItemDescription(item.itemDescription))
        results.append(validateItemQuantity(Int32(item.quantity)))
        results.append(validateOrderNumber(item.orderNumber))
        results.append(validateImageCount(item.images.count))
        
        // Validate each image
        for image in item.images {
            results.append(validateImageData(image.imageData))
        }
        
        return results
    }
    
    /// Validates a complete user data object
    static func validateUserData(_ userData: UserData) -> [ValidationResult] {
        var results: [ValidationResult] = []
        
        results.append(validateUserID(userData.userID))
        results.append(validateExportPreferences(userData.exportPreferences))
        
        return results
    }
    
    // MARK: - Business Rules Validation
    
    /// Validates list business rules against existing lists
    static func validateListBusinessRules(_ list: List, existingLists: [List]) -> [ValidationResult] {
        var results: [ValidationResult] = []
        
        // Check for duplicate names (case insensitive)
        let duplicateNames = existingLists.filter { 
            $0.id != list.id && 
            $0.name.lowercased() == list.name.lowercased() 
        }
        
        if !duplicateNames.isEmpty {
            results.append(.failure("A list with this name already exists"))
        }
        
        // Check for duplicate order numbers
        let duplicateOrders = existingLists.filter { 
            $0.id != list.id && 
            $0.orderNumber == list.orderNumber 
        }
        
        if !duplicateOrders.isEmpty {
            results.append(.failure("Order number \(list.orderNumber) is already in use"))
        }
        
        return results
    }
    
    /// Validates item business rules against existing items
    static func validateItemBusinessRules(_ item: Item, existingItems: [Item]) -> [ValidationResult] {
        var results: [ValidationResult] = []
        
        // Check for duplicate order numbers within the same list
        let duplicateOrders = existingItems.filter { 
            $0.id != item.id && 
            $0.listId == item.listId && 
            $0.orderNumber == item.orderNumber 
        }
        
        if !duplicateOrders.isEmpty {
            results.append(.failure("Order number \(item.orderNumber) is already in use in this list"))
        }
        
        return results
    }
    
    /// Validates data integrity across all lists
    static func validateDataIntegrity(lists: [List]) -> [ValidationResult] {
        var results: [ValidationResult] = []
        
        // Check for orphaned items
        let allItemIds = Set(lists.flatMap { $0.items.map { $0.id } })
        let allListIds = Set(lists.map { $0.id })
        
        for list in lists {
            for item in list.items {
                if let listId = item.listId, !allListIds.contains(listId) {
                    results.append(.failure("Item '\(item.title)' references non-existent list"))
                }
                
                // Check for orphaned images
                for image in item.images {
                    if let itemId = image.itemId, !allItemIds.contains(itemId) {
                        results.append(.failure("Image references non-existent item"))
                    }
                }
            }
        }
        
        return results
    }
}

enum ValidationResult {
    case success
    case failure(String)
    
    var isValid: Bool {
        switch self {
        case .success:
            return true
        case .failure:
            return false
        }
    }
    
    var errorMessage: String? {
        switch self {
        case .success:
            return nil
        case .failure(let message):
            return message
        }
    }
}
