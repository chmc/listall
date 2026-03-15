import XCTest
import Foundation
import CoreData
@testable import ListAll

class ItemMoveCopyTests: XCTestCase {

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
