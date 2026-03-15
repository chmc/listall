import XCTest
import Foundation
import CoreData
@testable import ListAll

class ItemMultiSelectTests: XCTestCase {

    // MARK: - Item Multi-Select Tests

    func testEnterSelectionModeForItems() throws {
        let dataManager = TestHelpers.createTestDataManager()
        let mainViewModel = TestMainViewModel(dataManager: dataManager)

        try mainViewModel.addList(name: "Test List")
        guard let list = mainViewModel.lists.first else {
            XCTFail("List should exist")
            return
        }

        let viewModel = TestListViewModel(list: list, dataManager: dataManager)

        XCTAssertFalse(viewModel.isInSelectionMode)
        XCTAssertTrue(viewModel.selectedItems.isEmpty)

        viewModel.enterSelectionMode()

        XCTAssertTrue(viewModel.isInSelectionMode)
        XCTAssertTrue(viewModel.selectedItems.isEmpty)
    }

    func testExitSelectionModeForItems() throws {
        let dataManager = TestHelpers.createTestDataManager()
        let mainViewModel = TestMainViewModel(dataManager: dataManager)

        try mainViewModel.addList(name: "Test List")
        guard let list = mainViewModel.lists.first else {
            XCTFail("List should exist")
            return
        }

        let viewModel = TestListViewModel(list: list, dataManager: dataManager)
        viewModel.createItem(title: "Item 1")

        viewModel.enterSelectionMode()

        guard let itemId = viewModel.items.first?.id else {
            XCTFail("Item should exist")
            return
        }

        viewModel.toggleSelection(for: itemId)
        XCTAssertTrue(viewModel.selectedItems.contains(itemId))

        viewModel.exitSelectionMode()

        XCTAssertFalse(viewModel.isInSelectionMode)
        XCTAssertTrue(viewModel.selectedItems.isEmpty)
    }

    func testToggleItemSelection() throws {
        let dataManager = TestHelpers.createTestDataManager()
        let mainViewModel = TestMainViewModel(dataManager: dataManager)

        try mainViewModel.addList(name: "Test List")
        guard let list = mainViewModel.lists.first else {
            XCTFail("List should exist")
            return
        }

        let viewModel = TestListViewModel(list: list, dataManager: dataManager)
        viewModel.createItem(title: "Item 1")

        guard let itemId = viewModel.items.first?.id else {
            XCTFail("Item should exist")
            return
        }

        viewModel.enterSelectionMode()

        // Select the item
        viewModel.toggleSelection(for: itemId)
        XCTAssertTrue(viewModel.selectedItems.contains(itemId))

        // Deselect the item
        viewModel.toggleSelection(for: itemId)
        XCTAssertFalse(viewModel.selectedItems.contains(itemId))
    }

    func testSelectAllItems() throws {
        let dataManager = TestHelpers.createTestDataManager()
        let mainViewModel = TestMainViewModel(dataManager: dataManager)

        try mainViewModel.addList(name: "Test List")
        guard let list = mainViewModel.lists.first else {
            XCTFail("List should exist")
            return
        }

        let viewModel = TestListViewModel(list: list, dataManager: dataManager)
        viewModel.createItem(title: "Item 1")
        viewModel.createItem(title: "Item 2")
        viewModel.createItem(title: "Item 3")

        viewModel.enterSelectionMode()
        viewModel.selectAll()

        XCTAssertEqual(viewModel.selectedItems.count, 3)
        for item in viewModel.items {
            XCTAssertTrue(viewModel.selectedItems.contains(item.id))
        }
    }

    func testDeselectAllItems() throws {
        let dataManager = TestHelpers.createTestDataManager()
        let mainViewModel = TestMainViewModel(dataManager: dataManager)

        try mainViewModel.addList(name: "Test List")
        guard let list = mainViewModel.lists.first else {
            XCTFail("List should exist")
            return
        }

        let viewModel = TestListViewModel(list: list, dataManager: dataManager)
        viewModel.createItem(title: "Item 1")
        viewModel.createItem(title: "Item 2")

        viewModel.enterSelectionMode()
        viewModel.selectAll()

        XCTAssertEqual(viewModel.selectedItems.count, 2)

        viewModel.deselectAll()

        XCTAssertTrue(viewModel.selectedItems.isEmpty)
    }

    func testDeleteSelectedItems() throws {
        let dataManager = TestHelpers.createTestDataManager()
        let mainViewModel = TestMainViewModel(dataManager: dataManager)

        try mainViewModel.addList(name: "Test List")
        guard let list = mainViewModel.lists.first else {
            XCTFail("List should exist")
            return
        }

        let viewModel = TestListViewModel(list: list, dataManager: dataManager)
        viewModel.createItem(title: "Item 1")
        viewModel.createItem(title: "Item 2")
        viewModel.createItem(title: "Item 3")

        XCTAssertEqual(viewModel.items.count, 3)

        viewModel.enterSelectionMode()

        // Select first and third items
        let firstItemId = viewModel.items[0].id
        let thirdItemId = viewModel.items[2].id
        viewModel.toggleSelection(for: firstItemId)
        viewModel.toggleSelection(for: thirdItemId)

        XCTAssertEqual(viewModel.selectedItems.count, 2)

        // Delete selected items
        viewModel.deleteSelectedItems()

        XCTAssertEqual(viewModel.items.count, 1)
        XCTAssertEqual(viewModel.items[0].title, "Item 2")
        XCTAssertTrue(viewModel.selectedItems.isEmpty)
    }

    func testDeleteAllItems() throws {
        let dataManager = TestHelpers.createTestDataManager()
        let mainViewModel = TestMainViewModel(dataManager: dataManager)

        try mainViewModel.addList(name: "Test List")
        guard let list = mainViewModel.lists.first else {
            XCTFail("List should exist")
            return
        }

        let viewModel = TestListViewModel(list: list, dataManager: dataManager)
        viewModel.createItem(title: "Item 1")
        viewModel.createItem(title: "Item 2")
        viewModel.createItem(title: "Item 3")

        XCTAssertEqual(viewModel.items.count, 3)

        viewModel.enterSelectionMode()
        viewModel.selectAll()
        viewModel.deleteSelectedItems()

        XCTAssertTrue(viewModel.items.isEmpty)
        XCTAssertTrue(viewModel.selectedItems.isEmpty)
    }

    func testItemSelectionModeWithEmptyItems() throws {
        let dataManager = TestHelpers.createTestDataManager()
        let mainViewModel = TestMainViewModel(dataManager: dataManager)

        try mainViewModel.addList(name: "Test List")
        guard let list = mainViewModel.lists.first else {
            XCTFail("List should exist")
            return
        }

        let viewModel = TestListViewModel(list: list, dataManager: dataManager)

        viewModel.enterSelectionMode()
        viewModel.selectAll()

        XCTAssertTrue(viewModel.selectedItems.isEmpty)
        XCTAssertTrue(viewModel.items.isEmpty)
    }

    func testItemMultiSelectPersistence() throws {
        let dataManager = TestHelpers.createTestDataManager()
        let mainViewModel = TestMainViewModel(dataManager: dataManager)

        try mainViewModel.addList(name: "Test List")
        guard let list = mainViewModel.lists.first else {
            XCTFail("List should exist")
            return
        }

        let viewModel = TestListViewModel(list: list, dataManager: dataManager)
        viewModel.createItem(title: "Item 1")
        viewModel.createItem(title: "Item 2")
        viewModel.createItem(title: "Item 3")

        viewModel.enterSelectionMode()

        let firstItemId = viewModel.items[0].id
        let secondItemId = viewModel.items[1].id

        viewModel.toggleSelection(for: firstItemId)
        viewModel.toggleSelection(for: secondItemId)

        // Verify selections persist
        XCTAssertEqual(viewModel.selectedItems.count, 2)
        XCTAssertTrue(viewModel.selectedItems.contains(firstItemId))
        XCTAssertTrue(viewModel.selectedItems.contains(secondItemId))

        // Add another item - selections should remain
        viewModel.createItem(title: "Item 4")

        XCTAssertEqual(viewModel.selectedItems.count, 2)
        XCTAssertTrue(viewModel.selectedItems.contains(firstItemId))
        XCTAssertTrue(viewModel.selectedItems.contains(secondItemId))
    }

    func testItemSelectAllRespectsFilters() throws {
        let dataManager = TestHelpers.createTestDataManager()
        let mainViewModel = TestMainViewModel(dataManager: dataManager)

        try mainViewModel.addList(name: "Test List")
        guard let list = mainViewModel.lists.first else {
            XCTFail("List should exist")
            return
        }

        let viewModel = TestListViewModel(list: list, dataManager: dataManager)
        viewModel.createItem(title: "Item 1")
        viewModel.createItem(title: "Item 2")
        viewModel.createItem(title: "Item 3")

        // Complete first item
        if let item1 = viewModel.items.first(where: { $0.title == "Item 1" }) {
            viewModel.toggleItemCrossedOut(item1)
        }

        // Set filter to show only active items
        viewModel.updateFilterOption(.active)

        // Select all should only select filtered (active) items
        viewModel.enterSelectionMode()
        viewModel.selectAll()

        // Should only select 2 active items, not the completed one
        XCTAssertEqual(viewModel.selectedItems.count, 2)
        XCTAssertEqual(viewModel.filteredItems.count, 2)
    }
}
