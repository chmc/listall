//
//  ValidationHelper.swift
//  ListAll
//
//  Created by Sutela Aleksi on 15.9.2025.
//

import Foundation

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
    static func validateItemDescription(_ description: String) -> ValidationResult {
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
