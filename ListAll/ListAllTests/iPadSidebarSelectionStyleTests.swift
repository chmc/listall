import Testing
import SwiftUI
@testable import ListAll

/// Tests for iPad sidebar selection style: teal left border, tinted background,
/// fully rounded corners, and suppressed system highlight (Phase D.1)
struct iPadSidebarSelectionStyleTests {

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

    // MARK: - iPad Selection Spec Constants

    @Test("iPad selected row uses 3px teal left border width")
    func iPadSelectedBorderWidth() {
        let specBorderWidth: CGFloat = iPadSidebarSelectionSpec.borderWidth
        #expect(specBorderWidth == 3)
    }

    @Test("iPad selection background opacity matches spec: 0.08")
    func iPadSelectionBackgroundOpacity() {
        let specOpacity: Double = iPadSidebarSelectionSpec.backgroundOpacity
        #expect(specOpacity == 0.08)
    }

    @Test("iPad selected row uses fully rounded corners with 10pt radius")
    func iPadFullyRoundedCorners() {
        let specRadius: CGFloat = iPadSidebarSelectionSpec.cornerRadius
        #expect(specRadius == 10, "iPad uses fully rounded RoundedRectangle, not UnevenRoundedRectangle")
    }

    // MARK: - Padding Alignment

    @Test("Unselected row leading padding accounts for 3px border: 12 + 3 = 15")
    func unselectedPaddingAlignment() {
        let expectedUnselectedLeading: CGFloat = iPadSidebarSelectionSpec.borderWidth + iPadSidebarSelectionSpec.contentHorizontalPadding
        #expect(expectedUnselectedLeading == 15)
    }

    // MARK: - Count Format (already implemented, verify it uses teal)

    @Test("Count format uses active/total format")
    func countFormatActiveTotal() {
        let list = makeList(activeCount: 4, crossedOutCount: 2)
        #expect(list.activeItemCount == 4)
        #expect(list.itemCount == 6)
    }

    // MARK: - Spec struct exists

    @Test("iPadSidebarSelectionSpec provides all required constants")
    func specStructExists() {
        #expect(iPadSidebarSelectionSpec.borderWidth == 3)
        #expect(iPadSidebarSelectionSpec.backgroundOpacity == 0.08)
        #expect(iPadSidebarSelectionSpec.cornerRadius == 10)
        #expect(iPadSidebarSelectionSpec.contentHorizontalPadding == 12)
        #expect(iPadSidebarSelectionSpec.borderCornerRadius == 2)
    }
}
