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
    @ObservedObject private var tooltipManager = MacTooltipManager.shared

    // ViewModel for filtering, sorting, and item management
    @StateObject private var viewModel: ListViewModel

    // State for item management (NOTE: edit sheet state moved to MacMainView)
    @State private var showingAddItemSheet = false
    @State private var showingEditListSheet = false

    // State for filter/sort popover
    @State private var showingOrganizationPopover = false

    // State for share popover
    @State private var showingSharePopover = false

    // State for multi-select mode
    @State private var showingMoveItemsPicker = false
    @State private var showingCopyItemsPicker = false
    // showingDeleteConfirmation removed (Task 12.8) - now uses undo banner instead
    @State private var selectedDestinationList: List?
    @State private var showingMoveConfirmation = false
    @State private var showingCopyConfirmation = false

    // State for Quick Look
    @State private var quickLookItem: Item?

    // DataRepository for drag-and-drop operations
    private let dataRepository = DataRepository()

    // MARK: - Keyboard Navigation (Task 11.1)
    /// Focus state for individual item rows - enables arrow key navigation
    @FocusState private var focusedItemID: UUID?
    /// Focus state for search field
    @FocusState private var isSearchFieldFocused: Bool

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
    private var currentList: List? {
        dataManager.lists.first(where: { $0.id == list.id })
    }

    /// Get items directly from DataManager for proper reactivity
    private var items: [Item] {
        dataManager.getItems(forListId: list.id)
            .sorted { $0.orderNumber < $1.orderNumber }
    }

    /// Display name from current data (falls back to original if list not found)
    private var displayName: String {
        currentList?.name ?? list.name
    }

    // MARK: - Archived List Read-Only Mode (Task 13.2)

    /// Check if current list is archived (read-only mode)
    /// When true, all editing functionality is disabled - only viewing is allowed
    /// IMPORTANT: Must check fresh data from dataManager, not stale `list` parameter
    private var isCurrentListArchived: Bool {
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
    private var hasActiveFilters: Bool {
        viewModel.currentFilterOption != .all ||
        viewModel.currentSortOption != .orderNumber ||
        !viewModel.searchText.isEmpty
    }

    /// Count of active filters (for showing "Clear All" button when multiple active)
    private var activeFilterCount: Int {
        var count = 0
        if !viewModel.searchText.isEmpty { count += 1 }
        if viewModel.currentFilterOption != .all { count += 1 }
        if viewModel.currentSortOption != .orderNumber { count += 1 }
        return count
    }

    // MARK: - Header View

    @ViewBuilder
    private var headerView: some View {
        HStack {
            // MARK: - Restore Button (Task 13.1 UX improvement)
            // Show Restore button instead of badge for better discoverability
            if isCurrentListArchived {
                restoreButton
            }

            Spacer()

            if viewModel.isInSelectionMode && !isCurrentListArchived {
                // Selection mode header controls (disabled for archived lists)
                selectionModeControls
            } else if !isCurrentListArchived {
                // Normal mode header controls (all editing disabled for archived lists)
                searchFieldView
                filterSortControls
                shareButton
                selectionModeButton
                editListButton
            } else {
                // Archived list: only show view-only controls
                searchFieldView
                filterSortControls
                shareButton
                // No selection mode or edit buttons for archived lists
            }
        }
        .padding()
    }

    // MARK: - Restore Button (Task 13.1 UX improvement)

    @ViewBuilder
    private var restoreButton: some View {
        Button(action: onRestore) {
            HStack(spacing: 4) {
                Image(systemName: "arrow.uturn.backward")
                    .font(.caption)
                Text(String(localized: "Restore"))
                    .font(.caption.weight(.medium))
            }
        }
        .buttonStyle(.borderedProminent)
        .controlSize(.small)
        .accessibilityLabel("Restore this archived list")
        .accessibilityHint("Moves list back to active lists")
    }

    // MARK: - Selection Mode Button

    @ViewBuilder
    private var selectionModeButton: some View {
        Button(action: { viewModel.enterSelectionMode() }) {
            Image(systemName: "checklist")
        }
        .buttonStyle(.plain)
        .help("Select Multiple Items")
        .accessibilityIdentifier("SelectItemsButton")
        .accessibilityLabel("Enter selection mode")
        .accessibilityHint("Enables multi-item selection for bulk operations")
    }

    // MARK: - Selection Mode Controls

    @ViewBuilder
    private var selectionModeControls: some View {
        HStack(spacing: 12) {
            // Selection count
            Text("\(viewModel.selectedItems.count) selected")
                .foregroundColor(.secondary)
                .font(.subheadline)

            // Ellipsis menu for bulk actions
            Menu {
                Section {
                    Button("Select All") {
                        viewModel.selectAll()
                    }
                    .keyboardShortcut("a", modifiers: .command)

                    Button("Deselect All") {
                        viewModel.deselectAll()
                    }
                }

                Divider()

                Section {
                    Button("Move Items...") {
                        showingMoveItemsPicker = true
                    }
                    .disabled(viewModel.selectedItems.isEmpty)

                    Button("Copy Items...") {
                        showingCopyItemsPicker = true
                    }
                    .disabled(viewModel.selectedItems.isEmpty)
                }

                Divider()

                Section {
                    Button("Delete Items", role: .destructive) {
                        // Task 12.8: Use undo banner instead of confirmation dialog
                        viewModel.deleteSelectedItemsWithUndo()
                        dataManager.loadData()
                    }
                    .disabled(viewModel.selectedItems.isEmpty)
                }
            } label: {
                Image(systemName: "ellipsis.circle")
                    .font(.title3)
            }
            .menuStyle(.borderlessButton)
            .fixedSize()
            .help("Bulk Actions")
            .accessibilityIdentifier("SelectionActionsMenu")
            .accessibilityLabel("Selection actions menu")

            // Cancel button
            Button("Cancel") {
                viewModel.exitSelectionMode()
            }
            .keyboardShortcut(.escape)
            .accessibilityIdentifier("CancelSelectionButton")
            .accessibilityLabel("Exit selection mode")
        }
    }

    @ViewBuilder
    private var shareButton: some View {
        Button(action: { showingSharePopover.toggle() }) {
            Image(systemName: "square.and.arrow.up")
        }
        .buttonStyle(.plain)
        .help("Share List (⇧⌘S)")
        .accessibilityIdentifier("ShareListButton")
        .accessibilityLabel("Share list")
        .popover(isPresented: $showingSharePopover) {
            MacShareFormatPickerView(
                list: currentList ?? list,
                onDismiss: { showingSharePopover = false }
            )
        }
    }

    @ViewBuilder
    private var searchFieldView: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.secondary)
                .accessibilityHidden(true)
            TextField(String(localized: "Search items") + "...", text: $viewModel.searchText)
                .textFieldStyle(.plain)
                .frame(width: 150)
                .focused($isSearchFieldFocused)
                .accessibilityIdentifier("ListSearchField")
                .accessibilityLabel("Search items")
                .onExitCommand {
                    // Enhanced Escape behavior (Task 12.12):
                    // 1. First press: clears search text (if not empty)
                    // 2. Second press: clears all filters (if search was empty but filters active)
                    if !viewModel.searchText.isEmpty {
                        // First: clear search text
                        viewModel.searchText = ""
                    } else if viewModel.hasActiveFilters {
                        // Second: clear all filters when search is already empty
                        viewModel.clearAllFilters()
                    }
                    isSearchFieldFocused = false
                }
            if !viewModel.searchText.isEmpty {
                Button(action: {
                    viewModel.searchText = ""
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Clear search")
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Color.secondary.opacity(0.1))
        .cornerRadius(6)
    }

    // MARK: - Filter & Sort Controls (Task 12.4)
    // Redesigned from iOS-style popover to native macOS pattern:
    // - Segmented control for filters (always visible, single click)
    // - Sort button with popover for less-frequent sort options

    @ViewBuilder
    private var filterSortControls: some View {
        HStack(spacing: 8) {
            // Filter segmented control - always visible, single click
            Picker("Filter", selection: $viewModel.currentFilterOption) {
                Text("All").tag(ItemFilterOption.all)
                Text("Active").tag(ItemFilterOption.active)
                Text("Done").tag(ItemFilterOption.completed)
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .frame(width: 180)
            .help("Filter items by status (Cmd+1/2/3)")
            .accessibilityIdentifier("FilterSegmentedControl")
            .onChange(of: viewModel.currentFilterOption) { _, newValue in
                // Sync showCrossedOutItems state when filter changes via Picker
                // This ensures "All" filter properly shows all items
                viewModel.updateFilterOption(newValue)
            }

            // Sort button - keeps popover for less-frequent sort options
            Button(action: { showingOrganizationPopover.toggle() }) {
                Image(systemName: "arrow.up.arrow.down")
            }
            .buttonStyle(.plain)
            .help("Sort Options")
            .accessibilityIdentifier("SortButton")
            .accessibilityLabel("Sort items")
            .accessibilityHint("Opens sort options")
            .popover(isPresented: $showingOrganizationPopover) {
                MacSortOnlyView(viewModel: viewModel)
            }
        }
    }

    @ViewBuilder
    private var editListButton: some View {
        Button(action: { showingEditListSheet = true }) {
            Image(systemName: "pencil")
        }
        .buttonStyle(.plain)
        .help("Edit List")
        .accessibilityIdentifier("EditListButton")
        .accessibilityLabel("Edit list name")
    }

    // MARK: - Active Filters Bar

    @ViewBuilder
    private var activeFiltersBar: some View {
        if hasActiveFilters {
            HStack(spacing: 12) {
                if !viewModel.searchText.isEmpty {
                    FilterBadge(
                        icon: "magnifyingglass",
                        text: "Search: \"\(viewModel.searchText)\"",
                        onClear: {
                            viewModel.searchText = ""
                            // CRITICAL: Refresh items from DataManager when clearing search
                            viewModel.items = items
                        }
                    )
                }

                if viewModel.currentFilterOption != .all {
                    FilterBadge(
                        icon: viewModel.currentFilterOption.systemImage,
                        text: viewModel.currentFilterOption.displayName,
                        onClear: {
                            viewModel.updateFilterOption(.all)
                            // CRITICAL: Refresh items from DataManager when clearing filter
                            viewModel.items = items
                        }
                    )
                }

                if viewModel.currentSortOption != .orderNumber {
                    let sortText = "\(viewModel.currentSortOption.displayName) (\(viewModel.currentSortDirection.displayName))"
                    FilterBadge(
                        icon: viewModel.currentSortOption.systemImage,
                        text: sortText,
                        onClear: {
                            viewModel.updateSortOption(.orderNumber)
                            // CRITICAL: Refresh items from DataManager when clearing sort
                            viewModel.items = items
                        }
                    )
                }

                // Clear All button (Task 12.12)
                // Shows when multiple filters are active or as a convenience
                if activeFilterCount > 1 {
                    Button(action: {
                        viewModel.clearAllFilters()
                        // CRITICAL: Refresh items from DataManager when clearing all filters
                        viewModel.items = items
                    }) {
                        Text("Clear All")
                            .font(.caption)
                    }
                    .buttonStyle(.plain)
                    .foregroundColor(.accentColor)
                    .help("Clear all filters (Cmd+Shift+Delete)")
                    .accessibilityIdentifier("ClearAllFiltersButton")
                }

                Spacer()

                Text("\(viewModel.filteredItems.count) of \(viewModel.items.count) items")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .numericContentTransition()
            }
            .padding(.horizontal)
            .padding(.bottom, 8)
        }
    }

    // MARK: - Empty State Views (Task 12.7: Consistent Empty State Components)
    // Replaced inline emptyListView with comprehensive MacItemsEmptyStateView component
    // Added dedicated search empty state (MacSearchEmptyStateView) for search-specific messaging

    /// Empty state view for lists with no items
    /// Uses the comprehensive MacItemsEmptyStateView component for consistency
    /// For archived lists, shows read-only state without add button (Task 13.2)
    @ViewBuilder
    private var emptyListView: some View {
        MacItemsEmptyStateView(
            hasItems: false,
            isArchived: isCurrentListArchived,
            onAddItem: {
                showingAddItemSheet = true
            }
        )
        .accessibilityIdentifier("ItemsEmptyStateView")
    }

    /// Empty state view for search with no results
    /// Dedicated messaging for search context (Task 12.7)
    @ViewBuilder
    private var searchEmptyStateView: some View {
        MacSearchEmptyStateView(
            searchText: viewModel.searchText,
            onClear: {
                viewModel.searchText = ""
                // Refresh items after clearing search
                viewModel.items = items
            }
        )
    }

    /// Empty state view when filters return no matching items
    /// Used when items exist but filter/sort hides all of them
    @ViewBuilder
    private var noMatchingItemsView: some View {
        VStack(spacing: 16) {
            Image(systemName: "line.3.horizontal.decrease.circle")
                .font(.system(size: 48))
                .foregroundColor(.secondary)
                .accessibilityHidden(true)

            Text(String(localized: "No Matching Items"))
                .font(.title3)
                .foregroundColor(.secondary)
                .accessibilityAddTraits(.isHeader)

            Text(String(localized: "Try adjusting your filter settings"))
                .font(.caption)
                .foregroundColor(.secondary)

            Button(String(localized: "Clear Filters")) {
                viewModel.searchText = ""
                viewModel.updateFilterOption(.all)
                // CRITICAL: Refresh items from DataManager when clearing all filters
                viewModel.items = items
            }
            .buttonStyle(.borderedProminent)
            .accessibilityLabel("Clear filters")
            .accessibilityHint("Clears all active filters to show all items")
        }
        .accessibilityIdentifier("NoMatchingItemsView")
    }

    // MARK: - Items List View

    /// Whether drag-to-reorder is enabled (only when sorted by orderNumber)
    private var canReorderItems: Bool {
        viewModel.currentSortOption == .orderNumber
    }

    /// The items to display, using ViewModel's filtered list
    private var displayedItems: [Item] {
        viewModel.filteredItems
    }

    private var itemsListView: some View {
        SwiftUI.List {
            ForEach(displayedItems) { item in
                makeItemRow(item: item)
                    // Task 13.2: Disable dragging for archived lists
                    // Conditional draggable using @ViewBuilder pattern
                    .modifier(ConditionalDraggable(item: item, isEnabled: !isCurrentListArchived))
                    // MARK: Keyboard Navigation (Task 11.1)
                    // CRITICAL: Use .activate interactions to prevent focus from capturing
                    // mouse clicks that should initiate drag gestures. Without this,
                    // .focusable() on macOS Sonoma+ captures all click interactions,
                    // blocking drag-and-drop from starting.
                    .focusable(interactions: .activate)
                    .focused($focusedItemID, equals: item.id)
                    // MARK: Cmd+Click and Shift+Click Multi-Select (Task 12.1)
                    // Uses NSEvent monitoring to detect modifier keys without blocking drag-and-drop
                    // Task 13.2: Disabled for archived lists
                    .onModifierClick(
                        command: {
                            guard !isCurrentListArchived else { return }
                            // Cmd+Click: Toggle selection of this item
                            viewModel.toggleSelection(for: item.id)
                        },
                        shift: {
                            guard !isCurrentListArchived else { return }
                            // Shift+Click: Select range from anchor to this item
                            viewModel.selectRange(to: item.id)
                        }
                    )
                    .accessibilityIdentifier("ItemRow_\(item.title)")
                    .listRowSeparator(.hidden)
                    .listRowInsets(EdgeInsets(top: 2, leading: 10, bottom: 2, trailing: 10))
            }
            // Task 13.2: Disable drag-to-reorder for archived lists
            .onMove(perform: isCurrentListArchived ? nil : handleMoveItem)
        }
        .listStyle(.inset)
        // MARK: - Drop Destination for Cross-List Item Moves
        // Enable dropping items from other lists onto this list
        // (Restored: this was accidentally removed, breaking item drag between lists)
        // Task 13.2: Disable drop destination for archived lists
        .dropDestination(for: ItemTransferData.self) { droppedItems, _ in
            guard !isCurrentListArchived else { return false }  // No drops on archived lists
            return handleItemDrop(droppedItems)
        }
        .accessibilityIdentifier("ItemsList")
        // MARK: - Keyboard Navigation Handlers (Task 11.1)
        // Task 13.2: Keyboard shortcuts for editing are disabled for archived lists
        .onKeyPress(.space) {
            // In selection mode, space toggles selection of focused item
            // Task 13.2: Selection mode is disabled for archived lists
            if viewModel.isInSelectionMode && !isCurrentListArchived {
                guard let focusedID = focusedItemID else {
                    return .ignored
                }
                viewModel.toggleSelection(for: focusedID)
                return .handled
            }
            // Normal mode: Space toggles completion state of focused item
            // Task 13.2: For archived lists, Space only shows Quick Look (no toggle)
            guard let focusedID = focusedItemID,
                  let item = displayedItems.first(where: { $0.id == focusedID }) else {
                return .ignored
            }
            // Check if item has images - if so, show Quick Look (allowed for archived lists)
            if item.hasImages {
                showQuickLook(for: item)
                return .handled
            } else if isCurrentListArchived {
                // Archived list without images: Space does nothing
                return .ignored
            } else {
                toggleItem(item)
                return .handled
            }
        }
        .onKeyPress(.return) {
            // Enter opens edit sheet for focused item (not in selection mode)
            // Task 13.2: Disabled for archived lists
            guard !viewModel.isInSelectionMode else {
                return .ignored
            }
            guard !isCurrentListArchived else {
                return .ignored  // No editing for archived lists
            }
            guard let focusedID = focusedItemID,
                  let item = displayedItems.first(where: { $0.id == focusedID }) else {
                return .ignored
            }
            onEditItem(item)
            return .handled
        }
        .onKeyPress(.delete) {
            // Task 13.2: Delete is disabled for archived lists
            guard !isCurrentListArchived else {
                return .ignored  // No deletion for archived lists
            }
            // In selection mode, delete selected items with undo (Task 12.8)
            if viewModel.isInSelectionMode && !viewModel.selectedItems.isEmpty {
                viewModel.deleteSelectedItemsWithUndo()
                dataManager.loadData()
                return .handled
            }
            // Normal mode: Delete removes the focused item
            guard let focusedID = focusedItemID,
                  let item = displayedItems.first(where: { $0.id == focusedID }) else {
                return .ignored
            }
            deleteItem(item)
            moveFocusAfterItemDeletion(deletedId: focusedID)
            return .handled
        }
        .onKeyPress(.escape) {
            // Escape exits selection mode
            if viewModel.isInSelectionMode {
                viewModel.exitSelectionMode()
                return .handled
            }
            return .ignored
        }
        .onKeyPress(characters: CharacterSet(charactersIn: "a")) { keyPress in
            // Cmd+A selects all items in selection mode
            // Task 13.2: Selection mode is disabled for archived lists
            guard keyPress.modifiers.contains(.command) && viewModel.isInSelectionMode && !isCurrentListArchived else {
                return .ignored
            }
            viewModel.selectAll()
            return .handled
        }
        .onKeyPress(characters: CharacterSet(charactersIn: "c")) { keyPress in
            // 'C' key toggles completion (alternative to Space for items with images)
            // Issue #9 fix: Ignore if modifier keys are pressed (don't capture Cmd+C)
            // Task 13.2: Disabled for archived lists
            guard keyPress.modifiers.isEmpty else {
                return .ignored
            }
            guard !isCurrentListArchived else {
                return .ignored  // No completion toggle for archived lists
            }
            guard let focusedID = focusedItemID,
                  let item = displayedItems.first(where: { $0.id == focusedID }) else {
                return .ignored
            }
            toggleItem(item)
            return .handled
        }
        // MARK: - Keyboard Reordering (Task 12.11)
        // Use onKeyPress with key set and check modifiers inside closure
        // Task 13.2: Keyboard reordering is disabled for archived lists
        .onKeyPress(keys: [.upArrow]) { keyPress in
            // Cmd+Option+Up moves focused item up one position
            guard keyPress.modifiers.contains(.command),
                  keyPress.modifiers.contains(.option) else {
                return .ignored
            }
            guard !isCurrentListArchived else { return .ignored }  // No reordering for archived lists
            guard viewModel.canReorderWithKeyboard else { return .ignored }
            guard let focusedID = focusedItemID else { return .ignored }
            viewModel.moveItemUp(focusedID)
            return .handled
        }
        .onKeyPress(keys: [.downArrow]) { keyPress in
            // Cmd+Option+Down moves focused item down one position
            guard keyPress.modifiers.contains(.command),
                  keyPress.modifiers.contains(.option) else {
                return .ignored
            }
            guard !isCurrentListArchived else { return .ignored }  // No reordering for archived lists
            guard viewModel.canReorderWithKeyboard else { return .ignored }
            guard let focusedID = focusedItemID else { return .ignored }
            viewModel.moveItemDown(focusedID)
            return .handled
        }
        // MARK: - Clear All Filters Shortcut (Task 12.12)
        // Cmd+Shift+Backspace (delete) clears all active filters
        .onKeyPress(keys: [.delete]) { keyPress in
            guard keyPress.modifiers.contains(.command),
                  keyPress.modifiers.contains(.shift) else {
                return .ignored
            }
            viewModel.clearAllFilters()
            return .handled
        }
    }

    private func handleMoveItem(from source: IndexSet, to destination: Int) {
        guard canReorderItems else { return }
        viewModel.moveItems(from: source, to: destination)
    }

    @ViewBuilder
    private func makeItemRow(item: Item) -> some View {
        MacItemRowView(
            item: item,
            isInSelectionMode: viewModel.isInSelectionMode,
            isSelected: viewModel.selectedItems.contains(item.id),
            isArchivedList: isCurrentListArchived,  // Task 13.2: Pass archived state for read-only mode
            onToggle: { toggleItem(item) },
            onEdit: {
                // CRITICAL FIX: Delegate to parent (MacMainView) for sheet presentation
                // Sheet state inside NavigationSplitView detail pane is lost during view invalidation
                // caused by @EnvironmentObject changes from CloudKit sync.
                // By calling parent's callback, sheet state lives OUTSIDE NavigationSplitView.
                print("🎯 MacListDetailView: Forwarding edit request to MacMainView for item: \(item.title)")
                onEditItem(item)
            },
            onDuplicate: { viewModel.duplicateItem(item) },  // Task 16.3: Duplicate item action
            onDelete: { deleteItem(item) },
            onQuickLook: { showQuickLook(for: item) },
            onToggleSelection: { viewModel.toggleSelection(for: item.id) }
        )
    }

    private func handleSpacebarPress() -> KeyPress.Result {
        if let item = quickLookItem, item.hasImages {
            showQuickLook(for: item)
            return .handled
        }
        return .ignored
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
            // Note: Restore button is in header view for better visibility
            // Delete Permanently is available via context menu on sidebar
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
            // NOTE: Edit state protection is now handled at MacMainView level (isEditingAnyItem)
            // which blocks dataManager.loadData() calls during editing
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
        // When clearing search/filter, we need fresh data from DataManager
        .onReceive(NotificationCenter.default.publisher(for: .coreDataRemoteChange)) { _ in
            // NOTE: Edit state protection is now handled at MacMainView level (isEditingAnyItem)
            // CRITICAL: Defer to next run loop to prevent layout recursion
            // Notifications can fire during layout passes, causing the error:
            // "It's not legal to call -layoutSubtreeIfNeeded on a view already being laid out"
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
        // MARK: - Delete Confirmation Alert removed (Task 12.8)
        // Bulk delete now uses undo banner instead of confirmation dialog
        // for consistency with individual delete operations
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
        // Receives notification from MacMainView's global Cmd+F handler
        // Focuses the search field regardless of where focus was before
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("FocusSearchField"))) { _ in
            isSearchFieldFocused = true
        }
        // MARK: - View Menu Filter Shortcuts (Task 12.4)
        // Receives notifications from View menu filter commands (Cmd+1/2/3)
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("SetFilterAll"))) { _ in
            viewModel.updateFilterOption(.all)
            // Refresh items from DataManager when changing filter
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

    // MARK: - Item Actions

    /// Toggles item completion state using ViewModel to enable undo functionality.
    /// When completing an item, a 5-second undo banner appears at the bottom.
    private func toggleItem(_ item: Item) {
        // Use ViewModel's toggleItemCrossedOut to enable undo banner
        // This triggers showUndoForCompletedItem when marking as complete
        viewModel.toggleItemCrossedOut(item)
    }

    private func addItem(title: String, quantity: Int, description: String?) {
        var newItem = Item(title: title, listId: list.id)
        newItem.quantity = quantity
        newItem.itemDescription = description
        newItem.orderNumber = items.count
        dataManager.addItem(newItem, to: list.id)
        dataManager.loadData()
    }

    private func updateItem(_ item: Item, title: String, quantity: Int, description: String?, images: [ItemImage]? = nil) {
        var updatedItem = item
        updatedItem.title = title
        updatedItem.quantity = quantity
        updatedItem.itemDescription = description
        if let images = images {
            updatedItem.images = images
        }
        updatedItem.modifiedAt = Date()
        dataManager.updateItem(updatedItem)
    }

    /// Deletes item using ViewModel to enable undo functionality.
    /// A 5-second undo banner appears at the bottom allowing restoration.
    private func deleteItem(_ item: Item) {
        // Use ViewModel's deleteItem to enable undo banner
        // This stores the item for potential restoration and shows the delete undo banner
        viewModel.deleteItem(item)
    }

    private func updateListName(_ name: String) {
        guard var updatedList = currentList else { return }
        updatedList.name = name
        dataManager.updateList(updatedList)
    }

    // MARK: - Quick Look

    /// Shows Quick Look preview for an item's images
    private func showQuickLook(for item: Item) {
        guard item.hasImages else {
            print("⚠️ Quick Look: Item '\(item.displayTitle)' has no images")
            return
        }

        // Use the shared QuickLookController to show preview
        QuickLookController.shared.preview(item: item)
        print("📷 Quick Look: Showing preview for '\(item.displayTitle)' with \(item.imageCount) images")
    }

    // MARK: - Keyboard Navigation Helpers (Task 11.1)

    /// Moves focus to the next or previous item after deletion
    private func moveFocusAfterItemDeletion(deletedId: UUID) {
        let items = displayedItems
        guard let currentIndex = items.firstIndex(where: { $0.id == deletedId }) else {
            focusedItemID = nil
            return
        }

        // Try next item first, then previous
        if currentIndex < items.count - 1 {
            focusedItemID = items[currentIndex + 1].id
        } else if currentIndex > 0 {
            focusedItemID = items[currentIndex - 1].id
        } else {
            focusedItemID = nil
        }
    }

    // MARK: - Drag-and-Drop Handlers

    /// Handle item drop on this list's detail view (moves item from another list)
    private func handleItemDrop(_ droppedItems: [ItemTransferData]) -> Bool {
        print("📦 handleItemDrop called with \(droppedItems.count) items")
        var didMoveAny = false

        for itemData in droppedItems {
            print("📦 Processing dropped item: \(itemData.itemId), sourceListId: \(String(describing: itemData.sourceListId))")

            // Skip if item is already in this list
            guard itemData.sourceListId != list.id else {
                print("📦 Drop skipped: item already in this list")
                continue
            }

            // Validate sourceListId exists
            guard let sourceListId = itemData.sourceListId else {
                print("❌ Drop failed: sourceListId is nil for item \(itemData.itemId)")
                continue
            }

            // Find the item in DataManager
            let sourceItems = dataManager.getItems(forListId: sourceListId)
            guard let item = sourceItems.first(where: { $0.id == itemData.itemId }) else {
                print("❌ Drop failed: could not find item \(itemData.itemId) in source list \(sourceListId)")
                continue
            }
            guard let targetList = currentList else {
                print("❌ Drop failed: currentList is nil")
                continue
            }

            // Move item to this list
            dataRepository.moveItem(item, to: targetList)
            didMoveAny = true
            print("📦 Moved item '\(item.title)' to list '\(targetList.name)'")
        }

        if didMoveAny {
            dataManager.loadData()
        }

        return didMoveAny
    }

    // MARK: - Proactive Feature Tips for Items (Task 12.5)

    /// Triggers item-related feature tips based on item count
    /// Tips help users discover features as they add more items
    private func triggerItemRelatedTips() {
        let itemCount = items.count

        // 5+ items: Show search tip
        if itemCount >= 5 {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                withAnimation(.easeIn(duration: 0.3)) {
                    _ = tooltipManager.showIfNeeded(.searchFunctionality)
                }
            }
        }

        // 7+ items: Show sort/filter tip
        if itemCount >= 7 {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.7) {
                withAnimation(.easeIn(duration: 0.3)) {
                    _ = tooltipManager.showIfNeeded(.sortFilterOptions)
                }
            }
        }

        // 2+ items: Show context menu tip
        if itemCount >= 2 {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                withAnimation(.easeIn(duration: 0.3)) {
                    _ = tooltipManager.showIfNeeded(.contextMenuActions)
                }
            }
        }
    }
}
