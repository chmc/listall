import XCTest
import Foundation
import CoreData
@testable import ListAll

class ListMultiSelectTests: XCTestCase {

    // MARK: - Multi-Select Tests

    func testEnterSelectionMode() throws {
        let viewModel = TestHelpers.createTestMainViewModel()

        XCTAssertFalse(viewModel.isInSelectionMode)
        XCTAssertTrue(viewModel.selectedLists.isEmpty)

        viewModel.enterSelectionMode()

        XCTAssertTrue(viewModel.isInSelectionMode)
        XCTAssertTrue(viewModel.selectedLists.isEmpty)
    }

    func testExitSelectionMode() throws {
        let viewModel = TestHelpers.createTestMainViewModel()
        try viewModel.addList(name: "List 1")

        // Enter selection mode and select a list
        viewModel.enterSelectionMode()
        if let listId = viewModel.lists.first?.id {
            viewModel.toggleSelection(for: listId)
        }

        XCTAssertTrue(viewModel.isInSelectionMode)
        XCTAssertFalse(viewModel.selectedLists.isEmpty)

        viewModel.exitSelectionMode()

        XCTAssertFalse(viewModel.isInSelectionMode)
        XCTAssertTrue(viewModel.selectedLists.isEmpty)
    }

    func testToggleSelection() throws {
        let viewModel = TestHelpers.createTestMainViewModel()
        try viewModel.addList(name: "List 1")

        guard let listId = viewModel.lists.first?.id else {
            XCTFail("List should exist")
            return
        }

        viewModel.enterSelectionMode()

        // Select the list
        viewModel.toggleSelection(for: listId)
        XCTAssertTrue(viewModel.selectedLists.contains(listId))

        // Deselect the list
        viewModel.toggleSelection(for: listId)
        XCTAssertFalse(viewModel.selectedLists.contains(listId))
    }

    func testSelectAll() throws {
        let viewModel = TestHelpers.createTestMainViewModel()
        try viewModel.addList(name: "List 1")
        try viewModel.addList(name: "List 2")
        try viewModel.addList(name: "List 3")

        viewModel.enterSelectionMode()
        viewModel.selectAll()

        XCTAssertEqual(viewModel.selectedLists.count, 3)
        for list in viewModel.lists {
            XCTAssertTrue(viewModel.selectedLists.contains(list.id))
        }
    }

    func testDeselectAll() throws {
        let viewModel = TestHelpers.createTestMainViewModel()
        try viewModel.addList(name: "List 1")
        try viewModel.addList(name: "List 2")

        viewModel.enterSelectionMode()
        viewModel.selectAll()

        XCTAssertEqual(viewModel.selectedLists.count, 2)

        viewModel.deselectAll()

        XCTAssertTrue(viewModel.selectedLists.isEmpty)
    }

    func testDeleteSelectedLists() throws {
        let viewModel = TestHelpers.createTestMainViewModel()
        try viewModel.addList(name: "List 1")
        try viewModel.addList(name: "List 2")
        try viewModel.addList(name: "List 3")

        XCTAssertEqual(viewModel.lists.count, 3)

        viewModel.enterSelectionMode()

        // Select first and third lists
        let firstListId = viewModel.lists[0].id
        let thirdListId = viewModel.lists[2].id
        viewModel.toggleSelection(for: firstListId)
        viewModel.toggleSelection(for: thirdListId)

        XCTAssertEqual(viewModel.selectedLists.count, 2)

        // Delete selected lists
        viewModel.deleteSelectedLists()

        XCTAssertEqual(viewModel.lists.count, 1)
        XCTAssertEqual(viewModel.lists[0].name, "List 2")
        XCTAssertTrue(viewModel.selectedLists.isEmpty)
    }

    func testDeleteAllLists() throws {
        let viewModel = TestHelpers.createTestMainViewModel()
        try viewModel.addList(name: "List 1")
        try viewModel.addList(name: "List 2")
        try viewModel.addList(name: "List 3")

        XCTAssertEqual(viewModel.lists.count, 3)

        viewModel.enterSelectionMode()
        viewModel.selectAll()
        viewModel.deleteSelectedLists()

        XCTAssertTrue(viewModel.lists.isEmpty)
        XCTAssertTrue(viewModel.selectedLists.isEmpty)
    }

    func testSelectionModeWithEmptyLists() throws {
        let viewModel = TestHelpers.createTestMainViewModel()

        viewModel.enterSelectionMode()
        viewModel.selectAll()

        XCTAssertTrue(viewModel.selectedLists.isEmpty)
        XCTAssertTrue(viewModel.lists.isEmpty)
    }

    func testMultiSelectPersistence() throws {
        let viewModel = TestHelpers.createTestMainViewModel()
        try viewModel.addList(name: "List 1")
        try viewModel.addList(name: "List 2")
        try viewModel.addList(name: "List 3")

        viewModel.enterSelectionMode()

        let firstListId = viewModel.lists[0].id
        let secondListId = viewModel.lists[1].id

        viewModel.toggleSelection(for: firstListId)
        viewModel.toggleSelection(for: secondListId)

        // Verify selections persist
        XCTAssertEqual(viewModel.selectedLists.count, 2)
        XCTAssertTrue(viewModel.selectedLists.contains(firstListId))
        XCTAssertTrue(viewModel.selectedLists.contains(secondListId))

        // Add another list - selections should remain
        try viewModel.addList(name: "List 4")

        XCTAssertEqual(viewModel.selectedLists.count, 2)
        XCTAssertTrue(viewModel.selectedLists.contains(firstListId))
        XCTAssertTrue(viewModel.selectedLists.contains(secondListId))
    }

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

    // MARK: - Move and Copy Items Tests

    func testMoveItemsToAnotherList() throws {
        let dataManager = TestHelpers.createTestDataManager()
        let mainViewModel = TestMainViewModel(dataManager: dataManager)

        // Create two lists
        try mainViewModel.addList(name: "Source List")
        try mainViewModel.addList(name: "Destination List")

        guard let sourceList = mainViewModel.lists.first(where: { $0.name == "Source List" }),
              let destList = mainViewModel.lists.first(where: { $0.name == "Destination List" }) else {
            XCTFail("Lists should exist")
            return
        }

        let sourceViewModel = TestListViewModel(list: sourceList, dataManager: dataManager)
        let destViewModel = TestListViewModel(list: destList, dataManager: dataManager)

        // Add items to source list
        sourceViewModel.createItem(title: "Item 1")
        sourceViewModel.createItem(title: "Item 2")
        sourceViewModel.createItem(title: "Item 3")

        XCTAssertEqual(sourceViewModel.items.count, 3)
        XCTAssertEqual(destViewModel.items.count, 0)

        // Select first and second items to move
        sourceViewModel.enterSelectionMode()
        sourceViewModel.toggleSelection(for: sourceViewModel.items[0].id)
        sourceViewModel.toggleSelection(for: sourceViewModel.items[1].id)

        // Move selected items
        sourceViewModel.moveSelectedItems(to: destList)

        // Verify items moved
        XCTAssertEqual(sourceViewModel.items.count, 1, "Source list should have 1 item")
        XCTAssertEqual(sourceViewModel.items[0].title, "Item 3", "Only Item 3 should remain")

        destViewModel.loadItems()
        XCTAssertEqual(destViewModel.items.count, 2, "Destination list should have 2 items")

        let destTitles = destViewModel.items.map { $0.title }.sorted()
        XCTAssertEqual(destTitles, ["Item 1", "Item 2"])

        // Verify selection cleared
        XCTAssertTrue(sourceViewModel.selectedItems.isEmpty)
    }

    func testCopyItemsToAnotherList() throws {
        let dataManager = TestHelpers.createTestDataManager()
        let mainViewModel = TestMainViewModel(dataManager: dataManager)

        // Create two lists
        try mainViewModel.addList(name: "Source List")
        try mainViewModel.addList(name: "Destination List")

        guard let sourceList = mainViewModel.lists.first(where: { $0.name == "Source List" }),
              let destList = mainViewModel.lists.first(where: { $0.name == "Destination List" }) else {
            XCTFail("Lists should exist")
            return
        }

        let sourceViewModel = TestListViewModel(list: sourceList, dataManager: dataManager)
        let destViewModel = TestListViewModel(list: destList, dataManager: dataManager)

        // Add items to source list
        sourceViewModel.createItem(title: "Item 1")
        sourceViewModel.createItem(title: "Item 2")
        sourceViewModel.createItem(title: "Item 3")

        XCTAssertEqual(sourceViewModel.items.count, 3)
        XCTAssertEqual(destViewModel.items.count, 0)

        // Select first and second items to copy
        sourceViewModel.enterSelectionMode()
        sourceViewModel.toggleSelection(for: sourceViewModel.items[0].id)
        sourceViewModel.toggleSelection(for: sourceViewModel.items[1].id)

        // Copy selected items
        sourceViewModel.copySelectedItems(to: destList)

        // Verify items copied (source unchanged, destination has copies)
        XCTAssertEqual(sourceViewModel.items.count, 3, "Source list should still have 3 items")

        destViewModel.loadItems()
        XCTAssertEqual(destViewModel.items.count, 2, "Destination list should have 2 items")

        let destTitles = destViewModel.items.map { $0.title }.sorted()
        XCTAssertEqual(destTitles, ["Item 1", "Item 2"])

        // Verify copied items have different IDs
        let sourceIds = Set(sourceViewModel.items.map { $0.id })
        let destIds = Set(destViewModel.items.map { $0.id })
        XCTAssertTrue(sourceIds.isDisjoint(with: destIds), "Copied items should have different IDs")

        // Verify selection cleared
        XCTAssertTrue(sourceViewModel.selectedItems.isEmpty)
    }

    func testMoveAllItemsToAnotherList() throws {
        let dataManager = TestHelpers.createTestDataManager()
        let mainViewModel = TestMainViewModel(dataManager: dataManager)

        // Create two lists
        try mainViewModel.addList(name: "Source List")
        try mainViewModel.addList(name: "Destination List")

        guard let sourceList = mainViewModel.lists.first(where: { $0.name == "Source List" }),
              let destList = mainViewModel.lists.first(where: { $0.name == "Destination List" }) else {
            XCTFail("Lists should exist")
            return
        }

        let sourceViewModel = TestListViewModel(list: sourceList, dataManager: dataManager)
        let destViewModel = TestListViewModel(list: destList, dataManager: dataManager)

        // Add items to source list
        sourceViewModel.createItem(title: "Item 1")
        sourceViewModel.createItem(title: "Item 2")

        XCTAssertEqual(sourceViewModel.items.count, 2)

        // Select all items
        sourceViewModel.enterSelectionMode()
        sourceViewModel.selectAll()

        // Move all items
        sourceViewModel.moveSelectedItems(to: destList)

        // Verify all items moved
        XCTAssertEqual(sourceViewModel.items.count, 0, "Source list should be empty")

        destViewModel.loadItems()
        XCTAssertEqual(destViewModel.items.count, 2, "Destination list should have 2 items")
    }

    func testCopyItemsPreservesProperties() throws {
        let dataManager = TestHelpers.createTestDataManager()
        let mainViewModel = TestMainViewModel(dataManager: dataManager)

        // Create two lists
        try mainViewModel.addList(name: "Source List")
        try mainViewModel.addList(name: "Destination List")

        guard let sourceList = mainViewModel.lists.first(where: { $0.name == "Source List" }),
              let destList = mainViewModel.lists.first(where: { $0.name == "Destination List" }) else {
            XCTFail("Lists should exist")
            return
        }

        let sourceViewModel = TestListViewModel(list: sourceList, dataManager: dataManager)
        let destViewModel = TestListViewModel(list: destList, dataManager: dataManager)

        // Create item with properties
        sourceViewModel.createItem(title: "Complex Item", description: "Test description", quantity: 5)

        guard let originalItem = sourceViewModel.items.first else {
            XCTFail("Item should exist")
            return
        }

        // Toggle crossed out status
        sourceViewModel.toggleItemCrossedOut(originalItem)

        // Select and copy
        sourceViewModel.enterSelectionMode()
        sourceViewModel.toggleSelection(for: sourceViewModel.items[0].id)
        sourceViewModel.copySelectedItems(to: destList)

        // Verify properties preserved
        destViewModel.loadItems()
        XCTAssertEqual(destViewModel.items.count, 1)

        let copiedItem = destViewModel.items[0]
        XCTAssertEqual(copiedItem.title, "Complex Item")
        XCTAssertEqual(copiedItem.itemDescription, "Test description")
        XCTAssertEqual(copiedItem.quantity, 5)
        XCTAssertEqual(copiedItem.isCrossedOut, true, "Crossed out status should be preserved")
    }

    func testMoveItemsUpdatesOrderNumbers() throws {
        let dataManager = TestHelpers.createTestDataManager()
        let mainViewModel = TestMainViewModel(dataManager: dataManager)

        // Create two lists
        try mainViewModel.addList(name: "Source List")
        try mainViewModel.addList(name: "Destination List")

        guard let sourceList = mainViewModel.lists.first(where: { $0.name == "Source List" }),
              let destList = mainViewModel.lists.first(where: { $0.name == "Destination List" }) else {
            XCTFail("Lists should exist")
            return
        }

        let destViewModel = TestListViewModel(list: destList, dataManager: dataManager)

        // Add existing items to destination list
        destViewModel.createItem(title: "Existing 1")
        destViewModel.createItem(title: "Existing 2")

        let sourceViewModel = TestListViewModel(list: sourceList, dataManager: dataManager)

        // Add items to source list
        sourceViewModel.createItem(title: "New Item")

        // Move item to destination
        sourceViewModel.enterSelectionMode()
        sourceViewModel.toggleSelection(for: sourceViewModel.items[0].id)
        sourceViewModel.moveSelectedItems(to: destList)

        // Verify order numbers
        destViewModel.loadItems()
        XCTAssertEqual(destViewModel.items.count, 3)

        let movedItem = destViewModel.items.first(where: { $0.title == "New Item" })
        XCTAssertNotNil(movedItem)
        XCTAssertGreaterThan(movedItem!.orderNumber, destViewModel.items.filter { $0.title != "New Item" }.map { $0.orderNumber }.max() ?? -1)
    }

    func testCopyItemsWithImages() throws {
        let dataManager = TestHelpers.createTestDataManager()
        let mainViewModel = TestMainViewModel(dataManager: dataManager)

        // Create two lists
        try mainViewModel.addList(name: "Source List")
        try mainViewModel.addList(name: "Destination List")

        guard let sourceList = mainViewModel.lists.first(where: { $0.name == "Source List" }),
              let destList = mainViewModel.lists.first(where: { $0.name == "Destination List" }) else {
            XCTFail("Lists should exist")
            return
        }

        let sourceViewModel = TestListViewModel(list: sourceList, dataManager: dataManager)
        let destViewModel = TestListViewModel(list: destList, dataManager: dataManager)

        // Create item
        sourceViewModel.createItem(title: "Item with Image")

        guard var item = sourceViewModel.items.first else {
            XCTFail("Item should exist")
            return
        }

        // Add image to item
        let testImageData = Data(count: 100)
        let image = ItemImage(imageData: testImageData, itemId: item.id)
        item.images.append(image)
        sourceViewModel.updateItem(item, title: item.title, description: item.itemDescription ?? "", quantity: item.quantity)

        // Copy item with image
        sourceViewModel.enterSelectionMode()
        sourceViewModel.toggleSelection(for: item.id)
        sourceViewModel.copySelectedItems(to: destList)

        // Verify image copied
        destViewModel.loadItems()
        XCTAssertEqual(destViewModel.items.count, 1)

        let copiedItem = destViewModel.items[0]
        XCTAssertEqual(copiedItem.images.count, 1, "Image should be copied")
        XCTAssertNotEqual(copiedItem.images[0].id, image.id, "Copied image should have different ID")
        XCTAssertEqual(copiedItem.images[0].itemId, copiedItem.id, "Image should reference copied item")
    }

    func testMoveItemsWithFilteredView() throws {
        let dataManager = TestHelpers.createTestDataManager()
        let mainViewModel = TestMainViewModel(dataManager: dataManager)

        // Create two lists
        try mainViewModel.addList(name: "Source List")
        try mainViewModel.addList(name: "Destination List")

        guard let sourceList = mainViewModel.lists.first(where: { $0.name == "Source List" }),
              let destList = mainViewModel.lists.first(where: { $0.name == "Destination List" }) else {
            XCTFail("Lists should exist")
            return
        }

        let sourceViewModel = TestListViewModel(list: sourceList, dataManager: dataManager)
        let destViewModel = TestListViewModel(list: destList, dataManager: dataManager)

        // Add items
        sourceViewModel.createItem(title: "Active Item")
        sourceViewModel.createItem(title: "Completed Item")

        // Complete second item
        if let item = sourceViewModel.items.first(where: { $0.title == "Completed Item" }) {
            sourceViewModel.toggleItemCrossedOut(item)
        }

        // Filter to show only active items
        sourceViewModel.updateFilterOption(.active)

        // Select visible (active) items
        sourceViewModel.enterSelectionMode()
        sourceViewModel.selectAll()

        XCTAssertEqual(sourceViewModel.selectedItems.count, 1, "Only active item should be selected")

        // Move selected
        sourceViewModel.moveSelectedItems(to: destList)

        // Verify only active item moved
        XCTAssertEqual(sourceViewModel.items.count, 1, "Completed item should remain")
        XCTAssertEqual(sourceViewModel.items[0].title, "Completed Item")

        destViewModel.loadItems()
        XCTAssertEqual(destViewModel.items.count, 1)
        XCTAssertEqual(destViewModel.items[0].title, "Active Item")
    }
}
