//
//  MacSidebarView+Actions.swift
//  ListAllMac
//
//  Sidebar action methods: selection mode, drag-and-drop, keyboard navigation.
//

import SwiftUI

extension MacSidebarView {

    // MARK: - Selection Mode Methods

    func enterSelectionMode() {
        isInSelectionMode = true
        selectedLists.removeAll()
    }

    func exitSelectionMode() {
        isInSelectionMode = false
        selectedLists.removeAll()
    }

    func toggleSelection(for listId: UUID) {
        if selectedLists.contains(listId) {
            selectedLists.remove(listId)
        } else {
            selectedLists.insert(listId)
        }
    }

    func selectAllLists() {
        selectedLists = Set(allVisibleLists.map { $0.id })
    }

    func deselectAllLists() {
        selectedLists.removeAll()
    }

    /// Archives selected lists (moves to archived, can be restored)
    func archiveSelectedLists() {
        // Store selected IDs before modifying
        let listsToArchive = selectedLists

        for listId in listsToArchive {
            // deleteList actually archives (sets isArchived = true)
            dataManager.deleteList(withId: listId)
        }
        dataManager.loadData()

        // Clear detail selection if archived list was selected
        if let currentSelection = selectedList, listsToArchive.contains(currentSelection.id) {
            selectedList = nil
        }

        selectedLists.removeAll()
        isInSelectionMode = false
    }

    /// Permanently deletes selected lists (irreversible, for archived lists view)
    func permanentlyDeleteSelectedLists() {
        // Store selected IDs before modifying
        let listsToDelete = selectedLists

        for listId in listsToDelete {
            dataManager.permanentlyDeleteList(withId: listId)
        }
        dataManager.loadData()

        // Clear detail selection if deleted list was selected
        if let currentSelection = selectedList, listsToDelete.contains(currentSelection.id) {
            selectedList = nil
        }

        selectedLists.removeAll()
        isInSelectionMode = false
    }

    // MARK: - Drag-and-Drop Handlers

    /// Handle item drop on a list in the sidebar (moves item to that list)
    func handleItemDrop(_ droppedItems: [ItemTransferData], to targetList: List) -> Bool {
        print("📦 Sidebar handleItemDrop called with \(droppedItems.count) items to list '\(targetList.name)'")
        var didMoveAny = false

        for itemData in droppedItems {
            print("📦 Processing dropped item: \(itemData.itemId), sourceListId: \(String(describing: itemData.sourceListId))")

            // Skip if item is already in the target list
            guard itemData.sourceListId != targetList.id else {
                print("📦 Drop skipped: item already in target list")
                continue
            }

            // Validate sourceListId exists
            guard let sourceListId = itemData.sourceListId else {
                print("❌ Sidebar drop failed: sourceListId is nil for item \(itemData.itemId)")
                continue
            }

            // Find the item in DataManager
            let items = dataManager.getItems(forListId: sourceListId)
            guard let item = items.first(where: { $0.id == itemData.itemId }) else {
                print("❌ Sidebar drop failed: could not find item \(itemData.itemId) in source list \(sourceListId)")
                continue
            }

            // Move item to the target list
            dataRepository.moveItem(item, to: targetList)
            didMoveAny = true
            print("📦 Moved item '\(item.title)' to list '\(targetList.name)'")
        }

        if didMoveAny {
            dataManager.loadData()
        }

        return didMoveAny
    }

    /// Handle list reordering via drag-and-drop (only for active lists section)
    func moveList(from source: IndexSet, to destination: Int) {
        // Get current order (displayedLists = activeLists only)
        var reorderedLists = displayedLists

        // Perform the move
        reorderedLists.move(fromOffsets: source, toOffset: destination)

        // Update order numbers - must modify array elements directly (value types!)
        for index in reorderedLists.indices {
            reorderedLists[index].orderNumber = index
            reorderedLists[index].modifiedAt = Date()
        }

        print("📦 Reordering lists: \(reorderedLists.map { "\($0.name):\($0.orderNumber)" })")

        // Persist the new order
        dataManager.updateListsOrder(reorderedLists)
        dataManager.loadData()

        print("📦 Reordered lists via drag-and-drop")
    }

    /// Shows share popover for a list from sidebar context menu
    func shareListFromSidebar(_ list: List) {
        listToShare = list
        showingSharePopover = true
    }

    // MARK: - Keyboard Navigation Helpers (Task 11.1)

    /// Moves focus to the next or previous list after deletion
    func moveFocusAfterDeletion(deletedId: UUID) {
        let lists = allVisibleLists
        guard let currentIndex = lists.firstIndex(where: { $0.id == deletedId }) else {
            focusedListID = nil
            return
        }

        // Try next list first, then previous
        if currentIndex < lists.count - 1 {
            focusedListID = lists[currentIndex + 1].id
        } else if currentIndex > 0 {
            focusedListID = lists[currentIndex - 1].id
        } else {
            focusedListID = nil
        }
    }
}
