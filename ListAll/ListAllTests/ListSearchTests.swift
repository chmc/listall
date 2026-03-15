import XCTest
import Foundation
import CoreData
@testable import ListAll

class ListSearchTests: XCTestCase {

    // MARK: - Search Tests (Phase 63)

    func testSearchWithEmptyText() throws {
        let dataManager = TestHelpers.createTestDataManager()
        let mainViewModel = TestMainViewModel(dataManager: dataManager)

        try mainViewModel.addList(name: "Test List")

        guard let list = mainViewModel.lists.first else {
            XCTFail("List should exist")
            return
        }

        let viewModel = TestListViewModel(list: list, dataManager: dataManager)
        viewModel.createItem(title: "Item 1", description: "Description 1")
        viewModel.createItem(title: "Item 2", description: "Description 2")

        // Empty search text should return all items
        viewModel.searchText = ""
        XCTAssertEqual(viewModel.filteredItems.count, 2)
    }

    func testSearchMatchingTitles() throws {
        let dataManager = TestHelpers.createTestDataManager()
        let mainViewModel = TestMainViewModel(dataManager: dataManager)

        try mainViewModel.addList(name: "Test List")

        guard let list = mainViewModel.lists.first else {
            XCTFail("List should exist")
            return
        }

        let viewModel = TestListViewModel(list: list, dataManager: dataManager)
        viewModel.createItem(title: "Apple", description: "Red fruit")
        viewModel.createItem(title: "Banana", description: "Yellow fruit")
        viewModel.createItem(title: "Cherry", description: "Small fruit")

        // Search for "Apple"
        viewModel.searchText = "Apple"
        XCTAssertEqual(viewModel.filteredItems.count, 1)
        XCTAssertEqual(viewModel.filteredItems[0].title, "Apple")

        // Search for "an" (should match Banana)
        viewModel.searchText = "an"
        XCTAssertEqual(viewModel.filteredItems.count, 1)
        XCTAssertEqual(viewModel.filteredItems[0].title, "Banana")
    }

    func testSearchMatchingDescriptions() throws {
        let dataManager = TestHelpers.createTestDataManager()
        let mainViewModel = TestMainViewModel(dataManager: dataManager)

        try mainViewModel.addList(name: "Test List")

        guard let list = mainViewModel.lists.first else {
            XCTFail("List should exist")
            return
        }

        let viewModel = TestListViewModel(list: list, dataManager: dataManager)
        viewModel.createItem(title: "Item 1", description: "This is a test description")
        viewModel.createItem(title: "Item 2", description: "Another description")
        viewModel.createItem(title: "Item 3", description: "Different content")

        // Search for "test" (should match first item's description)
        viewModel.searchText = "test"
        XCTAssertEqual(viewModel.filteredItems.count, 1)
        XCTAssertEqual(viewModel.filteredItems[0].title, "Item 1")

        // Search for "description" (should match first two items)
        viewModel.searchText = "description"
        XCTAssertEqual(viewModel.filteredItems.count, 2)
    }

    func testSearchWithNoMatches() throws {
        let dataManager = TestHelpers.createTestDataManager()
        let mainViewModel = TestMainViewModel(dataManager: dataManager)

        try mainViewModel.addList(name: "Test List")

        guard let list = mainViewModel.lists.first else {
            XCTFail("List should exist")
            return
        }

        let viewModel = TestListViewModel(list: list, dataManager: dataManager)
        viewModel.createItem(title: "Apple", description: "Red fruit")
        viewModel.createItem(title: "Banana", description: "Yellow fruit")

        // Search for something that doesn't exist
        viewModel.searchText = "xyz123notfound"
        XCTAssertEqual(viewModel.filteredItems.count, 0)
    }

    func testSearchCaseInsensitive() throws {
        let dataManager = TestHelpers.createTestDataManager()
        let mainViewModel = TestMainViewModel(dataManager: dataManager)

        try mainViewModel.addList(name: "Test List")

        guard let list = mainViewModel.lists.first else {
            XCTFail("List should exist")
            return
        }

        let viewModel = TestListViewModel(list: list, dataManager: dataManager)
        viewModel.createItem(title: "Apple", description: "Red Fruit")
        viewModel.createItem(title: "BANANA", description: "YELLOW FRUIT")

        // Test lowercase search matching uppercase title
        viewModel.searchText = "banana"
        XCTAssertEqual(viewModel.filteredItems.count, 1)
        XCTAssertEqual(viewModel.filteredItems[0].title, "BANANA")

        // Test uppercase search matching lowercase title
        viewModel.searchText = "APPLE"
        XCTAssertEqual(viewModel.filteredItems.count, 1)
        XCTAssertEqual(viewModel.filteredItems[0].title, "Apple")

        // Test mixed case search
        viewModel.searchText = "FrUiT"
        XCTAssertEqual(viewModel.filteredItems.count, 2)
    }

    func testSearchWithFiltering() throws {
        let dataManager = TestHelpers.createTestDataManager()
        let mainViewModel = TestMainViewModel(dataManager: dataManager)

        try mainViewModel.addList(name: "Test List")

        guard let list = mainViewModel.lists.first else {
            XCTFail("List should exist")
            return
        }

        let viewModel = TestListViewModel(list: list, dataManager: dataManager)
        viewModel.createItem(title: "Active Apple", description: "Red fruit")
        viewModel.createItem(title: "Completed Apple", description: "Green fruit")

        // Complete second item
        if let item = viewModel.items.first(where: { $0.title == "Completed Apple" }) {
            viewModel.toggleItemCrossedOut(item)
        }

        // Filter to show only active items
        viewModel.updateFilterOption(.active)

        // Search for "Apple" - should only find active one
        viewModel.searchText = "Apple"
        XCTAssertEqual(viewModel.filteredItems.count, 1)
        XCTAssertEqual(viewModel.filteredItems[0].title, "Active Apple")

        // Now filter to show completed items
        viewModel.updateFilterOption(.completed)

        // Same search should now find completed one
        viewModel.searchText = "Apple"
        XCTAssertEqual(viewModel.filteredItems.count, 1)
        XCTAssertEqual(viewModel.filteredItems[0].title, "Completed Apple")
    }

    func testSearchWithSorting() throws {
        let dataManager = TestHelpers.createTestDataManager()
        let mainViewModel = TestMainViewModel(dataManager: dataManager)

        try mainViewModel.addList(name: "Test List")

        guard let list = mainViewModel.lists.first else {
            XCTFail("List should exist")
            return
        }

        let viewModel = TestListViewModel(list: list, dataManager: dataManager)
        viewModel.createItem(title: "Zebra Test", description: "Last alphabetically")
        viewModel.createItem(title: "Apple Test", description: "First alphabetically")
        viewModel.createItem(title: "Banana Test", description: "Middle alphabetically")

        // Sort by title ascending
        viewModel.updateSortOption(.title)
        viewModel.updateSortDirection(.ascending)

        // Search for "Test" - should return all items in alphabetical order
        viewModel.searchText = "Test"
        XCTAssertEqual(viewModel.filteredItems.count, 3)
        XCTAssertEqual(viewModel.filteredItems[0].title, "Apple Test")
        XCTAssertEqual(viewModel.filteredItems[1].title, "Banana Test")
        XCTAssertEqual(viewModel.filteredItems[2].title, "Zebra Test")

        // Sort by title descending
        viewModel.updateSortDirection(.descending)

        // Same search should return items in reverse alphabetical order
        viewModel.searchText = "Test"
        XCTAssertEqual(viewModel.filteredItems.count, 3)
        XCTAssertEqual(viewModel.filteredItems[0].title, "Zebra Test")
        XCTAssertEqual(viewModel.filteredItems[1].title, "Banana Test")
        XCTAssertEqual(viewModel.filteredItems[2].title, "Apple Test")
    }

    func testSearchPartialMatching() throws {
        let dataManager = TestHelpers.createTestDataManager()
        let mainViewModel = TestMainViewModel(dataManager: dataManager)

        try mainViewModel.addList(name: "Test List")

        guard let list = mainViewModel.lists.first else {
            XCTFail("List should exist")
            return
        }

        let viewModel = TestListViewModel(list: list, dataManager: dataManager)
        viewModel.createItem(title: "Pineapple", description: "Tropical fruit")
        viewModel.createItem(title: "Apple", description: "Common fruit")
        viewModel.createItem(title: "Grapple", description: "Hybrid fruit")

        // Search for "apple" - should match all three (partial match)
        viewModel.searchText = "apple"
        XCTAssertEqual(viewModel.filteredItems.count, 3)
    }

    func testSearchEmptyItemDescription() throws {
        let dataManager = TestHelpers.createTestDataManager()
        let mainViewModel = TestMainViewModel(dataManager: dataManager)

        try mainViewModel.addList(name: "Test List")

        guard let list = mainViewModel.lists.first else {
            XCTFail("List should exist")
            return
        }

        let viewModel = TestListViewModel(list: list, dataManager: dataManager)
        viewModel.createItem(title: "Item with description", description: "Has text")
        viewModel.createItem(title: "Item without description", description: "")

        // Search for description text
        viewModel.searchText = "text"
        XCTAssertEqual(viewModel.filteredItems.count, 1)
        XCTAssertEqual(viewModel.filteredItems[0].title, "Item with description")

        // Search for title that has no description
        viewModel.searchText = "without"
        XCTAssertEqual(viewModel.filteredItems.count, 1)
        XCTAssertEqual(viewModel.filteredItems[0].title, "Item without description")
    }
}
