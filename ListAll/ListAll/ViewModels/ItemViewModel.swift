import Foundation
import SwiftUI
import Combine

class ItemViewModel: ObservableObject {
    @Published var item: Item
    @Published var isLoading = false
    @Published var errorMessage: String?

    // Lazy initialization to avoid accessing Core Data during unit tests
    // On unsigned macOS builds, eager DataManager/DataRepository access crashes
    // because App Groups require sandbox permissions
    private lazy var dataManager: DataManager = DataManager.shared
    private lazy var dataRepository: DataRepository = DataRepository()

    init(item: Item) {
        self.item = item
    }
    
    func save() {
        dataManager.updateItem(item)
    }
    
    func toggleCrossedOut() {
        var updatedItem = item
        updatedItem.toggleCrossedOut()
        dataManager.updateItem(updatedItem)
        self.item = updatedItem
    }
    
    func updateItem(title: String, description: String, quantity: Int) {
        var updatedItem = item
        updatedItem.title = title
        updatedItem.itemDescription = description.isEmpty ? nil : description
        updatedItem.quantity = quantity
        updatedItem.updateModifiedDate()
        dataManager.updateItem(updatedItem)
        self.item = updatedItem
    }
    
    // MARK: - Item Management Operations
    
    func duplicateItem(in list: List) -> Item? {
        guard item.listId != nil else { return nil }
        
        let duplicatedItem = dataRepository.createItem(
            in: list,
            title: "\(item.title) (Copy)",
            description: item.itemDescription ?? "",
            quantity: item.quantity
        )
        
        return duplicatedItem
    }
    
    func deleteItem() {
        dataRepository.deleteItem(item)
    }
    
    // MARK: - Validation
    
    func validateItem() -> ValidationResult {
        return dataRepository.validateItem(item)
    }
    
    // MARK: - Utility Methods
    
    func refreshItem() {
        if let refreshedItem = dataRepository.getItem(by: item.id) {
            self.item = refreshedItem
        }
    }
}