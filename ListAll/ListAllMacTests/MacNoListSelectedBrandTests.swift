//
//  MacNoListSelectedBrandTests.swift
//  ListAllMacTests
//
//  Tests for MacNoListSelectedView brand styling (Phase 11).
//

import Testing
import SwiftUI
@testable import ListAll

@Suite("MacNoListSelectedView Brand Styling")
struct MacNoListSelectedBrandTests {

    @Test("View can be instantiated with onCreateList callback")
    func testViewInstantiation() {
        var called = false
        let _ = MacNoListSelectedView(onCreateList: { called = true })
        // View struct created successfully
        #expect(!called, "Callback should not be called on init")
    }

    @Test("Theme.Colors.primary is available for brand tint")
    func testBrandColorAvailable() {
        let color = Theme.Colors.primary
        #expect(color != Color.clear, "Theme.Colors.primary should be a real color")
    }
}
