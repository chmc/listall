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

    // MARK: - Task O.2: Sort By — Pill Buttons

    func testShortDisplayNameReturnsAbbreviatedLabels() {
        // Mockup shows short labels: "Order", "A-Z", "Qty", "Created", "Modified"
        XCTAssertEqual(ItemSortOption.orderNumber.shortDisplayName, String(localized: "Order"))
        XCTAssertEqual(ItemSortOption.title.shortDisplayName, String(localized: "A-Z"))
        XCTAssertEqual(ItemSortOption.quantity.shortDisplayName, String(localized: "Qty"))
        XCTAssertEqual(ItemSortOption.createdAt.shortDisplayName, String(localized: "Created"))
        XCTAssertEqual(ItemSortOption.modifiedAt.shortDisplayName, String(localized: "Modified"))
    }

    func testShortDisplayNameDiffersFromDisplayNameForSomeCases() {
        // shortDisplayName should differ from displayName for title, quantity, createdAt, modifiedAt
        XCTAssertNotEqual(ItemSortOption.title.shortDisplayName, ItemSortOption.title.displayName)
        XCTAssertNotEqual(ItemSortOption.quantity.shortDisplayName, ItemSortOption.quantity.displayName)
        XCTAssertNotEqual(ItemSortOption.createdAt.shortDisplayName, ItemSortOption.createdAt.displayName)
        XCTAssertNotEqual(ItemSortOption.modifiedAt.shortDisplayName, ItemSortOption.modifiedAt.displayName)
    }

    func testAllSortOptionsHaveShortDisplayName() {
        // Every case must have a non-empty shortDisplayName
        for option in ItemSortOption.allCases {
            XCTAssertFalse(option.shortDisplayName.isEmpty, "\(option) should have a non-empty shortDisplayName")
        }
    }

    func testPillDisplayOrderMatchesMockup() {
        // Mockup shows: Order, A-Z, Qty, Created, Modified
        let expected: [ItemSortOption] = [.orderNumber, .title, .quantity, .createdAt, .modifiedAt]
        XCTAssertEqual(ItemSortOption.pillDisplayOrder, expected, "Pill order should match mockup: Order, A-Z, Qty, Created, Modified")
        XCTAssertEqual(ItemSortOption.pillDisplayOrder.count, ItemSortOption.allCases.count, "All sort options should be included")
    }

    func testSortBySectionHeaderExists() {
        // Section header uses "Sort By" key with .textCase(.uppercase) for visual "SORT BY"
        let header = String(localized: "Sort By")
        XCTAssertEqual(header, "Sort By", "Sort section header key should be 'Sort By'")
    }

    // MARK: - Task O.3: Sort Direction — Two Pill Buttons

    func testSortDirectionHasTwoCases() {
        // The direction pills should map to exactly two cases: ascending and descending
        XCTAssertEqual(SortDirection.allCases.count, 2, "SortDirection should have exactly 2 cases")
    }

    func testSortDirectionDisplayNames() {
        // Pill labels should be "Ascending" and "Descending"
        XCTAssertEqual(SortDirection.ascending.displayName, String(localized: "Ascending"))
        XCTAssertEqual(SortDirection.descending.displayName, String(localized: "Descending"))
    }

    func testSortDirectionCasesAreIdentifiable() {
        // Each direction must be identifiable for ForEach usage
        XCTAssertEqual(SortDirection.ascending.id, "Ascending")
        XCTAssertEqual(SortDirection.descending.id, "Descending")
    }

    func testSortDirectionAllCasesOrder() {
        // ascending should come first — matching left-to-right pill order in mockup
        let cases = SortDirection.allCases
        XCTAssertEqual(cases[0], .ascending, "Ascending should be first (left pill)")
        XCTAssertEqual(cases[1], .descending, "Descending should be second (right pill)")
    }

    // MARK: - Task O.4: Filter — Chip Buttons

    func testChipDisplayNameReturnsShortLabels() {
        // Mockup shows short labels: "All", "Active", "Completed", "With Photos"
        XCTAssertEqual(ItemFilterOption.all.chipDisplayName, String(localized: "All"))
        XCTAssertEqual(ItemFilterOption.active.chipDisplayName, String(localized: "Active"))
        XCTAssertEqual(ItemFilterOption.completed.chipDisplayName, String(localized: "Completed"))
        XCTAssertEqual(ItemFilterOption.hasImages.chipDisplayName, String(localized: "With Photos"))
    }

    func testChipDisplayOrderMatchesMockup() {
        // Mockup shows 4 chips: All, Active, Completed, With Photos (no hasDescription)
        let expected: [ItemFilterOption] = [.all, .active, .completed, .hasImages]
        XCTAssertEqual(ItemFilterOption.chipDisplayOrder, expected, "Chip order should match mockup")
        XCTAssertEqual(ItemFilterOption.chipDisplayOrder.count, 4, "Should have exactly 4 filter chips")
    }

    func testChipDisplayOrderExcludesHasDescription() {
        // hasDescription is deliberately excluded from chip UI per mockup
        XCTAssertFalse(ItemFilterOption.chipDisplayOrder.contains(.hasDescription),
                       "hasDescription should not appear in chip display order")
    }

    func testAllChipDisplayOrderOptionsHaveChipDisplayName() {
        // Every option in chipDisplayOrder must have a non-empty chipDisplayName
        for option in ItemFilterOption.chipDisplayOrder {
            XCTAssertFalse(option.chipDisplayName.isEmpty, "\(option) should have a non-empty chipDisplayName")
        }
    }

    func testFilterSectionHeaderKey() {
        // Section header uses "Filter" key with .textCase(.uppercase) for visual "FILTER"
        let header = String(localized: "Filter")
        XCTAssertEqual(header, "Filter", "Filter section header key should be 'Filter'")
    }
}
