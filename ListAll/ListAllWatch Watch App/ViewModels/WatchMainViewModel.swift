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
    
    // Watch sync properties
    @Published var isSyncingFromiOS = false
    
    init() {
        setupDataListener()
        setupWatchConnectivityObserver()
        
        // CRITICAL ORDER:
        // 1. Load lists first time
        loadLists()
        
        // 2. Clean up duplicates (modifies Core Data)
        #if os(watchOS)
        print("🧹 [watchOS] Checking for duplicate items on launch...")
        #endif
        dataManager.removeDuplicateItems()
        
        // 3. RELOAD lists after cleanup to get clean data
        #if os(watchOS)
        print("🔄 [watchOS] Reloading lists after cleanup...")
        #endif
        loadLists()
        
        // 4. Auto-sync clean data to iPhone (after WatchConnectivity activates)
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
            #if os(watchOS)
            print("🚀 [watchOS] Auto-sync on launch: Sending clean data to iPhone...")
            print("📊 [watchOS] Sending \(self.lists.count) lists with \(self.lists.reduce(0) { $0 + $1.items.count }) total items")
            #endif
            WatchConnectivityService.shared.sendListsData(self.dataManager.lists)
        }
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
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
    
    // MARK: - Watch Connectivity Integration
    
    private func setupWatchConnectivityObserver() {
        // Listen for old sync notifications (backward compatibility)
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleiOSSyncNotification(_:)),
            name: NSNotification.Name("WatchConnectivitySyncReceived"),
            object: nil
        )
        
        // Listen for new lists data notifications
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleiOSListsData(_:)),
            name: NSNotification.Name("WatchConnectivityListsDataReceived"),
            object: nil
        )
    }
    
    @objc private func handleiOSSyncNotification(_ notification: Notification) {
        #if os(watchOS)
        print("🔄 [watchOS] WatchMainViewModel: Received sync notification from iOS")
        #endif
        refreshFromiOS()
    }
    
    @objc private func handleiOSListsData(_ notification: Notification) {
        #if os(watchOS)
        print("📥 [watchOS] WatchMainViewModel: Received lists data from iOS")
        #endif
        
        guard let receivedLists = notification.userInfo?["lists"] as? [List] else {
            print("❌ [watchOS] Failed to extract lists from notification")
            return
        }
        
        print("📥 [watchOS] Processing \(receivedLists.count) lists from iOS")
        
        // Show sync indicator
        isSyncingFromiOS = true
        
        // Update Core Data with received lists
        updateCoreDataWithLists(receivedLists)
        
        // Reload UI
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            self.loadLists()
            
            // Hide sync indicator after brief delay
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                self.isSyncingFromiOS = false
            }
        }
    }
    
    private func updateCoreDataWithLists(_ receivedLists: [List]) {
        for receivedList in receivedLists {
            // Check if list already exists in local database
            if let existingList = dataManager.lists.first(where: { $0.id == receivedList.id }) {
                #if os(watchOS)
                print("🔄 [watchOS] Syncing existing list: \(receivedList.name) (\(receivedList.items.count) items from iOS)")
                #endif
                
                // Update list metadata only if received version is newer
                if receivedList.modifiedAt > existingList.modifiedAt {
                    #if os(watchOS)
                    print("  ⬆️ [watchOS] List metadata is newer, updating")
                    #endif
                    dataManager.updateList(receivedList)
                }
                
                // CRITICAL FIX: Always update items, regardless of list's modifiedAt
                // This ensures item additions, deletions, and property changes (like isCrossedOut) always sync
                // Item-level conflict resolution (checking each item's modifiedAt) handles conflicts correctly
                updateItemsForList(receivedList, existingList: existingList)
            } else {
                // Add new list
                #if os(watchOS)
                print("➕ [watchOS] Adding new list: \(receivedList.name) with \(receivedList.items.count) items")
                #endif
                dataManager.addList(receivedList)
                
                // Add all items for this new list
                for item in receivedList.items {
                    #if os(watchOS)
                    print("  ➕ [watchOS] Adding item: \(item.title)")
                    #endif
                    dataManager.addItem(item, to: receivedList.id)
                }
            }
        }
        
        // Remove lists that no longer exist on iOS (except archived ones)
        // CRITICAL: Only remove lists if we actually received data (not an empty sync)
        if !receivedLists.isEmpty {
            let receivedListIds = Set(receivedLists.map { $0.id })
            let localActiveListIds = Set(dataManager.lists.filter { !$0.isArchived }.map { $0.id })
            let listsToRemove = localActiveListIds.subtracting(receivedListIds)
            
            for listIdToRemove in listsToRemove {
                #if os(watchOS)
                print("🗑️ [watchOS] Removing deleted list")
                #endif
                dataManager.deleteList(withId: listIdToRemove)
            }
        } else {
            #if os(watchOS)
            print("⚠️ [watchOS] Received empty sync - not deleting any lists")
            #endif
        }
        
        // CRITICAL: Reload all data from Core Data ONCE after all changes
        #if os(watchOS)
        print("🔄 [watchOS] Reloading all data from Core Data after sync...")
        #endif
        dataManager.loadData()
        
        #if os(watchOS)
        let totalItems = receivedLists.reduce(0) { $0 + $1.items.count }
        let actualItems = dataManager.lists.reduce(0) { $0 + $1.items.count }
        print("✅ [watchOS] Core Data updated with \(receivedLists.count) lists and \(totalItems) items")
        print("✅ [watchOS] DataManager now has \(actualItems) items loaded")
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
                        #if os(watchOS)
                        print("  ⬆️ [watchOS] Updating item: \(receivedItem.title)")
                        #endif
                        dataManager.updateItem(receivedItem)
                    }
                }
            } else {
                // Add new item
                #if os(watchOS)
                print("  ➕ [watchOS] Adding item: \(receivedItem.title)")
                #endif
                dataManager.addItem(receivedItem, to: receivedList.id)
            }
        }
        
        // Remove items that no longer exist
        let itemsToRemove = existingItemIds.subtracting(receivedItemIds)
        for itemIdToRemove in itemsToRemove {
            #if os(watchOS)
            print("  🗑️ [watchOS] Removing deleted item")
            #endif
            dataManager.deleteItem(withId: itemIdToRemove, from: receivedList.id)
        }
    }
    
    func refreshFromiOS() {
        // Show sync indicator briefly
        isSyncingFromiOS = true
        
        // Reload lists from DataManager (which already has the updated data from Core Data)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            self.loadLists()
            
            // Hide sync indicator after brief delay
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                self.isSyncingFromiOS = false
            }
        }
    }
    
    /// Load all active (non-archived) lists
    func loadLists() {
        isLoading = true
        errorMessage = nil
        
        // CRITICAL: Always reload from Core Data first to get latest data
        dataManager.loadData()
        
        #if os(watchOS)
        print("📊 [watchOS] DataManager has \(dataManager.lists.count) total lists")
        #endif
        
        // Get active lists from DataManager (sorted by order number)
        lists = dataManager.lists
            .filter { !$0.isArchived }
            .sorted { $0.orderNumber < $1.orderNumber }
        
        #if os(watchOS)
        print("📊 [watchOS] Displaying \(lists.count) active lists with \(lists.reduce(0) { $0 + $1.items.count }) total items")
        #endif
        
        isLoading = false
    }
    
    /// Refresh data manually (for pull-to-refresh and manual sync button)
    func refresh() async {
        #if os(watchOS)
        print("🔄 [watchOS] Manual refresh/sync triggered")
        #endif
        
        await MainActor.run {
            isLoading = true
            isSyncingFromiOS = true
        }
        
        // Wait for WatchConnectivity session to be ready
        let watchConnectivity = WatchConnectivityService.shared
        var waitCount = 0
        while !watchConnectivity.isActivated && waitCount < 20 {
            #if os(watchOS)
            print("⏳ [watchOS] Waiting for WCSession to activate... (\(waitCount + 1)/20)")
            #endif
            try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
            waitCount += 1
        }
        
        // Send our data to iPhone if session is ready
        if watchConnectivity.isActivated {
            #if os(watchOS)
            print("📤 [watchOS] Sending \(dataManager.lists.count) lists to iPhone...")
            #endif
            watchConnectivity.sendListsData(dataManager.lists)
        } else {
            #if os(watchOS)
            print("⚠️ [watchOS] WCSession not activated after waiting, skipping send")
            #endif
        }
        
        // Reload data from Core Data (in case iPhone sent us data)
        #if os(watchOS)
        print("🔄 [watchOS] Reloading data from DataManager...")
        #endif
        dataManager.loadData()
        
        await MainActor.run {
            loadLists()
            #if os(watchOS)
            print("🔄 [watchOS] Refresh/sync complete. Loaded \(lists.count) lists")
            #endif
            isLoading = false
            
            // Hide sync indicator after brief delay
            Task {
                try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
                await MainActor.run {
                    isSyncingFromiOS = false
                }
            }
        }
    }
}


