//
//  MacListDetailView+Actions.swift
//  ListAllMac
//
//  Item action methods, drag-and-drop, Quick Look, and feature tips.
//

import SwiftUI
import Quartz

extension MacListDetailView {

    // MARK: - Item Actions

    /// Toggles item completion state using ViewModel to enable undo functionality.
    /// When completing an item, a 5-second undo banner appears at the bottom.
    func toggleItem(_ item: Item) {
        // Use ViewModel's toggleItemCrossedOut to enable undo banner
        // This triggers showUndoForCompletedItem when marking as complete
        viewModel.toggleItemCrossedOut(item)
    }

    func addItem(title: String, quantity: Int, description: String?) {
        var newItem = Item(title: title, listId: list.id)
        newItem.quantity = quantity
        newItem.itemDescription = description
        newItem.orderNumber = items.count
        dataManager.addItem(newItem, to: list.id)
        dataManager.loadData()
    }

    func updateItem(_ item: Item, title: String, quantity: Int, description: String?, images: [ItemImage]? = nil) {
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
    func deleteItem(_ item: Item) {
        // Use ViewModel's deleteItem to enable undo banner
        // This stores the item for potential restoration and shows the delete undo banner
        viewModel.deleteItem(item)
    }

    func updateListName(_ name: String) {
        guard var updatedList = currentList else { return }
        updatedList.name = name
        dataManager.updateList(updatedList)
    }

    // MARK: - Quick Look

    /// Shows Quick Look preview for an item's images
    func showQuickLook(for item: Item) {
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
    func moveFocusAfterItemDeletion(deletedId: UUID) {
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
    func handleItemDrop(_ droppedItems: [ItemTransferData]) -> Bool {
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
    func triggerItemRelatedTips() {
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
