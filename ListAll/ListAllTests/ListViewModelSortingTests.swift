import XCTest
import Foundation
import CoreData
@testable import ListAll

class ListViewModelSortingTests: XCTestCase {

    // MARK: - Sorting Tests

    func testItemSortingByOrderNumberAscending() throws {
        let dataManager = TestHelpers.createTestDataManager()
        let mainViewModel = TestMainViewModel(dataManager: dataManager)

        try mainViewModel.addList(name: "Test List")
        guard let list = mainViewModel.lists.first else {
            XCTFail("List should exist")
            return
        }

        let viewModel = TestListViewModel(list: list, dataManager: dataManager)

        // Create items with specific order numbers
        viewModel.createItem(title: "Third", description: "")
        viewModel.createItem(title: "First", description: "")
        viewModel.createItem(title: "Second", description: "")

        // Set sort to order number ascending
        viewModel.updateSortOption(.orderNumber)
        viewModel.updateSortDirection(.ascending)

        let sortedItems = viewModel.filteredItems
        XCTAssertEqual(sortedItems.count, 3)
        XCTAssertTrue(sortedItems[0].orderNumber < sortedItems[1].orderNumber)
        XCTAssertTrue(sortedItems[1].orderNumber < sortedItems[2].orderNumber)
    }

    func testItemSortingByOrderNumberDescending() throws {
        let dataManager = TestHelpers.createTestDataManager()
        let mainViewModel = TestMainViewModel(dataManager: dataManager)

        try mainViewModel.addList(name: "Test List")
        guard let list = mainViewModel.lists.first else {
            XCTFail("List should exist")
            return
        }

        let viewModel = TestListViewModel(list: list, dataManager: dataManager)

        // Create items
        viewModel.createItem(title: "First", description: "")
        viewModel.createItem(title: "Second", description: "")
        viewModel.createItem(title: "Third", description: "")

        // Set sort to order number descending
        viewModel.updateSortOption(.orderNumber)
        viewModel.updateSortDirection(.descending)

        let sortedItems = viewModel.filteredItems
        XCTAssertEqual(sortedItems.count, 3)
        XCTAssertTrue(sortedItems[0].orderNumber > sortedItems[1].orderNumber)
        XCTAssertTrue(sortedItems[1].orderNumber > sortedItems[2].orderNumber)
    }

    func testItemSortingByTitleAscending() throws {
        let dataManager = TestHelpers.createTestDataManager()
        let mainViewModel = TestMainViewModel(dataManager: dataManager)

        try mainViewModel.addList(name: "Test List")
        guard let list = mainViewModel.lists.first else {
            XCTFail("List should exist")
            return
        }

        let viewModel = TestListViewModel(list: list, dataManager: dataManager)

        // Create items with titles in non-alphabetical order
        viewModel.createItem(title: "Zebra", description: "")
        viewModel.createItem(title: "Apple", description: "")
        viewModel.createItem(title: "Banana", description: "")

        // Set sort to title ascending
        viewModel.updateSortOption(.title)
        viewModel.updateSortDirection(.ascending)

        let sortedItems = viewModel.filteredItems
        XCTAssertEqual(sortedItems.count, 3)
        XCTAssertEqual(sortedItems[0].title, "Apple")
        XCTAssertEqual(sortedItems[1].title, "Banana")
        XCTAssertEqual(sortedItems[2].title, "Zebra")
    }

    func testItemSortingByTitleDescending() throws {
        let dataManager = TestHelpers.createTestDataManager()
        let mainViewModel = TestMainViewModel(dataManager: dataManager)

        try mainViewModel.addList(name: "Test List")
        guard let list = mainViewModel.lists.first else {
            XCTFail("List should exist")
            return
        }

        let viewModel = TestListViewModel(list: list, dataManager: dataManager)

        // Create items with titles in non-alphabetical order
        viewModel.createItem(title: "Zebra", description: "")
        viewModel.createItem(title: "Apple", description: "")
        viewModel.createItem(title: "Banana", description: "")

        // Set sort to title descending
        viewModel.updateSortOption(.title)
        viewModel.updateSortDirection(.descending)

        let sortedItems = viewModel.filteredItems
        XCTAssertEqual(sortedItems.count, 3)
        XCTAssertEqual(sortedItems[0].title, "Zebra")
        XCTAssertEqual(sortedItems[1].title, "Banana")
        XCTAssertEqual(sortedItems[2].title, "Apple")
    }

    func testItemSortingByCreatedDateAscending() throws {
        let dataManager = TestHelpers.createTestDataManager()
        let mainViewModel = TestMainViewModel(dataManager: dataManager)

        try mainViewModel.addList(name: "Test List")
        guard let list = mainViewModel.lists.first else {
            XCTFail("List should exist")
            return
        }

        let viewModel = TestListViewModel(list: list, dataManager: dataManager)

        // Create items with small delays to ensure different timestamps
        viewModel.createItem(title: "First", description: "")
        Thread.sleep(forTimeInterval: 0.01)
        viewModel.createItem(title: "Second", description: "")
        Thread.sleep(forTimeInterval: 0.01)
        viewModel.createItem(title: "Third", description: "")

        // Set sort to created date ascending
        viewModel.updateSortOption(.createdAt)
        viewModel.updateSortDirection(.ascending)

        let sortedItems = viewModel.filteredItems
        XCTAssertEqual(sortedItems.count, 3)
        XCTAssertTrue(sortedItems[0].createdAt <= sortedItems[1].createdAt)
        XCTAssertTrue(sortedItems[1].createdAt <= sortedItems[2].createdAt)
    }

    func testItemSortingByQuantityAscending() throws {
        let dataManager = TestHelpers.createTestDataManager()
        let mainViewModel = TestMainViewModel(dataManager: dataManager)

        try mainViewModel.addList(name: "Test List")
        guard let list = mainViewModel.lists.first else {
            XCTFail("List should exist")
            return
        }

        let viewModel = TestListViewModel(list: list, dataManager: dataManager)

        // Create items with different quantities
        viewModel.createItem(title: "Large", description: "", quantity: 10)
        viewModel.createItem(title: "Small", description: "", quantity: 1)
        viewModel.createItem(title: "Medium", description: "", quantity: 5)

        // Set sort to quantity ascending
        viewModel.updateSortOption(.quantity)
        viewModel.updateSortDirection(.ascending)

        let sortedItems = viewModel.filteredItems
        XCTAssertEqual(sortedItems.count, 3)
        XCTAssertEqual(sortedItems[0].quantity, 1)
        XCTAssertEqual(sortedItems[1].quantity, 5)
        XCTAssertEqual(sortedItems[2].quantity, 10)
    }

    func testItemSortingByQuantityDescending() throws {
        let dataManager = TestHelpers.createTestDataManager()
        let mainViewModel = TestMainViewModel(dataManager: dataManager)

        try mainViewModel.addList(name: "Test List")
        guard let list = mainViewModel.lists.first else {
            XCTFail("List should exist")
            return
        }

        let viewModel = TestListViewModel(list: list, dataManager: dataManager)

        // Create items with different quantities
        viewModel.createItem(title: "Large", description: "", quantity: 10)
        viewModel.createItem(title: "Small", description: "", quantity: 1)
        viewModel.createItem(title: "Medium", description: "", quantity: 5)

        // Set sort to quantity descending
        viewModel.updateSortOption(.quantity)
        viewModel.updateSortDirection(.descending)

        let sortedItems = viewModel.filteredItems
        XCTAssertEqual(sortedItems.count, 3)
        XCTAssertEqual(sortedItems[0].quantity, 10)
        XCTAssertEqual(sortedItems[1].quantity, 5)
        XCTAssertEqual(sortedItems[2].quantity, 1)
    }

    func testSortPreferencesPersistence() throws {
        let dataManager = TestHelpers.createTestDataManager()
        let mainViewModel = TestMainViewModel(dataManager: dataManager)

        try mainViewModel.addList(name: "Test List")
        guard let list = mainViewModel.lists.first else {
            XCTFail("List should exist")
            return
        }

        let viewModel = TestListViewModel(list: list, dataManager: dataManager)

        // Change sort preferences
        viewModel.updateSortOption(.title)
        viewModel.updateSortDirection(.descending)

        // Verify preferences are saved
        XCTAssertEqual(viewModel.currentSortOption, .title)
        XCTAssertEqual(viewModel.currentSortDirection, .descending)
    }

    func testSortingWithFiltering() throws {
        let dataManager = TestHelpers.createTestDataManager()
        let mainViewModel = TestMainViewModel(dataManager: dataManager)

        try mainViewModel.addList(name: "Test List")
        guard let list = mainViewModel.lists.first else {
            XCTFail("List should exist")
            return
        }

        let viewModel = TestListViewModel(list: list, dataManager: dataManager)

        // Create items
        viewModel.createItem(title: "Zebra", description: "")
        viewModel.createItem(title: "Apple", description: "")
        viewModel.createItem(title: "Banana", description: "")

        // Cross out one item
        guard let itemToCross = viewModel.items.first(where: { $0.title == "Banana" }) else {
            XCTFail("Should find item to cross out")
            return
        }
        viewModel.toggleItemCrossedOut(itemToCross)

        // Set filter to active only and sort by title
        viewModel.updateFilterOption(.active)
        viewModel.updateSortOption(.title)
        viewModel.updateSortDirection(.ascending)

        let filteredAndSortedItems = viewModel.filteredItems
        XCTAssertEqual(filteredAndSortedItems.count, 2)
        XCTAssertEqual(filteredAndSortedItems[0].title, "Apple")
        XCTAssertEqual(filteredAndSortedItems[1].title, "Zebra")
    }

    // MARK: - Test Helper Validation

    func testTestHelpersIsolation() throws {
        let viewModel1 = TestHelpers.createTestMainViewModel()
        let viewModel2 = TestHelpers.createTestMainViewModel()

        try viewModel1.addList(name: "List 1")
        XCTAssertEqual(viewModel1.lists.count, 1)
        XCTAssertEqual(viewModel2.lists.count, 0)
    }

    func testInMemoryCoreDataStack() throws {
        let stack1 = TestHelpers.createInMemoryCoreDataStack()
        let stack2 = TestHelpers.createInMemoryCoreDataStack()

        XCTAssertTrue(stack1 !== stack2)

        let description1 = stack1.persistentStoreDescriptions.first
        let description2 = stack2.persistentStoreDescriptions.first

        XCTAssertEqual(description1?.type, NSInMemoryStoreType)
        XCTAssertEqual(description2?.type, NSInMemoryStoreType)
    }
}
