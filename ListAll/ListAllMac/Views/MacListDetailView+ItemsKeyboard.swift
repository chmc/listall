//
//  MacListDetailView+ItemsKeyboard.swift
//  ListAllMac
//
//  Keyboard navigation handlers for the items list.
//

import SwiftUI

extension MacListDetailView {

    // MARK: - Items List Keyboard Handlers (Task 11.1)

    /// Applies all keyboard navigation handlers to the items list
    func itemsKeyboardHandlers<V: View>(_ content: V) -> some View {
        content
            // Task 13.2: Keyboard shortcuts for editing are disabled for archived lists
            .onKeyPress(.space) {
                if viewModel.isInSelectionMode && !isCurrentListArchived {
                    guard let focusedID = focusedItemID else {
                        return .ignored
                    }
                    viewModel.toggleSelection(for: focusedID)
                    return .handled
                }
                guard let focusedID = focusedItemID,
                      let item = displayedItems.first(where: { $0.id == focusedID }) else {
                    return .ignored
                }
                if item.hasImages {
                    showQuickLook(for: item)
                    return .handled
                } else if isCurrentListArchived {
                    return .ignored
                } else {
                    toggleItem(item)
                    return .handled
                }
            }
            .onKeyPress(.return) {
                guard !viewModel.isInSelectionMode else {
                    return .ignored
                }
                guard !isCurrentListArchived else {
                    return .ignored
                }
                guard let focusedID = focusedItemID,
                      let item = displayedItems.first(where: { $0.id == focusedID }) else {
                    return .ignored
                }
                onEditItem(item)
                return .handled
            }
            .onKeyPress(.delete) {
                guard !isCurrentListArchived else {
                    return .ignored
                }
                if viewModel.isInSelectionMode && !viewModel.selectedItems.isEmpty {
                    viewModel.deleteSelectedItemsWithUndo()
                    dataManager.loadData()
                    return .handled
                }
                guard let focusedID = focusedItemID,
                      let item = displayedItems.first(where: { $0.id == focusedID }) else {
                    return .ignored
                }
                deleteItem(item)
                moveFocusAfterItemDeletion(deletedId: focusedID)
                return .handled
            }
            .onKeyPress(.escape) {
                if viewModel.isInSelectionMode {
                    viewModel.exitSelectionMode()
                    return .handled
                }
                return .ignored
            }
            .onKeyPress(characters: CharacterSet(charactersIn: "a")) { keyPress in
                guard keyPress.modifiers.contains(.command) && viewModel.isInSelectionMode && !isCurrentListArchived else {
                    return .ignored
                }
                viewModel.selectAll()
                return .handled
            }
            .onKeyPress(characters: CharacterSet(charactersIn: "c")) { keyPress in
                guard keyPress.modifiers.isEmpty else {
                    return .ignored
                }
                guard !isCurrentListArchived else {
                    return .ignored
                }
                guard let focusedID = focusedItemID,
                      let item = displayedItems.first(where: { $0.id == focusedID }) else {
                    return .ignored
                }
                toggleItem(item)
                return .handled
            }
            // MARK: - Keyboard Reordering (Task 12.11)
            .onKeyPress(keys: [.upArrow]) { keyPress in
                guard keyPress.modifiers.contains(.command),
                      keyPress.modifiers.contains(.option) else {
                    return .ignored
                }
                guard !isCurrentListArchived else { return .ignored }
                guard viewModel.canReorderWithKeyboard else { return .ignored }
                guard let focusedID = focusedItemID else { return .ignored }
                viewModel.moveItemUp(focusedID)
                return .handled
            }
            .onKeyPress(keys: [.downArrow]) { keyPress in
                guard keyPress.modifiers.contains(.command),
                      keyPress.modifiers.contains(.option) else {
                    return .ignored
                }
                guard !isCurrentListArchived else { return .ignored }
                guard viewModel.canReorderWithKeyboard else { return .ignored }
                guard let focusedID = focusedItemID else { return .ignored }
                viewModel.moveItemDown(focusedID)
                return .handled
            }
            // MARK: - Clear All Filters Shortcut (Task 12.12)
            .onKeyPress(keys: [.delete]) { keyPress in
                guard keyPress.modifiers.contains(.command),
                      keyPress.modifiers.contains(.shift) else {
                    return .ignored
                }
                viewModel.clearAllFilters()
                return .handled
            }
    }
}
