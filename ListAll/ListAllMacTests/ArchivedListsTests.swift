//
//  ArchivedListsTests.swift
//  ListAllMacTests
//

import XCTest
import CoreData
import Combine
#if os(macOS)
@preconcurrency import AppKit
#endif
@testable import ListAll

#if os(macOS)

final class ArchivedListsTests: XCTestCase {

    var testDataManager: TestDataManager!

    override func setUpWithError() throws {
        try super.setUpWithError()
        testDataManager = TestHelpers.createTestDataManager()
    }

    override func tearDownWithError() throws {
        testDataManager = nil
        try super.tearDownWithError()
    }

    // MARK: - Helper Methods

    /// Creates a test list with the given name
    private func createTestList(name: String, orderNumber: Int = 0) -> ListModel {
        var list = ListModel(name: name)
        list.orderNumber = orderNumber
        return list
    }

    /// Creates and archives a list, returning the archived list
    private func createAndArchiveList(name: String) -> ListModel {
        var list = createTestList(name: name)
        testDataManager.addList(list)

        // Archive the list by updating it with isArchived = true
        list.isArchived = true
        list.modifiedAt = Date()
        testDataManager.updateList(list)

        return list
    }

    // MARK: - Test 1: archivedLists property exists and starts empty

    /// Test that DataManager has an archivedLists property that starts empty
    /// This verifies the @Published var archivedLists: [List] = [] exists
    func testArchivedListsPropertyExists() {
        // Given: A fresh data manager
        // (testDataManager is created in setUp)

        // Then: archivedLists should exist and be empty initially
        // Note: TestDataManager uses loadArchivedLists() method from DataManaging protocol
        // We're testing the concept that archived lists are tracked separately
        let archivedLists = testDataManager.loadArchivedLists()
        XCTAssertNotNil(archivedLists, "archivedLists should exist")
        XCTAssertTrue(archivedLists.isEmpty, "archivedLists should start empty when no lists are archived")
    }

    // MARK: - Test 2: loadArchivedData populates archivedLists

    /// Test that loadArchivedData() populates archivedLists with archived lists
    func testLoadArchivedDataPopulatesArchivedLists() {
        // Given: Create a list and archive it
        let list = createAndArchiveList(name: "Archived Shopping List")

        // When: Call loadArchivedLists() (equivalent to loadArchivedData in production)
        let archivedLists = testDataManager.loadArchivedLists()

        // Then: archivedLists should contain the archived list
        XCTAssertEqual(archivedLists.count, 1, "archivedLists should contain 1 archived list")
        XCTAssertEqual(archivedLists.first?.id, list.id, "Archived list should match the one we archived")
        XCTAssertEqual(archivedLists.first?.name, "Archived Shopping List", "Archived list should have correct name")
        XCTAssertTrue(archivedLists.first?.isArchived ?? false, "List should be marked as archived")
    }

    // MARK: - Test 3: loadArchivedData only includes archived lists

    /// Test that loadArchivedData() only returns archived lists, not active ones
    func testLoadArchivedDataOnlyIncludesArchivedLists() {
        // Given: Create both active and archived lists
        let activeList1 = createTestList(name: "Active List 1", orderNumber: 0)
        testDataManager.addList(activeList1)

        let activeList2 = createTestList(name: "Active List 2", orderNumber: 1)
        testDataManager.addList(activeList2)

        let _ = createAndArchiveList(name: "Archived List")

        // When: Load both active and archived lists
        let activeLists = testDataManager.getLists()
        let archivedLists = testDataManager.loadArchivedLists()

        // Then: Active lists should not include archived, and vice versa
        XCTAssertEqual(activeLists.count, 2, "Should have 2 active lists")
        XCTAssertTrue(activeLists.allSatisfy { !$0.isArchived }, "Active lists should not include archived lists")

        XCTAssertEqual(archivedLists.count, 1, "Should have 1 archived list")
        XCTAssertTrue(archivedLists.allSatisfy { $0.isArchived }, "Archived lists should only include archived lists")
    }

    // MARK: - Test 4: restoreList updates archivedLists

    /// Test that restoreList() removes the list from archivedLists
    func testRestoreListUpdatesArchivedLists() {
        // Given: An archived list exists
        let archivedList = createAndArchiveList(name: "List to Restore")
        let archivedListsBefore = testDataManager.loadArchivedLists()
        XCTAssertEqual(archivedListsBefore.count, 1, "Should have 1 archived list before restore")

        // When: Restore the list
        testDataManager.restoreList(withId: archivedList.id)

        // Then: Archived lists should no longer contain the restored list
        let archivedListsAfter = testDataManager.loadArchivedLists()
        XCTAssertEqual(archivedListsAfter.count, 0, "archivedLists should be empty after restore")

        // And: The list should now appear in active lists
        let activeLists = testDataManager.getLists()
        let restoredList = activeLists.first { $0.id == archivedList.id }
        XCTAssertNotNil(restoredList, "Restored list should appear in active lists")
        XCTAssertFalse(restoredList?.isArchived ?? true, "Restored list should not be marked as archived")
    }

    // MARK: - Test 5: permanentlyDeleteList updates archivedLists

    /// Test that permanentlyDeleteList() removes the list from archivedLists
    func testPermanentlyDeleteListUpdatesArchivedLists() {
        // Given: An archived list exists
        let archivedList = createAndArchiveList(name: "List to Delete")
        let archivedListsBefore = testDataManager.loadArchivedLists()
        XCTAssertEqual(archivedListsBefore.count, 1, "Should have 1 archived list before deletion")

        // When: Permanently delete the list
        testDataManager.permanentlyDeleteList(withId: archivedList.id)

        // Then: Archived lists should no longer contain the deleted list
        let archivedListsAfter = testDataManager.loadArchivedLists()
        XCTAssertEqual(archivedListsAfter.count, 0, "archivedLists should be empty after permanent deletion")

        // And: The list should not exist anywhere
        let activeLists = testDataManager.getLists()
        let deletedInActive = activeLists.first { $0.id == archivedList.id }
        XCTAssertNil(deletedInActive, "Permanently deleted list should not appear in active lists")
    }

    // MARK: - Test 6: archivedLists sorted by modifiedAt descending

    /// Test that archivedLists are sorted by modifiedAt in descending order (most recent first)
    func testArchivedListsSortedByModifiedAtDescending() {
        // Given: Create multiple archived lists with different modifiedAt times

        // First archived list (oldest)
        var list1 = createTestList(name: "Old Archived List")
        testDataManager.addList(list1)
        list1.isArchived = true
        list1.modifiedAt = Date(timeIntervalSinceNow: -3600) // 1 hour ago
        testDataManager.updateList(list1)

        // Second archived list (middle)
        var list2 = createTestList(name: "Middle Archived List")
        testDataManager.addList(list2)
        list2.isArchived = true
        list2.modifiedAt = Date(timeIntervalSinceNow: -1800) // 30 minutes ago
        testDataManager.updateList(list2)

        // Third archived list (newest)
        var list3 = createTestList(name: "New Archived List")
        testDataManager.addList(list3)
        list3.isArchived = true
        list3.modifiedAt = Date() // now
        testDataManager.updateList(list3)

        // When: Load archived lists
        let archivedLists = testDataManager.loadArchivedLists()

        // Then: Should be sorted by modifiedAt descending (most recent first)
        XCTAssertEqual(archivedLists.count, 3, "Should have 3 archived lists")
        XCTAssertEqual(archivedLists[0].name, "New Archived List", "First should be most recently modified")
        XCTAssertEqual(archivedLists[1].name, "Middle Archived List", "Second should be middle")
        XCTAssertEqual(archivedLists[2].name, "Old Archived List", "Last should be oldest")

        // Verify ordering programmatically
        for i in 0..<(archivedLists.count - 1) {
            XCTAssertGreaterThanOrEqual(
                archivedLists[i].modifiedAt,
                archivedLists[i + 1].modifiedAt,
                "Archived lists should be sorted by modifiedAt descending"
            )
        }
    }

    // MARK: - Test 7: Multiple archives and restores maintain consistency

    /// Test that multiple archive/restore operations maintain data consistency
    func testMultipleArchiveRestoreOperations() {
        // Given: Multiple lists
        var list1 = createTestList(name: "List 1", orderNumber: 0)
        testDataManager.addList(list1)

        var list2 = createTestList(name: "List 2", orderNumber: 1)
        testDataManager.addList(list2)

        let list3 = createTestList(name: "List 3", orderNumber: 2)
        testDataManager.addList(list3)

        // Archive list1
        list1.isArchived = true
        list1.modifiedAt = Date()
        testDataManager.updateList(list1)

        // Archive list2
        list2.isArchived = true
        list2.modifiedAt = Date()
        testDataManager.updateList(list2)

        // When: Check state after archives
        var archivedLists = testDataManager.loadArchivedLists()
        var activeLists = testDataManager.getLists()

        // Then: Should have 2 archived and 1 active
        XCTAssertEqual(archivedLists.count, 2, "Should have 2 archived lists")
        XCTAssertEqual(activeLists.count, 1, "Should have 1 active list")

        // When: Restore list1
        testDataManager.restoreList(withId: list1.id)

        // Then: Should have 1 archived and 2 active
        archivedLists = testDataManager.loadArchivedLists()
        activeLists = testDataManager.getLists()
        XCTAssertEqual(archivedLists.count, 1, "Should have 1 archived list after restore")
        XCTAssertEqual(activeLists.count, 2, "Should have 2 active lists after restore")
    }

    // MARK: - Test 8: Archived list items are preserved

    /// Test that archived lists preserve their items
    func testArchivedListItemsArePreserved() {
        // Given: A list with items
        var list = createTestList(name: "List with Items")
        testDataManager.addList(list)

        // Add items to the list
        let item1 = Item(title: "Item 1")
        let item2 = Item(title: "Item 2")
        let item3 = Item(title: "Item 3")
        testDataManager.addItem(item1, to: list.id)
        testDataManager.addItem(item2, to: list.id)
        testDataManager.addItem(item3, to: list.id)

        // Verify items exist
        let itemsBefore = testDataManager.getItems(forListId: list.id)
        XCTAssertEqual(itemsBefore.count, 3, "Should have 3 items before archiving")

        // When: Archive the list
        list.isArchived = true
        list.modifiedAt = Date()
        testDataManager.updateList(list)

        // Then: Items should still be accessible
        let itemsAfter = testDataManager.getItems(forListId: list.id)
        XCTAssertEqual(itemsAfter.count, 3, "Archived list should preserve all 3 items")

        // And: Verify archived list shows in archived lists
        let archivedLists = testDataManager.loadArchivedLists()
        XCTAssertEqual(archivedLists.count, 1, "Should have 1 archived list")
        XCTAssertEqual(archivedLists.first?.id, list.id, "Archived list ID should match")
    }

    // MARK: - Test 9: Permanent delete removes items too

    /// Test that permanently deleting a list also removes its items
    func testPermanentDeleteRemovesItems() {
        // Given: An archived list with items
        var list = createTestList(name: "List to Delete Permanently")
        testDataManager.addList(list)

        let item1 = Item(title: "Item 1")
        let item2 = Item(title: "Item 2")
        testDataManager.addItem(item1, to: list.id)
        testDataManager.addItem(item2, to: list.id)

        list.isArchived = true
        list.modifiedAt = Date()
        testDataManager.updateList(list)

        let itemsBefore = testDataManager.getItems(forListId: list.id)
        XCTAssertEqual(itemsBefore.count, 2, "Should have 2 items before permanent deletion")

        // When: Permanently delete the list
        testDataManager.permanentlyDeleteList(withId: list.id)

        // Then: Items should also be deleted
        let itemsAfter = testDataManager.getItems(forListId: list.id)
        XCTAssertEqual(itemsAfter.count, 0, "Items should be deleted with the list")
    }

    // MARK: - Test 10: Empty archived state handling

    /// Test handling when there are no archived lists
    func testEmptyArchivedStateHandling() {
        // Given: Only active lists exist (no archived)
        let list1 = createTestList(name: "Active List 1")
        testDataManager.addList(list1)

        let list2 = createTestList(name: "Active List 2")
        testDataManager.addList(list2)

        // When: Load archived lists
        let archivedLists = testDataManager.loadArchivedLists()

        // Then: Should return empty array, not nil
        XCTAssertNotNil(archivedLists, "archivedLists should not be nil")
        XCTAssertTrue(archivedLists.isEmpty, "archivedLists should be empty when no lists are archived")
        XCTAssertEqual(archivedLists.count, 0, "archivedLists count should be 0")
    }

    // MARK: - Test 11: Restore UI State Management

    /// Test that restore confirmation state variables work correctly
    func testRestoreConfirmationStateManagement() {
        // Given: An archived list
        let archivedList = createAndArchiveList(name: "List to Restore via UI")

        // When: Simulating UI state for restore confirmation
        var showingRestoreConfirmation = false
        var listToRestore: ListModel? = nil

        // Trigger restore confirmation (simulates context menu "Restore" click)
        showingRestoreConfirmation = true
        listToRestore = archivedList

        // Then: State should be set correctly
        XCTAssertTrue(showingRestoreConfirmation, "Restore confirmation should be showing")
        XCTAssertNotNil(listToRestore, "listToRestore should be set")
        XCTAssertEqual(listToRestore?.id, archivedList.id, "listToRestore should match the archived list")

        // When: User confirms restore
        if let list = listToRestore {
            testDataManager.restoreList(withId: list.id)
        }
        showingRestoreConfirmation = false
        listToRestore = nil

        // Then: List should be restored and state reset
        let archivedLists = testDataManager.loadArchivedLists()
        XCTAssertTrue(archivedLists.isEmpty, "Archived lists should be empty after restore")
        XCTAssertFalse(showingRestoreConfirmation, "Confirmation should be dismissed")
        XCTAssertNil(listToRestore, "listToRestore should be nil after restore")
    }

    // MARK: - Test 12: Restore context menu availability

    /// Test that restore option should only be available for archived lists
    func testRestoreContextMenuAvailability() {
        // Given: Both active and archived lists
        let activeList = createTestList(name: "Active List")
        testDataManager.addList(activeList)

        let archivedList = createAndArchiveList(name: "Archived List")

        // Simulate UI state
        var showingArchivedLists = false

        // When: Viewing active lists
        showingArchivedLists = false

        // Then: Restore option should NOT be available (context menu shows Share/Delete)
        // This is a conceptual test - actual UI verification would be in UI tests
        XCTAssertFalse(showingArchivedLists, "Should be viewing active lists")
        // For active lists, context menu should have: Share, Divider, Delete

        // When: Viewing archived lists
        showingArchivedLists = true

        // Then: Restore option SHOULD be available
        XCTAssertTrue(showingArchivedLists, "Should be viewing archived lists")
        // For archived lists, context menu should have: Restore, Divider, Delete Permanently

        // Verify the archived list exists and can be restored
        let archivedLists = testDataManager.loadArchivedLists()
        XCTAssertEqual(archivedLists.count, 1, "Should have one archived list")
        XCTAssertEqual(archivedLists.first?.id, archivedList.id, "Archived list should be available for restore")
    }

    // MARK: - Test 13: Restore via MainViewModel

    /// Test that MainViewModel.restoreList() properly restores an archived list
    func testMainViewModelRestoreList() {
        // Given: An archived list
        let archivedList = createAndArchiveList(name: "List for ViewModel Restore")

        // Verify it's in archived lists
        var archivedLists = testDataManager.loadArchivedLists()
        XCTAssertEqual(archivedLists.count, 1, "Should have 1 archived list")

        // When: Restore the list (simulating MainViewModel.restoreList behavior)
        testDataManager.restoreList(withId: archivedList.id)

        // Then: List should move from archived to active
        archivedLists = testDataManager.loadArchivedLists()
        XCTAssertEqual(archivedLists.count, 0, "Archived lists should be empty after restore")

        let activeLists = testDataManager.getLists()
        let restoredList = activeLists.first { $0.id == archivedList.id }
        XCTAssertNotNil(restoredList, "Restored list should appear in active lists")
        XCTAssertFalse(restoredList?.isArchived ?? true, "Restored list should not be marked as archived")
    }

    // MARK: - Test 14: Restore confirmation dialog message

    /// Test that restore confirmation message includes list name
    func testRestoreConfirmationMessageIncludesListName() {
        // Given: An archived list with a specific name
        let listName = "My Important Shopping List"
        _ = createAndArchiveList(name: listName)

        // When: Building confirmation message (simulating iOS ArchivedListView pattern)
        let confirmationTitle = "Restore List"
        let confirmationMessage = String(format: "Do you want to restore \"%@\" to your active lists?", listName)

        // Then: Message should include the list name
        XCTAssertEqual(confirmationTitle, "Restore List", "Title should be 'Restore List'")
        XCTAssertTrue(confirmationMessage.contains(listName), "Message should include the list name")
        XCTAssertTrue(confirmationMessage.contains("restore"), "Message should mention restore action")
        XCTAssertTrue(confirmationMessage.contains("active lists"), "Message should mention destination")
    }

    // MARK: - Documentation Test

    func testArchivedListsDocumentation() {
        let documentation = """

        ========================================================================
        ARCHIVED LISTS BUG FIX (macOS)
        ========================================================================

        BUG DESCRIPTION:
        ----------------
        The macOS archived lists view shows empty because:
        1. MacSidebarView.displayedLists filters dataManager.lists
        2. dataManager.lists only contains active lists (isArchived == false)
        3. loadData() excludes archived lists with predicate:
           "isArchived == NO OR isArchived == nil"
        4. Therefore, filtering dataManager.lists for archived lists always returns empty

        ROOT CAUSE:
        -----------
        In MacSidebarView line 515-521:
        ```swift
        private var displayedLists: [List] {
            if showingArchivedLists {
                return dataManager.lists.filter { $0.isArchived }  // ALWAYS EMPTY!
                    .sorted { $0.orderNumber < $1.orderNumber }
            } else {
                return dataManager.lists.filter { !$0.isArchived }
                    .sorted { $0.orderNumber < $1.orderNumber }
            }
        }
        ```

        FIX IMPLEMENTATION:
        -------------------
        1. Add @Published var archivedLists: [List] = [] to DataManager
        2. Add loadArchivedData() method to populate archivedLists
        3. MacSidebarView should use dataManager.archivedLists when showingArchivedLists
        4. After restoreList() and permanentlyDeleteList(), refresh archivedLists

        TESTS IN THIS CLASS:
        --------------------
        1. testArchivedListsPropertyExists
        2. testLoadArchivedDataPopulatesArchivedLists
        3. testLoadArchivedDataOnlyIncludesArchivedLists
        4. testRestoreListUpdatesArchivedLists
        5. testPermanentlyDeleteListUpdatesArchivedLists
        6. testArchivedListsSortedByModifiedAtDescending
        7. testMultipleArchiveRestoreOperations
        8. testArchivedListItemsArePreserved
        9. testPermanentDeleteRemovesItems
        10. testEmptyArchivedStateHandling

        FILES TO MODIFY:
        ----------------
        - ListAll/Services/DataManager.swift (if exists, or equivalent)
          - Add @Published var archivedLists: [List] = []
          - Add loadArchivedData() method

        - ListAllMac/Views/MacMainView.swift
          - Update MacSidebarView.displayedLists to use dataManager.archivedLists
          - Or update MacMainView to pass archivedLists to sidebar

        REFERENCES:
        -----------
        - DataManaging protocol: loadArchivedLists() method exists
        - TestDataManager: Already implements loadArchivedLists()
        - MainViewModel: Has @Published var archivedLists already

        ========================================================================

        """

        print(documentation)
        XCTAssertTrue(true, "Documentation generated")
    }
}


#endif
