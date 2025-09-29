import Foundation
// import CoreData // Removed CoreData import
import SwiftUI

class ListViewModel: ObservableObject {
    @Published var items: [Item] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var showCrossedOutItems = true
    
    private let dataManager = DataManager.shared // Changed from coreDataManager
    private let dataRepository = DataRepository()
    // private let viewContext: NSManagedObjectContext // Removed viewContext
    private let list: List
    
    init(list: List) {
        self.list = list
        // self.viewContext = coreDataManager.container.viewContext // Removed CoreData initialization
        loadUserPreferences()
        loadItems()
    }
    
    func loadItems() {
        isLoading = true
        errorMessage = nil
        
        // Simulate fetching from DataManager
        items = dataManager.getItems(forListId: list.id)
        
        isLoading = false
    }
    
    func save() {
        // dataManager.save() // DataManager now handles its own persistence implicitly for simple models
        // For now, we'll just update the items in the DataManager
        for item in items {
            dataManager.updateItem(item)
        }
    }
    
    // MARK: - Item Management Operations
    
    func createItem(title: String, description: String = "", quantity: Int = 1) {
        let _ = dataRepository.createItem(in: list, title: title, description: description, quantity: quantity)
        loadItems() // Refresh the list
    }
    
    func deleteItem(_ item: Item) {
        dataRepository.deleteItem(item)
        loadItems() // Refresh the list
    }
    
    func duplicateItem(_ item: Item) {
        let _ = dataRepository.createItem(
            in: list,
            title: "\(item.title) (Copy)",
            description: item.itemDescription ?? "",
            quantity: item.quantity
        )
        loadItems() // Refresh the list
    }
    
    func toggleItemCrossedOut(_ item: Item) {
        dataRepository.toggleItemCrossedOut(item)
        loadItems() // Refresh the list
    }
    
    func updateItem(_ item: Item, title: String, description: String, quantity: Int) {
        dataRepository.updateItem(item, title: title, description: description, quantity: quantity)
        loadItems() // Refresh the list
    }
    
    func reorderItems(from sourceIndex: Int, to destinationIndex: Int) {
        dataRepository.reorderItems(in: list, from: sourceIndex, to: destinationIndex)
        loadItems() // Refresh the list
    }
    
    func moveItems(from source: IndexSet, to destination: Int) {
        // Handle the SwiftUI List onMove callback
        guard let sourceIndex = source.first else { return }
        let destinationIndex = destination > sourceIndex ? destination - 1 : destination
        reorderItems(from: sourceIndex, to: destinationIndex)
    }
    
    // MARK: - Utility Methods
    
    func refreshItems() {
        loadItems()
    }
    
    var sortedItems: [Item] {
        return items.sorted { $0.orderNumber < $1.orderNumber }
    }
    
    var activeItems: [Item] {
        return items.filter { !$0.isCrossedOut }
    }
    
    var completedItems: [Item] {
        return items.filter { $0.isCrossedOut }
    }
    
    /// Returns filtered items based on the showCrossedOutItems setting
    var filteredItems: [Item] {
        if showCrossedOutItems {
            return items
        } else {
            return activeItems
        }
    }
    
    // MARK: - User Preferences
    
    func loadUserPreferences() {
        // Load user preferences from DataRepository
        if let userData = dataRepository.getUserData() {
            showCrossedOutItems = userData.showCrossedOutItems
        }
    }
    
    func toggleShowCrossedOutItems() {
        showCrossedOutItems.toggle()
        saveUserPreferences()
    }
    
    private func saveUserPreferences() {
        // Save user preferences to DataRepository
        var userData = dataRepository.getUserData() ?? UserData(userID: "default")
        userData.showCrossedOutItems = showCrossedOutItems
        dataRepository.saveUserData(userData)
    }
}
