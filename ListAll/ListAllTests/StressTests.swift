import XCTest
import CoreData
@testable import ListAll

/// Stress tests for volume operations and rapid state changes.
/// These tests verify that the app handles large data volumes and rapid mutations
/// without data corruption, duplicate order numbers, or crashes.
final class StressTests: XCTestCase {

    var testDataManager: TestDataManager!
    var testViewModel: TestMainViewModel!

    override func setUp() {
        super.setUp()
        testDataManager = TestHelpers.createTestDataManager()
        testViewModel = TestMainViewModel(dataManager: testDataManager)
    }

    override func tearDown() {
        testDataManager.clearAll()
        testDataManager = nil
        testViewModel = nil
        super.tearDown()
    }

    // MARK: - 500+ Items in One List

    /// Verify that a list with 500+ items maintains correct sorting
    func testLargeList_500Items_sortingPreserved() throws {
        // Arrange: Create a list
        try testViewModel.addList(name: "Large List")
        let list = try XCTUnwrap(testViewModel.lists.first, "List should exist")

        // Act: Add 500 items with varying order numbers
        for i in 0..<500 {
            var item = Item(title: "Item \(i)", listId: list.id)
            item.orderNumber = i
            testDataManager.addItem(item, to: list.id)
        }

        // Assert: Fetch items and verify they are sorted correctly
        let items = testDataManager.getItems(forListId: list.id)
        XCTAssertEqual(items.count, 500, "Should have exactly 500 items")

        // Verify items are sorted by orderNumber
        for i in 0..<items.count - 1 {
            XCTAssertLessThanOrEqual(
                items[i].orderNumber, items[i + 1].orderNumber,
                "Items should be sorted by orderNumber: item[\(i)].orderNumber=\(items[i].orderNumber) should be <= item[\(i+1)].orderNumber=\(items[i+1].orderNumber)"
            )
        }
    }

    /// Verify that 500+ items persist correctly after reload
    func testLargeList_500Items_persistsAfterReload() throws {
        // Arrange: Create a list with 500 items
        try testViewModel.addList(name: "Export Test List")
        let list = try XCTUnwrap(testViewModel.lists.first, "List should exist")

        for i in 0..<500 {
            var item = Item(title: "Item \(i)", listId: list.id)
            item.orderNumber = i
            item.quantity = (i % 10) + 1
            if i % 3 == 0 {
                item.itemDescription = "Description for item \(i)"
            }
            testDataManager.addItem(item, to: list.id)
        }

        // Act: Reload and verify data is intact
        testDataManager.loadData()
        let reloadedItems = testDataManager.getItems(forListId: list.id)

        // Assert: All items present with correct data
        XCTAssertEqual(reloadedItems.count, 500, "All 500 items should be present after reload")

        // Verify a sample of items retained their properties
        let sampleItem = reloadedItems.first(where: { $0.title == "Item 42" })
        XCTAssertNotNil(sampleItem, "Item 42 should exist")
        XCTAssertEqual(sampleItem?.quantity, 3, "Item 42 quantity should be 3 (42 % 10 + 1)")
        XCTAssertEqual(sampleItem?.itemDescription, "Description for item 42", "Item 42 should have description (42 % 3 == 0)")
    }

    // MARK: - 500 Lists Reorder

    /// Verify that creating 500 lists and reordering first-to-last produces no duplicate order numbers
    func testReorder500Lists_firstToLast_noDuplicateOrderNumbers() throws {
        // Arrange: Create 500 lists
        for i in 0..<500 {
            try testViewModel.addList(name: "List \(i)")
        }
        XCTAssertEqual(testViewModel.lists.count, 500, "Should have exactly 500 lists")

        // Verify initial order numbers are unique
        let initialOrderNumbers = testViewModel.lists.map { $0.orderNumber }
        XCTAssertEqual(Set(initialOrderNumbers).count, 500, "Initial order numbers should all be unique")

        // Act: Move first list to last position
        testViewModel.moveList(from: IndexSet(integer: 0), to: 500)

        // Assert: All order numbers should be unique after reorder
        let reorderedOrderNumbers = testViewModel.lists.map { $0.orderNumber }
        XCTAssertEqual(Set(reorderedOrderNumbers).count, 500, "Order numbers should remain unique after reorder")

        // Verify sequential ordering (0, 1, 2, ...)
        let sortedOrderNumbers = reorderedOrderNumbers.sorted()
        for (index, orderNum) in sortedOrderNumbers.enumerated() {
            XCTAssertEqual(orderNum, index, "Order number at sorted position \(index) should be \(index), got \(orderNum)")
        }

        // Verify the moved list is now last
        let lastList = testViewModel.lists.last
        XCTAssertEqual(lastList?.name, "List 0", "List 0 should now be at the end")
    }

    /// Verify that reordering 500 lists persists after reload
    func testReorder500Lists_persistsAfterReload() throws {
        // Arrange: Create 500 lists
        for i in 0..<500 {
            try testViewModel.addList(name: "List \(i)")
        }

        // Act: Move first list to last position and reload
        testViewModel.moveList(from: IndexSet(integer: 0), to: 500)

        // Simulate app restart by creating a new ViewModel from the same data manager
        let freshViewModel = TestMainViewModel(dataManager: testDataManager)

        // Assert: Order should persist
        XCTAssertEqual(freshViewModel.lists.count, 500, "Should still have 500 lists")
        XCTAssertEqual(freshViewModel.lists.last?.name, "List 0", "List 0 should still be at the end after reload")
        XCTAssertEqual(freshViewModel.lists.first?.name, "List 1", "List 1 should now be first after reload")
    }

    // MARK: - Rapid Add/Delete/Reorder Cycle

    /// Verify that 200 rapid add/delete/reorder cycles leave clean state
    func testRapidAddDeleteReorder_200Iterations_cleanState() throws {
        // Seed with initial lists
        for i in 0..<5 {
            try testViewModel.addList(name: "Seed \(i)")
        }

        // Act: 200 iterations of rapid add/delete/reorder
        for iteration in 0..<200 {
            let action = iteration % 3

            switch action {
            case 0:
                // Add a list
                try testViewModel.addList(name: "Iter \(iteration)")
            case 1:
                // Delete a list (if any exist)
                if let listToDelete = testViewModel.lists.first {
                    testViewModel.deleteList(listToDelete)
                }
            case 2:
                // Reorder: move first to last (if at least 2 lists)
                if testViewModel.lists.count >= 2 {
                    let lastIndex = testViewModel.lists.count
                    testViewModel.moveList(from: IndexSet(integer: 0), to: lastIndex)
                }
            default:
                break
            }
        }

        // Assert: State should be clean
        let lists = testViewModel.lists

        // All order numbers should be unique
        let orderNumbers = lists.map { $0.orderNumber }
        XCTAssertEqual(
            Set(orderNumbers).count, orderNumbers.count,
            "All order numbers should be unique after 200 iterations. Duplicates found in: \(orderNumbers)"
        )

        // All list IDs should be unique
        let listIds = lists.map { $0.id }
        XCTAssertEqual(
            Set(listIds).count, listIds.count,
            "All list IDs should be unique"
        )

        // Lists should be sorted by orderNumber
        for i in 0..<lists.count - 1 {
            XCTAssertLessThan(
                lists[i].orderNumber, lists[i + 1].orderNumber,
                "Lists should be sorted by orderNumber"
            )
        }

        // Verify Core Data is consistent by reloading
        testDataManager.loadData()
        let reloadedLists = testDataManager.lists.sorted { $0.orderNumber < $1.orderNumber }
        XCTAssertEqual(reloadedLists.count, lists.count, "Core Data should match in-memory list count")
    }

    // MARK: - validateDataIntegrity Tests

    /// Verify validateDataIntegrity returns success for valid data
    func testValidateDataIntegrity_validData_returnsEmpty() {
        let listId = UUID()
        var list = List(name: "Valid List")
        list.id = listId
        var item = Item(title: "Valid Item", listId: listId)
        item.listId = listId
        list.items = [item]

        let results = ValidationHelper.validateDataIntegrity(lists: [list])
        let failures = results.filter { !$0.isValid }
        XCTAssertTrue(failures.isEmpty, "Valid data should have no integrity failures, got: \(failures.map { $0.errorMessage ?? "" })")
    }

    /// Verify validateDataIntegrity detects items referencing non-existent lists
    func testValidateDataIntegrity_orphanedItem_detectsFailure() {
        let listId = UUID()
        let nonExistentListId = UUID()
        var list = List(name: "Test List")
        list.id = listId
        var item = Item(title: "Orphan Item")
        item.listId = nonExistentListId  // References a list that does not exist
        list.items = [item]

        let results = ValidationHelper.validateDataIntegrity(lists: [list])
        let failures = results.filter { !$0.isValid }
        XCTAssertFalse(failures.isEmpty, "Should detect orphaned item referencing non-existent list")
        XCTAssertTrue(
            failures.contains(where: { $0.errorMessage?.contains("non-existent list") == true }),
            "Error message should mention non-existent list"
        )
    }

    /// Verify validateDataIntegrity handles empty lists array
    func testValidateDataIntegrity_emptyLists_returnsEmpty() {
        let results = ValidationHelper.validateDataIntegrity(lists: [])
        XCTAssertTrue(results.filter { !$0.isValid }.isEmpty, "Empty lists should produce no failures")
    }

    /// Verify validateDataIntegrity with large volume of valid data
    func testValidateDataIntegrity_largeVolume_noFalsePositives() {
        var lists: [List] = []
        for i in 0..<100 {
            let listId = UUID()
            var list = List(name: "List \(i)")
            list.id = listId
            var items: [Item] = []
            for j in 0..<10 {
                var item = Item(title: "Item \(j)", listId: listId)
                item.listId = listId
                items.append(item)
            }
            list.items = items
            lists.append(list)
        }

        let results = ValidationHelper.validateDataIntegrity(lists: lists)
        let failures = results.filter { !$0.isValid }
        XCTAssertTrue(failures.isEmpty, "100 lists with 10 items each should have no integrity failures")
    }

    // MARK: - validateListBusinessRules Tests

    /// Verify duplicate name detection (case insensitive)
    func testValidateListBusinessRules_duplicateName_detectsFailure() {
        var existingList = List(name: "Groceries")
        existingList.id = UUID()
        existingList.orderNumber = 0

        var newList = List(name: "groceries")  // Same name, different case
        newList.id = UUID()
        newList.orderNumber = 1

        let results = ValidationHelper.validateListBusinessRules(newList, existingLists: [existingList])
        let failures = results.filter { !$0.isValid }
        XCTAssertFalse(failures.isEmpty, "Should detect duplicate name (case insensitive)")
        XCTAssertTrue(
            failures.contains(where: { $0.errorMessage?.contains("already exists") == true }),
            "Error message should mention list already exists"
        )
    }

    /// Verify duplicate order number detection
    func testValidateListBusinessRules_duplicateOrderNumber_detectsFailure() {
        var existingList = List(name: "List A")
        existingList.id = UUID()
        existingList.orderNumber = 5

        var newList = List(name: "List B")  // Different name, same order number
        newList.id = UUID()
        newList.orderNumber = 5

        let results = ValidationHelper.validateListBusinessRules(newList, existingLists: [existingList])
        let failures = results.filter { !$0.isValid }
        XCTAssertFalse(failures.isEmpty, "Should detect duplicate order number")
        XCTAssertTrue(
            failures.contains(where: { $0.errorMessage?.contains("already in use") == true }),
            "Error message should mention order number in use"
        )
    }

    /// Verify no false positive when list validates against itself (same ID)
    func testValidateListBusinessRules_sameId_noFalsePositive() {
        let sharedId = UUID()
        var list = List(name: "My List")
        list.id = sharedId
        list.orderNumber = 0

        // Validating a list against existing lists that include itself should pass
        let results = ValidationHelper.validateListBusinessRules(list, existingLists: [list])
        let failures = results.filter { !$0.isValid }
        XCTAssertTrue(failures.isEmpty, "List should not flag itself as a duplicate")
    }

    /// Verify validation with no existing lists returns empty
    func testValidateListBusinessRules_noExistingLists_returnsEmpty() {
        let newList = List(name: "New List")
        let results = ValidationHelper.validateListBusinessRules(newList, existingLists: [])
        let failures = results.filter { !$0.isValid }
        XCTAssertTrue(failures.isEmpty, "No existing lists should produce no failures")
    }

    /// Verify that both duplicate name AND duplicate order are reported simultaneously
    func testValidateListBusinessRules_bothViolations_reportsAll() {
        var existingList = List(name: "Groceries")
        existingList.id = UUID()
        existingList.orderNumber = 3

        var newList = List(name: "GROCERIES")
        newList.id = UUID()
        newList.orderNumber = 3  // Same order number too

        let results = ValidationHelper.validateListBusinessRules(newList, existingLists: [existingList])
        let failures = results.filter { !$0.isValid }
        XCTAssertEqual(failures.count, 2, "Should report both duplicate name and duplicate order number")
    }

    // MARK: - Order Number Collision Recovery

    /// Verify that corrupted (duplicate) order numbers are fixed by reorder operation
    func testOrderNumberCollisionRecovery_corruptedOrders_fixedByReorder() throws {
        // Arrange: Create lists with manually corrupted order numbers (all set to 0)
        for i in 0..<10 {
            try testViewModel.addList(name: "List \(i)")
        }

        // Corrupt the order numbers: set all to the same value via Core Data
        let context = testDataManager.coreDataManager.viewContext
        let request: NSFetchRequest<ListEntity> = ListEntity.fetchRequest()
        let entities = try context.fetch(request)
        for entity in entities {
            entity.orderNumber = 0  // All corrupted to 0
        }
        try context.save()
        testDataManager.loadData()

        // Verify corruption: all order numbers are 0
        let corruptedOrderNumbers = testDataManager.lists.map { $0.orderNumber }
        XCTAssertTrue(
            corruptedOrderNumbers.allSatisfy { $0 == 0 },
            "All order numbers should be corrupted to 0"
        )

        // Act: Reload ViewModel and perform a reorder to trigger recovery
        testViewModel = TestMainViewModel(dataManager: testDataManager)
        // Move first to last to trigger order number reassignment
        if testViewModel.lists.count >= 2 {
            testViewModel.moveList(from: IndexSet(integer: 0), to: testViewModel.lists.count)
        }

        // Assert: Order numbers should now be unique and sequential
        let recoveredOrderNumbers = testViewModel.lists.map { $0.orderNumber }
        XCTAssertEqual(
            Set(recoveredOrderNumbers).count, recoveredOrderNumbers.count,
            "Order numbers should all be unique after recovery. Got: \(recoveredOrderNumbers)"
        )

        // Verify sequential
        let sorted = recoveredOrderNumbers.sorted()
        for (index, orderNum) in sorted.enumerated() {
            XCTAssertEqual(orderNum, index, "Order number at position \(index) should be \(index), got \(orderNum)")
        }
    }

    /// Verify that partially corrupted order numbers (some duplicates) are fixed
    func testOrderNumberCollisionRecovery_partialCorruption_fixedByReorder() throws {
        // Arrange: Create 5 lists
        for i in 0..<5 {
            try testViewModel.addList(name: "List \(i)")
        }

        // Corrupt: set first 3 lists to orderNumber 1
        let context = testDataManager.coreDataManager.viewContext
        let request: NSFetchRequest<ListEntity> = ListEntity.fetchRequest()
        request.sortDescriptors = [NSSortDescriptor(keyPath: \ListEntity.orderNumber, ascending: true)]
        let entities = try context.fetch(request)
        for i in 0..<min(3, entities.count) {
            entities[i].orderNumber = 1
        }
        try context.save()
        testDataManager.loadData()

        // Act: Reload and reorder
        testViewModel = TestMainViewModel(dataManager: testDataManager)
        if testViewModel.lists.count >= 2 {
            testViewModel.moveList(from: IndexSet(integer: 0), to: testViewModel.lists.count)
        }

        // Assert: All unique
        let orderNumbers = testViewModel.lists.map { $0.orderNumber }
        XCTAssertEqual(
            Set(orderNumbers).count, orderNumbers.count,
            "All order numbers should be unique after partial corruption recovery"
        )
    }
}
