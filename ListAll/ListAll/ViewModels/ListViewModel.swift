import Foundation
// import CoreData // Removed CoreData import
import SwiftUI
import Combine

class ListViewModel: ObservableObject {
    @Published var items: [Item] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var showCrossedOutItems = true
    
    // Item Organization Properties
    @Published var currentSortOption: ItemSortOption = .orderNumber
    @Published var currentSortDirection: SortDirection = .ascending
    @Published var currentFilterOption: ItemFilterOption = .active
    @Published var showingOrganizationOptions = false
    
    // Undo Complete Properties
    @Published var recentlyCompletedItem: Item?
    @Published var showUndoButton = false
    
    private let dataManager = DataManager.shared // Changed from coreDataManager
    private let dataRepository = DataRepository()
    // private let viewContext: NSManagedObjectContext // Removed viewContext
    private let list: List
    private var undoTimer: Timer?
    private let undoTimeout: TimeInterval = 5.0 // 5 seconds standard timeout
    
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
        // Check if item is being completed (not already crossed out)
        let wasCompleted = item.isCrossedOut
        let itemId = item.id
        
        dataRepository.toggleItemCrossedOut(item)
        loadItems() // Refresh the list
        
        // Show undo button only when completing an item (not when uncompleting)
        if !wasCompleted, let refreshedItem = items.first(where: { $0.id == itemId }) {
            showUndoForCompletedItem(refreshedItem)
        }
    }
    
    // MARK: - Undo Complete Functionality
    
    private func showUndoForCompletedItem(_ item: Item) {
        // Cancel any existing timer
        undoTimer?.invalidate()
        
        // Store the completed item
        recentlyCompletedItem = item
        showUndoButton = true
        
        // Set up timer to hide undo button after timeout
        undoTimer = Timer.scheduledTimer(withTimeInterval: undoTimeout, repeats: false) { [weak self] _ in
            self?.hideUndoButton()
        }
    }
    
    func undoComplete() {
        guard let item = recentlyCompletedItem else { return }
        
        // Directly toggle the item back to incomplete without triggering undo logic
        dataRepository.toggleItemCrossedOut(item)
        
        // Hide undo button immediately BEFORE loading items
        hideUndoButton()
        
        loadItems() // Refresh the list
    }
    
    private func hideUndoButton() {
        undoTimer?.invalidate()
        undoTimer = nil
        showUndoButton = false
        recentlyCompletedItem = nil
    }
    
    deinit {
        undoTimer?.invalidate()
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
        // IMPORTANT: source and destination are indices in filteredItems, 
        // but we need to map them to indices in the full items array
        
        guard let filteredSourceIndex = source.first else { return }
        
        // Get the actual items from filteredItems
        let movedItem = filteredItems[filteredSourceIndex]
        
        // Calculate destination in filtered array
        let filteredDestIndex = destination > filteredSourceIndex ? destination - 1 : destination
        let destinationItem = filteredDestIndex < filteredItems.count ? filteredItems[filteredDestIndex] : filteredItems.last
        
        // Find the actual indices in the full items array
        guard let actualSourceIndex = items.firstIndex(where: { $0.id == movedItem.id }) else { return }
        
        // For destination, we need to find where to insert relative to the destination item
        let actualDestIndex: Int
        if let destItem = destinationItem,
           let destIndex = items.firstIndex(where: { $0.id == destItem.id }) {
            actualDestIndex = destIndex
        } else {
            // If no destination item (moving to end), use the last index
            actualDestIndex = items.count - 1
        }
        
        reorderItems(from: actualSourceIndex, to: actualDestIndex)
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
    
    /// Returns filtered and sorted items based on current organization settings
    var filteredItems: [Item] {
        // First apply filtering
        let filtered = applyFilter(to: items)
        
        // Then apply sorting
        return applySorting(to: filtered)
    }
    
    // MARK: - Item Organization Methods
    
    private func applyFilter(to items: [Item]) -> [Item] {
        switch currentFilterOption {
        case .all:
            // Respect the showCrossedOutItems setting for the "all" filter
            if showCrossedOutItems {
                return items
            } else {
                return items.filter { !$0.isCrossedOut }
            }
        case .active:
            return items.filter { !$0.isCrossedOut }
        case .completed:
            return items.filter { $0.isCrossedOut }
        case .hasDescription:
            return items.filter { $0.hasDescription }
        case .hasImages:
            return items.filter { $0.hasImages }
        }
    }
    
    private func applySorting(to items: [Item]) -> [Item] {
        let sorted = items.sorted { item1, item2 in
            switch currentSortOption {
            case .orderNumber:
                return item1.orderNumber < item2.orderNumber
            case .title:
                return item1.title.localizedCaseInsensitiveCompare(item2.title) == .orderedAscending
            case .createdAt:
                return item1.createdAt < item2.createdAt
            case .modifiedAt:
                return item1.modifiedAt < item2.modifiedAt
            case .quantity:
                return item1.quantity < item2.quantity
            }
        }
        
        return currentSortDirection == .ascending ? sorted : sorted.reversed()
    }
    
    // MARK: - User Preferences
    
    func loadUserPreferences() {
        // Load user preferences from DataRepository
        if let userData = dataRepository.getUserData() {
            showCrossedOutItems = userData.showCrossedOutItems
            currentSortOption = userData.defaultSortOption
            currentSortDirection = userData.defaultSortDirection
            currentFilterOption = userData.defaultFilterOption
        } else {
            // Apply default preferences for new users
            let defaultUserData = UserData(userID: "default")
            showCrossedOutItems = defaultUserData.showCrossedOutItems
            currentSortOption = defaultUserData.defaultSortOption
            currentSortDirection = defaultUserData.defaultSortDirection
            currentFilterOption = defaultUserData.defaultFilterOption
        }
    }
    
    func toggleShowCrossedOutItems() {
        showCrossedOutItems.toggle()
        
        // Synchronize the filter option with the eye button state
        if showCrossedOutItems {
            // When showing crossed out items, switch to "All Items" filter
            currentFilterOption = .all
        } else {
            // When hiding crossed out items, switch to "Active Only" filter
            currentFilterOption = .active
        }
        
        saveUserPreferences()
    }
    
    func updateSortOption(_ sortOption: ItemSortOption) {
        currentSortOption = sortOption
        saveUserPreferences()
    }
    
    func updateSortDirection(_ direction: SortDirection) {
        currentSortDirection = direction
        saveUserPreferences()
    }
    
    func updateFilterOption(_ filterOption: ItemFilterOption) {
        currentFilterOption = filterOption
        // Update the legacy showCrossedOutItems based on filter
        if filterOption == .completed {
            showCrossedOutItems = true
        } else if filterOption == .active {
            showCrossedOutItems = false
        } else if filterOption == .all {
            showCrossedOutItems = true
        }
        // For other filters (.hasDescription, .hasImages), keep current showCrossedOutItems state
        saveUserPreferences()
    }
    
    private func saveUserPreferences() {
        // Save user preferences to DataRepository
        var userData = dataRepository.getUserData() ?? UserData(userID: "default")
        userData.showCrossedOutItems = showCrossedOutItems
        userData.defaultSortOption = currentSortOption
        userData.defaultSortDirection = currentSortDirection
        userData.defaultFilterOption = currentFilterOption
        dataRepository.saveUserData(userData)
    }
}
