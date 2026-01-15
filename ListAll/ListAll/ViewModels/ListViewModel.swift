import Foundation
// import CoreData // Removed CoreData import
import SwiftUI
import Combine
#if os(iOS)
import WatchConnectivity
#endif

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
    
    // Search Properties
    @Published var searchText: String = ""
    
    // Undo Complete Properties
    @Published var recentlyCompletedItem: Item?
    @Published var showUndoButton = false
    
    // Undo Delete Properties (Single Item)
    @Published var recentlyDeletedItem: Item?
    @Published var showDeleteUndoButton = false

    // Undo Bulk Delete Properties (Multiple Items)
    @Published var recentlyDeletedItems: [Item]?
    @Published var showBulkDeleteUndoBanner = false

    // Multi-Selection Properties
    @Published var isInSelectionMode = false
    @Published var selectedItems: Set<UUID> = []
    @Published var lastSelectedItemID: UUID?  // Anchor point for Shift+Click range selection
    
    // Watch sync properties
    @Published var isSyncingFromWatch = false

    /// Data manager instance - uses dependency injection for testability
    /// Production code uses default (DataManager.shared), tests can inject mock
    private let dataManager: any DataManaging
    private lazy var dataRepository = DataRepository()
    // private let viewContext: NSManagedObjectContext // Removed viewContext
    private let list: List
    private var undoTimer: Timer?
    private var deleteUndoTimer: Timer?
    private var bulkDeleteUndoTimer: Timer?
    private let undoTimeout: TimeInterval = 5.0 // 5 seconds standard timeout
    private let bulkDeleteUndoTimeout: TimeInterval = 10.0 // 10 seconds for bulk delete per macOS convention
    private lazy var hapticManager = HapticManager.shared

    /// Initialize with list and optional data manager injection for testing
    /// - Parameters:
    ///   - list: The list to display items for
    ///   - dataManager: DataManaging instance (defaults to DataManager.shared)
    init(list: List, dataManager: any DataManaging = DataManager.shared) {
        self.list = list
        self.dataManager = dataManager
        // self.viewContext = coreDataManager.container.viewContext // Removed CoreData initialization
        loadUserPreferences()
        loadItems()
        #if os(iOS)
        setupWatchConnectivityObserver()
        #endif

        // CRITICAL: Observe CloudKit remote changes (synced from other devices)
        // This ensures items refresh in real-time when macOS or other devices sync changes
        setupRemoteChangeObserver()
    }

    private func setupRemoteChangeObserver() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleRemoteChange(_:)),
            name: .coreDataRemoteChange,
            object: nil
        )
    }

    @objc private func handleRemoteChange(_ notification: Notification) {
        // CRITICAL: @objc selectors can be called from any thread - ensure main thread
        // Without this guard, @Published property updates happen on background thread,
        // causing SwiftUI to silently ignore the changes
        guard Thread.isMainThread else {
            DispatchQueue.main.async { [weak self] in
                self?.handleRemoteChange(notification)
            }
            return
        }

        // Reload items from Core Data to reflect changes made by other devices
        print("🌐 ListViewModel: Received Core Data remote change - refreshing items for list '\(list.name)'")
        loadItems()
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
        undoTimer?.invalidate()
        deleteUndoTimer?.invalidate()
        bulkDeleteUndoTimer?.invalidate()
    }
    
    #if os(iOS)
    // MARK: - Watch Connectivity Integration

    private func setupWatchConnectivityObserver() {
        // Listen for old sync notifications (backward compatibility)
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleWatchSyncNotification(_:)),
            name: NSNotification.Name("WatchConnectivitySyncReceived"),
            object: nil
        )

        // CRITICAL FIX: Listen for new lists data notifications
        // This ensures the list view updates in real-time when watch sends data
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleWatchListsData(_:)),
            name: NSNotification.Name("WatchConnectivityListsDataReceived"),
            object: nil
        )
    }

    @objc private func handleWatchSyncNotification(_ notification: Notification) {
        refreshItemsFromWatch()
    }

    @objc private func handleWatchListsData(_ notification: Notification) {
        // MainViewModel has already updated Core Data at this point
        // We just need to reload items for this list from the updated data
        refreshItemsFromWatch()
    }

    func refreshItemsFromWatch() {
        // Show sync indicator briefly
        isSyncingFromWatch = true

        // Reload items from DataManager (which already has the updated data from Core Data)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            self.loadItems()

            // Hide sync indicator after brief delay
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                self.isSyncingFromWatch = false
            }
        }
    }
    #endif

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
        hapticManager.itemCreated()
    }
    
    func deleteItem(_ item: Item) {
        // Store the item before deleting for undo functionality
        showDeleteUndoForItem(item)
        
        dataRepository.deleteItem(item)
        loadItems() // Refresh the list
        hapticManager.itemDeleted()
    }
    
    func duplicateItem(_ item: Item) {
        let _ = dataRepository.createItem(
            in: list,
            title: "\(item.title) (Copy)",
            description: item.itemDescription ?? "",
            quantity: item.quantity
        )
        loadItems() // Refresh the list
        hapticManager.itemCreated()
    }
    
    func toggleItemCrossedOut(_ item: Item) {
        // Check if item is being completed (not already crossed out)
        let wasCompleted = item.isCrossedOut
        let itemId = item.id
        
        dataRepository.toggleItemCrossedOut(item)
        
        // Use explicit animation for smooth visual feedback
        withAnimation(Theme.Animation.spring) {
            loadItems() // Refresh the list
        }
        
        // Trigger haptic feedback
        if wasCompleted {
            hapticManager.itemUncrossed()
        } else {
            hapticManager.itemCrossed()
        }
        
        // Show undo button only when completing an item (not when uncompleting)
        if !wasCompleted, let refreshedItem = items.first(where: { $0.id == itemId }) {
            showUndoForCompletedItem(refreshedItem)
        }
        
        #if os(iOS)
        // CRITICAL: Sync change to watchOS immediately
        // When user completes/uncompletes an item on iOS, watchOS needs to know about it

        // Send updated lists to watchOS via WatchConnectivity
        WatchConnectivityService.shared.sendListsData(dataManager.lists)
        #endif
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
        
        // Use explicit animation for smooth visual feedback
        withAnimation(Theme.Animation.spring) {
            loadItems() // Refresh the list
        }
    }
    
    func hideUndoButton() {
        undoTimer?.invalidate()
        undoTimer = nil
        showUndoButton = false
        recentlyCompletedItem = nil
    }
    
    // MARK: - Undo Delete Functionality
    
    private func showDeleteUndoForItem(_ item: Item) {
        // Cancel any existing timer
        deleteUndoTimer?.invalidate()
        
        // Store the deleted item
        recentlyDeletedItem = item
        showDeleteUndoButton = true
        
        // Set up timer to hide undo button after timeout
        deleteUndoTimer = Timer.scheduledTimer(withTimeInterval: undoTimeout, repeats: false) { [weak self] _ in
            self?.hideDeleteUndoButton()
        }
    }
    
    func undoDeleteItem() {
        guard let item = recentlyDeletedItem else { return }
        
        // Re-create the item with all its properties using addItemForImport
        // which preserves all item state including isCrossedOut and orderNumber
        dataRepository.addItemForImport(item, to: list.id)
        
        // Hide undo button immediately BEFORE loading items
        hideDeleteUndoButton()
        
        loadItems() // Refresh the list
    }
    
    func hideDeleteUndoButton() {
        deleteUndoTimer?.invalidate()
        deleteUndoTimer = nil
        showDeleteUndoButton = false
        recentlyDeletedItem = nil
    }

    // MARK: - Undo Bulk Delete Functionality (Task 12.8)

    /// Computed property to get the count of recently deleted items for display
    var deletedItemsCount: Int {
        return recentlyDeletedItems?.count ?? 0
    }

    /// Deletes selected items with undo support.
    /// Instead of showing a confirmation dialog, this method stores items for undo
    /// and shows an undo banner for 10 seconds (per macOS convention).
    func deleteSelectedItemsWithUndo() {
        // Guard against empty selection
        guard !selectedItems.isEmpty else { return }

        // Cancel any existing bulk delete undo timer
        bulkDeleteUndoTimer?.invalidate()

        // Store the items before deleting for undo functionality
        let itemsToDelete = items.filter { selectedItems.contains($0.id) }
        recentlyDeletedItems = itemsToDelete

        // Delete each selected item
        for itemId in selectedItems {
            if let item = items.first(where: { $0.id == itemId }) {
                dataRepository.deleteItem(item)
            }
        }

        // Clear selection and exit selection mode
        selectedItems.removeAll()
        exitSelectionMode()

        // Show undo banner
        showBulkDeleteUndoBanner = true

        // Set up timer to hide undo banner after timeout (10 seconds for bulk delete)
        bulkDeleteUndoTimer = Timer.scheduledTimer(withTimeInterval: bulkDeleteUndoTimeout, repeats: false) { [weak self] _ in
            self?.hideBulkDeleteUndoBanner()
        }

        loadItems() // Refresh the list
        hapticManager.itemDeleted()
    }

    /// Restores all items that were bulk deleted
    func undoBulkDelete() {
        guard let deletedItems = recentlyDeletedItems else { return }

        // Re-create each item with all its properties
        for item in deletedItems {
            dataRepository.addItemForImport(item, to: list.id)
        }

        // Hide undo banner immediately BEFORE loading items
        hideBulkDeleteUndoBanner()

        loadItems() // Refresh the list
    }

    /// Hides the bulk delete undo banner and clears the stored items
    func hideBulkDeleteUndoBanner() {
        bulkDeleteUndoTimer?.invalidate()
        bulkDeleteUndoTimer = nil
        showBulkDeleteUndoBanner = false
        recentlyDeletedItems = nil
    }

    func updateItem(_ item: Item, title: String, description: String, quantity: Int) {
        dataRepository.updateItem(item, title: title, description: description, quantity: quantity)
        loadItems() // Refresh the list
    }
    
    func reorderItems(from sourceIndex: Int, to destinationIndex: Int) {
        dataRepository.reorderItems(in: list, from: sourceIndex, to: destinationIndex)
        loadItems() // Refresh the list
        hapticManager.dragDropped()
    }
    
    func moveItems(from source: IndexSet, to destination: Int) {
        // Handle the SwiftUI List onMove callback
        // IMPORTANT: source and destination are indices in filteredItems, 
        // but we need to map them to indices in the full items array
        
        guard let filteredSourceIndex = source.first else { return }
        
        // Get the actual item being dragged from filteredItems
        let draggedItem = filteredItems[filteredSourceIndex]
        
        // Check if we're in selection mode and the dragged item is selected
        if isInSelectionMode && selectedItems.contains(draggedItem.id) {
            // Multi-select drag: Move all selected items together
            moveSelectedItemsToPosition(destination: destination)
        } else {
            // Single item drag: Original behavior
            moveSingleItem(from: filteredSourceIndex, to: destination)
        }
    }
    
    private func moveSingleItem(from filteredSourceIndex: Int, to destination: Int) {
        // Get the actual item from filteredItems
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
    
    private func moveSelectedItemsToPosition(destination: Int) {
        // Get all selected items in their current order
        let selectedItemsList = items.filter { selectedItems.contains($0.id) }
        guard !selectedItemsList.isEmpty else { return }
        
        // Get IDs of selected items for quick lookup
        let selectedIds = Set(selectedItemsList.map { $0.id })
        
        // Find the destination item in filteredItems
        let destinationItem: Item?
        if destination < filteredItems.count {
            destinationItem = filteredItems[destination]
        } else {
            destinationItem = filteredItems.last
        }
        
        // Find where to insert in the full items array
        // We need to calculate the index AFTER removing selected items
        let insertionIndex: Int
        if let destItem = destinationItem {
            // Count how many selected items are before the destination in the full items array
            var countSelectedBeforeDestination = 0
            for item in items {
                if item.id == destItem.id {
                    break
                }
                if selectedIds.contains(item.id) {
                    countSelectedBeforeDestination += 1
                }
            }
            
            // Find the destination item's current index
            if let destIndex = items.firstIndex(where: { $0.id == destItem.id }) {
                // Adjust insertion index by subtracting selected items that will be removed before it
                insertionIndex = destIndex - countSelectedBeforeDestination
            } else {
                insertionIndex = items.count - selectedItemsList.count
            }
        } else {
            // Insert at the end (after removing selected items)
            insertionIndex = items.count - selectedItemsList.count
        }
        
        // Use DataRepository to reorder multiple items as a batch
        dataRepository.reorderMultipleItems(in: list, itemsToMove: selectedItemsList, to: insertionIndex)
        
        // Reload items to reflect the changes
        loadItems()
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
    
    /// Returns filtered and sorted items based on current organization settings and search text
    var filteredItems: [Item] {
        // First apply filtering
        let filtered = applyFilter(to: items)
        
        // Then apply search filtering
        let searchFiltered = applySearch(to: filtered)
        
        // Finally apply sorting
        return applySorting(to: searchFiltered)
    }
    
    // MARK: - Item Organization Methods
    
    private func applySearch(to items: [Item]) -> [Item] {
        // If search text is empty, return all items
        guard !searchText.isEmpty else {
            return items
        }
        
        // Filter items based on search text
        // Search in title and description
        return items.filter { item in
            let titleMatch = item.title.localizedCaseInsensitiveContains(searchText)
            let descriptionMatch = (item.itemDescription ?? "").localizedCaseInsensitiveContains(searchText)
            return titleMatch || descriptionMatch
        }
    }
    
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

    // MARK: - Clear All Filters (Task 12.12)

    /// Whether any filter is active (non-default filter, sort, or search)
    var hasActiveFilters: Bool {
        currentFilterOption != .all ||
        currentSortOption != .orderNumber ||
        currentSortDirection != .ascending ||
        !searchText.isEmpty
    }

    /// Clears all filters, search text, and sort options to default values.
    /// Called by Cmd+Shift+Backspace keyboard shortcut or "Clear All" button.
    func clearAllFilters() {
        searchText = ""
        currentFilterOption = .all
        currentSortOption = .orderNumber
        currentSortDirection = .ascending
        showCrossedOutItems = true  // Sync with .all filter
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
    
    // MARK: - Multi-Selection Methods
    
    /// Toggle selection for a single item (Cmd+Click behavior)
    /// Updates lastSelectedItemID to serve as anchor for range selection
    func toggleSelection(for itemId: UUID) {
        if selectedItems.contains(itemId) {
            selectedItems.remove(itemId)
            // Don't update anchor on deselection
        } else {
            selectedItems.insert(itemId)
            lastSelectedItemID = itemId  // Update anchor point
            hapticManager.itemSelected()
        }
    }

    /// Select a range of items from lastSelectedItemID to targetId (Shift+Click behavior)
    /// Uses filteredItems order for range calculation
    func selectRange(to targetId: UUID) {
        guard let anchorId = lastSelectedItemID,
              let anchorIndex = filteredItems.firstIndex(where: { $0.id == anchorId }),
              let targetIndex = filteredItems.firstIndex(where: { $0.id == targetId }) else {
            // No anchor point - treat as single selection
            selectedItems = [targetId]
            lastSelectedItemID = targetId
            return
        }

        // Calculate range bounds (handles both upward and downward selection)
        let startIndex = min(anchorIndex, targetIndex)
        let endIndex = max(anchorIndex, targetIndex)

        // Select all items in the range
        selectedItems = Set(filteredItems[startIndex...endIndex].map { $0.id })

        // Keep anchor unchanged for subsequent Shift+Clicks
        hapticManager.itemSelected()
    }

    /// Handle click with optional modifiers (for macOS Cmd+Click and Shift+Click)
    /// - Parameters:
    ///   - itemId: The clicked item's ID
    ///   - commandKey: Whether Command key was held
    ///   - shiftKey: Whether Shift key was held
    func handleClick(for itemId: UUID, commandKey: Bool, shiftKey: Bool) {
        if commandKey {
            // Cmd+Click: Toggle this item's selection without affecting others
            toggleSelection(for: itemId)
        } else if shiftKey {
            // Shift+Click: Select range from anchor to clicked item
            selectRange(to: itemId)
        } else {
            // Regular click: Clear selection, select only this item
            selectedItems = [itemId]
            lastSelectedItemID = itemId
        }
    }
    
    func selectAll() {
        selectedItems = Set(filteredItems.map { $0.id })
    }
    
    func deselectAll() {
        selectedItems.removeAll()
    }
    
    func deleteSelectedItems() {
        for itemId in selectedItems {
            if let item = items.first(where: { $0.id == itemId }) {
                dataRepository.deleteItem(item)
            }
        }
        selectedItems.removeAll()
        loadItems() // Refresh the list
        hapticManager.itemDeleted()
    }
    
    func moveSelectedItems(to destinationList: List) {
        // Get selected items
        let itemsToMove = items.filter { selectedItems.contains($0.id) }
        
        // Move each item to destination list
        for item in itemsToMove {
            dataRepository.moveItem(item, to: destinationList)
        }
        
        selectedItems.removeAll()
        loadItems() // Refresh the list
    }
    
    func copySelectedItems(to destinationList: List) {
        // Get selected items
        let itemsToCopy = items.filter { selectedItems.contains($0.id) }
        
        // Copy each item to destination list
        for item in itemsToCopy {
            dataRepository.copyItem(item, to: destinationList)
        }
        
        selectedItems.removeAll()
        loadItems() // Refresh the list
    }
    
    func enterSelectionMode() {
        isInSelectionMode = true
        selectedItems.removeAll()
        hapticManager.selectionModeToggled()
    }
    
    func exitSelectionMode() {
        isInSelectionMode = false
        selectedItems.removeAll()
        lastSelectedItemID = nil
    }

    // MARK: - Keyboard Reordering (Task 12.11)

    /// Indicates whether keyboard-based reordering is available.
    /// Only true when sorted by orderNumber (manual order).
    var canReorderWithKeyboard: Bool {
        return currentSortOption == .orderNumber
    }

    /// Move an item up one position in the list (Cmd+Option+Up)
    /// - Parameter id: The UUID of the item to move up
    func moveItemUp(_ id: UUID) {
        // Guard: Only allow when sorted by orderNumber
        guard canReorderWithKeyboard else { return }

        // Find the item index in the current items array
        guard let currentIndex = items.firstIndex(where: { $0.id == id }) else { return }

        // Guard: Cannot move up if already at top
        guard currentIndex > 0 else { return }

        // Calculate new destination index (one position up)
        let destinationIndex = currentIndex - 1

        // Use existing reorderItems method to perform the move
        reorderItems(from: currentIndex, to: destinationIndex)
    }

    /// Move an item down one position in the list (Cmd+Option+Down)
    /// - Parameter id: The UUID of the item to move down
    func moveItemDown(_ id: UUID) {
        // Guard: Only allow when sorted by orderNumber
        guard canReorderWithKeyboard else { return }

        // Find the item index in the current items array
        guard let currentIndex = items.firstIndex(where: { $0.id == id }) else { return }

        // Guard: Cannot move down if already at bottom
        guard currentIndex < items.count - 1 else { return }

        // Calculate new destination index (one position down)
        let destinationIndex = currentIndex + 1

        // Use existing reorderItems method to perform the move
        reorderItems(from: currentIndex, to: destinationIndex)
    }
}
