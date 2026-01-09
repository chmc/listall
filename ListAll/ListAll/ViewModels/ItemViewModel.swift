import Foundation
import SwiftUI
import Combine

class ItemViewModel: ObservableObject {
    @Published var item: Item
    @Published var isLoading = false
    @Published var errorMessage: String?

    /// Data manager instance - uses dependency injection for testability
    /// Production code uses default (DataManager.shared), tests can inject mock
    private let dataManager: any DataManaging
    private lazy var dataRepository: DataRepository = DataRepository()

    /// Initialize with item and optional data manager injection for testing
    /// - Parameters:
    ///   - item: The item to manage
    ///   - dataManager: DataManaging instance (defaults to DataManager.shared)
    init(item: Item, dataManager: any DataManaging = DataManager.shared) {
        self.item = item
        self.dataManager = dataManager
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