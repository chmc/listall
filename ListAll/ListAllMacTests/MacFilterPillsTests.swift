//
//  MacFilterPillsTests.swift
//  ListAllMacTests
//
//  Tests for the teal pill-style filter buttons replacing segmented picker.
//

import XCTest
@testable import ListAll

#if os(macOS)

final class MacFilterPillsTests: XCTestCase {

    // MARK: - Pill Configuration Tests

    /// Test that MacListDetailView defines exactly 3 inline filter options
    func testInlineFilterOptionsCount() {
        let options = MacListDetailView.inlineFilterOptions
        XCTAssertEqual(options.count, 3, "Should have exactly 3 inline filter options")
    }

    /// Test that inline filter options are All, Active, Done in correct order
    func testInlineFilterOptionsOrder() {
        let options = MacListDetailView.inlineFilterOptions
        XCTAssertEqual(options[0].label, "All")
        XCTAssertEqual(options[0].option, .all)
        XCTAssertEqual(options[1].label, "Active")
        XCTAssertEqual(options[1].option, .active)
        XCTAssertEqual(options[2].label, "Done")
        XCTAssertEqual(options[2].option, .completed)
    }

    /// Test that pill labels match the expected iOS labels (All, Active, Done)
    func testPillLabelsMatchExpected() {
        let options = MacListDetailView.inlineFilterOptions
        let expectedLabels = ["All", "Active", "Done"]
        let actualLabels = options.map(\.label)
        XCTAssertEqual(actualLabels, expectedLabels, "macOS pill labels should match iOS: All, Active, Done")
    }
}

#endif
