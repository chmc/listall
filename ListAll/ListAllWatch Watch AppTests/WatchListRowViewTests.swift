import XCTest
import SwiftUI
@testable import ListAllWatch_Watch_App

class WatchListRowViewTests: XCTestCase {

    // MARK: - Helper

    private func makeList(name: String, activeCount: Int, completedCount: Int) -> ListAllWatch_Watch_App.List {
        var list = ListAllWatch_Watch_App.List(name: name)
        for i in 0..<activeCount {
            var item = Item(title: "Active \(i)", listId: list.id)
            item.isCrossedOut = false
            list.items.append(item)
        }
        for i in 0..<completedCount {
            var item = Item(title: "Done \(i)", listId: list.id)
            item.isCrossedOut = true
            list.items.append(item)
        }
        return list
    }

    // MARK: - Count Format Tests

    func testCountFormatShowsSlashFormat() {
        // 4 active, 2 completed = "4/6"
        let list = makeList(name: "Groceries", activeCount: 4, completedCount: 2)
        let view = WatchListRowView(list: list)
        XCTAssertEqual(view.activeCountText, "4/6")
    }

    func testCountFormatAllActive() {
        // All active, no completed = "3/3"
        let list = makeList(name: "Tasks", activeCount: 3, completedCount: 0)
        let view = WatchListRowView(list: list)
        XCTAssertEqual(view.activeCountText, "3/3")
    }

    func testCountFormatNoItems() {
        let list = makeList(name: "Empty", activeCount: 0, completedCount: 0)
        let view = WatchListRowView(list: list)
        XCTAssertEqual(view.activeCountText, "0/0")
    }

    func testCountFormatAllCompleted() {
        let list = makeList(name: "Done", activeCount: 0, completedCount: 5)
        let view = WatchListRowView(list: list)
        XCTAssertEqual(view.activeCountText, "0/5")
    }

    // MARK: - Progress Ratio Tests

    func testProgressRatioPartialCompletion() {
        let list = makeList(name: "Groceries", activeCount: 4, completedCount: 2)
        let view = WatchListRowView(list: list)
        // 2 completed out of 6 total = ~0.333
        XCTAssertEqual(view.progressRatio, 2.0 / 6.0, accuracy: 0.001)
    }

    func testProgressRatioAllActive() {
        let list = makeList(name: "Tasks", activeCount: 3, completedCount: 0)
        let view = WatchListRowView(list: list)
        XCTAssertEqual(view.progressRatio, 0.0, accuracy: 0.001)
    }

    func testProgressRatioAllCompleted() {
        let list = makeList(name: "Done", activeCount: 0, completedCount: 5)
        let view = WatchListRowView(list: list)
        XCTAssertEqual(view.progressRatio, 1.0, accuracy: 0.001)
    }

    func testProgressRatioEmpty() {
        let list = makeList(name: "Empty", activeCount: 0, completedCount: 0)
        let view = WatchListRowView(list: list)
        XCTAssertEqual(view.progressRatio, 0.0, accuracy: 0.001)
    }

    // MARK: - View Initialization

    func testViewInitializesWithList() {
        let list = makeList(name: "Test", activeCount: 2, completedCount: 1)
        let view = WatchListRowView(list: list)
        XCTAssertNotNil(view)
    }
}
