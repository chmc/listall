import Foundation
import SwiftUI

enum ValidationError: LocalizedError {
    case emptyName
    case nameTooLong
    
    var errorDescription: String? {
        switch self {
        case .emptyName:
            return "Please enter a list name"
        case .nameTooLong:
            return "List name must be 100 characters or less"
        }
    }
}

class MainViewModel: ObservableObject {
    @Published var lists: [List] = []
    @Published var archivedLists: [List] = []
    @Published var showingArchivedLists = false
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var selectedLists: Set<UUID> = []
    @Published var isInSelectionMode = false
    @Published var selectedListForNavigation: List?
    
    // Archive notification properties
    @Published var recentlyArchivedList: List?
    @Published var showArchivedNotification = false
    
    private let dataManager = DataManager.shared
    private var archiveNotificationTimer: Timer?
    private let archiveNotificationTimeout: TimeInterval = 5.0 // 5 seconds
    private let hapticManager = HapticManager.shared
    
    // Watch sync properties
    @Published var isSyncingFromWatch = false
    
    init() {
        setupWatchConnectivityObserver()
        
        // CRITICAL ORDER:
        // 1. Load lists first time
        loadLists()
        
        // 2. Clean up duplicates (modifies Core Data)
        #if os(iOS)
        print("🧹 [iOS] Checking for duplicate items on launch...")
        #endif
        dataManager.removeDuplicateItems()
        
        // 3. RELOAD lists after cleanup to get clean data
        #if os(iOS)
        print("🔄 [iOS] Reloading lists after cleanup...")
        #endif
        loadLists()
        
        // 4. Auto-sync clean data to Watch (after WatchConnectivity activates)
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
            #if os(iOS)
            print("🚀 [iOS] Auto-sync on launch: Sending clean data to Watch...")
            print("📊 [iOS] Sending \(self.lists.count) lists with \(self.lists.reduce(0) { $0 + $1.items.count }) total items")
            #endif
            WatchConnectivityService.shared.sendListsData(self.dataManager.lists)
        }
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
        archiveNotificationTimer?.invalidate()
    }
    
    // MARK: - Watch Connectivity Integration
    
    private func setupWatchConnectivityObserver() {
        // Listen for old sync notifications (backward compatibility)
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleWatchSyncNotification(_:)),
            name: NSNotification.Name("WatchConnectivitySyncReceived"),
            object: nil
        )
        
        // Listen for new lists data notifications
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleWatchListsData(_:)),
            name: NSNotification.Name("WatchConnectivityListsDataReceived"),
            object: nil
        )
    }
    
    @objc private func handleWatchSyncNotification(_ notification: Notification) {
        #if os(iOS)
        print("🔄 [iOS] MainViewModel: Received sync notification from Watch")
        #endif
        refreshFromWatch()
    }
    
    @objc private func handleWatchListsData(_ notification: Notification) {
        #if os(iOS)
        print("📥 [iOS] MainViewModel: Received lists data from Watch")
        #endif
        
        guard let receivedLists = notification.userInfo?["lists"] as? [List] else {
            print("❌ [iOS] Failed to extract lists from notification")
            return
        }
        
        print("📥 [iOS] Processing \(receivedLists.count) lists from Watch")
        
        // Show sync indicator
        isSyncingFromWatch = true
        
        // Update Core Data with received lists
        updateCoreDataWithLists(receivedLists)
        
        // Reload UI
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            self.loadLists()
            
            // Hide sync indicator after brief delay
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                self.isSyncingFromWatch = false
            }
        }
    }
    
    private func updateCoreDataWithLists(_ receivedLists: [List]) {
        for receivedList in receivedLists {
            // Check if list already exists in local database
            if let existingList = dataManager.lists.first(where: { $0.id == receivedList.id }) {
                #if os(iOS)
                print("🔄 [iOS] Syncing existing list: \(receivedList.name) (\(receivedList.items.count) items from Watch)")
                #endif
                
                // Update list metadata only if received version is newer
                if receivedList.modifiedAt > existingList.modifiedAt {
                    #if os(iOS)
                    print("  ⬆️ [iOS] List metadata is newer, updating")
                    #endif
                    dataManager.updateList(receivedList)
                }
                
                // CRITICAL FIX: Always update items, regardless of list's modifiedAt
                // This ensures item additions, deletions, and property changes (like isCrossedOut) always sync
                // Item-level conflict resolution (checking each item's modifiedAt) handles conflicts correctly
                updateItemsForList(receivedList, existingList: existingList)
            } else {
                // Add new list
                #if os(iOS)
                print("➕ [iOS] Adding new list: \(receivedList.name) with \(receivedList.items.count) items")
                #endif
                dataManager.addList(receivedList)
                
                // Add all items for this new list
                for item in receivedList.items {
                    #if os(iOS)
                    print("  ➕ [iOS] Adding item: \(item.title)")
                    #endif
                    dataManager.addItem(item, to: receivedList.id)
                }
            }
        }
        
        // Remove lists that no longer exist on Watch (except archived ones)
        // CRITICAL: Only remove lists if we actually received data (not an empty sync)
        if !receivedLists.isEmpty {
            let receivedListIds = Set(receivedLists.map { $0.id })
            let localActiveListIds = Set(dataManager.lists.filter { !$0.isArchived }.map { $0.id })
            let listsToRemove = localActiveListIds.subtracting(receivedListIds)
            
            for listIdToRemove in listsToRemove {
                #if os(iOS)
                print("🗑️ [iOS] Removing deleted list")
                #endif
                dataManager.deleteList(withId: listIdToRemove)
            }
        } else {
            #if os(iOS)
            print("⚠️ [iOS] Received empty sync from Watch - not deleting any lists")
            #endif
        }
        
        // CRITICAL: Reload all data from Core Data ONCE after all changes
        #if os(iOS)
        print("🔄 [iOS] Reloading all data from Core Data after sync...")
        #endif
        dataManager.loadData()
        
        #if os(iOS)
        let totalItems = receivedLists.reduce(0) { $0 + $1.items.count }
        let actualItems = dataManager.lists.reduce(0) { $0 + $1.items.count }
        print("✅ [iOS] Core Data updated with \(receivedLists.count) lists and \(totalItems) items")
        print("✅ [iOS] DataManager now has \(actualItems) items loaded")
        #endif
    }
    
    /// Updates items for an existing list (add new, update existing, remove deleted)
    private func updateItemsForList(_ receivedList: List, existingList: List) {
        let receivedItemIds = Set(receivedList.items.map { $0.id })
        let existingItemIds = Set(existingList.items.map { $0.id })
        
        // Add new items or update existing ones
        for receivedItem in receivedList.items {
            if existingItemIds.contains(receivedItem.id) {
                // Update existing item if received version is newer
                if let existingItem = existingList.items.first(where: { $0.id == receivedItem.id }) {
                    if receivedItem.modifiedAt > existingItem.modifiedAt {
                        #if os(iOS)
                        print("  ⬆️ [iOS] Updating item: \(receivedItem.title)")
                        #endif
                        dataManager.updateItem(receivedItem)
                    }
                }
            } else {
                // Add new item
                #if os(iOS)
                print("  ➕ [iOS] Adding item: \(receivedItem.title)")
                #endif
                dataManager.addItem(receivedItem, to: receivedList.id)
            }
        }
        
        // Remove items that no longer exist
        let itemsToRemove = existingItemIds.subtracting(receivedItemIds)
        for itemIdToRemove in itemsToRemove {
            #if os(iOS)
            print("  🗑️ [iOS] Removing deleted item")
            #endif
            dataManager.deleteItem(withId: itemIdToRemove, from: receivedList.id)
        }
    }
    
    func refreshFromWatch() {
        // Show sync indicator briefly
        isSyncingFromWatch = true
        
        // Reload lists from DataManager (which already has the updated data from Core Data)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            self.loadLists()
            
            // Hide sync indicator after brief delay
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                self.isSyncingFromWatch = false
            }
        }
    }
    
    /// Manual sync - request data from Watch and send our data to Watch
    func manualSync() {
        #if os(iOS)
        print("🔄 [iOS] Manual sync triggered by user")
        #endif
        
        isSyncingFromWatch = true
        
        // Send our data to Watch
        let watchConnectivity = WatchConnectivityService.shared
        watchConnectivity.sendListsData(dataManager.lists)
        
        // Reload local data (in case Watch sent us data)
        dataManager.loadData()
        loadLists()
        
        // Hide sync indicator after delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            self.isSyncingFromWatch = false
        }
    }
    
    var displayedLists: [List] {
        showingArchivedLists ? archivedLists : lists
    }
    
    func loadLists() {
        isLoading = true
        errorMessage = nil
        
        // CRITICAL: Always reload from Core Data first to get latest data
        dataManager.loadData()
        
        if showingArchivedLists {
            // Load archived lists
            archivedLists = dataManager.loadArchivedLists()
        } else {
            // Get active lists from DataManager
            lists = dataManager.lists.sorted { $0.orderNumber < $1.orderNumber }
            
            #if os(iOS)
            print("📊 [iOS] Loaded \(lists.count) lists with \(lists.reduce(0) { $0 + $1.items.count }) total items")
            #endif
        }
        
        isLoading = false
    }
    
    func loadArchivedLists() {
        isLoading = true
        errorMessage = nil
        
        archivedLists = dataManager.loadArchivedLists()
        
        isLoading = false
    }
    
    func toggleArchivedView() {
        showingArchivedLists.toggle()
        if showingArchivedLists {
            loadArchivedLists()
        } else {
            loadLists()
        }
        // Clear selection when switching views
        selectedLists.removeAll()
        isInSelectionMode = false
    }
    
    func restoreList(_ list: List) {
        dataManager.restoreList(withId: list.id)
        // Remove from archived lists
        archivedLists.removeAll { $0.id == list.id }
        // Reload active lists to include restored list
        lists = dataManager.lists.sorted { $0.orderNumber < $1.orderNumber }
        
        // Send updated data to paired device
        WatchConnectivityService.shared.sendListsData(dataManager.lists)
    }
    
    func archiveList(_ list: List) {
        dataManager.deleteList(withId: list.id) // This archives the list
        // Remove from active lists
        lists.removeAll { $0.id == list.id }
        
        // Send updated data to paired device
        WatchConnectivityService.shared.sendListsData(dataManager.lists)
        
        // Show archive notification
        showArchiveNotification(for: list)
        
        // Trigger haptic feedback
        hapticManager.listArchived()
    }
    
    func permanentlyDeleteList(_ list: List) {
        dataManager.permanentlyDeleteList(withId: list.id)
        // Remove from archived lists
        archivedLists.removeAll { $0.id == list.id }
        
        // Trigger haptic feedback
        hapticManager.listDeleted()
    }
    
    // MARK: - Archive Notification Methods
    
    private func showArchiveNotification(for list: List) {
        // Cancel any existing timer
        archiveNotificationTimer?.invalidate()
        
        // Store the archived list
        recentlyArchivedList = list
        showArchivedNotification = true
        
        // Set up timer to hide notification after timeout
        archiveNotificationTimer = Timer.scheduledTimer(withTimeInterval: archiveNotificationTimeout, repeats: false) { [weak self] _ in
            self?.hideArchiveNotification()
        }
    }
    
    func undoArchive() {
        guard let list = recentlyArchivedList else { return }
        
        // Restore the list
        dataManager.restoreList(withId: list.id)
        
        // Hide notification immediately BEFORE reloading lists
        hideArchiveNotification()
        
        // Reload active lists to include restored list
        lists = dataManager.lists.sorted { $0.orderNumber < $1.orderNumber }
        
        // Send updated data to paired device
        WatchConnectivityService.shared.sendListsData(dataManager.lists)
    }
    
    func hideArchiveNotification() {
        archiveNotificationTimer?.invalidate()
        archiveNotificationTimer = nil
        showArchivedNotification = false
        recentlyArchivedList = nil
    }
    
    func addList(name: String) throws -> List {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        
        guard !trimmedName.isEmpty else {
            throw ValidationError.emptyName
        }
        
        guard trimmedName.count <= 100 else {
            throw ValidationError.nameTooLong
        }
        
        let newList = List(name: trimmedName)
        dataManager.addList(newList)
        
        // Refresh lists from dataManager (which already added the list)
        lists = dataManager.lists.sorted { $0.orderNumber < $1.orderNumber }
        
        // Trigger haptic feedback
        hapticManager.listCreated()
        
        return newList
    }
    
    func deleteList(_ list: List) {
        dataManager.deleteList(withId: list.id)
        lists.removeAll { $0.id == list.id }
        
        // Trigger haptic feedback
        hapticManager.listDeleted()
    }
    
    func updateList(_ list: List, name: String) throws {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        
        guard !trimmedName.isEmpty else {
            throw ValidationError.emptyName
        }
        
        guard trimmedName.count <= 100 else {
            throw ValidationError.nameTooLong
        }
        
        var updatedList = list
        updatedList.name = trimmedName
        updatedList.updateModifiedDate()
        dataManager.updateList(updatedList)
        if let index = lists.firstIndex(where: { $0.id == list.id }) {
            lists[index] = updatedList
        }
    }
    
    func duplicateList(_ list: List) throws {
        // Create a duplicate name with "Copy" suffix
        let duplicateName = generateDuplicateName(for: list.name)
        
        guard duplicateName.count <= 100 else {
            throw ValidationError.nameTooLong
        }
        
        // Create new list with duplicate name
        let duplicatedList = List(name: duplicateName)
        
        // Get items from the original list
        let originalItems = dataManager.getItems(forListId: list.id)
        
        // Add the duplicated list first
        dataManager.addList(duplicatedList)
        
        // Duplicate all items from the original list
        for originalItem in originalItems {
            var duplicatedItem = originalItem
            duplicatedItem.id = UUID() // Generate new ID
            duplicatedItem.listId = duplicatedList.id // Associate with new list
            duplicatedItem.createdAt = Date()
            duplicatedItem.modifiedAt = Date()
            
            dataManager.addItem(duplicatedItem, to: duplicatedList.id)
        }
        
        // Refresh lists from dataManager (which already added the list)
        lists = dataManager.lists.sorted { $0.orderNumber < $1.orderNumber }
    }
    
    private func generateDuplicateName(for originalName: String) -> String {
        let baseName = originalName
        var duplicateNumber = 1
        var candidateName = "\(baseName) Copy"
        
        // Check if a list with this name already exists
        while lists.contains(where: { $0.name == candidateName }) {
            duplicateNumber += 1
            candidateName = "\(baseName) Copy \(duplicateNumber)"
        }
        
        return candidateName
    }
    
    func moveList(from source: IndexSet, to destination: Int) {
        // Standard SwiftUI pattern: use move directly
        lists.move(fromOffsets: source, toOffset: destination)
        
        // Update order numbers based on new positions
        for (index, list) in lists.enumerated() {
            var updatedList = list
            updatedList.orderNumber = Int(index)
            lists[index] = updatedList
        }
        
        // Batch update all lists at once - saves to Core Data and syncs DataManager
        dataManager.updateListsOrder(lists)
        
        // Trigger haptic feedback
        hapticManager.dragDropped()
    }
    
    // MARK: - Multi-Selection Methods
    
    func toggleSelection(for listId: UUID) {
        if selectedLists.contains(listId) {
            selectedLists.remove(listId)
        } else {
            selectedLists.insert(listId)
        }
    }
    
    func selectAll() {
        selectedLists = Set(lists.map { $0.id })
    }
    
    func deselectAll() {
        selectedLists.removeAll()
    }
    
    func deleteSelectedLists() {
        for listId in selectedLists {
            dataManager.deleteList(withId: listId)
        }
        lists.removeAll { selectedLists.contains($0.id) }
        selectedLists.removeAll()
    }
    
    func enterSelectionMode() {
        isInSelectionMode = true
        selectedLists.removeAll()
    }
    
    func exitSelectionMode() {
        isInSelectionMode = false
        selectedLists.removeAll()
    }
    
    // MARK: - Sample List Creation
    
    /// Create a list from a sample template
    /// - Parameter template: The template to use
    /// - Returns: The created list
    func createSampleList(from template: SampleDataService.SampleListTemplate) -> List {
        let createdList = SampleDataService.saveTemplateList(template, using: dataManager)
        
        // Reload lists to get the updated data
        loadLists()
        
        return createdList
    }
}