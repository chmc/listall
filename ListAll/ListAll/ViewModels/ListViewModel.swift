import Foundation
// import CoreData // Removed CoreData import
import SwiftUI

class ListViewModel: ObservableObject {
    @Published var items: [Item] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    private let dataManager = DataManager.shared // Changed from coreDataManager
    // private let viewContext: NSManagedObjectContext // Removed viewContext
    private let list: List
    
    init(list: List) {
        self.list = list
        // self.viewContext = coreDataManager.container.viewContext // Removed CoreData initialization
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
}
