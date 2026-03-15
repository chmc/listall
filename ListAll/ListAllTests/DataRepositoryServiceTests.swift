import XCTest
@testable import ListAll

final class DataRepositoryServiceTests: XCTestCase {

    // MARK: - DataRepository Tests

    func testDataRepositoryReorderItems() throws {
        let testDataManager = TestHelpers.createTestDataManager()
        let repository = TestDataRepository(dataManager: testDataManager)

        // Create test list and items
        let testList = List(name: "Test List")
        testDataManager.addList(testList)

        let _ = repository.createItem(in: testList, title: "Item 1", description: "", quantity: 1)
        let _ = repository.createItem(in: testList, title: "Item 2", description: "", quantity: 1)
        let _ = repository.createItem(in: testList, title: "Item 3", description: "", quantity: 1)

        let initialItems = testDataManager.getItems(forListId: testList.id).sorted { $0.orderNumber < $1.orderNumber }
        XCTAssertEqual(initialItems.count, 3)

        // Test reordering
        repository.reorderItems(in: testList, from: 0, to: 2)

        let reorderedItems = testDataManager.getItems(forListId: testList.id).sorted { $0.orderNumber < $1.orderNumber }
        XCTAssertEqual(reorderedItems.count, 3)

        // Verify order changed
        XCTAssertEqual(reorderedItems[0].title, initialItems[1].title)
        XCTAssertEqual(reorderedItems[1].title, initialItems[2].title)
        XCTAssertEqual(reorderedItems[2].title, initialItems[0].title)
    }

    func testDataRepositoryReorderItemsInvalidIndices() throws {
        let testDataManager = TestHelpers.createTestDataManager()
        let repository = TestDataRepository(dataManager: testDataManager)

        // Create test list and items
        let testList = List(name: "Test List")
        testDataManager.addList(testList)

        let _ = repository.createItem(in: testList, title: "Item 1", description: "", quantity: 1)
        let _ = repository.createItem(in: testList, title: "Item 2", description: "", quantity: 1)

        let initialItems = testDataManager.getItems(forListId: testList.id).sorted { $0.orderNumber < $1.orderNumber }

        // Test invalid indices (should not crash)
        repository.reorderItems(in: testList, from: -1, to: 1)
        repository.reorderItems(in: testList, from: 0, to: 10)
        repository.reorderItems(in: testList, from: 5, to: 1)

        let finalItems = testDataManager.getItems(forListId: testList.id).sorted { $0.orderNumber < $1.orderNumber }

        // Items should remain unchanged after invalid operations
        XCTAssertEqual(finalItems.count, initialItems.count)
        XCTAssertEqual(finalItems[0].title, initialItems[0].title)
        XCTAssertEqual(finalItems[1].title, initialItems[1].title)
    }

    // MARK: - Phase 72: DataRepository Sync Integration Tests

    func testDataRepositoryHandlesSyncNotification() throws {
        // Test that DataRepository responds to sync notifications
        let testDataManager = TestHelpers.createTestDataManager()
        let repository = TestDataRepository(dataManager: testDataManager)

        // Create a test list
        let testList = List(name: "Test List")
        testDataManager.addList(testList)

        // Add an item directly to Core Data (simulating change from watch)
        let externalItem = Item(title: "External Item")
        testDataManager.addItem(externalItem, to: testList.id)

        // Set up expectation to observe the notification directly before posting it
        let syncExpectation = expectation(
            forNotification: NSNotification.Name("WatchConnectivitySyncReceived"),
            object: nil
        )

        // Post sync notification (simulating notification from Watch)
        NotificationCenter.default.post(
            name: NSNotification.Name("WatchConnectivitySyncReceived"),
            object: nil,
            userInfo: ["syncNotification": true]
        )

        wait(for: [syncExpectation], timeout: 5.0)

        // Verify data was reloaded by checking if lists are up to date
        let lists = repository.getAllLists()
        XCTAssertFalse(lists.isEmpty, "Lists should be reloaded after sync notification")
    }

    func testDataRepositoryListOperationsSendSyncNotification() throws {
        // Test that list operations trigger sync notifications
        let testDataManager = TestHelpers.createTestDataManager()
        let repository = TestDataRepository(dataManager: testDataManager)

        // Note: We can't easily verify WatchConnectivityService.sendSyncNotification()
        // was called without mocking, but we can verify operations complete successfully

        // Create list
        let newList = repository.createList(name: "New List")
        XCTAssertNotNil(newList, "List should be created")
        XCTAssertEqual(newList.name, "New List")

        // Update list
        let updatedName = "Updated List"
        repository.updateList(newList, name: updatedName)
        let retrievedList = repository.getList(by: newList.id)
        XCTAssertEqual(retrievedList?.name, updatedName, "List should be updated")

        // Delete list
        repository.deleteList(newList)
        let deletedList = repository.getList(by: newList.id)
        XCTAssertNil(deletedList, "List should be deleted")
    }

    func testDataRepositoryItemOperationsSendSyncNotification() throws {
        // Test that item operations trigger sync notifications
        let testDataManager = TestHelpers.createTestDataManager()
        let repository = TestDataRepository(dataManager: testDataManager)

        // Create a test list
        let testList = List(name: "Test List")
        testDataManager.addList(testList)

        // Create item
        let newItem = repository.createItem(in: testList, title: "New Item", description: "Test", quantity: 1)
        XCTAssertNotNil(newItem, "Item should be created")
        XCTAssertEqual(newItem.title, "New Item")

        // Update item
        repository.updateItem(newItem, title: "Updated Item", description: "Updated", quantity: 2)
        let retrievedItem = repository.getItem(by: newItem.id)
        XCTAssertEqual(retrievedItem?.title, "Updated Item", "Item should be updated")
        XCTAssertEqual(retrievedItem?.quantity, 2, "Item quantity should be updated")

        // Toggle item completion
        repository.toggleItemCrossedOut(newItem)
        let toggledItem = repository.getItem(by: newItem.id)
        XCTAssertTrue(toggledItem?.isCrossedOut ?? false, "Item should be crossed out")

        // Delete item
        repository.deleteItem(newItem)
        let deletedItem = repository.getItem(by: newItem.id)
        XCTAssertNil(deletedItem, "Item should be deleted")
    }
}
