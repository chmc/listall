//
//  MacListDetailView+ItemsList.swift
//  ListAllMac
//
//  Items list view with keyboard navigation handlers.
//

import SwiftUI

extension MacListDetailView {

    // MARK: - Items List View

    /// Whether drag-to-reorder is enabled (only when sorted by orderNumber)
    var canReorderItems: Bool {
        viewModel.currentSortOption == .orderNumber
    }

    /// The items to display, using ViewModel's filtered list
    var displayedItems: [Item] {
        viewModel.filteredItems
    }

    var itemsListView: some View {
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

    func handleMoveItem(from source: IndexSet, to destination: Int) {
        guard canReorderItems else { return }
        viewModel.moveItems(from: source, to: destination)
    }

    @ViewBuilder
    func makeItemRow(item: Item) -> some View {
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
}
