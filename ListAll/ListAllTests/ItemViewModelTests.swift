import XCTest
import Foundation
import CoreData
@testable import ListAll

class ItemViewModelTests: XCTestCase {

    // MARK: - ItemViewModel Tests

    func testItemViewModelInitialization() throws {
        let item = Item(title: "Test Item")
        let viewModel = TestHelpers.createTestItemViewModel(with: item)

        XCTAssertEqual(viewModel.item.id, item.id)
        XCTAssertEqual(viewModel.item.title, item.title)
    }

    func testItemViewModelToggleCrossedOut() throws {
        let item = Item(title: "Test Item")
        let viewModel = TestHelpers.createTestItemViewModel(with: item)
        let originalState = item.isCrossedOut

        viewModel.toggleCrossedOut()
        XCTAssertEqual(viewModel.item.isCrossedOut, !originalState)

        viewModel.toggleCrossedOut()
        XCTAssertEqual(viewModel.item.isCrossedOut, originalState)
    }

    func testUpdateItemSetsDescriptionToNilWhenEmpty() throws {
        var item = Item(title: "Test Item")
        item.itemDescription = "Original description"
        let viewModel = TestHelpers.createTestItemViewModel(with: item)

        viewModel.updateItem(title: "Test Item", description: "", quantity: 1)

        XCTAssertNil(viewModel.item.itemDescription, "Empty description should be stored as nil")
    }

    func testUpdateItemSetsDescriptionWhenNotEmpty() throws {
        let item = Item(title: "Test Item")
        let viewModel = TestHelpers.createTestItemViewModel(with: item)

        viewModel.updateItem(title: "Test Item", description: "New description", quantity: 1)

        XCTAssertEqual(viewModel.item.itemDescription, "New description")
    }

    func testUpdateItemUpdatesModifiedDate() throws {
        let item = Item(title: "Test Item")
        let viewModel = TestHelpers.createTestItemViewModel(with: item)
        let originalDate = viewModel.item.modifiedAt

        viewModel.updateItem(title: "Updated Title", description: "", quantity: 2)

        XCTAssertGreaterThan(viewModel.item.modifiedAt, originalDate, "modifiedAt should advance after updateItem")
    }
}
