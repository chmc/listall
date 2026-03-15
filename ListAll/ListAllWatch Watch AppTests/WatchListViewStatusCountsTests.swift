import XCTest
import SwiftUI
@testable import ListAllWatch_Watch_App

class WatchListViewStatusCountsTests: XCTestCase {

    // MARK: - Status Label Localization Tests

    func testActiveLocalizationKeyResolves() {
        let label = watchLocalizedString("watch_status_active", comment: "")
        XCTAssertFalse(label.isEmpty, "active localization key should resolve")
        // In English, should resolve to "active"
        XCTAssertEqual(label, "active")
    }

    func testDoneLocalizationKeyResolves() {
        let label = watchLocalizedString("watch_status_done", comment: "")
        XCTAssertFalse(label.isEmpty, "done localization key should resolve")
        // In English, should resolve to "done"
        XCTAssertEqual(label, "done")
    }

    func testTotalLocalizationKeyResolves() {
        let label = String.localizedStringWithFormat(
            watchLocalizedString("%lld total", comment: ""),
            Int64(6)
        )
        XCTAssertTrue(label.contains("6"), "total format should include the count")
        XCTAssertTrue(label.contains("total"), "total format should include 'total' word")
    }
}
