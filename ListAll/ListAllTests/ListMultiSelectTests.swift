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
}
