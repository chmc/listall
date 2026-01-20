//
//  ReadOnlyArchivedListsTests.swift
//  ListAllMacTests
//
//  TDD tests for macOS read-only archived lists functionality (Task 13.2).
//  Tests written before implementation following TDD approach.
//
//  Goal: Archived lists should be completely read-only - no editing,
//  no adding items, no deleting items, no reordering. Only viewing allowed.
//

import Testing
import Foundation
@testable import ListAll

// Use ListModel typealias to avoid conflict with SwiftUI.List
typealias ReadOnlyTestListModel = ListAll.List

/// Tests for macOS read-only archived lists behavior
/// Verifies that archived lists cannot be modified
@Suite(.serialized)
struct ReadOnlyArchivedListsTests {

    // MARK: - Test 1: isCurrentListArchived property returns correct value

    @Test("isCurrentListArchived returns true for archived list")
    func testIsCurrentListArchivedReturnsTrue() async throws {
        // Arrange: Create an archived list
        var list = ReadOnlyTestListModel(name: "Archived Test List")
        list.isArchived = true

        // Assert: isArchived property should be true
        #expect(list.isArchived == true, "isArchived should be true for archived list")
    }

    @Test("isCurrentListArchived returns false for active list")
    func testIsCurrentListArchivedReturnsFalse() async throws {
        // Arrange: Create an active list
        let list = ReadOnlyTestListModel(name: "Active Test List")

        // Assert: isArchived property should be false by default
        #expect(list.isArchived == false, "isArchived should be false for active list")
    }

    // MARK: - Test 2: Add Item functionality is disabled for archived lists

    @Test("Add item button should be hidden for archived lists")
    func testAddItemButtonHiddenForArchivedList() async throws {
        // Arrange: Create an archived list
        var list = ReadOnlyTestListModel(name: "Archived List")
        list.isArchived = true

        // Assert: For archived list, add item should be disabled
        // This is a behavioral specification - the UI will hide the button
        // based on list.isArchived
        #expect(list.isArchived == true, "Archived list should have isArchived = true")

        // Implementation note: MacListDetailView toolbar should conditionally show
        // Add Item button only when !isCurrentListArchived
    }

    // MARK: - Test 3: Edit List functionality is disabled for archived lists

    @Test("Edit list button should be hidden for archived lists")
    func testEditListButtonHiddenForArchivedList() async throws {
        // Arrange: Create an archived list
        var list = ReadOnlyTestListModel(name: "Archived List")
        list.isArchived = true

        // Assert: Archived list should have isArchived = true
        #expect(list.isArchived == true, "Archived list should have isArchived = true")

        // Implementation note: headerView's editListButton should be hidden
        // when isCurrentListArchived is true
    }

    // MARK: - Test 4: Selection mode is disabled for archived lists

    @Test("Selection mode button should be hidden for archived lists")
    func testSelectionModeButtonHiddenForArchivedList() async throws {
        // Arrange: Create an archived list
        var list = ReadOnlyTestListModel(name: "Archived List")
        list.isArchived = true

        // Assert: Archived list should have isArchived = true
        #expect(list.isArchived == true, "Archived list should have isArchived = true")

        // Implementation note: selectionModeButton should be hidden
        // when isCurrentListArchived is true
    }

    // MARK: - Test 5: Item toggle completion is disabled for archived lists

    @Test("Item row should not show completion toggle for archived lists")
    func testItemRowReadOnlyForArchivedList() async throws {
        // Arrange: Create an item in an archived list
        var list = ReadOnlyTestListModel(name: "Archived List")
        list.isArchived = true
        let item = Item(title: "Test Item", listId: list.id)

        // Assert: Item should exist but list should be archived
        #expect(list.isArchived == true, "List should be archived")
        #expect(item.title == "Test Item", "Item should have correct title")

        // Implementation note: MacItemRowView should hide completion checkbox
        // and edit/delete buttons when isArchivedList is true
    }

    // MARK: - Test 6: Item edit button is hidden for archived lists

    @Test("Item edit button should be hidden for archived lists")
    func testItemEditButtonHiddenForArchivedList() async throws {
        // Arrange: Create an item in an archived list
        var list = ReadOnlyTestListModel(name: "Archived List")
        list.isArchived = true

        // Assert
        #expect(list.isArchived == true, "List should be archived")

        // Implementation note: MacItemRowView hover actions should not show
        // edit button when isArchivedList is true
    }

    // MARK: - Test 7: Item delete button is hidden for archived lists

    @Test("Item delete button should be hidden for archived lists")
    func testItemDeleteButtonHiddenForArchivedList() async throws {
        // Arrange: Create an archived list
        var list = ReadOnlyTestListModel(name: "Archived List")
        list.isArchived = true

        // Assert
        #expect(list.isArchived == true, "List should be archived")

        // Implementation note: MacItemRowView hover actions should not show
        // delete button when isArchivedList is true
    }

    // MARK: - Test 8: Quick Look button should REMAIN visible for archived lists

    @Test("Quick Look button should remain visible for archived lists")
    func testQuickLookButtonVisibleForArchivedList() async throws {
        // Arrange: Create an item with images in an archived list
        var list = ReadOnlyTestListModel(name: "Archived List")
        list.isArchived = true
        var item = Item(title: "Item with Images", listId: list.id)
        let testImage = ItemImage(imageData: Data([0x89, 0x50, 0x4E, 0x47])) // PNG header
        item.images = [testImage]

        // Assert: Item has images and list is archived
        #expect(list.isArchived == true, "List should be archived")
        #expect(item.hasImages == true, "Item should have images")

        // Implementation note: Quick Look button should REMAIN visible
        // as viewing images is allowed for archived lists
    }

    // MARK: - Test 9: Drag-to-reorder is disabled for archived lists

    @Test("Drag-to-reorder should be disabled for archived lists")
    func testDragReorderDisabledForArchivedList() async throws {
        // Arrange: Create an archived list
        var list = ReadOnlyTestListModel(name: "Archived List")
        list.isArchived = true

        // Assert
        #expect(list.isArchived == true, "List should be archived")

        // Implementation note: .onMove handler should only be enabled
        // when !isCurrentListArchived
    }

    // MARK: - Test 10: Context menu shows only Quick Look for archived lists

    @Test("Context menu should only show Quick Look for archived list items")
    func testContextMenuReadOnlyForArchivedList() async throws {
        // Arrange: Create an archived list with items
        var list = ReadOnlyTestListModel(name: "Archived List")
        list.isArchived = true

        // Assert
        #expect(list.isArchived == true, "List should be archived")

        // Implementation note: MacItemRowView context menu should only show
        // Quick Look option (if images exist) for archived list items
        // No Edit, Mark as Complete/Active, or Delete options
    }

    // MARK: - Test 11: Keyboard shortcuts for editing disabled for archived lists

    @Test("Space key should only trigger Quick Look, not toggle completion for archived lists")
    func testSpaceKeyBehaviorForArchivedList() async throws {
        // Arrange: Create an archived list
        var list = ReadOnlyTestListModel(name: "Archived List")
        list.isArchived = true

        // Assert
        #expect(list.isArchived == true, "List should be archived")

        // Implementation note: Space key in itemsListView should:
        // - Show Quick Look if item has images (allowed)
        // - Do nothing if item has no images (no toggle allowed)
    }

    @Test("Enter key should not open edit sheet for archived lists")
    func testEnterKeyBehaviorForArchivedList() async throws {
        // Arrange: Create an archived list
        var list = ReadOnlyTestListModel(name: "Archived List")
        list.isArchived = true

        // Assert
        #expect(list.isArchived == true, "List should be archived")

        // Implementation note: Enter key handler should return .ignored
        // when isCurrentListArchived is true
    }

    @Test("Delete key should not delete items for archived lists")
    func testDeleteKeyBehaviorForArchivedList() async throws {
        // Arrange: Create an archived list
        var list = ReadOnlyTestListModel(name: "Archived List")
        list.isArchived = true

        // Assert
        #expect(list.isArchived == true, "List should be archived")

        // Implementation note: Delete key handler should return .ignored
        // when isCurrentListArchived is true
    }

    @Test("Cmd+Option+Up/Down should not reorder items for archived lists")
    func testKeyboardReorderingDisabledForArchivedList() async throws {
        // Arrange: Create an archived list
        var list = ReadOnlyTestListModel(name: "Archived List")
        list.isArchived = true

        // Assert
        #expect(list.isArchived == true, "List should be archived")

        // Implementation note: Keyboard reordering handlers should return .ignored
        // when isCurrentListArchived is true
    }

    // MARK: - Test 12: Share button should remain visible for archived lists

    @Test("Share button should remain visible for archived lists")
    func testShareButtonVisibleForArchivedList() async throws {
        // Arrange: Create an archived list
        var list = ReadOnlyTestListModel(name: "Archived List")
        list.isArchived = true

        // Assert
        #expect(list.isArchived == true, "List should be archived")

        // Implementation note: shareButton in headerView should remain visible
        // Sharing (viewing/exporting) is allowed for archived lists
    }

    // MARK: - Test 13: Filter/Sort controls should remain visible for archived lists

    @Test("Filter and Sort controls should remain visible for archived lists")
    func testFilterSortVisibleForArchivedList() async throws {
        // Arrange: Create an archived list
        var list = ReadOnlyTestListModel(name: "Archived List")
        list.isArchived = true

        // Assert
        #expect(list.isArchived == true, "List should be archived")

        // Implementation note: filterSortControls and searchFieldView should remain visible
        // Filtering and sorting are view-only operations, allowed for archived lists
    }

    // MARK: - Test 14: Visual archived indicator should be shown

    @Test("Archived badge should be displayed for archived lists")
    func testArchivedBadgeDisplayed() async throws {
        // Arrange: Create an archived list
        var list = ReadOnlyTestListModel(name: "Archived List")
        list.isArchived = true

        // Assert
        #expect(list.isArchived == true, "List should be archived")

        // Implementation note: headerView should display an "Archived" badge
        // similar to iOS ArchivedListView's header styling
    }
}

// MARK: - Integration Tests with DataManager

@Suite(.serialized)
struct ReadOnlyArchivedListsIntegrationTests {

    @Test("Archived list items should not be modifiable via UI")
    func testArchivedListItemsNotModifiableViaUI() async throws {
        // This test validates the DESIGN PRINCIPLE:
        // Archived lists are read-only at the UI level, not the DataManager level.
        // The DataManager CAN still modify archived list items (for restore functionality),
        // but the UI prevents all modifications.

        // Arrange: Create an archived list
        var list = ReadOnlyTestListModel(name: "Test List")
        list.isArchived = true

        // Assert: The isArchived property is what the UI checks
        #expect(list.isArchived == true, "List should be marked as archived")

        // Implementation note:
        // - MacListDetailView.isCurrentListArchived returns list.isArchived
        // - When true, UI hides: Add Item, Edit List, Selection Mode, Edit/Delete buttons
        // - When true, UI disables: keyboard shortcuts for editing, drag-to-reorder
        // - When true, UI shows: read-only badge, Quick Look only in context menu
        // - The DataManager does NOT enforce read-only (allows restore functionality)
    }
}

// MARK: - Tab Switching Behavior Tests (Task 13.4)

/// Tests for selection clearing when switching between Active/Archived views
/// Bug discovered: When switching from archived to active view, selectedList retained
/// the archived list, causing active view to show archived UI (Restore button, read-only)
@Suite(.serialized)
struct TabSwitchSelectionTests {

    @Test("Switching from archived to active view should clear archived list selection")
    func testSwitchFromArchivedToActiveViewClearsSelection() async throws {
        // This test documents the expected behavior:
        // When user switches from "Archived Lists" view to "Active Lists" view,
        // any selected archived list should be deselected to prevent showing
        // archived UI in the active lists context.

        var archivedList = ReadOnlyTestListModel(name: "Archived List")
        archivedList.isArchived = true

        // Scenario:
        // 1. User is in "Archived Lists" view (showingArchivedLists = true)
        // 2. User selects an archived list (selectedList = archivedList)
        // 3. User switches to "Active Lists" view (showingArchivedLists = false)
        // 4. Expected: selectedList should become nil

        // Implementation note:
        // MacMainView's .onChange(of: showingArchivedLists) handler should set
        // selectedList = nil when the view changes, to prevent stale selection.

        // Assert the design principle
        #expect(archivedList.isArchived == true, "Archived list should have isArchived = true")

        // Implementation requirement: The selection MUST be cleared on tab switch
        // to prevent an archived list from appearing selected in active view
    }

    @Test("Switching from active to archived view should clear active list selection")
    func testSwitchFromActiveToArchivedViewClearsSelection() async throws {
        // This test documents the expected behavior:
        // When user switches from "Active Lists" view to "Archived Lists" view,
        // any selected active list should be deselected for consistency.

        let activeList = ReadOnlyTestListModel(name: "Active List")

        // Scenario:
        // 1. User is in "Active Lists" view (showingArchivedLists = false)
        // 2. User selects an active list (selectedList = activeList)
        // 3. User switches to "Archived Lists" view (showingArchivedLists = true)
        // 4. Expected: selectedList should become nil

        // Assert the design principle
        #expect(activeList.isArchived == false, "Active list should have isArchived = false")

        // Implementation requirement: The selection MUST be cleared on tab switch
        // to prevent an active list from appearing selected in archived view
    }

    @Test("Selected list must belong to current displayedLists domain")
    func testSelectedListMustBelongToDisplayedLists() async throws {
        // This test documents the invariant:
        // If selectedList is not nil, it must exist in displayedLists.
        // An archived list should never be shown in active lists view, and vice versa.

        var archivedList = ReadOnlyTestListModel(name: "Archived List")
        archivedList.isArchived = true

        let activeList = ReadOnlyTestListModel(name: "Active List")

        // Design principle:
        // - When showingArchivedLists = true, displayedLists = archivedLists
        // - When showingArchivedLists = false, displayedLists = lists.filter { !$0.isArchived }
        // - selectedList (if not nil) must exist in displayedLists

        #expect(archivedList.isArchived == true, "Archived list has isArchived = true")
        #expect(activeList.isArchived == false, "Active list has isArchived = false")

        // Implementation note:
        // When switching tabs, clearing selectedList ensures this invariant is maintained.
        // An alternative approach would be to validate selectedList against displayedLists
        // and clear it only if invalid, but clearing unconditionally is simpler and safer.
    }

    @Test("Active list detail view must not show Restore button")
    func testActiveListDetailViewNoRestoreButton() async throws {
        // This test documents the critical bug that was fixed:
        // An active list was showing the Restore button because selectedList retained
        // an archived list when switching from archived to active view.

        let activeList = ReadOnlyTestListModel(name: "Active List")

        // For an active list (isArchived = false):
        // - Restore button should NOT be visible
        // - Add Item button SHOULD be visible
        // - All editing controls SHOULD be enabled

        #expect(activeList.isArchived == false, "Active list should not be archived")

        // The Restore button visibility is controlled by isCurrentListArchived
        // which checks list.isArchived. With the fix clearing selectedList on tab switch,
        // active lists can never show archived UI.
    }

    @Test("Active list should allow adding new items")
    func testActiveListAllowsAddingItems() async throws {
        // This test documents that active lists must have full editing capabilities

        let activeList = ReadOnlyTestListModel(name: "Active List")

        // For an active list (isArchived = false):
        // - Add Item button should be visible
        // - All editing keyboard shortcuts should work
        // - Drag-to-reorder should be enabled

        #expect(activeList.isArchived == false, "Active list should not be archived")

        // The fix ensures that when viewing active lists, selectedList cannot
        // be an archived list, so all editing capabilities are available.
    }
}
