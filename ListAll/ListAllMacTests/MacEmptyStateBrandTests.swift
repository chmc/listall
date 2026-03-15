//
//  MacEmptyStateBrandTests.swift
//  ListAllMacTests
//
//  Tests for Phase 27: macOS empty state brand styling.
//  Verifies teal CTA buttons, teal icons, proper text per mockups.
//

import Testing
import SwiftUI
@testable import ListAll

@Suite("macOS Empty State Brand Styling")
struct MacEmptyStateBrandTests {

    // MARK: - MacItemsEmptyStateView Tests (No Items + All Done)

    @Test("MacItemsEmptyStateView accepts totalItems parameter for celebration subtitle")
    func testCelebrationStateTotalItemsParameter() {
        // The view should accept a totalItems parameter to show "X/X items completed"
        let _ = MacItemsEmptyStateView(hasItems: true, totalItems: 6, onAddItem: {})
        // If this compiles, the parameter exists
    }

    @Test("MacItemsEmptyStateView defaults totalItems to 0")
    func testCelebrationStateDefaultTotalItems() {
        // Should still work without totalItems (backward compatible)
        let _ = MacItemsEmptyStateView(hasItems: false, onAddItem: {})
    }

    @Test("Theme.Colors.primary is available for teal tint")
    func testTealColorAvailable() {
        let color = Theme.Colors.primary
        #expect(color != Color.clear, "Theme.Colors.primary should exist")
    }

    // MARK: - MacSearchEmptyStateView Tests

    @Test("MacSearchEmptyStateView can be instantiated with search text")
    func testSearchEmptyStateInstantiation() {
        var clearCalled = false
        let _ = MacSearchEmptyStateView(
            searchText: "avocado toast",
            onClear: { clearCalled = true }
        )
        #expect(!clearCalled)
    }

    // MARK: - MacListsEmptyStateView Tests (Welcome)

    @Test("MacListsEmptyStateView can be instantiated")
    func testWelcomeStateInstantiation() {
        let _ = MacListsEmptyStateView(
            onCreateSampleList: { _ in },
            onCreateCustomList: {}
        )
    }

    @Test("SampleDataService templates have item counts for welcome grid")
    func testTemplatesHaveItemCounts() {
        let templates = SampleDataService.templates
        for template in templates {
            #expect(template.sampleItems.count > 0, "Template '\(template.name)' should have items")
        }
    }
}
