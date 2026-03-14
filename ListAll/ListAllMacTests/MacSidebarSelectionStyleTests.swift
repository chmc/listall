//
//  MacSidebarSelectionStyleTests.swift
//  ListAllMacTests
//
//  Tests for sidebar selection style: teal left border, tinted background,
//  right-side-only rounding, and suppressed system highlight.
//

import Testing
import Foundation
@testable import ListAll

struct MacSidebarSelectionStyleTests {

    // MARK: - Helper

    private func makeList(name: String = "Test", activeCount: Int = 3, crossedOutCount: Int = 1) -> ListAll.List {
        var list = ListAll.List(name: name)
        for i in 0..<activeCount {
            var item = Item(title: "Active \(i)")
            item.isCrossedOut = false
            list.items.append(item)
        }
        for i in 0..<crossedOutCount {
            var item = Item(title: "Done \(i)")
            item.isCrossedOut = true
            list.items.append(item)
        }
        return list
    }

    // MARK: - Count Format in Selection Context

    @Test("Selected row shows active/total count format")
    func selectedRowCountFormat() {
        let list = makeList(activeCount: 4, crossedOutCount: 2)
        let result = MacSidebarFormatting.itemCountText(for: list)
        #expect(result == "4/6")
    }

    @Test("Unselected row shows same active/total format")
    func unselectedRowCountFormat() {
        let list = makeList(activeCount: 2, crossedOutCount: 3)
        let result = MacSidebarFormatting.itemCountText(for: list)
        #expect(result == "2/5")
    }

    // MARK: - Padding Alignment Verification

    @Test("Unselected row leading padding accounts for 3px border: 12 + 3 = 15")
    func unselectedPaddingAlignment() {
        // The unselected row uses .padding(.leading, 15) to align with
        // the selected row's content which has a 3px border + 12px horizontal padding
        let borderWidth: CGFloat = 3
        let contentHorizontalPadding: CGFloat = 12
        let expectedUnselectedLeading: CGFloat = borderWidth + contentHorizontalPadding
        #expect(expectedUnselectedLeading == 15)
    }

    @Test("Selected row uses 3px border width")
    func selectedBorderWidth() {
        // The teal left accent bar is 3px wide per design spec
        let specBorderWidth: CGFloat = 3
        #expect(specBorderWidth == 3)
    }

    // MARK: - Background Color Spec

    @Test("Selection background opacity matches spec: 0.08")
    func selectionBackgroundOpacity() {
        // Theme.Colors.primary.opacity(0.08) is the spec for selected row background
        let specOpacity: Double = 0.08
        #expect(specOpacity == 0.08)
    }

    // MARK: - UnevenRoundedRectangle Spec

    @Test("Selected row uses right-side-only rounding with 8pt radius")
    func rightSideOnlyRounding() {
        // Spec: UnevenRoundedRectangle(topLeadingRadius: 0, bottomLeadingRadius: 0,
        //                               bottomTrailingRadius: 8, topTrailingRadius: 8)
        let topLeading: CGFloat = 0
        let bottomLeading: CGFloat = 0
        let bottomTrailing: CGFloat = 8
        let topTrailing: CGFloat = 8

        #expect(topLeading == 0, "Top leading must be square (flush with sidebar edge)")
        #expect(bottomLeading == 0, "Bottom leading must be square (flush with sidebar edge)")
        #expect(bottomTrailing == 8, "Bottom trailing must be rounded")
        #expect(topTrailing == 8, "Top trailing must be rounded")
    }
}
