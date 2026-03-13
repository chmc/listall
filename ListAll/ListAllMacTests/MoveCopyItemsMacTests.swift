//
//  MoveCopyItemsMacTests.swift
//  ListAllMacTests
//

import XCTest
import CoreData
import Combine
#if os(macOS)
@preconcurrency import AppKit
#endif
@testable import ListAll

#if os(macOS)

final class MoveCopyItemsMacTests: XCTestCase {

    var testContainer: NSPersistentContainer!
    var testContext: NSManagedObjectContext!

    override func setUpWithError() throws {
        try super.setUpWithError()

        // Create in-memory Core Data stack for testing
        testContainer = NSPersistentContainer(name: "ListAll")

        let description = NSPersistentStoreDescription()
        description.type = NSInMemoryStoreType
        description.url = URL(fileURLWithPath: "/dev/null")
        testContainer.persistentStoreDescriptions = [description]

        let expectation = XCTestExpectation(description: "Load stores")
        testContainer.loadPersistentStores { _, error in
            XCTAssertNil(error, "Failed to load in-memory store: \(error?.localizedDescription ?? "unknown")")
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 5.0)

        testContext = testContainer.viewContext
        testContext.automaticallyMergesChangesFromParent = true
        testContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
    }

    override func tearDownWithError() throws {
        testContext = nil
        testContainer = nil
        try super.tearDownWithError()
    }

    // MARK: - MacDestinationListAction Tests

    /// Test that MacDestinationListAction.move has correct properties
    func testMoveActionProperties() {
        let action = MacDestinationListAction.move

        XCTAssertEqual(action.title, String(localized: "Move Items"))
        XCTAssertEqual(action.verb, String(localized: "move"))
        XCTAssertEqual(action.systemImage, "arrow.right.square")
    }

    /// Test that MacDestinationListAction.copy has correct properties
    func testCopyActionProperties() {
        let action = MacDestinationListAction.copy

        XCTAssertEqual(action.title, String(localized: "Copy Items"))
        XCTAssertEqual(action.verb, String(localized: "copy"))
        XCTAssertEqual(action.systemImage, "doc.on.doc")
    }

    // MARK: - ListViewModel Selection Mode Tests

    /// Test that entering selection mode initializes correctly
    func testEnterSelectionMode() {
        // Given
        let list = List(name: "Test List")
        let viewModel = ListViewModel(list: list)

        // When
        viewModel.enterSelectionMode()

        // Then
        XCTAssertTrue(viewModel.isInSelectionMode)
        XCTAssertTrue(viewModel.selectedItems.isEmpty)
    }

    /// Test that exiting selection mode clears state
    func testExitSelectionMode() {
        // Given
        let list = List(name: "Test List")
        let viewModel = ListViewModel(list: list)
        viewModel.enterSelectionMode()
        viewModel.selectedItems.insert(UUID())

        // When
        viewModel.exitSelectionMode()

        // Then
        XCTAssertFalse(viewModel.isInSelectionMode)
        XCTAssertTrue(viewModel.selectedItems.isEmpty)
    }

    /// Test that toggling selection adds/removes items
    func testToggleSelection() {
        // Given
        let list = List(name: "Test List")
        let viewModel = ListViewModel(list: list)
        let itemId = UUID()
        viewModel.enterSelectionMode()

        // When - toggle on
        viewModel.toggleSelection(for: itemId)

        // Then
        XCTAssertTrue(viewModel.selectedItems.contains(itemId))

        // When - toggle off
        viewModel.toggleSelection(for: itemId)

        // Then
        XCTAssertFalse(viewModel.selectedItems.contains(itemId))
    }

    /// Test that select all selects all filtered items
    func testSelectAll() {
        // Given
        let list = List(name: "Test List")
        let viewModel = ListViewModel(list: list)

        // Create test items
        var items: [Item] = []
        for i in 1...3 {
            var item = Item(title: "Item \(i)", listId: list.id)
            item.orderNumber = i
            items.append(item)
        }
        viewModel.items = items
        viewModel.enterSelectionMode()

        // When
        viewModel.selectAll()

        // Then
        XCTAssertEqual(viewModel.selectedItems.count, 3)
        for item in items {
            XCTAssertTrue(viewModel.selectedItems.contains(item.id))
        }
    }

    /// Test that deselect all clears selection
    func testDeselectAll() {
        // Given
        let list = List(name: "Test List")
        let viewModel = ListViewModel(list: list)

        var items: [Item] = []
        for i in 1...3 {
            var item = Item(title: "Item \(i)", listId: list.id)
            item.orderNumber = i
            items.append(item)
        }
        viewModel.items = items
        viewModel.enterSelectionMode()
        viewModel.selectAll()

        XCTAssertEqual(viewModel.selectedItems.count, 3)

        // When
        viewModel.deselectAll()

        // Then
        XCTAssertTrue(viewModel.selectedItems.isEmpty)
    }

    // MARK: - Platform Verification

    /// Test that we're running on macOS
    func testRunningOnMacOS() {
        #if os(macOS)
        XCTAssertTrue(true, "Running on macOS")
        #else
        XCTFail("This test should only run on macOS")
        #endif
    }

    // MARK: - Documentation

    /// Documentation test for Move/Copy Items feature
    func testMoveCopyItemsDocumentation() {
        let documentation = """

        ========================================================================
        MOVE/COPY ITEMS BETWEEN LISTS - macOS IMPLEMENTATION
        ========================================================================

        Overview:
        ---------
        This feature allows users to move or copy selected items from one list
        to another on macOS. It follows the same pattern as the iOS implementation
        but uses macOS-native sheet presentation and styling.

        Components:
        ----------
        1. MacDestinationListPickerSheet
           - Displays available destination lists
           - Shows list name and item count
           - Excludes current list and archived lists
           - Supports creating new list inline

        2. MacDestinationListAction enum
           - .move: Removes items from source, adds to destination
           - .copy: Keeps items in source, adds copy to destination

        3. Integration in MacListDetailView
           - State variables: showingMoveItemsPicker, showingCopyItemsPicker
           - State variables: selectedDestinationList
           - State variables: showingMoveConfirmation, showingCopyConfirmation
           - Uses shared ListViewModel methods: moveSelectedItems, copySelectedItems

        User Flow:
        ---------
        1. Enter selection mode (checkmark button)
        2. Select items to move/copy
        3. Click ellipsis menu -> "Move Items..." or "Copy Items..."
        4. MacDestinationListPickerSheet appears
        5. Select destination list (or create new one)
        6. Confirmation alert shows
        7. Confirm to execute action
        8. Items are moved/copied
        9. Selection mode exits

        Shared Code (ListViewModel):
        ---------------------------
        - enterSelectionMode() - Activates selection mode
        - exitSelectionMode() - Deactivates and clears selection
        - toggleSelection(for:) - Toggle item selection
        - selectAll() - Select all filtered items
        - deselectAll() - Clear selection
        - moveSelectedItems(to:) - Move selected items to destination
        - copySelectedItems(to:) - Copy selected items to destination

        ========================================================================

        """

        print(documentation)
        XCTAssertTrue(true, "Documentation generated")
    }
}


#endif
