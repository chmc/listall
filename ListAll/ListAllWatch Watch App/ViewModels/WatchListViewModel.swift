import Foundation
import SwiftUI
import Combine

/// ViewModel for managing a single list's items on watchOS
/// Simplified version optimized for watchOS constraints
class WatchListViewModel: ObservableObject {
    @Published var items: [Item] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var currentFilter: ItemFilterOption = .all
    
    let list: List
    private let dataManager = DataManager.shared
    private let dataRepository = DataRepository()
    private var cancellables = Set<AnyCancellable>()
    
    // Watch sync properties
    @Published var isSyncingFromiOS = false
    
    init(list: List) {
        self.list = list
        restoreFilterPreference()
        setupDataListener()
        setupWatchConnectivityObserver()
        loadItems()
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    /// Setup listener for data changes from Core Data
    private func setupDataListener() {
        // Listen to data changes from DataManager
        NotificationCenter.default.publisher(for: NSNotification.Name("ItemDataChanged"))
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.loadItems()
            }
            .store(in: &cancellables)
    }
    
    // MARK: - Watch Connectivity Integration
    
    private func setupWatchConnectivityObserver() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleiOSSyncNotification(_:)),
            name: NSNotification.Name("WatchConnectivitySyncReceived"),
            object: nil
        )
    }
    
    @objc private func handleiOSSyncNotification(_ notification: Notification) {
        refreshItemsFromiOS()
    }
    
    func refreshItemsFromiOS() {
        // Show sync indicator briefly
        isSyncingFromiOS = true
        
        // Reload items from DataManager (which already has the updated data from Core Data)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            self.loadItems()
            
            // Hide sync indicator after brief delay
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                self.isSyncingFromiOS = false
            }
        }
    }
    
    /// Load items for this list
    func loadItems() {
        isLoading = true
        errorMessage = nil
        
        // Get items from DataManager
        // IMPORTANT: Preserve order from sync (matches iOS display order)
        // Don't sort here - items are already in correct order from iOS
        items = dataManager.getItems(forListId: list.id)
        
        isLoading = false
    }
    
    /// Refresh items manually (for pull-to-refresh)
    func refresh() async {
        await MainActor.run {
            isLoading = true
            errorMessage = nil
        }
        
        // Reload data from Core Data
        dataManager.loadData()
        
        await MainActor.run {
            loadItems()
            isLoading = false
        }
    }
    
    /// Toggle item completion status
    func toggleItemCompletion(_ item: Item) {
        dataRepository.toggleItemCrossedOut(item)
        // Items will be reloaded automatically via notification
        
        // CRITICAL: Sync change to iOS immediately
        // When user completes an item on watchOS, iOS needs to know about it
        
        // Send updated lists to iOS via WatchConnectivity
        WatchConnectivityService.shared.sendListsData(dataManager.lists)
    }
    
    // MARK: - Computed Properties
    
    /// Returns items in display order (preserves iOS sort), filtered by current filter
    var sortedItems: [Item] {
        // Don't sort - items are already in correct display order from iOS
        // This ensures Watch displays items in same order as iOS, regardless of iOS sort preference
        return applyFilter(to: items)
    }
    
    /// Returns active (non-completed) items
    var activeItems: [Item] {
        return items.filter { !$0.isCrossedOut }
    }
    
    /// Returns completed items
    var completedItems: [Item] {
        return items.filter { $0.isCrossedOut }
    }
    
    /// Returns count of active items
    var activeItemCount: Int {
        return activeItems.count
    }
    
    /// Returns count of completed items
    var completedItemCount: Int {
        return completedItems.count
    }
    
    /// Returns total item count
    var totalItemCount: Int {
        return items.count
    }
    
    // MARK: - Filter Management
    
    /// Apply current filter to items
    private func applyFilter(to items: [Item]) -> [Item] {
        switch currentFilter {
        case .all:
            return items
        case .active:
            return items.filter { !$0.isCrossedOut }
        case .completed:
            return items.filter { $0.isCrossedOut }
        case .hasDescription:
            // Not commonly used on watchOS, but support it anyway
            return items.filter { $0.hasDescription }
        case .hasImages:
            // Not commonly used on watchOS, but support it anyway
            return items.filter { $0.hasImages }
        }
    }
    
    /// Change the current filter and persist preference
    func setFilter(_ filter: ItemFilterOption) {
        currentFilter = filter
        saveFilterPreference()
    }
    
    // MARK: - Filter Persistence
    
    /// UserDefaults key for filter preferences (keyed by list ID)
    private var filterPreferenceKey: String {
        return "watchListFilter_\(list.id.uuidString)"
    }
    
    /// Save filter preference to UserDefaults
    private func saveFilterPreference() {
        UserDefaults.standard.set(currentFilter.rawValue, forKey: filterPreferenceKey)
    }
    
    /// Restore filter preference from UserDefaults
    private func restoreFilterPreference() {
        if let savedFilterString = UserDefaults.standard.string(forKey: filterPreferenceKey),
           let savedFilter = ItemFilterOption.allCases.first(where: { $0.rawValue == savedFilterString }) {
            currentFilter = savedFilter
        } else {
            currentFilter = .active // Default to showing only active items (like iOS)
        }
    }
}

