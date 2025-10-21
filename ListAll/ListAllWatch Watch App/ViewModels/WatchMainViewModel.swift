//
//  WatchMainViewModel.swift
//  ListAllWatch Watch App
//
//  Created by AI Assistant on 20.10.2025.
//

import Foundation
import SwiftUI
import Combine

/// ViewModel for the main lists view on watchOS
/// Simplified version of MainViewModel optimized for watchOS
class WatchMainViewModel: ObservableObject {
    @Published var lists: [List] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    private let dataManager = DataManager.shared
    private var cancellables = Set<AnyCancellable>()
    
    init() {
        setupDataListener()
        loadLists()
    }
    
    /// Setup listener for data changes from Core Data
    private func setupDataListener() {
        // Listen to data changes from DataManager
        NotificationCenter.default.publisher(for: NSNotification.Name("DataUpdated"))
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.loadLists()
            }
            .store(in: &cancellables)
    }
    
    /// Load all active (non-archived) lists
    func loadLists() {
        isLoading = true
        errorMessage = nil
        
        // Get active lists from DataManager (sorted by order number)
        lists = dataManager.lists
            .filter { !$0.isArchived }
            .sorted { $0.orderNumber < $1.orderNumber }
        
        isLoading = false
    }
    
    /// Refresh data manually (for pull-to-refresh)
    func refresh() async {
        await MainActor.run {
            isLoading = true
        }
        
        // Reload data from Core Data
        dataManager.loadData()
        
        await MainActor.run {
            loadLists()
            isLoading = false
        }
    }
}


