import XCTest
import Foundation
import CoreData
@testable import ListAll

class MainViewModelTests: XCTestCase {

    // MARK: - MainViewModel Tests

    func testMainViewModelInitialization() throws {
        let viewModel = TestHelpers.createTestMainViewModel()

        XCTAssertTrue(viewModel.lists.isEmpty)
    }

    func testAddListSuccess() throws {
        let viewModel = TestHelpers.createTestMainViewModel()
        let initialCount = viewModel.lists.count

        try viewModel.addList(name: "Test List")
        XCTAssertEqual(viewModel.lists.count, initialCount + 1)
        XCTAssertEqual(viewModel.lists.last?.name, "Test List")
    }

    func testAddListEmptyName() throws {
        let viewModel = TestHelpers.createTestMainViewModel()

        do {
            try viewModel.addList(name: "")
            XCTFail("Should have thrown ValidationError.emptyName")
        } catch ValidationError.emptyName {
            XCTAssertTrue(true)
        } catch {
            XCTFail("Unexpected error type: \(error)")
        }
    }

    func testAddListWhitespaceName() throws {
        let viewModel = TestHelpers.createTestMainViewModel()

        do {
            try viewModel.addList(name: "   ")
            XCTFail("Should have thrown ValidationError.emptyName")
        } catch ValidationError.emptyName {
            XCTAssertTrue(true)
        } catch {
            XCTFail("Unexpected error type: \(error)")
        }
    }

    func testAddListNameTooLong() throws {
        let viewModel = TestHelpers.createTestMainViewModel()
        let longName = String(repeating: "a", count: 101)

        do {
            try viewModel.addList(name: longName)
            XCTFail("Should have thrown ValidationError.nameTooLong")
        } catch ValidationError.nameTooLong {
            XCTAssertTrue(true)
        } catch {
            XCTFail("Unexpected error type: \(error)")
        }
    }

    func testAddListExactly100Characters() throws {
        let viewModel = TestHelpers.createTestMainViewModel()
        let exactName = String(repeating: "a", count: 100)

        try viewModel.addList(name: exactName)
        XCTAssertEqual(viewModel.lists.last?.name, exactName)
    }

    func testUpdateListSuccess() throws {
        let viewModel = TestHelpers.createTestMainViewModel()
        try viewModel.addList(name: "Original Name")

        guard let list = viewModel.lists.first else {
            XCTFail("List should exist")
            return
        }

        try viewModel.updateList(list, name: "Updated Name")
        XCTAssertEqual(viewModel.lists.first?.name, "Updated Name")
    }

    func testUpdateListEmptyName() throws {
        let viewModel = TestHelpers.createTestMainViewModel()
        try viewModel.addList(name: "Test List")

        guard let list = viewModel.lists.first else {
            XCTFail("List should exist")
            return
        }

        do {
            try viewModel.updateList(list, name: "")
            XCTFail("Should have thrown ValidationError.emptyName")
        } catch ValidationError.emptyName {
            XCTAssertTrue(true)
        } catch {
            XCTFail("Unexpected error type: \(error)")
        }
    }

    func testUpdateListNameTooLong() throws {
        let viewModel = TestHelpers.createTestMainViewModel()
        try viewModel.addList(name: "Test List")

        guard let list = viewModel.lists.first else {
            XCTFail("List should exist")
            return
        }

        let longName = String(repeating: "a", count: 101)
        do {
            try viewModel.updateList(list, name: longName)
            XCTFail("Should have thrown ValidationError.nameTooLong")
        } catch ValidationError.nameTooLong {
            XCTAssertTrue(true)
        } catch {
            XCTFail("Unexpected error type: \(error)")
        }
    }

    func testDeleteList() throws {
        let viewModel = TestHelpers.createTestMainViewModel()
        try viewModel.addList(name: "Test List")
        let initialCount = viewModel.lists.count

        guard let list = viewModel.lists.first else {
            XCTFail("List should exist")
            return
        }

        viewModel.deleteList(list)
        XCTAssertEqual(viewModel.lists.count, initialCount - 1)
        XCTAssertFalse(viewModel.lists.contains { $0.id == list.id })
    }

    func testArchiveList() throws {
        let viewModel = TestHelpers.createTestMainViewModel()
        try viewModel.addList(name: "Test List")
        let initialCount = viewModel.lists.count

        guard let list = viewModel.lists.first else {
            XCTFail("List should exist")
            return
        }

        viewModel.archiveList(list)

        // List should be removed from active lists
        XCTAssertEqual(viewModel.lists.count, initialCount - 1)
        XCTAssertFalse(viewModel.lists.contains { $0.id == list.id })
    }

    func testArchiveListShowsNotification() throws {
        let viewModel = TestHelpers.createTestMainViewModel()
        try viewModel.addList(name: "Test List")

        guard let list = viewModel.lists.first else {
            XCTFail("List should exist")
            return
        }

        viewModel.archiveList(list)

        // Notification should be shown
        XCTAssertTrue(viewModel.showArchivedNotification)
        XCTAssertEqual(viewModel.recentlyArchivedList?.id, list.id)
    }

    func testUndoArchive() throws {
        let viewModel = TestHelpers.createTestMainViewModel()
        try viewModel.addList(name: "Test List")

        guard let list = viewModel.lists.first else {
            XCTFail("List should exist")
            return
        }

        let listId = list.id
        viewModel.archiveList(list)

        // List should be archived
        XCTAssertFalse(viewModel.lists.contains { $0.id == listId })
        XCTAssertTrue(viewModel.showArchivedNotification)

        // Undo archive
        viewModel.undoArchive()

        // List should be restored
        XCTAssertTrue(viewModel.lists.contains { $0.id == listId })
        XCTAssertFalse(viewModel.showArchivedNotification)
        XCTAssertNil(viewModel.recentlyArchivedList)
    }

    func testRestoreArchivedList() throws {
        let viewModel = TestHelpers.createTestMainViewModel()
        try viewModel.addList(name: "Test List")

        guard let list = viewModel.lists.first else {
            XCTFail("List should exist")
            return
        }

        let listId = list.id

        // Archive the list
        viewModel.archiveList(list)
        XCTAssertFalse(viewModel.lists.contains { $0.id == listId })

        // Load archived lists
        viewModel.loadArchivedLists()

        guard let archivedList = viewModel.archivedLists.first(where: { $0.id == listId }) else {
            XCTFail("Archived list should exist")
            return
        }

        // Restore the list
        viewModel.restoreList(archivedList)

        // List should be back in active lists
        XCTAssertTrue(viewModel.lists.contains { $0.id == listId })
        XCTAssertFalse(viewModel.archivedLists.contains { $0.id == listId })
    }

    func testPermanentlyDeleteArchivedList() throws {
        let viewModel = TestHelpers.createTestMainViewModel()
        try viewModel.addList(name: "Test List")

        guard let list = viewModel.lists.first else {
            XCTFail("List should exist")
            return
        }

        let listId = list.id

        // Archive the list first
        viewModel.archiveList(list)

        // Load archived lists
        viewModel.loadArchivedLists()

        guard let archivedList = viewModel.archivedLists.first(where: { $0.id == listId }) else {
            XCTFail("Archived list should exist")
            return
        }

        let archivedCount = viewModel.archivedLists.count

        // Permanently delete the archived list
        viewModel.permanentlyDeleteList(archivedList)

        // List should be removed from archived lists
        XCTAssertEqual(viewModel.archivedLists.count, archivedCount - 1)
        XCTAssertFalse(viewModel.archivedLists.contains { $0.id == listId })

        // List should not be in active lists either
        XCTAssertFalse(viewModel.lists.contains { $0.id == listId })
    }

    func testValidationErrorEmptyNameDescription() throws {
        let error = ValidationError.emptyName
        XCTAssertEqual(error.errorDescription, "Please enter a list name")
    }

    func testValidationErrorNameTooLongDescription() throws {
        let error = ValidationError.nameTooLong
        XCTAssertEqual(error.errorDescription, "List name must be 100 characters or less")
    }

    func testSpecialCharactersInListNames() throws {
        let viewModel = TestHelpers.createTestMainViewModel()
        let specialName = "Test 🎉 List & More!"

        try viewModel.addList(name: specialName)
        XCTAssertEqual(viewModel.lists.count, 1)
        XCTAssertEqual(viewModel.lists.first?.name, specialName)
    }
}
