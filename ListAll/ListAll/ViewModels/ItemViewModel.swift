import Foundation
import SwiftUI

class ItemViewModel: ObservableObject {
    @Published var item: Item
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    private let dataManager = DataManager.shared
    
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
}