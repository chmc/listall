//
//  MacListDetailView+Sheets.swift
//  ListAllMac
//
//  Sheet, alert, and notification modifiers for the detail view.
//

import SwiftUI

extension MacListDetailView {

    // MARK: - Sheet & Alert Modifiers

    /// Applies all sheet, alert, and notification modifiers to the detail view
    func detailSheetsAndAlerts<V: View>(_ content: V) -> some View {
        content
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
    }

    // MARK: - Keyboard & Notification Handlers

    /// Applies keyboard shortcuts and notification handlers to the detail view
    func detailKeyboardAndNotifications<V: View>(_ content: V) -> some View {
        content
            // MARK: - Keyboard Shortcuts (Task 11.1)
            .onKeyPress(characters: CharacterSet(charactersIn: "f")) { keyPress in
                guard keyPress.modifiers.contains(.command) else {
                    return .ignored
                }
                isSearchFieldFocused = true
                return .handled
            }
            .onAppear {
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
