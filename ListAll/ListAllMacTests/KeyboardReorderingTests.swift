//
//  KeyboardReorderingTests.swift
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

final class KeyboardReorderingTests: XCTestCase {

    // MARK: - Test Helpers

    private func createTestItem(
        title: String = "Test Item",
        orderNumber: Int = 0
    ) -> Item {
        var item = Item(title: title, listId: UUID())
        item.orderNumber = orderNumber
        return item
    }

    private func createTestList(withItemCount count: Int) -> ListModel {
        var list = ListModel(name: "Test List")
        list.items = (0..<count).map { index in
            createTestItem(title: "Item \(index)", orderNumber: index)
        }
        return list
    }

    // MARK: - Helper Method

    /// Creates a test environment with a list and items using proper data path
    private func createViewModelWithItems(itemCount: Int) -> TestListViewModel {
        let testDataManager = TestHelpers.createTestDataManager()
        // First add the list to the data manager
        let testList = ListModel(name: "Test List")
        testDataManager.addList(testList)

        let viewModel = TestListViewModel(list: testList, dataManager: testDataManager)

        // Create items through the proper data path
        for i in 0..<itemCount {
            viewModel.createItem(title: "Item \(i)")
        }
        viewModel.currentSortOption = .orderNumber
        return viewModel
    }

    // MARK: - moveItemUp Tests

    func testMoveItemUpFromMiddle() {
        // ARRANGE: Create a test list and add items through createItem
        let viewModel = createViewModelWithItems(itemCount: 5)

        // Get the item at position 2 (middle)
        let itemToMove = viewModel.items[2]
        let itemId = itemToMove.id

        // ACT: Move item up
        viewModel.moveItemUp(itemId)

        // ASSERT: Item should now be at position 1
        let movedItem = viewModel.items.first { $0.id == itemId }
        XCTAssertNotNil(movedItem)
        XCTAssertEqual(movedItem?.orderNumber, 1, "Item should have moved up from position 2 to 1")
    }

    func testMoveItemUpFromFirstPosition() {
        // ARRANGE: Create a test list and add items through createItem
        let viewModel = createViewModelWithItems(itemCount: 3)

        // Get the first item
        let firstItem = viewModel.items[0]
        let itemId = firstItem.id
        let originalOrder = firstItem.orderNumber

        // ACT: Try to move the first item up (should do nothing)
        viewModel.moveItemUp(itemId)

        // ASSERT: Item should still be at position 0
        let item = viewModel.items.first { $0.id == itemId }
        XCTAssertNotNil(item)
        XCTAssertEqual(item?.orderNumber, originalOrder, "First item should not move when moveItemUp is called")
    }

    func testMoveItemUpWithInvalidId() {
        // ARRANGE: Create a test list and add items through createItem
        let viewModel = createViewModelWithItems(itemCount: 3)

        let originalOrders = viewModel.items.map { $0.orderNumber }

        // ACT: Try to move an item with non-existent ID
        viewModel.moveItemUp(UUID())

        // ASSERT: All items should remain in original positions
        let currentOrders = viewModel.items.map { $0.orderNumber }
        XCTAssertEqual(currentOrders, originalOrders, "Items should not change when invalid ID is provided")
    }

    // MARK: - moveItemDown Tests

    func testMoveItemDownFromMiddle() {
        // ARRANGE: Create a test list and add items through createItem
        let viewModel = createViewModelWithItems(itemCount: 5)

        // Get the item at position 2 (middle)
        let itemToMove = viewModel.items[2]
        let itemId = itemToMove.id

        // ACT: Move item down
        viewModel.moveItemDown(itemId)

        // ASSERT: Item should now be at position 3
        let movedItem = viewModel.items.first { $0.id == itemId }
        XCTAssertNotNil(movedItem)
        XCTAssertEqual(movedItem?.orderNumber, 3, "Item should have moved down from position 2 to 3")
    }

    func testMoveItemDownFromLastPosition() {
        // ARRANGE: Create a test list and add items through createItem
        let viewModel = createViewModelWithItems(itemCount: 3)

        // Get the last item
        let lastItem = viewModel.items[2]
        let itemId = lastItem.id
        let originalOrder = lastItem.orderNumber

        // ACT: Try to move the last item down (should do nothing)
        viewModel.moveItemDown(itemId)

        // ASSERT: Item should still be at position 2
        let item = viewModel.items.first { $0.id == itemId }
        XCTAssertNotNil(item)
        XCTAssertEqual(item?.orderNumber, originalOrder, "Last item should not move when moveItemDown is called")
    }

    func testMoveItemDownWithInvalidId() {
        // ARRANGE: Create a test list and add items through createItem
        let viewModel = createViewModelWithItems(itemCount: 3)

        let originalOrders = viewModel.items.map { $0.orderNumber }

        // ACT: Try to move an item with non-existent ID
        viewModel.moveItemDown(UUID())

        // ASSERT: All items should remain in original positions
        let currentOrders = viewModel.items.map { $0.orderNumber }
        XCTAssertEqual(currentOrders, originalOrders, "Items should not change when invalid ID is provided")
    }

    // MARK: - Sort Option Constraint Tests

    func testKeyboardReorderingOnlyWorksWithOrderSort() {
        // ARRANGE: Create a test list and add items through createItem
        let viewModel = createViewModelWithItems(itemCount: 3)

        // ACT/ASSERT: Test with orderNumber sort (should work)
        viewModel.currentSortOption = .orderNumber
        XCTAssertTrue(viewModel.canReorderWithKeyboard, "Should be able to reorder when sorted by orderNumber")

        // ACT/ASSERT: Test with title sort (should not work)
        viewModel.currentSortOption = .title
        XCTAssertFalse(viewModel.canReorderWithKeyboard, "Should not be able to reorder when sorted by title")

        // ACT/ASSERT: Test with createdAt sort (should not work)
        viewModel.currentSortOption = .createdAt
        XCTAssertFalse(viewModel.canReorderWithKeyboard, "Should not be able to reorder when sorted by createdAt")

        // ACT/ASSERT: Test with modifiedAt sort (should not work)
        viewModel.currentSortOption = .modifiedAt
        XCTAssertFalse(viewModel.canReorderWithKeyboard, "Should not be able to reorder when sorted by modifiedAt")

        // ACT/ASSERT: Test with quantity sort (should not work)
        viewModel.currentSortOption = .quantity
        XCTAssertFalse(viewModel.canReorderWithKeyboard, "Should not be able to reorder when sorted by quantity")
    }

    func testMoveItemUpIgnoredWhenNotSortedByOrder() {
        // ARRANGE: Create a test list and add items through createItem
        let viewModel = createViewModelWithItems(itemCount: 3)

        // Set to title sort (not orderNumber)
        viewModel.currentSortOption = .title

        let itemId = viewModel.items[1].id
        let originalOrders = viewModel.items.map { $0.orderNumber }

        // ACT: Try to move item up (should be ignored)
        viewModel.moveItemUp(itemId)

        // ASSERT: Items should not change
        let currentOrders = viewModel.items.map { $0.orderNumber }
        XCTAssertEqual(currentOrders, originalOrders, "Items should not move when not sorted by orderNumber")
    }

    func testMoveItemDownIgnoredWhenNotSortedByOrder() {
        // ARRANGE: Create a test list and add items through createItem
        let viewModel = createViewModelWithItems(itemCount: 3)

        // Set to createdAt sort (not orderNumber)
        viewModel.currentSortOption = .createdAt

        let itemId = viewModel.items[1].id
        let originalOrders = viewModel.items.map { $0.orderNumber }

        // ACT: Try to move item down (should be ignored)
        viewModel.moveItemDown(itemId)

        // ASSERT: Items should not change
        let currentOrders = viewModel.items.map { $0.orderNumber }
        XCTAssertEqual(currentOrders, originalOrders, "Items should not move when not sorted by orderNumber")
    }

    // MARK: - Edge Cases

    func testMoveItemUpWithSingleItem() {
        // ARRANGE: Create a test list with single item
        let viewModel = createViewModelWithItems(itemCount: 1)

        let itemId = viewModel.items[0].id

        // ACT: Try to move the only item up
        viewModel.moveItemUp(itemId)

        // ASSERT: Item should remain at position 0
        XCTAssertEqual(viewModel.items.count, 1)
        XCTAssertEqual(viewModel.items[0].orderNumber, 0)
    }

    func testMoveItemDownWithSingleItem() {
        // ARRANGE: Create a test list with single item
        let viewModel = createViewModelWithItems(itemCount: 1)

        let itemId = viewModel.items[0].id

        // ACT: Try to move the only item down
        viewModel.moveItemDown(itemId)

        // ASSERT: Item should remain at position 0
        XCTAssertEqual(viewModel.items.count, 1)
        XCTAssertEqual(viewModel.items[0].orderNumber, 0)
    }

    func testMoveItemUpWithEmptyList() {
        // ARRANGE: Create a test list with no items
        let viewModel = createViewModelWithItems(itemCount: 0)

        // ACT: Try to move an item up with random ID
        viewModel.moveItemUp(UUID())

        // ASSERT: Should not crash, no items
        XCTAssertEqual(viewModel.items.count, 0)
    }

    func testMoveItemDownWithEmptyList() {
        // ARRANGE: Create a test list with no items
        let viewModel = createViewModelWithItems(itemCount: 0)

        // ACT: Try to move an item down with random ID
        viewModel.moveItemDown(UUID())

        // ASSERT: Should not crash, no items
        XCTAssertEqual(viewModel.items.count, 0)
    }

    // MARK: - Sequential Moves Tests

    func testSequentialMoveUp() {
        // ARRANGE: Create a test list and add items through createItem
        let viewModel = createViewModelWithItems(itemCount: 5)

        // Get the item at position 4 (last)
        let itemToMove = viewModel.items[4]
        let itemId = itemToMove.id

        // ACT: Move item up multiple times
        viewModel.moveItemUp(itemId)
        viewModel.moveItemUp(itemId)
        viewModel.moveItemUp(itemId)

        // ASSERT: Item should now be at position 1
        let movedItem = viewModel.items.first { $0.id == itemId }
        XCTAssertNotNil(movedItem)
        XCTAssertEqual(movedItem?.orderNumber, 1, "Item should have moved from position 4 to 1 after 3 moves up")
    }

    func testSequentialMoveDown() {
        // ARRANGE: Create a test list and add items through createItem
        let viewModel = createViewModelWithItems(itemCount: 5)

        // Get the item at position 0 (first)
        let itemToMove = viewModel.items[0]
        let itemId = itemToMove.id

        // ACT: Move item down multiple times
        viewModel.moveItemDown(itemId)
        viewModel.moveItemDown(itemId)
        viewModel.moveItemDown(itemId)

        // ASSERT: Item should now be at position 3
        let movedItem = viewModel.items.first { $0.id == itemId }
        XCTAssertNotNil(movedItem)
        XCTAssertEqual(movedItem?.orderNumber, 3, "Item should have moved from position 0 to 3 after 3 moves down")
    }

    // MARK: - Documentation Test

    func testKeyboardReorderingDocumentation() {
        let documentation = """

        ========================================================================
        KEYBOARD REORDERING (TASK 12.11)
        ========================================================================

        PURPOSE:
        --------
        Add keyboard-based item reordering for accessibility and power users.
        Users with motor disabilities or keyboard-first workflows cannot
        reorder items without using a mouse with drag-and-drop.

        KEYBOARD SHORTCUTS:
        -------------------
        - Cmd+Option+Up Arrow: Move focused item up one position
        - Cmd+Option+Down Arrow: Move focused item down one position

        CONSTRAINTS:
        ------------
        - Only works when sorted by "Order" (orderNumber)
        - Disabled when sorted by title, date, quantity, etc.
        - Visual feedback during move (item animates to new position)

        TESTS IN THIS CLASS:
        --------------------
        1. moveItemUp from middle position
        2. moveItemUp from first position (should do nothing)
        3. moveItemUp with invalid ID
        4. moveItemDown from middle position
        5. moveItemDown from last position (should do nothing)
        6. moveItemDown with invalid ID
        7. canReorderWithKeyboard only true with orderNumber sort
        8. moveItemUp ignored when not sorted by order
        9. moveItemDown ignored when not sorted by order
        10. Edge cases: single item, empty list
        11. Sequential moves up/down

        FILES MODIFIED:
        ---------------
        - ListAll/ViewModels/ListViewModel.swift
          - Added moveItemUp(_ id: UUID)
          - Added moveItemDown(_ id: UUID)
          - Added canReorderWithKeyboard computed property

        - ListAllMac/Views/MacMainView.swift
          - Added .onKeyPress handlers for Cmd+Option+Up/Down

        - ListAllMacTests/TestHelpers.swift
          - Added matching methods to TestListViewModel

        ACCESSIBILITY:
        --------------
        This feature improves accessibility by:
        - Allowing keyboard-only users to reorder items
        - Supporting VoiceOver users who cannot use drag-and-drop
        - Following macOS accessibility best practices

        REFERENCES:
        -----------
        - Task 12.11 in /documentation/TODO.md
        - Apple HIG: Keyboard navigation
        - WCAG 2.1 Guideline 2.1.1 (Keyboard)

        ========================================================================

        """

        print(documentation)
        XCTAssertTrue(true, "Documentation generated")
    }
}


#endif
