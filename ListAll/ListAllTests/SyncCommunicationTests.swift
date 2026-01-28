//
//  SyncCommunicationTests.swift
//  ListAllTests
//
//  Tests for iOS ↔ Watch sync communication
//  Verifies critical sync functionality including the list modifiedAt bug fix
//

import XCTest
@testable import ListAll

/// Tests for iOS ↔ Watch sync communication
/// Tests the critical bug: items not syncing when list's modifiedAt isn't updated
/// Uses isolated TestDataManager to avoid App Groups entitlement requirements
final class SyncCommunicationTests: XCTestCase {

    var dataManager: TestDataManager!

    override func setUpWithError() throws {
        // During fastlane snapshot runs, skip these tests to avoid interfering with UI tests
        // and to prevent simulator crash dialogs from background sync-related notifications.
        if ProcessInfo.processInfo.environment["FASTLANE_SNAPSHOT"] == "YES" {
            throw XCTSkip("Skipping SyncCommunicationTests during fastlane snapshot run")
        }
    }

    @MainActor
    override func setUp() {
        super.setUp()
        dataManager = TestHelpers.createTestDataManager()
    }

    override func tearDown() {
        dataManager = nil
        super.tearDown()
    }

    // MARK: - Critical Bug Fix Tests: Always Sync Items

    /// Test: Items sync even when list's modifiedAt hasn't changed
    /// This was the critical bug: we only synced items if list.modifiedAt > existing.modifiedAt
    func testItemsSyncRegardlessOfListModifiedAt() {
        // Given: iOS has a list
        var list = List(name: "Test List")
        list.modifiedAt = Date(timeIntervalSince1970: 1000) // Old timestamp
        dataManager.addList(list)

        // When: Watch receives the same list with a new item, but same list modifiedAt
        var item = Item(title: "New Item", listId: list.id)
        item.modifiedAt = Date(timeIntervalSince1970: 2000) // Item is newer

        var updatedList = list
        updatedList.items = [item]
        updatedList.modifiedAt = Date(timeIntervalSince1970: 1000) // Same as before!

        // Simulate receiving sync from Watch using isolated helper
        TestHelpers.simulateSyncFromWatch(receivedLists: [updatedList], dataManager: dataManager)

        // Then: Item should be added even though list's modifiedAt didn't change
        let syncedList = dataManager.lists.first { $0.id == list.id }
        XCTAssertNotNil(syncedList, "List should exist after sync")
        XCTAssertEqual(syncedList?.items.count, 1, "Item should be added despite list's modifiedAt not changing")
        XCTAssertEqual(syncedList?.items.first?.title, "New Item")
    }

    /// Test: Item crossed-out state syncs even when list's modifiedAt hasn't changed
    func testItemCrossedOutStateSyncsRegardlessOfListModifiedAt() {
        // Given: iOS has a list with an uncrossed item
        var list = List(name: "Groceries")
        list.modifiedAt = Date(timeIntervalSince1970: 1000)

        var item = Item(title: "Milk", listId: list.id)
        item.isCrossedOut = false
        item.modifiedAt = Date(timeIntervalSince1970: 1500)

        list.items = [item]
        dataManager.addList(list)
        dataManager.addItem(item, to: list.id)

        // When: Watch receives the same list with item crossed out, but same list modifiedAt
        var crossedItem = item
        crossedItem.isCrossedOut = true
        crossedItem.modifiedAt = Date(timeIntervalSince1970: 2000) // Item updated

        var updatedList = list
        updatedList.items = [crossedItem]
        updatedList.modifiedAt = Date(timeIntervalSince1970: 1000) // List timestamp unchanged!

        // Simulate sync directly
        TestHelpers.simulateSyncFromWatch(receivedLists: [updatedList], dataManager: dataManager)

        // Then: Item's crossed-out state should update
        let syncedList = dataManager.lists.first { $0.id == list.id }
        let syncedItem = syncedList?.items.first { $0.id == item.id }
        XCTAssertTrue(syncedItem?.isCrossedOut ?? false, "Item should be crossed out after sync")
    }

    /// Test: Adding multiple items to existing list syncs correctly
    func testMultipleItemAdditionsSync() {
        // Given: iOS has a list with 1 item
        var list = List(name: "Todo")
        list.modifiedAt = Date(timeIntervalSince1970: 1000)

        var item1 = Item(title: "Task 1", listId: list.id)
        item1.modifiedAt = Date(timeIntervalSince1970: 1100)
        list.items = [item1]

        dataManager.addList(list)
        dataManager.addItem(item1, to: list.id)

        // When: Watch sends the list with 3 more items added
        var item2 = Item(title: "Task 2", listId: list.id)
        item2.modifiedAt = Date(timeIntervalSince1970: 1200)

        var item3 = Item(title: "Task 3", listId: list.id)
        item3.modifiedAt = Date(timeIntervalSince1970: 1300)

        var item4 = Item(title: "Task 4", listId: list.id)
        item4.modifiedAt = Date(timeIntervalSince1970: 1400)

        var updatedList = list
        updatedList.items = [item1, item2, item3, item4]
        updatedList.modifiedAt = Date(timeIntervalSince1970: 1000) // List timestamp unchanged

        // Simulate sync directly
        TestHelpers.simulateSyncFromWatch(receivedLists: [updatedList], dataManager: dataManager)

        // Then: All items should be present
        let syncedList = dataManager.lists.first { $0.id == list.id }
        XCTAssertEqual(syncedList?.items.count, 4, "All 4 items should be synced")
    }

    /// Test: Item deletion syncs even when list's modifiedAt hasn't changed
    func testItemDeletionSyncsRegardlessOfListModifiedAt() {
        // Given: iOS has a list with 3 items
        var list = List(name: "Shopping")
        list.modifiedAt = Date(timeIntervalSince1970: 1000)

        var item1 = Item(title: "Item 1", listId: list.id)
        item1.modifiedAt = Date(timeIntervalSince1970: 1100)

        var item2 = Item(title: "Item 2", listId: list.id)
        item2.modifiedAt = Date(timeIntervalSince1970: 1200)

        var item3 = Item(title: "Item 3", listId: list.id)
        item3.modifiedAt = Date(timeIntervalSince1970: 1300)

        list.items = [item1, item2, item3]
        dataManager.addList(list)
        dataManager.addItem(item1, to: list.id)
        dataManager.addItem(item2, to: list.id)
        dataManager.addItem(item3, to: list.id)

        // When: Watch sends the list with item2 deleted
        var updatedList = list
        updatedList.items = [item1, item3] // item2 removed
        updatedList.modifiedAt = Date(timeIntervalSince1970: 1000) // List timestamp unchanged

        // Simulate sync directly
        TestHelpers.simulateSyncFromWatch(receivedLists: [updatedList], dataManager: dataManager)

        // Then: Item2 should be removed
        let syncedList = dataManager.lists.first { $0.id == list.id }
        XCTAssertEqual(syncedList?.items.count, 2, "Should have 2 items after deletion")
        XCTAssertNil(syncedList?.items.first { $0.id == item2.id }, "Deleted item should not exist")
    }

    // MARK: - Conflict Resolution Tests

    /// Test: Newer item wins in conflict resolution
    func testNewerItemWinsConflict() {
        // Given: iOS has an item with timestamp 1000
        var list = List(name: "Tasks")
        list.modifiedAt = Date(timeIntervalSince1970: 1000)

        var item = Item(title: "Old Title", listId: list.id)
        item.modifiedAt = Date(timeIntervalSince1970: 1000)
        item.itemDescription = "Old description"

        list.items = [item]
        dataManager.addList(list)
        dataManager.addItem(item, to: list.id)

        // When: Watch sends newer version of the same item
        var newerItem = item
        newerItem.title = "New Title"
        newerItem.itemDescription = "New description"
        newerItem.modifiedAt = Date(timeIntervalSince1970: 2000) // Newer!

        var updatedList = list
        updatedList.items = [newerItem]

        // Simulate sync directly
        TestHelpers.simulateSyncFromWatch(receivedLists: [updatedList], dataManager: dataManager)

        // Then: Newer version should win
        let syncedList = dataManager.lists.first { $0.id == list.id }
        let syncedItem = syncedList?.items.first { $0.id == item.id }
        XCTAssertEqual(syncedItem?.title, "New Title", "Newer title should win")
        XCTAssertEqual(syncedItem?.itemDescription, "New description", "Newer description should win")
    }

    /// Test: Older item is rejected in conflict resolution
    func testOlderItemIsRejected() {
        // Given: iOS has an item with timestamp 2000
        var list = List(name: "Tasks")
        list.modifiedAt = Date(timeIntervalSince1970: 2000)

        var item = Item(title: "New Title", listId: list.id)
        item.modifiedAt = Date(timeIntervalSince1970: 2000)
        item.itemDescription = "New description"

        list.items = [item]
        dataManager.addList(list)
        dataManager.addItem(item, to: list.id)

        // When: Watch sends older version of the same item
        var olderItem = item
        olderItem.title = "Old Title"
        olderItem.itemDescription = "Old description"
        olderItem.modifiedAt = Date(timeIntervalSince1970: 1000) // Older!

        var updatedList = list
        updatedList.items = [olderItem]

        // Simulate sync directly
        TestHelpers.simulateSyncFromWatch(receivedLists: [updatedList], dataManager: dataManager)

        // Then: Newer local version should be preserved
        let syncedList = dataManager.lists.first { $0.id == list.id }
        let syncedItem = syncedList?.items.first { $0.id == item.id }
        XCTAssertEqual(syncedItem?.title, "New Title", "Newer local title should be preserved")
        XCTAssertEqual(syncedItem?.itemDescription, "New description", "Newer local description should be preserved")
    }

    // MARK: - Bi-directional Sync Tests

    /// Test: Multiple lists sync correctly
    func testMultipleListsSync() {
        // Given: iOS has 2 lists
        var list1 = List(name: "List 1")
        list1.modifiedAt = Date(timeIntervalSince1970: 1000)

        var item1 = Item(title: "Item 1-1", listId: list1.id)
        item1.modifiedAt = Date(timeIntervalSince1970: 1100)
        list1.items = [item1]

        var list2 = List(name: "List 2")
        list2.modifiedAt = Date(timeIntervalSince1970: 2000)

        var item2 = Item(title: "Item 2-1", listId: list2.id)
        item2.modifiedAt = Date(timeIntervalSince1970: 2100)
        list2.items = [item2]

        dataManager.addList(list1)
        dataManager.addItem(item1, to: list1.id)
        dataManager.addList(list2)
        dataManager.addItem(item2, to: list2.id)

        // When: Watch sends updated versions of both lists with new items
        var newItem1 = Item(title: "Item 1-2", listId: list1.id)
        newItem1.modifiedAt = Date(timeIntervalSince1970: 1200)

        var updatedList1 = list1
        updatedList1.items = [item1, newItem1]

        var newItem2 = Item(title: "Item 2-2", listId: list2.id)
        newItem2.modifiedAt = Date(timeIntervalSince1970: 2200)

        var updatedList2 = list2
        updatedList2.items = [item2, newItem2]

        // Simulate sync directly
        TestHelpers.simulateSyncFromWatch(receivedLists: [updatedList1, updatedList2], dataManager: dataManager)

        // Then: Both lists should have new items
        let syncedList1 = dataManager.lists.first { $0.id == list1.id }
        let syncedList2 = dataManager.lists.first { $0.id == list2.id }

        XCTAssertEqual(syncedList1?.items.count, 2, "List 1 should have 2 items")
        XCTAssertEqual(syncedList2?.items.count, 2, "List 2 should have 2 items")
    }

    // MARK: - Edge Cases

    /// Test: Empty list syncs correctly
    func testEmptyListSync() {
        // Given: iOS has a list with items
        var list = List(name: "Tasks")
        list.modifiedAt = Date(timeIntervalSince1970: 1000)

        var item = Item(title: "Task 1", listId: list.id)
        item.modifiedAt = Date(timeIntervalSince1970: 1100)
        list.items = [item]

        dataManager.addList(list)
        dataManager.addItem(item, to: list.id)

        // When: Watch sends the same list with all items removed
        var updatedList = list
        updatedList.items = []
        updatedList.modifiedAt = Date(timeIntervalSince1970: 2000) // Newer list

        // Simulate sync directly
        TestHelpers.simulateSyncFromWatch(receivedLists: [updatedList], dataManager: dataManager)

        // Then: List should be empty
        let syncedList = dataManager.lists.first { $0.id == list.id }
        XCTAssertEqual(syncedList?.items.count, 0, "List should be empty after sync")
    }

    /// Test: New list with items syncs correctly
    func testNewListWithItemsSync() {
        // Given: iOS has no lists
        XCTAssertEqual(dataManager.lists.count, 0, "Should start with no lists")

        // When: Watch sends a new list with items
        var newList = List(name: "New List")
        newList.modifiedAt = Date(timeIntervalSince1970: 1000)

        var item1 = Item(title: "Item 1", listId: newList.id)
        item1.modifiedAt = Date(timeIntervalSince1970: 1100)

        var item2 = Item(title: "Item 2", listId: newList.id)
        item2.modifiedAt = Date(timeIntervalSince1970: 1200)

        newList.items = [item1, item2]

        // Simulate sync directly
        TestHelpers.simulateSyncFromWatch(receivedLists: [newList], dataManager: dataManager)

        // Then: List and items should be created
        XCTAssertEqual(dataManager.lists.count, 1, "Should have 1 list")
        let syncedList = dataManager.lists.first { $0.id == newList.id }
        XCTAssertNotNil(syncedList, "New list should exist")
        XCTAssertEqual(syncedList?.items.count, 2, "New list should have 2 items")
    }

    /// Test: Item property changes sync (quantity, description, etc.)
    func testItemPropertyChangesSync() {
        // Given: iOS has an item
        var list = List(name: "Shopping")
        list.modifiedAt = Date(timeIntervalSince1970: 1000)

        var item = Item(title: "Milk", listId: list.id)
        item.quantity = 1
        item.itemDescription = "2% fat"
        item.modifiedAt = Date(timeIntervalSince1970: 1100)
        list.items = [item]

        dataManager.addList(list)
        dataManager.addItem(item, to: list.id)

        // When: Watch sends same item with updated properties
        var updatedItem = item
        updatedItem.quantity = 3
        updatedItem.itemDescription = "Whole milk"
        updatedItem.modifiedAt = Date(timeIntervalSince1970: 2000)

        var updatedList = list
        updatedList.items = [updatedItem]
        updatedList.modifiedAt = Date(timeIntervalSince1970: 1000) // List unchanged

        // Simulate sync directly
        TestHelpers.simulateSyncFromWatch(receivedLists: [updatedList], dataManager: dataManager)

        // Then: Item properties should update
        let syncedList = dataManager.lists.first { $0.id == list.id }
        let syncedItem = syncedList?.items.first { $0.id == item.id }
        XCTAssertEqual(syncedItem?.quantity, 3, "Quantity should update")
        XCTAssertEqual(syncedItem?.itemDescription, "Whole milk", "Description should update")
    }

    // MARK: - List Deletion Tests

    /// Test: List deletion during sync (list on Watch deleted should be removed locally)
    func testListDeletionDuringSync() {
        // Given: iOS has 2 lists
        var list1 = List(name: "Keep Me")
        list1.modifiedAt = Date(timeIntervalSince1970: 1000)
        var list2 = List(name: "Delete Me")
        list2.modifiedAt = Date(timeIntervalSince1970: 1000)

        dataManager.addList(list1)
        dataManager.addList(list2)

        XCTAssertEqual(dataManager.lists.count, 2, "Should have 2 lists initially")

        // When: Watch sends only list1 (list2 was deleted on Watch)
        TestHelpers.simulateSyncFromWatch(receivedLists: [list1], dataManager: dataManager)

        // Then: list2 should be deleted locally
        XCTAssertEqual(dataManager.lists.count, 1, "Should have 1 list after sync")
        XCTAssertNil(dataManager.lists.first { $0.id == list2.id }, "Deleted list should not exist")
        XCTAssertNotNil(dataManager.lists.first { $0.id == list1.id }, "Kept list should exist")
    }
}
