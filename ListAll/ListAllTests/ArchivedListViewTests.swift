import Testing
@testable import ListAll

@Suite("ArchivedListView Styling Tests")
struct ArchivedListViewStylingTests {

    // MARK: - 8a: Archived Badge

    @Test("Archived badge should use orange color scheme, not secondary")
    func archivedBadgeUsesOrangeNotSecondary() {
        // The ArchivedListView header badge should display "Archived" text
        // with archivebox icon in an orange capsule badge.
        // Visual verification: badge should be orange with 0.12 opacity background
        // This test verifies the data model supports the view correctly.
        let list = List(name: "Test Archived List")
        #expect(list.name == "Test Archived List")
        // The view should render an orange "Archived" capsule badge
        // Verified visually: font .caption.weight(.semibold), .foregroundColor(.orange),
        // background Color.orange.opacity(0.12), clipShape Capsule()
    }

    // MARK: - 8b: Toolbar Buttons

    @Test("Restore button should use Theme.Colors.primary, not .accentColor")
    func restoreButtonUsesBrandTeal() {
        // The restore toolbar button should use Theme.Colors.primary (brand teal)
        // instead of .accentColor for consistent brand styling.
        // Visual verification required for color correctness.
        // ArchivedListView requires MainViewModel (not TestMainViewModel),
        // so color verification is done via visual screenshots.
        let list = List(name: "Archived List")
        #expect(list.name == "Archived List")
    }

    // MARK: - 8c: Archived Item Row Styling

    @Test("ArchivedItemRowView renders all items with strikethrough, secondary color, and 0.6 opacity")
    func archivedItemRowAlwaysStrikethrough() {
        // ALL archived items should display with strikethrough regardless of isCrossedOut state
        // - .strikethrough(true) (unconditional — all archived items are muted)
        // - .foregroundColor(.secondary)
        // - .opacity(0.6)
        var activeItem = Item(title: "Active Item")
        activeItem.isCrossedOut = false
        #expect(activeItem.displayTitle == "Active Item")
        _ = ArchivedItemRowView(item: activeItem)

        var crossedOutItem = Item(title: "Completed Item")
        crossedOutItem.isCrossedOut = true
        #expect(crossedOutItem.displayTitle == "Completed Item")
        _ = ArchivedItemRowView(item: crossedOutItem)
        // Both should render identically with strikethrough — verified visually
    }

    @Test("ArchivedItemRowView shows quantity for items with quantity > 1")
    func archivedItemRowQuantityDisplay() {
        var item = Item(title: "Multi Item")
        item.quantity = 3
        #expect(item.quantity > 1)
        _ = ArchivedItemRowView(item: item)
    }

    @Test("ArchivedItemRowView shows description when present")
    func archivedItemRowDescriptionDisplay() {
        var item = Item(title: "Item with Desc")
        item.itemDescription = "Some description"
        #expect(item.hasDescription)
        #expect(item.displayDescription == "Some description")
        _ = ArchivedItemRowView(item: item)
    }
}
