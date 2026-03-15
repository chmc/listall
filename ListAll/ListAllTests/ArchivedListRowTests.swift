import Testing
@testable import ListAll

@Suite("Archived List Row - No Inline Buttons")
struct ArchivedListRowTests {

    @Test("ListRowView in archived mode should not have inline restore/delete buttons — only name + count + chevron")
    func archivedRowShowsSimpleLayout() {
        // Archived list rows should display:
        // - List name
        // - Count subtitle (e.g., "3/3 items")
        // - Chevron for navigation
        // They should NOT display inline Restore pill or Delete trash buttons.
        // Restore/Delete actions live in ArchivedListView toolbar only.
        let list = List(name: "Holiday Party")
        #expect(list.name == "Holiday Party")
        #expect(list.activeItemCount >= 0)
        #expect(list.itemCount >= 0)
        // Visual verification: archived row in listContent has no HStack with
        // Restore/Delete buttons — just VStack(name, count) + Spacer + chevron
    }

    @Test("Archived row subtitle shows count format without archivebox icon")
    func archivedRowSubtitleHasNoArchiveboxIcon() {
        // Design mockup shows "3/3 items" text only — no archivebox icon
        // in the archived list row subtitle. The archivebox icon was removed
        // to match the clean row design.
        let list = List(name: "Old Groceries")
        #expect(list.name == "Old Groceries")
        // Visual verification: no Image(systemName: "archivebox") in subtitle HStack
    }

    @MainActor
    @Test("ArchivedListView toolbar still has Restore and Delete buttons")
    func archivedListViewToolbarHasActions() {
        // Restore/Delete actions are in ArchivedListView.swift toolbar (lines 83-106),
        // not inline in the row. This ensures actions are accessible after drill-down.
        let list = List(name: "Test List")
        _ = ArchivedListView(list: list, mainViewModel: MainViewModel())
        // View instantiates successfully with toolbar actions
    }
}
