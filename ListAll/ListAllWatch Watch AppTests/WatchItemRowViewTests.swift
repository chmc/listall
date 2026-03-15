import XCTest
import SwiftUI
@testable import ListAllWatch_Watch_App

class WatchItemRowViewTests: XCTestCase {

    // MARK: - Helper

    private func makeItem(title: String, isCrossedOut: Bool = false, quantity: Int = 1) -> Item {
        var item = Item(title: title)
        item.isCrossedOut = isCrossedOut
        item.quantity = quantity
        return item
    }

    private func makeView(for item: Item) -> WatchItemRowView {
        WatchItemRowView(item: item, onToggle: {})
    }

    // MARK: - Title Color Tests

    func testActiveItemTitleColorIsPrimary() {
        let item = makeItem(title: "Milk")
        let view = makeView(for: item)
        XCTAssertEqual(view.titleColor, .primary)
    }

    func testCompletedItemTitleColorIsGreen() {
        let item = makeItem(title: "Milk", isCrossedOut: true)
        let view = makeView(for: item)
        XCTAssertEqual(view.titleColor, Color.green)
    }

    // MARK: - Strikethrough Tests

    func testActiveItemHasNoStrikethrough() {
        let item = makeItem(title: "Milk")
        let view = makeView(for: item)
        XCTAssertFalse(view.showStrikethrough)
    }

    func testCompletedItemHasStrikethrough() {
        let item = makeItem(title: "Milk", isCrossedOut: true)
        let view = makeView(for: item)
        XCTAssertTrue(view.showStrikethrough)
    }

    // MARK: - Quantity Display Tests

    func testQuantityHiddenWhenOne() {
        let item = makeItem(title: "Milk", quantity: 1)
        let view = makeView(for: item)
        XCTAssertFalse(view.showQuantity)
    }

    func testQuantityShownWhenGreaterThanOne() {
        let item = makeItem(title: "Apples", quantity: 5)
        let view = makeView(for: item)
        XCTAssertTrue(view.showQuantity)
    }

    func testQuantityTextFormat() {
        let item = makeItem(title: "Apples", quantity: 6)
        let view = makeView(for: item)
        XCTAssertEqual(view.quantityText, "×6")
    }

    // MARK: - Opacity Tests

    func testActiveItemFullOpacity() {
        let item = makeItem(title: "Milk")
        let view = makeView(for: item)
        XCTAssertEqual(view.rowOpacity, 1.0)
    }

    func testCompletedItemReducedOpacity() {
        let item = makeItem(title: "Milk", isCrossedOut: true)
        let view = makeView(for: item)
        XCTAssertEqual(view.rowOpacity, 0.6)
    }

    // MARK: - View Initialization

    func testViewInitializesWithItem() {
        let item = makeItem(title: "Test")
        let view = makeView(for: item)
        XCTAssertNotNil(view)
    }
}
