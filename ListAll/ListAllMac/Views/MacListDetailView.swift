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
    // This ensures the view updates immediately when CloudKit syncs remote changes

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
    /// When true, all editing functionality is disabled - only viewing is allowed
    /// IMPORTANT: Must check fresh data from dataManager, not stale `list` parameter
    var isCurrentListArchived: Bool {
        // Check currentList first (fresh data from dataManager.lists)
        if let current = currentList {
            return current.isArchived
        }
        // If not in active lists, check archivedLists (for when viewing archived list)
        if let archived = dataManager.archivedLists.first(where: { $0.id == list.id }) {
            return archived.isArchived
        }
        // Fallback to original list (shouldn't normally reach here)
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
        ZStack(alignment: .bottom) {
            // Main content
            VStack(spacing: 0) {
                headerView
                activeFiltersBar
                Divider()

                // MARK: - Empty State Logic (Task 12.7)
                // Three-way decision for empty states:
                // 1. No items in list at all -> MacItemsEmptyStateView (comprehensive)
                // 2. Search returned no results -> MacSearchEmptyStateView (search-specific)
                // 3. Filter removed all items -> noMatchingItemsView (filter-specific)
                if viewModel.filteredItems.isEmpty {
                    Group {
                        if items.isEmpty {
                            // No items in list at all - show comprehensive empty state
                            emptyListView
                        } else if !viewModel.searchText.isEmpty {
                            // Search returned no results - show search-specific empty state
                            searchEmptyStateView
                        } else {
                            // Filter removed all items - show filter-specific empty state
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
            // Undo Complete Banner - shows when item is marked as completed
            if viewModel.showUndoButton, let item = viewModel.recentlyCompletedItem {
                MacUndoBanner(
                    itemName: item.displayTitle,
                    onUndo: {
                        viewModel.undoComplete()
                    },
                    onDismiss: {
                        viewModel.hideUndoButton()
                    }
                )
                .frame(maxWidth: 400)
                .padding(.horizontal, 20)
                .padding(.bottom, 20)
                .transition(.move(edge: .bottom).combined(with: .opacity))
                .animation(.spring(response: 0.3, dampingFraction: 0.7), value: viewModel.showUndoButton)
                .accessibilityIdentifier("UndoCompleteBanner")
            }

            // Undo Delete Banner - shows when single item is deleted
            if viewModel.showDeleteUndoButton, let item = viewModel.recentlyDeletedItem {
                MacDeleteUndoBanner(
                    itemName: item.displayTitle,
                    onUndo: {
                        viewModel.undoDeleteItem()
                    },
                    onDismiss: {
                        viewModel.hideDeleteUndoButton()
                    }
                )
                .frame(maxWidth: 400)
                .padding(.horizontal, 20)
                .padding(.bottom, 20)
                .transition(.move(edge: .bottom).combined(with: .opacity))
                .animation(.spring(response: 0.3, dampingFraction: 0.7), value: viewModel.showDeleteUndoButton)
                .accessibilityIdentifier("UndoDeleteBanner")
            }

            // Bulk Delete Undo Banner - shows when multiple items are deleted (Task 12.8)
            if viewModel.showBulkDeleteUndoBanner {
                MacBulkDeleteUndoBanner(
                    itemCount: viewModel.deletedItemsCount,
                    onUndo: {
                        viewModel.undoBulkDelete()
                        dataManager.loadData()
                    },
                    onDismiss: {
                        viewModel.hideBulkDeleteUndoBanner()
                    }
                )
                .frame(maxWidth: 400)
                .padding(.horizontal, 20)
                .padding(.bottom, 20)
                .transition(.move(edge: .bottom).combined(with: .opacity))
                .animation(.spring(response: 0.3, dampingFraction: 0.7), value: viewModel.showBulkDeleteUndoBanner)
                .accessibilityIdentifier("BulkDeleteUndoBanner")
            }
        }
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
            // Initialize ViewModel with current items
            viewModel.items = items
            // MARK: - Item-Related Proactive Tips (Task 12.5)
            triggerItemRelatedTips()
        }
        // Trigger tips when items change (e.g., user adds items)
        .onChange(of: items.count) { oldCount, newCount in
            if newCount > oldCount {
                triggerItemRelatedTips()
            }
        }
        // CRITICAL: Observe DataManager changes directly to keep ViewModel in sync
        .onReceive(NotificationCenter.default.publisher(for: .coreDataRemoteChange)) { _ in
            // CRITICAL: Defer to next run loop to prevent layout recursion
            DispatchQueue.main.async {
                // Force refresh ViewModel items when Core Data syncs remote changes
                viewModel.items = items
            }
        }
        .sheet(isPresented: $showingAddItemSheet) {
            MacAddItemSheet(
                listId: list.id,
                onSave: { title, quantity, description in
                    addItem(title: title, quantity: quantity, description: description)
                    showingAddItemSheet = false
                },
                onCancel: { showingAddItemSheet = false }
            )
        }
        // NOTE: Edit item sheet has been moved to MacMainView (outside NavigationSplitView)
        // to prevent state loss during CloudKit sync view invalidation
        .sheet(isPresented: $showingEditListSheet) {
            MacEditListSheet(
                list: currentList ?? list,
                onSave: { name in
                    updateListName(name)
                    showingEditListSheet = false
                },
                onCancel: { showingEditListSheet = false }
            )
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("CreateNewItem"))) { _ in
            // Task 13.2: Block add item for archived lists
            guard !isCurrentListArchived else { return }
            showingAddItemSheet = true
        }
        // MARK: - Move/Copy Item Sheets
        .sheet(isPresented: $showingMoveItemsPicker, onDismiss: {
            // When sheet is dismissed, show confirmation if a destination was selected
            if selectedDestinationList != nil {
                showingMoveConfirmation = true
            }
        }) {
            MacDestinationListPickerSheet(
                action: .move,
                itemCount: viewModel.selectedItems.count,
                currentListId: list.id,
                onSelect: { destinationList in
                    selectedDestinationList = destinationList
                    showingMoveItemsPicker = false
                },
                onCancel: {
                    selectedDestinationList = nil
                    showingMoveItemsPicker = false
                }
            )
        }
        .sheet(isPresented: $showingCopyItemsPicker, onDismiss: {
            // When sheet is dismissed, show confirmation if a destination was selected
            if selectedDestinationList != nil {
                showingCopyConfirmation = true
            }
        }) {
            MacDestinationListPickerSheet(
                action: .copy,
                itemCount: viewModel.selectedItems.count,
                currentListId: list.id,
                onSelect: { destinationList in
                    selectedDestinationList = destinationList
                    showingCopyItemsPicker = false
                },
                onCancel: {
                    selectedDestinationList = nil
                    showingCopyItemsPicker = false
                }
            )
        }
        // MARK: - Move/Copy Confirmation Alerts
        .alert("Move Items", isPresented: $showingMoveConfirmation) {
            Button("Cancel", role: .cancel) {
                selectedDestinationList = nil
            }
            Button("Move", role: .destructive) {
                if let destination = selectedDestinationList {
                    viewModel.moveSelectedItems(to: destination)
                    viewModel.exitSelectionMode()
                    dataManager.loadData()
                }
                selectedDestinationList = nil
            }
        } message: {
            if let destination = selectedDestinationList {
                Text("Move \(viewModel.selectedItems.count) item(s) to \"\(destination.name)\"? Items will be removed from this list.")
            }
        }
        .alert("Copy Items", isPresented: $showingCopyConfirmation) {
            Button("Cancel", role: .cancel) {
                selectedDestinationList = nil
            }
            Button("Copy") {
                if let destination = selectedDestinationList {
                    viewModel.copySelectedItems(to: destination)
                    viewModel.exitSelectionMode()
                    dataManager.loadData()
                }
                selectedDestinationList = nil
            }
        } message: {
            if let destination = selectedDestinationList {
                Text("Copy \(viewModel.selectedItems.count) item(s) to \"\(destination.name)\"? Items will remain in this list.")
            }
        }
        // MARK: - Keyboard Shortcuts (Task 11.1)
        .onKeyPress(characters: CharacterSet(charactersIn: "f")) { keyPress in
            // Cmd+F focuses the search field
            guard keyPress.modifiers.contains(.command) else {
                return .ignored
            }
            isSearchFieldFocused = true
            return .handled
        }
        .onAppear {
            // Advertise Handoff activity for viewing this specific list
            HandoffService.shared.startViewingListActivity(list: list)
        }
        // MARK: - Global Cmd+F Notification Receiver (Task 12.2)
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("FocusSearchField"))) { _ in
            isSearchFieldFocused = true
        }
        // MARK: - View Menu Filter Shortcuts (Task 12.4)
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("SetFilterAll"))) { _ in
            viewModel.updateFilterOption(.all)
            viewModel.items = items
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("SetFilterActive"))) { _ in
            viewModel.updateFilterOption(.active)
            viewModel.items = items
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("SetFilterCompleted"))) { _ in
            viewModel.updateFilterOption(.completed)
            viewModel.items = items
        }
    }
}
