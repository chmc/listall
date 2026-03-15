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

    // MARK: - Inline Filter Pill Tests

    func testUpdateFilterOptionToAll() throws {
        let dataManager = TestHelpers.createTestDataManager()
        let mainViewModel = TestMainViewModel(dataManager: dataManager)
        try mainViewModel.addList(name: "Test List")
        guard let list = mainViewModel.lists.first else { XCTFail("List should exist"); return }
        let viewModel = TestListViewModel(list: list, dataManager: dataManager)

        viewModel.updateFilterOption(.all)

        XCTAssertEqual(viewModel.currentFilterOption, .all)
        XCTAssertTrue(viewModel.showCrossedOutItems, "All filter should show crossed out items")
    }

    func testUpdateFilterOptionToActive() throws {
        let dataManager = TestHelpers.createTestDataManager()
        let mainViewModel = TestMainViewModel(dataManager: dataManager)
        try mainViewModel.addList(name: "Test List")
        guard let list = mainViewModel.lists.first else { XCTFail("List should exist"); return }
        let viewModel = TestListViewModel(list: list, dataManager: dataManager)

        viewModel.updateFilterOption(.active)

        XCTAssertEqual(viewModel.currentFilterOption, .active)
        XCTAssertFalse(viewModel.showCrossedOutItems, "Active filter should hide crossed out items")
    }

    func testUpdateFilterOptionToCompleted() throws {
        let dataManager = TestHelpers.createTestDataManager()
        let mainViewModel = TestMainViewModel(dataManager: dataManager)
        try mainViewModel.addList(name: "Test List")
        guard let list = mainViewModel.lists.first else { XCTFail("List should exist"); return }
        let viewModel = TestListViewModel(list: list, dataManager: dataManager)

        viewModel.updateFilterOption(.completed)

        XCTAssertEqual(viewModel.currentFilterOption, .completed)
        XCTAssertTrue(viewModel.showCrossedOutItems, "Completed filter should show crossed out items")
    }

    func testInlinePillFilterOptionsAreSubsetOfAllOptions() {
        // Inline pills only expose .all, .active, .completed
        let inlinePillOptions: [ItemFilterOption] = [.all, .active, .completed]
        XCTAssertEqual(inlinePillOptions.count, 3)
        XCTAssertTrue(inlinePillOptions.contains(.all))
        XCTAssertTrue(inlinePillOptions.contains(.active))
        XCTAssertTrue(inlinePillOptions.contains(.completed))
        XCTAssertFalse(inlinePillOptions.contains(.hasDescription))
        XCTAssertFalse(inlinePillOptions.contains(.hasImages))
    }

    func testSheetOnlyFilterOptionHasNoMatchingPill() throws {
        // When filter is set to .hasImages via sheet, no inline pill should be selected
        let dataManager = TestHelpers.createTestDataManager()
        let mainViewModel = TestMainViewModel(dataManager: dataManager)
        try mainViewModel.addList(name: "Test List")
        guard let list = mainViewModel.lists.first else { XCTFail("List should exist"); return }
        let viewModel = TestListViewModel(list: list, dataManager: dataManager)

        viewModel.updateFilterOption(.hasImages)

        let inlinePillOptions: [ItemFilterOption] = [.all, .active, .completed]
        XCTAssertFalse(inlinePillOptions.contains(viewModel.currentFilterOption),
                       "Sheet-only filter .hasImages should not match any inline pill")
    }

    func testTappingPillOverridesSheetFilter() throws {
        // When .hasImages is active and user taps "Active" pill, it should override
        let dataManager = TestHelpers.createTestDataManager()
        let mainViewModel = TestMainViewModel(dataManager: dataManager)
        try mainViewModel.addList(name: "Test List")
        guard let list = mainViewModel.lists.first else { XCTFail("List should exist"); return }
        let viewModel = TestListViewModel(list: list, dataManager: dataManager)

        viewModel.updateFilterOption(.hasImages)
        XCTAssertEqual(viewModel.currentFilterOption, .hasImages)

        // Simulate tapping "Active" pill
        viewModel.updateFilterOption(.active)
        XCTAssertEqual(viewModel.currentFilterOption, .active, "Tapping pill should override sheet filter")
    }

    func testFilteredItemsWithCompletedFilter() throws {
        let dataManager = TestHelpers.createTestDataManager()
        let mainViewModel = TestMainViewModel(dataManager: dataManager)
        try mainViewModel.addList(name: "Test List")
        guard let list = mainViewModel.lists.first else { XCTFail("List should exist"); return }
        let viewModel = TestListViewModel(list: list, dataManager: dataManager)

        viewModel.createItem(title: "Active Item", description: "")
        viewModel.createItem(title: "Done Item", description: "")

        guard let itemToCross = viewModel.items.first(where: { $0.title == "Done Item" }) else {
            XCTFail("Should find item"); return
        }
        viewModel.toggleItemCrossedOut(itemToCross)

        viewModel.updateFilterOption(.completed)
        XCTAssertEqual(viewModel.filteredItems.count, 1)
        XCTAssertEqual(viewModel.filteredItems.first?.title, "Done Item")
    }

    // MARK: - Show/Hide Crossed Out Items Tests (existing)

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
