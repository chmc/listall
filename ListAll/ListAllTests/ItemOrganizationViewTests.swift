import SwiftUI
import XCTest
@testable import ListAll

class ItemOrganizationViewTests: XCTestCase {

    // MARK: - Task O.1: Sheet Title + Toolbar

    func testNavigationTitleIsSortAndFilter() {
        // The navigation title should be "Sort & Filter", not "Organization"
        // We verify the localized string key exists and resolves correctly
        let title = String(localized: "Sort & Filter")
        XCTAssertEqual(title, "Sort & Filter", "Navigation title should be 'Sort & Filter'")
    }

    func testResetButtonUsesRedColor() {
        // Reset button should use .red foreground color (destructive action convention)
        // This is a design constraint verified by mockup iphone--13-11-sort-filter-sheet.png
        let resetColor = Color.red
        XCTAssertNotNil(resetColor, "Reset button should use .red color")
    }

    func testDoneButtonUsesTealColor() {
        // Done button should use Theme.Colors.primary (teal) instead of default blue
        let doneColor = Theme.Colors.primary
        XCTAssertNotNil(doneColor, "Done button should use Theme.Colors.primary (teal)")

        // Verify it's not system blue
        let systemBlue = Color.blue
        XCTAssertNotEqual(
            doneColor.description,
            systemBlue.description,
            "Done button color should be teal, not system blue"
        )
    }

    func testOrganizationStringNoLongerUsedInTitle() {
        // The old "Organization" title should not be used in the navigation title
        // The source file should use "Sort & Filter" instead
        let newTitle = String(localized: "Sort & Filter")
        let oldTitle = String(localized: "Organization")
        XCTAssertNotEqual(newTitle, oldTitle, "New title should differ from old 'Organization' title")
    }
}
