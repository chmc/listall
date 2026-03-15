import XCTest
import Foundation
import CoreData
@testable import ListAll

class ListViewModelTests: XCTestCase {

    // MARK: - ListViewModel Tests

    func testListViewModelCreateItem() throws {
        // Create a shared data manager
        let dataManager = TestHelpers.createTestDataManager()
        let mainViewModel = TestMainViewModel(dataManager: dataManager)

        try mainViewModel.addList(name: "Test List")

        guard let list = mainViewModel.lists.first else {
            XCTFail("List should exist")
            return
        }

        // Use the same data manager for the list view model
        let viewModel = TestListViewModel(list: list, dataManager: dataManager)
        let initialCount = viewModel.items.count

        viewModel.createItem(title: "New Item", description: "Description")
        XCTAssertEqual(viewModel.items.count, initialCount + 1)
        XCTAssertTrue(viewModel.items.contains { $0.title == "New Item" })
    }

    func testListViewModelToggleItemCrossedOut() throws {
        // Create a shared data manager
        let dataManager = TestHelpers.createTestDataManager()
        let mainViewModel = TestMainViewModel(dataManager: dataManager)

        try mainViewModel.addList(name: "Test List")

        guard let list = mainViewModel.lists.first else {
            XCTFail("List should exist")
            return
        }

        // Use the same data manager for the list view model
        let viewModel = TestListViewModel(list: list, dataManager: dataManager)
        viewModel.createItem(title: "Test Item", description: "")

        guard let item = viewModel.items.first else {
            XCTFail("Item should exist")
            return
        }

        let originalState = item.isCrossedOut
        viewModel.toggleItemCrossedOut(item)

        // Refresh the item from the list
        guard let updatedItem = viewModel.items.first(where: { $0.id == item.id }) else {
            XCTFail("Item should still exist")
            return
        }

        XCTAssertEqual(updatedItem.isCrossedOut, !originalState)
    }

    func testListViewModelDeleteItem() throws {
        // Create a shared data manager
        let dataManager = TestHelpers.createTestDataManager()
        let mainViewModel = TestMainViewModel(dataManager: dataManager)

        try mainViewModel.addList(name: "Test List")

        guard let list = mainViewModel.lists.first else {
            XCTFail("List should exist")
            return
        }

        // Use the same data manager for the list view model
        let viewModel = TestListViewModel(list: list, dataManager: dataManager)
        viewModel.createItem(title: "Test Item", description: "")
        let initialCount = viewModel.items.count

        guard let item = viewModel.items.first else {
            XCTFail("Item should exist")
            return
        }

        viewModel.deleteItem(item)
        XCTAssertEqual(viewModel.items.count, initialCount - 1)
        XCTAssertFalse(viewModel.items.contains { $0.id == item.id })
    }

    func testListViewModelReorderItems() throws {
        // Create a shared data manager
        let dataManager = TestHelpers.createTestDataManager()
        let mainViewModel = TestMainViewModel(dataManager: dataManager)

        try mainViewModel.addList(name: "Test List")

        guard let list = mainViewModel.lists.first else {
            XCTFail("List should exist")
            return
        }

        // Use the same data manager for the list view model
        let viewModel = TestListViewModel(list: list, dataManager: dataManager)

        // Create multiple items to test reordering
        viewModel.createItem(title: "First Item", description: "")
        viewModel.createItem(title: "Second Item", description: "")
        viewModel.createItem(title: "Third Item", description: "")

        // Verify initial order
        XCTAssertEqual(viewModel.items.count, 3)
        let initialItems = viewModel.items.sorted { $0.orderNumber < $1.orderNumber }
        XCTAssertEqual(initialItems[0].title, "First Item")
        XCTAssertEqual(initialItems[1].title, "Second Item")
        XCTAssertEqual(initialItems[2].title, "Third Item")

        // Test reordering: move first item to last position
        viewModel.reorderItems(from: 0, to: 2)

        // Verify new order
        let reorderedItems = viewModel.items.sorted { $0.orderNumber < $1.orderNumber }
        XCTAssertEqual(reorderedItems.count, 3)
        XCTAssertEqual(reorderedItems[0].title, "Second Item")
        XCTAssertEqual(reorderedItems[1].title, "Third Item")
        XCTAssertEqual(reorderedItems[2].title, "First Item")

        // Verify order numbers are correct
        XCTAssertEqual(reorderedItems[0].orderNumber, 0)
        XCTAssertEqual(reorderedItems[1].orderNumber, 1)
        XCTAssertEqual(reorderedItems[2].orderNumber, 2)
    }

    func testListViewModelMoveItems() throws {
        // Create a shared data manager
        let dataManager = TestHelpers.createTestDataManager()
        let mainViewModel = TestMainViewModel(dataManager: dataManager)

        try mainViewModel.addList(name: "Test List")

        guard let list = mainViewModel.lists.first else {
            XCTFail("List should exist")
            return
        }

        // Use the same data manager for the list view model
        let viewModel = TestListViewModel(list: list, dataManager: dataManager)

        // Create multiple items to test moving
        viewModel.createItem(title: "Item A", description: "")
        viewModel.createItem(title: "Item B", description: "")
        viewModel.createItem(title: "Item C", description: "")
        viewModel.createItem(title: "Item D", description: "")

        // Verify initial order
        XCTAssertEqual(viewModel.items.count, 4)
        let initialItems = viewModel.items.sorted { $0.orderNumber < $1.orderNumber }
        XCTAssertEqual(initialItems[0].title, "Item A")
        XCTAssertEqual(initialItems[1].title, "Item B")
        XCTAssertEqual(initialItems[2].title, "Item C")
        XCTAssertEqual(initialItems[3].title, "Item D")

        // Test moving: simulate SwiftUI's onMove behavior (move item B to position 3)
        let sourceIndexSet = IndexSet([1])
        viewModel.moveItems(from: sourceIndexSet, to: 3)

        // Verify new order: A, C, B, D
        let movedItems = viewModel.items.sorted { $0.orderNumber < $1.orderNumber }
        XCTAssertEqual(movedItems.count, 4)
        XCTAssertEqual(movedItems[0].title, "Item A")
        XCTAssertEqual(movedItems[1].title, "Item C")
        XCTAssertEqual(movedItems[2].title, "Item B")
        XCTAssertEqual(movedItems[3].title, "Item D")
    }

    func testListViewModelReorderItemsInvalidIndices() throws {
        // Create a shared data manager
        let dataManager = TestHelpers.createTestDataManager()
        let mainViewModel = TestMainViewModel(dataManager: dataManager)

        try mainViewModel.addList(name: "Test List")

        guard let list = mainViewModel.lists.first else {
            XCTFail("List should exist")
            return
        }

        // Use the same data manager for the list view model
        let viewModel = TestListViewModel(list: list, dataManager: dataManager)

        // Create items
        viewModel.createItem(title: "Item 1", description: "")
        viewModel.createItem(title: "Item 2", description: "")

        let initialItems = viewModel.items.sorted { $0.orderNumber < $1.orderNumber }
        let initialCount = initialItems.count

        // Test invalid indices - should not crash and should not change order
        viewModel.reorderItems(from: -1, to: 0) // Invalid source
        viewModel.reorderItems(from: 0, to: 10) // Invalid destination
        viewModel.reorderItems(from: 0, to: 0) // Same index

        // Verify no changes occurred
        let finalItems = viewModel.items.sorted { $0.orderNumber < $1.orderNumber }
        XCTAssertEqual(finalItems.count, initialCount)
        XCTAssertEqual(finalItems[0].title, initialItems[0].title)
        XCTAssertEqual(finalItems[1].title, initialItems[1].title)
    }
}
