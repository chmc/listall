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
        loadLists()
        setupWatchConnectivityObserver()
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
        archiveNotificationTimer?.invalidate()
    }
    
    // MARK: - Watch Connectivity Integration
    
    private func setupWatchConnectivityObserver() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleWatchSyncNotification(_:)),
            name: NSNotification.Name("WatchConnectivitySyncReceived"),
            object: nil
        )
    }
    
    @objc private func handleWatchSyncNotification(_ notification: Notification) {
        #if os(iOS)
        print("🔄 [iOS] MainViewModel: Received sync notification from Watch")
        #endif
        refreshFromWatch()
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
    
    var displayedLists: [List] {
        showingArchivedLists ? archivedLists : lists
    }
    
    func loadLists() {
        isLoading = true
        errorMessage = nil
        
        if showingArchivedLists {
            // Load archived lists
            archivedLists = dataManager.loadArchivedLists()
        } else {
            // Get active lists from DataManager
            lists = dataManager.lists.sorted { $0.orderNumber < $1.orderNumber }
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
    }
    
    func archiveList(_ list: List) {
        dataManager.deleteList(withId: list.id) // This archives the list
        // Remove from active lists
        lists.removeAll { $0.id == list.id }
        
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