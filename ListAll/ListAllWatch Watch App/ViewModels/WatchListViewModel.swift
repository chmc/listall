//
//  WatchListViewModel.swift
//  ListAllWatch Watch App
//
//  Created by AI Assistant on 21.10.2025.
//

import Foundation
import SwiftUI
import Combine

/// ViewModel for managing a single list's items on watchOS
/// Simplified version optimized for watchOS constraints
class WatchListViewModel: ObservableObject {
    @Published var items: [Item] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    let list: List
    private let dataManager = DataManager.shared
    private let dataRepository = DataRepository()
    private var cancellables = Set<AnyCancellable>()
    
    init(list: List) {
        self.list = list
        setupDataListener()
        loadItems()
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
    
    /// Load items for this list
    func loadItems() {
        isLoading = true
        errorMessage = nil
        
        // Get items from DataManager (sorted by order number)
        items = dataManager.getItems(forListId: list.id)
            .sorted { $0.orderNumber < $1.orderNumber }
        
        isLoading = false
    }
    
    /// Refresh items manually (for pull-to-refresh)
    func refresh() async {
        await MainActor.run {
            isLoading = true
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
    }
    
    // MARK: - Computed Properties
    
    /// Returns items sorted by order number
    var sortedItems: [Item] {
        return items.sorted { $0.orderNumber < $1.orderNumber }
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
}

