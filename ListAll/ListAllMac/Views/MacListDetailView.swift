//
//  MacListDetailView.swift
//  ListAllMac
//
//  Detail view showing items for a selected list.
//

import SwiftUI
import AppKit
import Quartz

struct MacListDetailView: View {
    let list: List  // Original list from selection (may become stale)
    let onEditItem: (Item) -> Void  // Callback to parent for edit sheet (prevents state loss)
    @EnvironmentObject var dataManager: DataManager

    // MARK: - Proactive Feature Tips (Task 12.5)
    @ObservedObject var tooltipManager = MacTooltipManager.shared

    // ViewModel for filtering, sorting, and item management
    @StateObject var viewModel: ListViewModel

    // State for item management (NOTE: edit sheet state moved to MacMainView)
    @State var showingAddItemSheet = false
    @State var showingEditListSheet = false

    // State for filter/sort popover
    @State var showingOrganizationPopover = false

    // State for share popover
    @State var showingSharePopover = false

    // State for multi-select mode
    @State var showingMoveItemsPicker = false
    @State var showingCopyItemsPicker = false
    // showingDeleteConfirmation removed (Task 12.8) - now uses undo banner instead
    @State var selectedDestinationList: List?
    @State var showingMoveConfirmation = false
    @State var showingCopyConfirmation = false

    // State for Quick Look
    @State var quickLookItem: Item?

    // DataRepository for drag-and-drop operations
    let dataRepository = DataRepository()

    // MARK: - Keyboard Navigation (Task 11.1)
    /// Focus state for individual item rows - enables arrow key navigation
    @FocusState var focusedItemID: UUID?
    /// Focus state for search field
    @FocusState var isSearchFieldFocused: Bool

    /// Callback to restore the archived list (Task 13.1 UX improvement)
    let onRestore: () -> Void

    init(list: List, onEditItem: @escaping (Item) -> Void, onRestore: @escaping () -> Void = {}) {
        self.list = list
        self.onEditItem = onEditItem
        self.onRestore = onRestore
        _viewModel = StateObject(wrappedValue: ListViewModel(list: list))
    }

    // CRITICAL: Compute current list and items directly from @Published source
    // Using @State copy breaks SwiftUI observation chain on macOS

    /// Get the current version of this list from DataManager (may have been updated by CloudKit)
    var currentList: List? {
        dataManager.lists.first(where: { $0.id == list.id })
    }

    /// Get items directly from DataManager for proper reactivity
    var items: [Item] {
        dataManager.getItems(forListId: list.id)
            .sorted { $0.orderNumber < $1.orderNumber }
    }

    /// Display name from current data (falls back to original if list not found)
    var displayName: String {
        currentList?.name ?? list.name
    }

    // MARK: - Archived List Read-Only Mode (Task 13.2)

    /// Check if current list is archived (read-only mode)
    var isCurrentListArchived: Bool {
        if let current = currentList {
            return current.isArchived
        }
        if let archived = dataManager.archivedLists.first(where: { $0.id == list.id }) {
            return archived.isArchived
        }
        return list.isArchived
    }

    /// Whether any filter is active (non-default filter, sort, or search)
    var hasActiveFilters: Bool {
        viewModel.currentFilterOption != .all ||
        viewModel.currentSortOption != .orderNumber ||
        !viewModel.searchText.isEmpty
    }

    /// Count of active filters (for showing "Clear All" button when multiple active)
    var activeFilterCount: Int {
        var count = 0
        if !viewModel.searchText.isEmpty { count += 1 }
        if viewModel.currentFilterOption != .all { count += 1 }
        if viewModel.currentSortOption != .orderNumber { count += 1 }
        return count
    }

    // MARK: - Main Body

    var body: some View {
        detailKeyboardAndNotifications(
            detailSheetsAndAlerts(
                mainContent
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .navigationTitle(displayName)
                    .toolbar {
                        // MARK: - Add Item Button (Task 13.2: Hidden for archived lists)
                        ToolbarItem(placement: .primaryAction) {
                            if !isCurrentListArchived {
                                Button(action: { showingAddItemSheet = true }) {
                                    Label("Add Item", systemImage: "plus")
                                }
                                .accessibilityIdentifier("AddItemButton")
                                .accessibilityHint("Opens sheet to add new item")
                            }
                        }
                    }
                    // Sync ViewModel items with DataManager for proper reactivity
                    .onChange(of: items) { _, newItems in
                        viewModel.items = newItems
                    }
                    .onAppear {
                        viewModel.items = items
                        // MARK: - Item-Related Proactive Tips (Task 12.5)
                        triggerItemRelatedTips()
                    }
                    .onChange(of: items.count) { oldCount, newCount in
                        if newCount > oldCount {
                            triggerItemRelatedTips()
                        }
                    }
                    // CRITICAL: Observe DataManager changes directly to keep ViewModel in sync
                    .onReceive(NotificationCenter.default.publisher(for: .coreDataRemoteChange)) { _ in
                        DispatchQueue.main.async {
                            viewModel.items = items
                        }
                    }
            )
        )
    }

    // MARK: - Main Content

    private var mainContent: some View {
        ZStack(alignment: .bottom) {
            VStack(spacing: 0) {
                headerView
                activeFiltersBar
                Divider()

                // MARK: - Empty State Logic (Task 12.7)
                if viewModel.filteredItems.isEmpty {
                    Group {
                        if items.isEmpty {
                            emptyListView
                        } else if !viewModel.searchText.isEmpty {
                            searchEmptyStateView
                        } else {
                            noMatchingItemsView
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .dropDestination(for: ItemTransferData.self) { droppedItems, _ in
                        handleItemDrop(droppedItems)
                    }
                } else {
                    itemsListView
                }
            }

            // MARK: - Undo Banners Overlay
            undoBannersOverlay
        }
    }

}
