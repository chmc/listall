import XCTest
import Foundation
import CoreData
@testable import ListAll

class ListViewModelFilterTests: XCTestCase {

    // MARK: - Show/Hide Crossed Out Items Tests

    func testListViewModelShowCrossedOutItemsDefault() throws {
        // Create a shared data manager
        let dataManager = TestHelpers.createTestDataManager()
        let mainViewModel = TestMainViewModel(dataManager: dataManager)

        try mainViewModel.addList(name: "Test List")

        guard let list = mainViewModel.lists.first else {
            XCTFail("List should exist")
            return
        }

        let viewModel = TestListViewModel(list: list, dataManager: dataManager)

        // By default, should show crossed out items
        XCTAssertTrue(viewModel.showCrossedOutItems)
    }

    func testListViewModelToggleShowCrossedOutItems() throws {
        // Create a shared data manager
        let dataManager = TestHelpers.createTestDataManager()
        let mainViewModel = TestMainViewModel(dataManager: dataManager)

        try mainViewModel.addList(name: "Test List")

        guard let list = mainViewModel.lists.first else {
            XCTFail("List should exist")
            return
        }

        let viewModel = TestListViewModel(list: list, dataManager: dataManager)

        let initialState = viewModel.showCrossedOutItems
        viewModel.toggleShowCrossedOutItems()

        XCTAssertEqual(viewModel.showCrossedOutItems, !initialState)
    }

    func testListViewModelFilteredItemsShowAll() throws {
        // Create a shared data manager
        let dataManager = TestHelpers.createTestDataManager()
        let mainViewModel = TestMainViewModel(dataManager: dataManager)

        try mainViewModel.addList(name: "Test List")

        guard let list = mainViewModel.lists.first else {
            XCTFail("List should exist")
            return
        }

        let viewModel = TestListViewModel(list: list, dataManager: dataManager)

        // Create items with different states
        viewModel.createItem(title: "Active Item 1", description: "")
        viewModel.createItem(title: "Active Item 2", description: "")
        viewModel.createItem(title: "Crossed Item", description: "")

        // Cross out one item
        guard let itemToCross = viewModel.items.first(where: { $0.title == "Crossed Item" }) else {
            XCTFail("Should find item to cross out")
            return
        }

        viewModel.toggleItemCrossedOut(itemToCross)

        // When showCrossedOutItems is true, should show all items
        viewModel.showCrossedOutItems = true
        XCTAssertEqual(viewModel.filteredItems.count, 3)
        XCTAssertTrue(viewModel.filteredItems.contains { $0.title == "Active Item 1" })
        XCTAssertTrue(viewModel.filteredItems.contains { $0.title == "Active Item 2" })
        XCTAssertTrue(viewModel.filteredItems.contains { $0.title == "Crossed Item" })
    }

    func testListViewModelFilteredItemsHideCrossedOut() throws {
        // Create a shared data manager
        let dataManager = TestHelpers.createTestDataManager()
        let mainViewModel = TestMainViewModel(dataManager: dataManager)

        try mainViewModel.addList(name: "Test List")

        guard let list = mainViewModel.lists.first else {
            XCTFail("List should exist")
            return
        }

        let viewModel = TestListViewModel(list: list, dataManager: dataManager)

        // Create items with different states
        viewModel.createItem(title: "Active Item 1", description: "")
        viewModel.createItem(title: "Active Item 2", description: "")
        viewModel.createItem(title: "Crossed Item", description: "")

        // Cross out one item
        guard let itemToCross = viewModel.items.first(where: { $0.title == "Crossed Item" }) else {
            XCTFail("Should find item to cross out")
            return
        }

        viewModel.toggleItemCrossedOut(itemToCross)

        // When showCrossedOutItems is false, should only show active items
        viewModel.showCrossedOutItems = false
        XCTAssertEqual(viewModel.filteredItems.count, 2)
        XCTAssertTrue(viewModel.filteredItems.contains { $0.title == "Active Item 1" })
        XCTAssertTrue(viewModel.filteredItems.contains { $0.title == "Active Item 2" })
        XCTAssertFalse(viewModel.filteredItems.contains { $0.title == "Crossed Item" })
    }

    func testListViewModelFilteredItemsEmptyWhenAllCrossedOut() throws {
        // Create a shared data manager
        let dataManager = TestHelpers.createTestDataManager()
        let mainViewModel = TestMainViewModel(dataManager: dataManager)

        try mainViewModel.addList(name: "Test List")

        guard let list = mainViewModel.lists.first else {
            XCTFail("List should exist")
            return
        }

        let viewModel = TestListViewModel(list: list, dataManager: dataManager)

        // Create items and cross them all out
        viewModel.createItem(title: "Item 1", description: "")
        viewModel.createItem(title: "Item 2", description: "")

        for item in viewModel.items {
            viewModel.toggleItemCrossedOut(item)
        }

        // When showCrossedOutItems is false and all items are crossed out, should show empty
        viewModel.showCrossedOutItems = false
        XCTAssertEqual(viewModel.filteredItems.count, 0)

        // When showCrossedOutItems is true, should show all crossed out items
        viewModel.showCrossedOutItems = true
        XCTAssertEqual(viewModel.filteredItems.count, 2)
    }
}
