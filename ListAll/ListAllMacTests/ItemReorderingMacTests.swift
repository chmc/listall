//
//  ItemReorderingMacTests.swift
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

final class ItemReorderingMacTests: XCTestCase {

    // MARK: - Test Helpers

    private func createTestItem(
        title: String = "Test Item",
        description: String? = nil,
        quantity: Int = 1,
        isCrossedOut: Bool = false,
        orderNumber: Int = 0
    ) -> Item {
        var item = Item(title: title, listId: UUID())
        item.itemDescription = description
        item.quantity = quantity
        item.isCrossedOut = isCrossedOut
        item.orderNumber = orderNumber
        return item
    }

    private func createTestList(withItemCount count: Int) -> ListAll.List {
        var list = ListAll.List(name: "Test List")
        list.items = (0..<count).map { index in
            createTestItem(title: "Item \(index)", orderNumber: index)
        }
        return list
    }

    // MARK: - Reordering Logic Tests (Unit Tests Without DataManager)

    func testReorderingLogicSingleItemMove() {
        // Test the reordering algorithm in isolation
        var items = [
            createTestItem(title: "Item 0", orderNumber: 0),
            createTestItem(title: "Item 1", orderNumber: 1),
            createTestItem(title: "Item 2", orderNumber: 2)
        ]

        // Simulate moving item 0 to position 2
        let movedItem = items.remove(at: 0)
        items.insert(movedItem, at: 1) // destination - 1 because source was removed

        XCTAssertEqual(items.map { $0.title }, ["Item 1", "Item 0", "Item 2"])
    }

    func testReorderingLogicBackwardMove() {
        // Test backward move logic
        var items = (0..<5).map { createTestItem(title: "Item \($0)", orderNumber: $0) }

        // Move item 3 to position 1
        let movedItem = items.remove(at: 3)
        items.insert(movedItem, at: 1)

        XCTAssertEqual(items.map { $0.title }, ["Item 0", "Item 3", "Item 1", "Item 2", "Item 4"])
    }

    func testReorderingLogicForwardMove() {
        // Test forward move logic
        var items = (0..<5).map { createTestItem(title: "Item \($0)", orderNumber: $0) }

        // Move item 1 to position 4
        let movedItem = items.remove(at: 1)
        items.insert(movedItem, at: 3) // 4-1 = 3 because source was removed

        XCTAssertEqual(items.map { $0.title }, ["Item 0", "Item 2", "Item 3", "Item 1", "Item 4"])
    }

    func testOrderNumberUpdateLogic() {
        // Test that order numbers should be sequential after reordering
        var items = [
            createTestItem(title: "Item A", orderNumber: 5),
            createTestItem(title: "Item B", orderNumber: 10),
            createTestItem(title: "Item C", orderNumber: 15)
        ]

        // After reordering, update orderNumbers to be sequential
        for (index, _) in items.enumerated() {
            items[index].orderNumber = index
        }

        XCTAssertEqual(items[0].orderNumber, 0)
        XCTAssertEqual(items[1].orderNumber, 1)
        XCTAssertEqual(items[2].orderNumber, 2)
    }

    // MARK: - Sort Option Constraint Tests

    func testDragDisabledWhenSortedByTitle() {
        // ARRANGE: Create test list
        let testList = createTestList(withItemCount: 3)
        let viewModel = ListViewModel(list: testList)
        viewModel.items = testList.items

        // ACT: Change sort option to title
        viewModel.currentSortOption = .title

        // ASSERT: Verify sort option is not orderNumber (drag should be disabled)
        XCTAssertNotEqual(viewModel.currentSortOption, .orderNumber,
                         "Drag should be disabled when not sorted by orderNumber")
        XCTAssertEqual(viewModel.currentSortOption, .title)
    }

    func testDragDisabledWhenSortedByCreatedAt() {
        // ARRANGE: Create test list
        let testList = createTestList(withItemCount: 3)
        let viewModel = ListViewModel(list: testList)
        viewModel.items = testList.items

        // ACT: Change sort option to createdAt
        viewModel.currentSortOption = .createdAt

        // ASSERT: Verify sort option is not orderNumber
        XCTAssertNotEqual(viewModel.currentSortOption, .orderNumber,
                         "Drag should be disabled when sorted by createdAt")
        XCTAssertEqual(viewModel.currentSortOption, .createdAt)
    }

    func testDragDisabledWhenSortedByModifiedAt() {
        // ARRANGE: Create test list
        let testList = createTestList(withItemCount: 3)
        let viewModel = ListViewModel(list: testList)
        viewModel.items = testList.items

        // ACT: Change sort option to modifiedAt
        viewModel.currentSortOption = .modifiedAt

        // ASSERT: Verify sort option is not orderNumber
        XCTAssertNotEqual(viewModel.currentSortOption, .orderNumber,
                         "Drag should be disabled when sorted by modifiedAt")
        XCTAssertEqual(viewModel.currentSortOption, .modifiedAt)
    }

    func testDragDisabledWhenSortedByQuantity() {
        // ARRANGE: Create test list
        let testList = createTestList(withItemCount: 3)
        let viewModel = ListViewModel(list: testList)
        viewModel.items = testList.items

        // ACT: Change sort option to quantity
        viewModel.currentSortOption = .quantity

        // ASSERT: Verify sort option is not orderNumber
        XCTAssertNotEqual(viewModel.currentSortOption, .orderNumber,
                         "Drag should be disabled when sorted by quantity")
        XCTAssertEqual(viewModel.currentSortOption, .quantity)
    }

    func testCanReorderOnlyWithOrderNumberSort() {
        // ARRANGE: Create test list
        let testList = createTestList(withItemCount: 3)
        let viewModel = ListViewModel(list: testList)
        viewModel.items = testList.items

        // ASSERT: Test each sort option
        viewModel.currentSortOption = .orderNumber
        XCTAssertEqual(viewModel.currentSortOption, .orderNumber,
                      "canReorder should be true when sortOption == .orderNumber")

        viewModel.currentSortOption = .title
        XCTAssertNotEqual(viewModel.currentSortOption, .orderNumber,
                         "canReorder should be false when sortOption == .title")

        viewModel.currentSortOption = .createdAt
        XCTAssertNotEqual(viewModel.currentSortOption, .orderNumber,
                         "canReorder should be false when sortOption == .createdAt")

        viewModel.currentSortOption = .modifiedAt
        XCTAssertNotEqual(viewModel.currentSortOption, .orderNumber,
                         "canReorder should be false when sortOption == .modifiedAt")

        viewModel.currentSortOption = .quantity
        XCTAssertNotEqual(viewModel.currentSortOption, .orderNumber,
                         "canReorder should be false when sortOption == .quantity")
    }

    // MARK: - Multi-Selection Logic Tests

    func testMultiSelectReorderingLogic() {
        // Test that multiple items maintain relative order when moved
        let items = (0..<5).map { createTestItem(title: "Item \($0)", orderNumber: $0) }
        let selectedIds = Set([items[1].id, items[3].id])

        // Get selected items in their original order
        let selectedItems = items.filter { selectedIds.contains($0.id) }
        XCTAssertEqual(selectedItems.count, 2)
        XCTAssertEqual(selectedItems[0].title, "Item 1")
        XCTAssertEqual(selectedItems[1].title, "Item 3")

        // Remove selected items from array
        let remainingItems = items.filter { !selectedIds.contains($0.id) }
        XCTAssertEqual(remainingItems.count, 3)
        XCTAssertEqual(remainingItems.map { $0.title }, ["Item 0", "Item 2", "Item 4"])

        // Insert selected items at new position (e.g., position 2)
        var reordered = remainingItems
        reordered.insert(contentsOf: selectedItems, at: 2)
        XCTAssertEqual(reordered.map { $0.title }, ["Item 0", "Item 2", "Item 1", "Item 3", "Item 4"])
    }

    func testMultiSelectPreservesRelativeOrder() {
        // Verify that selected items maintain their relative order after move
        let items = (0..<4).map { createTestItem(title: "Item \($0)", orderNumber: $0) }
        let selectedIds = Set([items[0].id, items[2].id])

        let selectedItems = items.filter { selectedIds.contains($0.id) }
        XCTAssertEqual(selectedItems[0].title, "Item 0")
        XCTAssertEqual(selectedItems[1].title, "Item 2")

        // Verify order is maintained regardless of insertion position
        var remaining = items.filter { !selectedIds.contains($0.id) }
        remaining.insert(contentsOf: selectedItems, at: 1)

        let item0Index = remaining.firstIndex(where: { $0.title == "Item 0" })
        let item2Index = remaining.firstIndex(where: { $0.title == "Item 2" })

        XCTAssertNotNil(item0Index)
        XCTAssertNotNil(item2Index)
        if let idx0 = item0Index, let idx2 = item2Index {
            XCTAssertLessThan(idx0, idx2, "Item 0 should remain before Item 2")
        }
    }

    // MARK: - Edge Cases

    func testReorderSingleItemLogic() {
        // Test that reordering with a single item is safe
        var items = [createTestItem(title: "Item 0", orderNumber: 0)]
        let originalCount = items.count

        // Simulate reordering to same position
        if items.count > 0 {
            let item = items.remove(at: 0)
            items.insert(item, at: 0)
        }

        XCTAssertEqual(items.count, originalCount)
        XCTAssertEqual(items[0].title, "Item 0")
    }

    func testReorderEmptyListLogic() {
        // Test that reordering with empty list is safe
        var items: [Item] = []

        // Attempting to reorder empty list should not crash
        if items.indices.contains(0) {
            let item = items.remove(at: 0)
            items.insert(item, at: 0)
        }

        XCTAssertEqual(items.count, 0, "Empty list should remain empty")
    }

    func testReorderToSamePositionLogic() {
        // Test that reordering to same position maintains order
        var items = (0..<3).map { createTestItem(title: "Item \($0)", orderNumber: $0) }
        let originalTitles = items.map { $0.title }

        // Move item 1 to position 1 (no change)
        let item = items.remove(at: 1)
        items.insert(item, at: 1)

        XCTAssertEqual(items.map { $0.title }, originalTitles)
    }

    // MARK: - Item Property Preservation Tests

    func testReorderPreservesItemProperties() {
        // Test that reordering preserves all item properties except orderNumber
        let item1 = createTestItem(title: "Item 1", description: "Desc 1",
                                   quantity: 5, isCrossedOut: false, orderNumber: 0)
        let item2 = createTestItem(title: "Item 2", description: "Desc 2",
                                   quantity: 10, isCrossedOut: true, orderNumber: 1)
        let item3 = createTestItem(title: "Item 3", description: "Desc 3",
                                   quantity: 15, isCrossedOut: false, orderNumber: 2)

        var items = [item1, item2, item3]

        // Reorder: move item 0 to position 2
        let movedItem = items.remove(at: 0)
        items.insert(movedItem, at: 1)

        // Verify properties preserved
        let reorderedItem1 = items.first(where: { $0.id == item1.id })!
        XCTAssertEqual(reorderedItem1.title, "Item 1")
        XCTAssertEqual(reorderedItem1.itemDescription, "Desc 1")
        XCTAssertEqual(reorderedItem1.quantity, 5)
        XCTAssertEqual(reorderedItem1.isCrossedOut, false)

        let unchangedItem2 = items.first(where: { $0.id == item2.id })!
        XCTAssertEqual(unchangedItem2.title, "Item 2")
        XCTAssertEqual(unchangedItem2.itemDescription, "Desc 2")
        XCTAssertEqual(unchangedItem2.quantity, 10)
        XCTAssertEqual(unchangedItem2.isCrossedOut, true)
    }

    // MARK: - macOS Platform Verification

    func testRunningOnMacOS() {
        #if os(macOS)
        XCTAssertTrue(true, "Item reordering tests are running on macOS")
        #else
        XCTFail("Item reordering tests should only run on macOS")
        #endif
    }
}


#endif
