import Foundation
import SwiftUI
import CoreData
import Combine
#if os(iOS)
import WatchConnectivity
#endif

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

@MainActor
class MainViewModel: ObservableObject {
    // Direct @Published array - same pattern as ListViewModel.items
    // Sort happens at assignment time, not via computed property
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

    // Force ForEach refresh on reorder - increment this to break SwiftUI animation identity
    @Published var listsReorderTrigger: Int = 0

    private let dataManager = DataManager.shared
    private let dataRepository = DataRepository()
    private var archiveNotificationTimer: Timer?
    private let archiveNotificationTimeout: TimeInterval = 5.0 // 5 seconds
    private let hapticManager = HapticManager.shared

    // Watch sync properties
    @Published var isSyncingFromWatch = false

    // CRITICAL: Track active drag operations to prevent reload during drag
    // isDragging = set when moveList() is called (drop completes)
    // isEditModeActive = set when edit mode is active (drag becomes possible)
    // We block sync if EITHER is true to prevent corruption during entire drag operation
    private var isDragging = false
    private var isEditModeActive = false

    init() {
        #if os(iOS)
        setupWatchConnectivityObserver()
        #endif

        // Setup Core Data remote change observer for CloudKit sync (all platforms)
        setupCoreDataRemoteChangeObserver()

        // CRITICAL ORDER:
        // 1. Load lists first time
        loadLists()

        // 2. Clean up duplicates (modifies Core Data)
        dataManager.removeDuplicateLists()  // Remove duplicate lists first
        dataManager.removeDuplicateItems()  // Then remove duplicate items

        // 3. RELOAD lists after cleanup to get clean data
        loadLists()

        #if os(iOS)
        // 4. Auto-sync clean data to Watch (after WatchConnectivity activates)
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
            WatchConnectivityService.shared.sendListsData(self.dataManager.lists)
        }
        #endif
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
        archiveNotificationTimer?.invalidate()
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

        // Listen for new lists data notifications
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleWatchListsData(_:)),
            name: NSNotification.Name("WatchConnectivityListsDataReceived"),
            object: nil
        )
    }

    @objc private func handleWatchSyncNotification(_ notification: Notification) {
        // CRITICAL: @objc selectors can be called from any thread - ensure main thread
        // @MainActor attribute does NOT protect @objc selectors from background thread calls
        guard Thread.isMainThread else {
            DispatchQueue.main.async { [weak self] in
                self?.handleWatchSyncNotification(notification)
            }
            return
        }
        refreshFromWatch()
    }

    @objc private func handleWatchListsData(_ notification: Notification) {
        // CRITICAL: @objc selectors can be called from any thread - ensure main thread
        guard Thread.isMainThread else {
            DispatchQueue.main.async { [weak self] in
                self?.handleWatchListsData(notification)
            }
            return
        }

        guard let receivedLists = notification.userInfo?["lists"] as? [List] else {
            return
        }

        // CRITICAL: If we're in edit mode OR actively dragging, IGNORE this sync completely
        // Edit mode = user CAN drag (sync would corrupt state during drag)
        // isDragging = drop is being processed
        //
        // IMPORTANT: Don't defer/re-post! The Watch data is STALE (from before our drag).
        // Our drag already sent the CORRECT new order to Watch, so we should ignore
        // the Watch's response containing OLD data. Re-posting would cause the "one sync behind" bug.
        if isDragOperationInProgress {
            print("⚠️ Watch sync received during edit mode/drag - IGNORING stale Watch data")
            return
        }

        // Show sync indicator
        isSyncingFromWatch = true

        // CRITICAL FIX: Build a map of our LOCAL lists with their current modifiedAt timestamps
        // This prevents Watch sync from overwriting drag-drop changes we just made
        let localListsById = Dictionary(uniqueKeysWithValues: lists.map { ($0.id, $0) })

        // Update Core Data with received lists (using local list timestamps for comparison)
        updateCoreDataWithLists(receivedLists, localListsById: localListsById)

        // Reload UI from Core Data
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            self.loadLists()

            // Hide sync indicator after brief delay
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                self.isSyncingFromWatch = false
            }
        }
    }

    private func updateCoreDataWithLists(_ receivedLists: [List], localListsById: [UUID: List] = [:]) {
        for receivedList in receivedLists {
            // CRITICAL FIX: Use our LOCAL ViewModel lists for comparison, not dataManager.lists
            // Our local lists have the most recent drag-drop changes that may not be in Core Data yet
            let localList = localListsById[receivedList.id]
            let existingList = localList ?? dataManager.lists.first(where: { $0.id == receivedList.id })

            if let existingList = existingList {
                // CRITICAL FIX: Only update if received version is STRICTLY newer
                // This prevents Watch sync from overwriting drag-drop changes we just made
                // The drag-drop updates modifiedAt, so our local version will be newer
                if receivedList.modifiedAt > existingList.modifiedAt {
                    dataManager.updateList(receivedList)
                }

                // Always update items (item-level conflict resolution handles individual item timestamps)
                updateItemsForList(receivedList, existingList: existingList)
            } else {
                // Add new list
                dataManager.addList(receivedList)

                // Add all items for this new list
                for item in receivedList.items {
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
                dataManager.deleteList(withId: listIdToRemove)
            }
        }

        // CRITICAL: Reload all data from Core Data ONCE after all changes
        dataManager.loadData()
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
                        dataManager.updateItem(receivedItem)
                    }
                }
            } else {
                // Add new item
                dataManager.addItem(receivedItem, to: receivedList.id)
            }
        }

        // Remove items that no longer exist
        let itemsToRemove = existingItemIds.subtracting(receivedItemIds)
        for itemIdToRemove in itemsToRemove {
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
        isSyncingFromWatch = true

        // CRITICAL FIX: Reload local data FIRST to ensure we send the latest state to Watch
        // This prevents race condition where drag-and-drop changes are overwritten by stale cached data
        dataManager.loadData()
        loadLists()

        // Send our FRESH data to Watch
        let watchConnectivity = WatchConnectivityService.shared
        watchConnectivity.sendListsData(dataManager.lists)

        // Hide sync indicator after delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            self.isSyncingFromWatch = false
        }
    }
    #elseif os(macOS)
    // MARK: - macOS Manual Sync (no Watch Connectivity)

    /// Manual sync for macOS - reloads data from Core Data
    /// macOS doesn't sync with Watch, but this provides consistent API
    func manualSync() {
        isSyncingFromWatch = true

        // Reload local data from Core Data
        dataManager.loadData()
        loadLists()

        // Hide sync indicator after delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            self.isSyncingFromWatch = false
        }
    }
    #endif

    // MARK: - Core Data Remote Change (CloudKit Sync)
    // Universal observer for CloudKit sync - works on iOS and macOS

    private func setupCoreDataRemoteChangeObserver() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleCoreDataRemoteChange(_:)),
            name: .coreDataRemoteChange,
            object: nil
        )
    }

    @objc private func handleCoreDataRemoteChange(_ notification: Notification) {
        // CRITICAL: @objc selectors can be called from any thread - ensure main thread
        // @MainActor attribute does NOT protect @objc selectors from background thread calls
        // Without this guard, @Published property updates happen on background thread,
        // causing SwiftUI to silently ignore the changes (iOS sync bug!)
        guard Thread.isMainThread else {
            DispatchQueue.main.async { [weak self] in
                self?.handleCoreDataRemoteChange(notification)
            }
            return
        }

        // CRITICAL: Same logic as Watch sync - ignore during drag operations
        // This prevents the "sync ping-pong" bug described in learnings/swiftui-list-drag-drop-ordering.md
        if isDragging || isEditModeActive {
            print("⚠️ Core Data remote change received during edit mode/drag - IGNORING stale data")
            return
        }

        print("🌐 Core Data remote change detected - reloading lists from CloudKit")

        // Reload lists from DataManager (which already reloaded from Core Data)
        loadLists()
    }

    var displayedLists: [List] {
        // CRITICAL FIX: ALWAYS sort by orderNumber to force SwiftUI re-evaluation
        // Even though lists array is sorted, SwiftUI ForEach can cache old positions during drag
        // This explicit sort ensures the computed property returns a NEW array with correct order
        let source = showingArchivedLists ? archivedLists : lists
        return source.sorted { $0.orderNumber < $1.orderNumber }
    }

    // MARK: - Edit Mode Tracking (for drag-drop sync protection)

    /// Called by MainView when edit mode changes
    /// This blocks sync during the ENTIRE time edit mode is active, not just during drop
    func setEditModeActive(_ active: Bool) {
        isEditModeActive = active
        if active {
            print("🔄 Edit mode ACTIVE - sync blocked until edit mode exits")
        } else {
            print("🔄 Edit mode INACTIVE - sync re-enabled")
        }
    }

    /// Check if any drag-related operation is in progress
    private var isDragOperationInProgress: Bool {
        isDragging || isEditModeActive
    }

    func loadLists() {
        // CRITICAL: Never reload during active drag operations
        // Reloading replaces the array SwiftUI is animating, breaking drag-drop
        // Block if EITHER isDragging (drop in progress) OR isEditModeActive (drag possible)
        if isDragOperationInProgress {
            print("⚠️ loadLists() called during drag/edit mode - SKIPPING to preserve drag animation")
            return
        }

        isLoading = true
        errorMessage = nil

        // CRITICAL: Always reload from Core Data first to get latest data
        dataManager.loadData()

        if showingArchivedLists {
            // Load archived lists
            archivedLists = dataManager.loadArchivedLists()
        } else {
            // Get active lists from DataManager and sort by orderNumber
            let newLists = dataManager.lists.sorted { $0.orderNumber < $1.orderNumber }

            // OPTIMIZATION: Only update if order actually changed
            // This prevents unnecessary SwiftUI re-renders that could desync with drag state
            let currentIds = lists.map { $0.id }
            let newIds = newLists.map { $0.id }
            if currentIds != newIds {
                print("📋 loadLists: Order changed, updating lists array")
                lists = newLists
            } else {
                // Just update the list objects in place without changing array order
                // This preserves ForEach's index mapping
                for (index, newList) in newLists.enumerated() {
                    if index < lists.count {
                        lists[index] = newList
                    }
                }
            }
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

        #if os(iOS)
        // Send updated data to paired device
        WatchConnectivityService.shared.sendListsData(dataManager.lists)
        #endif
    }

    func archiveList(_ list: List) {
        dataManager.deleteList(withId: list.id) // This archives the list
        // Remove from active lists
        lists.removeAll { $0.id == list.id }

        #if os(iOS)
        // Send updated data to paired device
        WatchConnectivityService.shared.sendListsData(dataManager.lists)
        #endif

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

        #if os(iOS)
        // Send updated data to paired device
        WatchConnectivityService.shared.sendListsData(dataManager.lists)
        #endif
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

        #if os(iOS)
        // Send updated data to paired device
        WatchConnectivityService.shared.sendListsData(dataManager.lists)
        #endif

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

        #if os(iOS)
        // Send updated data to paired device
        WatchConnectivityService.shared.sendListsData(dataManager.lists)
        #endif
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

        #if os(iOS)
        // Send updated data to paired device
        WatchConnectivityService.shared.sendListsData(dataManager.lists)
        #endif
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
        // CRITICAL: Use EXACT same pattern as ListViewModel.moveSingleItem()
        // The key is: calculate destination using (destination - 1) when moving down,
        // find the destination ITEM by ID, then call DataRepository with those indices.

        guard let sourceIndex = source.first else { return }

        // Mark as actively dragging to block any interference
        isDragging = true

        // Get the displayed array (what ForEach is rendering)
        let displayed = displayedLists

        // Get the backing array for logging
        let workingArray = showingArchivedLists ? archivedLists : lists

        print("🔄 moveList: source=\(sourceIndex), destination=\(destination)")
        print("🔄 BEFORE: \(workingArray.map { "\($0.name)(order:\($0.orderNumber))" })")

        // Validate source index
        guard sourceIndex < displayed.count else {
            print("❌ ERROR: sourceIndex \(sourceIndex) out of bounds")
            isDragging = false
            return
        }

        // Get the dragged list from displayed array
        let draggedList = displayed[sourceIndex]

        // EXACT PATTERN FROM ListViewModel.moveSingleItem():
        // Calculate destination in displayed array using (destination - 1) when moving down
        let displayedDestIndex = destination > sourceIndex ? destination - 1 : destination
        let destinationList = displayedDestIndex < displayed.count ? displayed[displayedDestIndex] : displayed.last

        // Find actual indices in backing array by ID
        guard let actualSourceIndex = workingArray.firstIndex(where: { $0.id == draggedList.id }) else {
            print("❌ ERROR: Could not find dragged list '\(draggedList.name)' in backing array")
            isDragging = false
            return
        }

        let actualDestIndex: Int
        if let destList = destinationList,
           let destIndex = workingArray.firstIndex(where: { $0.id == destList.id }) {
            actualDestIndex = destIndex
        } else {
            // Moving to end
            actualDestIndex = workingArray.count - 1
        }

        print("🔄 Mapped: actualSource=\(actualSourceIndex) (\(draggedList.name)), actualDest=\(actualDestIndex) (\(destinationList?.name ?? "end"))")

        // Skip if no actual movement needed
        guard actualSourceIndex != actualDestIndex else {
            print("🔄 No movement needed - source equals destination")
            isDragging = false
            return
        }

        // CRITICAL: Use DataRepository.reorderLists() which uses remove()+insert() pattern
        // This is the EXACT same approach as ListViewModel.reorderItems()
        // NOTE: reorderLists() now calls dataManager.loadData() before returning,
        // so dataManager.lists cache is already fresh when we read it here
        dataRepository.reorderLists(from: actualSourceIndex, to: actualDestIndex)

        // Reload lists directly from dataManager (bypass loadLists() which is blocked by isDragging)
        // This matches ListViewModel.reorderItems() -> loadItems() pattern
        // Cache is already fresh from reorderLists(), so we can read directly
        let updatedLists = dataManager.lists.sorted { $0.orderNumber < $1.orderNumber }
        if showingArchivedLists {
            archivedLists = updatedLists.filter { $0.isArchived }
        } else {
            lists = updatedLists.filter { !$0.isArchived }
        }

        print("🔄 AFTER: \(lists.map { "\($0.name)(order:\($0.orderNumber))" })")

        // CRITICAL FIX: Increment trigger to force SwiftUI ForEach to rebuild
        // This breaks the animation identity and forces re-render from updated array
        listsReorderTrigger += 1

        // Haptic feedback
        hapticManager.dragDropped()

        // Clear dragging flag after animation settles
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            self.isDragging = false
            print("🔄 Drag completed - sync re-enabled")
        }
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

        #if os(iOS)
        // Send updated data to paired device
        WatchConnectivityService.shared.sendListsData(dataManager.lists)
        #endif
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