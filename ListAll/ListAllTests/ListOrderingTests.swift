import XCTest
@testable import ListAll

/// Test suite for list ordering functionality (TDD - Red phase)
/// These tests verify the fix for the list ordering bug where all new lists get orderNumber = 0
/// causing non-deterministic ordering after app restart.
///
/// Bug Description:
/// - All new lists get orderNumber = 0 in List.init()
/// - DataManager.addList() doesn't assign unique sequential orderNumbers
/// - After drag-and-drop reorder, modifiedAt timestamps are not updated
/// - This causes random/unpredictable ordering after app restart
///
/// Expected Behavior After Fix:
/// - First list gets orderNumber = 0
/// - Second list gets orderNumber = 1
/// - Third list gets orderNumber = 2, etc.
/// - After deleting a list and adding a new one, new list gets next available number
/// - After drag-and-drop reorder, order persists after "restart" (new ViewModel)
/// - After reordering, modifiedAt timestamps are updated for affected lists
class ListOrderingTests: XCTestCase {

    var testDataManager: TestDataManager!
    var testViewModel: TestMainViewModel!

    override func setUp() {
        super.setUp()
        // Create isolated test environment with in-memory Core Data
        testDataManager = TestHelpers.createTestDataManager()
        testViewModel = TestMainViewModel(dataManager: testDataManager)
    }

    override func tearDown() {
        // Clean up test data
        testDataManager.clearAll()
        testDataManager = nil
        testViewModel = nil
        super.tearDown()
    }

    // MARK: - Sequential orderNumber Assignment Tests

    /// Test that the first list created gets orderNumber = 0
    func testFirstList_getsOrderNumber0() {
        // Act
        try! testViewModel.addList(name: "First List")

        // Assert
        XCTAssertEqual(testViewModel.lists.count, 1, "Should have exactly 1 list")
        let firstList = testViewModel.lists[0]
        XCTAssertEqual(firstList.orderNumber, 0, "First list should have orderNumber = 0")
        XCTAssertEqual(firstList.name, "First List")
    }

    /// Test that lists get sequential orderNumbers (0, 1, 2)
    func testMultipleLists_getSequentialOrderNumbers() {
        // Act
        try! testViewModel.addList(name: "First")
        try! testViewModel.addList(name: "Second")
        try! testViewModel.addList(name: "Third")

        // Assert
        XCTAssertEqual(testViewModel.lists.count, 3, "Should have exactly 3 lists")

        let firstList = testViewModel.lists[0]
        let secondList = testViewModel.lists[1]
        let thirdList = testViewModel.lists[2]

        XCTAssertEqual(firstList.orderNumber, 0, "First list should have orderNumber = 0")
        XCTAssertEqual(secondList.orderNumber, 1, "Second list should have orderNumber = 1")
        XCTAssertEqual(thirdList.orderNumber, 2, "Third list should have orderNumber = 2")

        XCTAssertEqual(firstList.name, "First")
        XCTAssertEqual(secondList.name, "Second")
        XCTAssertEqual(thirdList.name, "Third")
    }

    /// Test that orderNumbers are unique (no duplicates)
    func testMultipleLists_haveUniqueOrderNumbers() {
        // Act
        try! testViewModel.addList(name: "A")
        try! testViewModel.addList(name: "B")
        try! testViewModel.addList(name: "C")
        try! testViewModel.addList(name: "D")
        try! testViewModel.addList(name: "E")

        // Assert
        let orderNumbers = testViewModel.lists.map { $0.orderNumber }
        let uniqueOrderNumbers = Set(orderNumbers)

        XCTAssertEqual(orderNumbers.count, 5, "Should have 5 lists")
        XCTAssertEqual(uniqueOrderNumbers.count, 5, "All orderNumbers should be unique (no duplicates)")

        // Verify specific sequence
        XCTAssertEqual(orderNumbers, [0, 1, 2, 3, 4], "orderNumbers should be sequential from 0 to 4")
    }

    /// Test that after deleting a list, new list gets the next available orderNumber
    /// (not the deleted list's number, which would cause gaps)
    func testAfterDeletingList_newListGetsNextOrderNumber() {
        // Arrange - Create 3 lists
        try! testViewModel.addList(name: "List A")
        try! testViewModel.addList(name: "List B")
        try! testViewModel.addList(name: "List C")

        XCTAssertEqual(testViewModel.lists.count, 3)
        let listB = testViewModel.lists[1]
        XCTAssertEqual(listB.orderNumber, 1)

        // Act - Delete middle list (orderNumber = 1)
        testViewModel.deleteList(listB)

        // Assert - Should have 2 lists remaining
        XCTAssertEqual(testViewModel.lists.count, 2, "Should have 2 lists after deletion")

        let remainingList0 = testViewModel.lists[0]
        let remainingList1 = testViewModel.lists[1]
        XCTAssertEqual(remainingList0.name, "List A")
        XCTAssertEqual(remainingList0.orderNumber, 0)
        XCTAssertEqual(remainingList1.name, "List C")
        XCTAssertEqual(remainingList1.orderNumber, 2) // Still has original orderNumber

        // Act - Add new list
        try! testViewModel.addList(name: "List D")

        // Assert - New list should get orderNumber = 3 (next in sequence after max 2)
        XCTAssertEqual(testViewModel.lists.count, 3, "Should have 3 lists after adding new one")

        let newList = testViewModel.lists.first { $0.name == "List D" }
        XCTAssertNotNil(newList, "Should find the newly added list")
        XCTAssertEqual(newList?.orderNumber, 3, "New list should get orderNumber = 3 (max was 2, so next is 3)")
    }

    /// Test that adding lists in rapid succession maintains sequential order
    func testRapidListCreation_maintainsSequentialOrder() {
        // Act - Create 10 lists rapidly
        for i in 0..<10 {
            try! testViewModel.addList(name: "List \(i)")
        }

        // Assert
        XCTAssertEqual(testViewModel.lists.count, 10, "Should have 10 lists")

        for (index, list) in testViewModel.lists.enumerated() {
            XCTAssertEqual(list.orderNumber, index, "List at index \(index) should have orderNumber = \(index)")
            XCTAssertEqual(list.name, "List \(index)")
        }

        // Verify all orderNumbers are unique
        let orderNumbers = testViewModel.lists.map { $0.orderNumber }
        let uniqueOrderNumbers = Set(orderNumbers)
        XCTAssertEqual(uniqueOrderNumbers.count, 10, "All 10 orderNumbers should be unique")
    }

    // MARK: - Reorder Persistence Tests

    /// Test that after drag-and-drop reorder, the order persists after "restart" (creating new ViewModel)
    /// This simulates closing and reopening the app
    func testReorder_persistsAfterRestart() {
        // Arrange - Create 3 lists: A (0), B (1), C (2)
        try! testViewModel.addList(name: "A")
        try! testViewModel.addList(name: "B")
        try! testViewModel.addList(name: "C")

        let originalOrder = testViewModel.lists.map { $0.name }
        XCTAssertEqual(originalOrder, ["A", "B", "C"], "Initial order should be A, B, C")

        // Act - Move C (index 2) to top (index 0) → should result in C, A, B
        testViewModel.moveList(from: IndexSet(integer: 2), to: 0)

        let reorderedOrder = testViewModel.lists.map { $0.name }
        XCTAssertEqual(reorderedOrder, ["C", "A", "B"], "After reorder, should be C, A, B")

        // Simulate app restart by creating new ViewModel with same DataManager
        let newViewModel = TestMainViewModel(dataManager: testDataManager)

        // Assert - Order should persist after restart
        let persistedOrder = newViewModel.lists.map { $0.name }
        XCTAssertEqual(persistedOrder, ["C", "A", "B"], "Order should persist after restart")

        // Verify orderNumbers are sequential
        XCTAssertEqual(newViewModel.lists[0].orderNumber, 0, "C should have orderNumber 0")
        XCTAssertEqual(newViewModel.lists[1].orderNumber, 1, "A should have orderNumber 1")
        XCTAssertEqual(newViewModel.lists[2].orderNumber, 2, "B should have orderNumber 2")
    }

    /// Test moving a list from top to bottom
    func testMoveList_fromTopToBottom_persistsCorrectly() {
        // Arrange
        try! testViewModel.addList(name: "First")
        try! testViewModel.addList(name: "Second")
        try! testViewModel.addList(name: "Third")
        try! testViewModel.addList(name: "Fourth")

        // Act - Move First (index 0) to bottom (index 4)
        testViewModel.moveList(from: IndexSet(integer: 0), to: 4)

        // Assert - Should be: Second, Third, Fourth, First
        let expectedOrder = ["Second", "Third", "Fourth", "First"]
        let actualOrder = testViewModel.lists.map { $0.name }
        XCTAssertEqual(actualOrder, expectedOrder, "Order should be Second, Third, Fourth, First")

        // Simulate restart
        let newViewModel = TestMainViewModel(dataManager: testDataManager)
        let persistedOrder = newViewModel.lists.map { $0.name }
        XCTAssertEqual(persistedOrder, expectedOrder, "Order should persist after restart")

        // Verify sequential orderNumbers
        for (index, list) in newViewModel.lists.enumerated() {
            XCTAssertEqual(list.orderNumber, index, "List \(list.name) should have orderNumber \(index)")
        }
    }

    /// Test moving a list from bottom to top
    func testMoveList_fromBottomToTop_persistsCorrectly() {
        // Arrange
        try! testViewModel.addList(name: "Alpha")
        try! testViewModel.addList(name: "Beta")
        try! testViewModel.addList(name: "Gamma")
        try! testViewModel.addList(name: "Delta")

        // Act - Move Delta (index 3) to top (index 0)
        testViewModel.moveList(from: IndexSet(integer: 3), to: 0)

        // Assert
        let expectedOrder = ["Delta", "Alpha", "Beta", "Gamma"]
        let actualOrder = testViewModel.lists.map { $0.name }
        XCTAssertEqual(actualOrder, expectedOrder)

        // Simulate restart
        let newViewModel = TestMainViewModel(dataManager: testDataManager)
        let persistedOrder = newViewModel.lists.map { $0.name }
        XCTAssertEqual(persistedOrder, expectedOrder, "Order should persist after restart")
    }

    /// Test moving a list within the middle positions
    func testMoveList_withinMiddle_persistsCorrectly() {
        // Arrange - 5 lists
        try! testViewModel.addList(name: "1")
        try! testViewModel.addList(name: "2")
        try! testViewModel.addList(name: "3")
        try! testViewModel.addList(name: "4")
        try! testViewModel.addList(name: "5")

        // Act - Move "4" (index 3) to position 1
        testViewModel.moveList(from: IndexSet(integer: 3), to: 1)

        // Assert - Should be: 1, 4, 2, 3, 5
        let expectedOrder = ["1", "4", "2", "3", "5"]
        let actualOrder = testViewModel.lists.map { $0.name }
        XCTAssertEqual(actualOrder, expectedOrder)

        // Simulate restart
        let newViewModel = TestMainViewModel(dataManager: testDataManager)
        let persistedOrder = newViewModel.lists.map { $0.name }
        XCTAssertEqual(persistedOrder, expectedOrder, "Order should persist after restart")
    }

    /// Test multiple reorders to ensure orderNumbers stay consistent
    func testMultipleReorders_persistCorrectly() {
        // Arrange
        try! testViewModel.addList(name: "A")
        try! testViewModel.addList(name: "B")
        try! testViewModel.addList(name: "C")
        try! testViewModel.addList(name: "D")

        // Act - First reorder: Move D to top → D, A, B, C
        testViewModel.moveList(from: IndexSet(integer: 3), to: 0)
        XCTAssertEqual(testViewModel.lists.map { $0.name }, ["D", "A", "B", "C"])

        // Act - Second reorder: Move B to bottom → D, A, C, B
        testViewModel.moveList(from: IndexSet(integer: 2), to: 4)
        XCTAssertEqual(testViewModel.lists.map { $0.name }, ["D", "A", "C", "B"])

        // Act - Third reorder: Move A to position 2 → D, C, A, B
        // Note: SwiftUI move(toOffset:) inserts "just before" the destination,
        // so toOffset: 3 moves A from index 1 to end up at index 2
        testViewModel.moveList(from: IndexSet(integer: 1), to: 3)
        XCTAssertEqual(testViewModel.lists.map { $0.name }, ["D", "C", "A", "B"])

        // Simulate restart
        let newViewModel = TestMainViewModel(dataManager: testDataManager)

        // Assert - Final order should persist
        let expectedOrder = ["D", "C", "A", "B"]
        let persistedOrder = newViewModel.lists.map { $0.name }
        XCTAssertEqual(persistedOrder, expectedOrder, "Final order should persist after multiple reorders")

        // Verify sequential orderNumbers
        for (index, list) in newViewModel.lists.enumerated() {
            XCTAssertEqual(list.orderNumber, index, "List \(list.name) at position \(index) should have orderNumber \(index)")
        }
    }

    // MARK: - modifiedAt Timestamp Tests

    /// Test that after reordering, modifiedAt timestamps are updated for affected lists
    func testReorder_updatesModifiedAtTimestamps() {
        // Arrange - Create lists with known timestamps
        try! testViewModel.addList(name: "List 1")
        try! testViewModel.addList(name: "List 2")
        try! testViewModel.addList(name: "List 3")

        // Get original timestamps
        let originalTimestamps = testViewModel.lists.map { $0.modifiedAt }

        // Wait to ensure new timestamps will be different
        let expectation = self.expectation(description: "Wait for timestamp difference")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.01) {
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 1.0)

        // Act - Reorder lists
        testViewModel.moveList(from: IndexSet(integer: 2), to: 0)

        // Assert - All lists should have updated modifiedAt timestamps
        let newTimestamps = testViewModel.lists.map { $0.modifiedAt }

        for (index, newTimestamp) in newTimestamps.enumerated() {
            XCTAssertGreaterThan(
                newTimestamp,
                originalTimestamps[index],
                "List at index \(index) should have updated modifiedAt after reorder"
            )
        }
    }

    /// Test that modifiedAt updates persist to Core Data
    func testReorder_modifiedAtPersistsToDatabase() {
        // Arrange
        try! testViewModel.addList(name: "X")
        try! testViewModel.addList(name: "Y")
        try! testViewModel.addList(name: "Z")

        // Wait for timestamp difference
        let expectation = self.expectation(description: "Wait for timestamp")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.01) {
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 1.0)

        // Act - Reorder
        testViewModel.moveList(from: IndexSet(integer: 0), to: 3)

        let timestampsAfterReorder = testViewModel.lists.map { $0.modifiedAt }

        // Simulate restart
        let newViewModel = TestMainViewModel(dataManager: testDataManager)
        let persistedTimestamps = newViewModel.lists.map { $0.modifiedAt }

        // Assert - Timestamps should match after restart (proving they persisted)
        for (index, persistedTimestamp) in persistedTimestamps.enumerated() {
            let difference = abs(persistedTimestamp.timeIntervalSince(timestampsAfterReorder[index]))
            XCTAssertLessThan(
                difference,
                0.001,
                "Timestamp for list at index \(index) should persist to database (difference: \(difference)s)"
            )
        }
    }

    // MARK: - Edge Cases

    /// Test reordering a single list (should be a no-op)
    func testReorder_singleList_handlesGracefully() {
        // Arrange
        try! testViewModel.addList(name: "Only List")

        let originalOrderNumber = testViewModel.lists[0].orderNumber

        // Act - Try to move the only list
        testViewModel.moveList(from: IndexSet(integer: 0), to: 0)

        // Assert - Should remain the same
        XCTAssertEqual(testViewModel.lists.count, 1)
        XCTAssertEqual(testViewModel.lists[0].name, "Only List")
        XCTAssertEqual(testViewModel.lists[0].orderNumber, originalOrderNumber)

        // Simulate restart
        let newViewModel = TestMainViewModel(dataManager: testDataManager)
        XCTAssertEqual(newViewModel.lists.count, 1)
        XCTAssertEqual(newViewModel.lists[0].name, "Only List")
    }

    /// Test that empty list scenario doesn't crash
    func testReorder_emptyList_handlesGracefully() {
        // Arrange - No lists
        XCTAssertEqual(testViewModel.lists.count, 0)

        // Act - Try to move (should not crash)
        testViewModel.moveList(from: IndexSet(integer: 0), to: 0)

        // Assert - Should still be empty
        XCTAssertEqual(testViewModel.lists.count, 0)
    }

    /// Test that adding a list after reordering maintains correct sequential numbers
    func testAddListAfterReorder_maintainsSequentialOrder() {
        // Arrange
        try! testViewModel.addList(name: "A")
        try! testViewModel.addList(name: "B")
        try! testViewModel.addList(name: "C")

        // Act - Reorder: C, A, B
        testViewModel.moveList(from: IndexSet(integer: 2), to: 0)
        XCTAssertEqual(testViewModel.lists.map { $0.name }, ["C", "A", "B"])
        XCTAssertEqual(testViewModel.lists.map { $0.orderNumber }, [0, 1, 2])

        // Add new list
        try! testViewModel.addList(name: "D")

        // Assert - New list should go to bottom with orderNumber = 3
        XCTAssertEqual(testViewModel.lists.count, 4)
        let newList = testViewModel.lists.first { $0.name == "D" }
        XCTAssertNotNil(newList)
        XCTAssertEqual(newList?.orderNumber, 3, "New list should have orderNumber = 3")

        // Verify all orderNumbers are sequential and unique
        let orderNumbers = testViewModel.lists.map { $0.orderNumber }.sorted()
        XCTAssertEqual(orderNumbers, [0, 1, 2, 3], "All orderNumbers should be sequential")
    }

    /// Test complex scenario: create, delete, reorder, add more lists
    func testComplexScenario_maintainsCorrectOrdering() {
        // Step 1: Create 5 lists
        try! testViewModel.addList(name: "List 1")
        try! testViewModel.addList(name: "List 2")
        try! testViewModel.addList(name: "List 3")
        try! testViewModel.addList(name: "List 4")
        try! testViewModel.addList(name: "List 5")

        XCTAssertEqual(testViewModel.lists.map { $0.orderNumber }, [0, 1, 2, 3, 4])

        // Step 2: Delete List 2 and List 4
        let list2 = testViewModel.lists.first { $0.name == "List 2" }!
        let list4 = testViewModel.lists.first { $0.name == "List 4" }!
        testViewModel.deleteList(list2)
        testViewModel.deleteList(list4)

        XCTAssertEqual(testViewModel.lists.count, 3)
        XCTAssertEqual(testViewModel.lists.map { $0.name }, ["List 1", "List 3", "List 5"])

        // Step 3: Reorder - Move List 5 to top
        testViewModel.moveList(from: IndexSet(integer: 2), to: 0)
        XCTAssertEqual(testViewModel.lists.map { $0.name }, ["List 5", "List 1", "List 3"])
        XCTAssertEqual(testViewModel.lists.map { $0.orderNumber }, [0, 1, 2])

        // Step 4: Add 2 new lists
        try! testViewModel.addList(name: "List 6")
        try! testViewModel.addList(name: "List 7")

        XCTAssertEqual(testViewModel.lists.count, 5)

        // Step 5: Verify final state
        let list6 = testViewModel.lists.first { $0.name == "List 6" }!
        let list7 = testViewModel.lists.first { $0.name == "List 7" }!
        XCTAssertEqual(list6.orderNumber, 3, "List 6 should have orderNumber 3")
        XCTAssertEqual(list7.orderNumber, 4, "List 7 should have orderNumber 4")

        // Step 6: Simulate restart and verify everything persists
        let newViewModel = TestMainViewModel(dataManager: testDataManager)

        XCTAssertEqual(newViewModel.lists.count, 5, "Should have 5 lists after restart")

        // Verify order persisted
        let names = newViewModel.lists.map { $0.name }
        XCTAssertTrue(names.contains("List 5"))
        XCTAssertTrue(names.contains("List 1"))
        XCTAssertTrue(names.contains("List 3"))
        XCTAssertTrue(names.contains("List 6"))
        XCTAssertTrue(names.contains("List 7"))

        // Verify all orderNumbers are sequential and unique
        let orderNumbers = newViewModel.lists.map { $0.orderNumber }.sorted()
        XCTAssertEqual(orderNumbers, [0, 1, 2, 3, 4], "All orderNumbers should be sequential 0-4")
    }

    // MARK: - Database Integrity Tests

    /// Test that Core Data actually persists the orderNumbers correctly
    func testOrderNumbers_persistedToDatabase() {
        // Arrange
        try! testViewModel.addList(name: "First")
        try! testViewModel.addList(name: "Second")
        try! testViewModel.addList(name: "Third")

        let expectedOrderNumbers = [0, 1, 2]

        // Act - Force a reload from database by creating new ViewModel
        let newViewModel = TestMainViewModel(dataManager: testDataManager)

        // Assert - Order numbers should match
        let actualOrderNumbers = newViewModel.lists.map { $0.orderNumber }
        XCTAssertEqual(actualOrderNumbers, expectedOrderNumbers, "orderNumbers should persist to database")
    }

    /// Test that after multiple operations, database state is consistent
    func testDatabaseConsistency_afterMultipleOperations() {
        // Create, reorder, delete, add - all in sequence
        try! testViewModel.addList(name: "A")
        try! testViewModel.addList(name: "B")
        try! testViewModel.addList(name: "C")

        testViewModel.moveList(from: IndexSet(integer: 1), to: 0)

        let listC = testViewModel.lists.first { $0.name == "C" }!
        testViewModel.deleteList(listC)

        try! testViewModel.addList(name: "D")

        // Reload from database
        let newViewModel = TestMainViewModel(dataManager: testDataManager)

        // Verify database state is consistent
        XCTAssertEqual(newViewModel.lists.count, 3)

        let orderNumbers = newViewModel.lists.map { $0.orderNumber }
        let uniqueOrderNumbers = Set(orderNumbers)
        XCTAssertEqual(uniqueOrderNumbers.count, orderNumbers.count, "All orderNumbers should be unique in database")

        // All lists should be retrievable
        for list in newViewModel.lists {
            XCTAssertFalse(list.name.isEmpty, "List name should not be empty")
            XCTAssertGreaterThanOrEqual(list.orderNumber, 0, "orderNumber should be non-negative")
        }
    }
}
