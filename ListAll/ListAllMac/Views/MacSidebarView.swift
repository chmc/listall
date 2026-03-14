//
//  MacSidebarView.swift
//  ListAllMac
//
//  Sidebar navigation view for macOS app.
//

import SwiftUI

// MARK: - Sidebar Formatting (extracted for testability)

/// Formatting helpers for macOS sidebar display
enum MacSidebarFormatting {
    /// Formats item count as "active/total" (e.g., "4/6")
    static func itemCountText(for list: List) -> String {
        let activeCount = list.items.filter { !$0.isCrossedOut }.count
        let totalCount = list.items.count
        return "\(activeCount)/\(totalCount)"
    }
}

// MARK: - Sidebar View

struct MacSidebarView: View {
    // CRITICAL: Observe dataManager directly instead of receiving array by value
    // Passing [List] by value breaks SwiftUI observation chain on macOS
    @EnvironmentObject var dataManager: DataManager

    // Access CoreDataManager for sync status and manual refresh
    @ObservedObject private var coreDataManager = CoreDataManager.shared

    @Binding var selectedList: List?
    let onCreateList: () -> Void
    let onDeleteList: (List) -> Void

    // State for share popover from context menu
    @State private var listToShare: List?
    @State private var showingSharePopover = false

    // DataRepository for drag-and-drop operations
    private let dataRepository = DataRepository()

    // MARK: - Multi-Select Mode State
    @State private var isInSelectionMode = false
    @State private var selectedLists: Set<UUID> = []
    @State private var showingArchiveConfirmation = false
    @State private var showingPermanentDeleteConfirmation = false
    @State private var showingDeleteActiveListsConfirmation = false  // Task 15.4

    // MARK: - Restore Confirmation State (Task 13.1)
    @State private var showingRestoreConfirmation = false
    @State private var listToRestore: List? = nil

    // MARK: - Keyboard Navigation (Task 11.1)
    /// Focus state for individual list rows - enables arrow key navigation
    @FocusState private var focusedListID: UUID?

    // MARK: - Archived Section Expansion State
    /// Persisted collapsed/expanded state for Archived section (collapsed by default)
    @AppStorage("archivedSectionExpanded") private var isArchivedSectionExpanded = false

    // MARK: - Computed List Properties

    /// Active (non-archived) lists sorted by order number
    private var activeLists: [List] {
        dataManager.lists.filter { !$0.isArchived }
            .sorted { $0.orderNumber < $1.orderNumber }
    }

    /// Archived lists sorted by modification date (most recent first)
    private var archivedLists: [List] {
        dataManager.archivedLists
    }

    /// All visible lists for keyboard navigation - only includes archived when section is expanded
    private var allVisibleLists: [List] {
        if isArchivedSectionExpanded {
            return activeLists + archivedLists
        } else {
            return activeLists
        }
    }

    /// Legacy computed property for backwards compatibility (selection mode actions)
    /// Now returns only active lists (archived shown in separate section)
    private var displayedLists: [List] {
        activeLists
    }

    /// Tooltip text showing last sync time for refresh button
    private var lastSyncTooltip: String {
        if let lastSync = coreDataManager.lastSyncDate {
            let formatter = RelativeDateTimeFormatter()
            formatter.unitsStyle = .abbreviated
            return "Last synced: \(formatter.localizedString(for: lastSync, relativeTo: Date()))"
        } else {
            return "Refresh - Click to sync with iCloud"
        }
    }

    /// Formatted last sync time for display in UI
    private var lastSyncDisplayText: String {
        if let lastSync = coreDataManager.lastSyncDate {
            let formatter = RelativeDateTimeFormatter()
            formatter.unitsStyle = .short
            return "Synced \(formatter.localizedString(for: lastSync, relativeTo: Date()))"
        } else {
            return "Not synced yet"
        }
    }

    // MARK: - Selection Mode Methods

    private func enterSelectionMode() {
        isInSelectionMode = true
        selectedLists.removeAll()
    }

    private func exitSelectionMode() {
        isInSelectionMode = false
        selectedLists.removeAll()
    }

    private func toggleSelection(for listId: UUID) {
        if selectedLists.contains(listId) {
            selectedLists.remove(listId)
        } else {
            selectedLists.insert(listId)
        }
    }

    private func selectAllLists() {
        selectedLists = Set(allVisibleLists.map { $0.id })
    }

    private func deselectAllLists() {
        selectedLists.removeAll()
    }

    /// Archives selected lists (moves to archived, can be restored)
    private func archiveSelectedLists() {
        // Store selected IDs before modifying
        let listsToArchive = selectedLists

        for listId in listsToArchive {
            // deleteList actually archives (sets isArchived = true)
            dataManager.deleteList(withId: listId)
        }
        dataManager.loadData()

        // Clear detail selection if archived list was selected
        if let currentSelection = selectedList, listsToArchive.contains(currentSelection.id) {
            selectedList = nil
        }

        selectedLists.removeAll()
        isInSelectionMode = false
    }

    /// Permanently deletes selected lists (irreversible, for archived lists view)
    private func permanentlyDeleteSelectedLists() {
        // Store selected IDs before modifying
        let listsToDelete = selectedLists

        for listId in listsToDelete {
            dataManager.permanentlyDeleteList(withId: listId)
        }
        dataManager.loadData()

        // Clear detail selection if deleted list was selected
        if let currentSelection = selectedList, listsToDelete.contains(currentSelection.id) {
            selectedList = nil
        }

        selectedLists.removeAll()
        isInSelectionMode = false
    }

    // MARK: - Bulk Action Button (extracted for type-checker performance)

    /// Check if any selected lists are archived
    private var hasArchivedSelection: Bool {
        selectedLists.contains { id in
            allVisibleLists.first(where: { $0.id == id })?.isArchived == true
        }
    }

    /// Builds the appropriate bulk action buttons based on selected lists
    @ViewBuilder
    private var bulkActionButton: some View {
        if hasArchivedSelection {
            // Has archived lists selected: permanent deletion only
            Button(role: .destructive, action: { showingPermanentDeleteConfirmation = true }) {
                Label("Delete Permanently", systemImage: "trash")
            }
            .disabled(selectedLists.isEmpty)
        } else {
            // Active lists only: archive (recoverable) and delete (permanent)
            Button(action: { showingArchiveConfirmation = true }) {
                Label("Archive Lists", systemImage: "archivebox")
            }
            .disabled(selectedLists.isEmpty)

            // Task 15.4: Add permanent delete option for active lists
            Button(role: .destructive, action: { showingDeleteActiveListsConfirmation = true }) {
                Label("Delete Lists", systemImage: "trash")
            }
            .disabled(selectedLists.isEmpty)
        }
    }

    // MARK: - List Row Content (extracted for type-checker performance)

    /// Helper to format item count display
    private func itemCountText(for list: List) -> String {
        MacSidebarFormatting.itemCountText(for: list)
    }

    /// Returns active and total counts for a list
    private func itemCounts(for list: List) -> (active: Int, total: Int) {
        let activeCount = list.items.filter { !$0.isCrossedOut }.count
        return (activeCount, list.items.count)
    }

    /// Whether a list is currently selected
    private func isSelected(_ list: List) -> Bool {
        selectedList?.id == list.id
    }

    /// Builds a list row for selection mode
    @ViewBuilder
    private func selectionModeRow(for list: List) -> some View {
        let counts = itemCounts(for: list)
        Button(action: { toggleSelection(for: list.id) }) {
            HStack(spacing: 8) {
                Image(systemName: selectedLists.contains(list.id) ? "checkmark.circle.fill" : "circle")
                    .foregroundColor(selectedLists.contains(list.id) ? .blue : .gray)
                    .font(.title3)
                Text(list.name)
                    .foregroundColor(.primary)
                Spacer()
                Text("\(counts.active)/\(counts.total)")
                    .foregroundColor(.secondary)
                    .font(.caption)
                    .monospacedDigit()
                    .numericContentTransition()
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        // CRITICAL: Use .activate interactions to allow sidebar drag-drop to work.
        // Default .focusable() on macOS Sonoma+ captures mouse clicks.
        .focusable(interactions: .activate)
        .focused($focusedListID, equals: list.id)
        .accessibilityIdentifier("SidebarListCell_\(list.name)")
        .accessibilityLabel("\(list.name)")
        .accessibilityValue(selectedLists.contains(list.id) ? "selected" : "not selected")
        .accessibilityHint("Double-tap to toggle selection")
    }

    /// Builds the row content for a sidebar list (selected or unselected)
    @ViewBuilder
    private func sidebarRowContent(for list: List) -> some View {
        let counts = itemCounts(for: list)
        let selected = isSelected(list)

        if selected {
            HStack(spacing: 0) {
                // Teal left accent bar
                RoundedRectangle(cornerRadius: 2)
                    .fill(Theme.Colors.primary)
                    .frame(width: 3)

                // Row content with tinted background
                HStack {
                    Text(list.name)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(Theme.Colors.primary)
                    Spacer()
                    Text("\(counts.active)/\(counts.total)")
                        .font(.caption)
                        .monospacedDigit()
                        .foregroundColor(Theme.Colors.primary.opacity(0.5))
                        .numericContentTransition()
                }
                .padding(.vertical, 10)
                .padding(.horizontal, 12)
            }
            .background(Theme.Colors.primary.opacity(0.08))
            .clipShape(UnevenRoundedRectangle(topLeadingRadius: 0, bottomLeadingRadius: 0,
                                              bottomTrailingRadius: 8, topTrailingRadius: 8))
        } else {
            HStack {
                Text(list.name)
                    .font(.system(size: 13))
                    .foregroundColor(.primary.opacity(0.7))
                Spacer()
                Text("\(counts.active)/\(counts.total)")
                    .font(.caption)
                    .monospacedDigit()
                    .foregroundColor(.secondary.opacity(0.5))
                    .numericContentTransition()
            }
            .padding(.vertical, 10)
            .padding(.leading, 15)  // 12 + 3 (align with selected content after border)
            .padding(.trailing, 12)
        }
    }

    /// Builds a list row for normal navigation mode
    @ViewBuilder
    private func normalModeRow(for list: List) -> some View {
        NavigationLink(value: list) {
            sidebarRowContent(for: list)
        }
        .listRowBackground(Color.clear)
        // CRITICAL: Use .activate interactions to allow list drag-drop to work.
        // Default .focusable() on macOS Sonoma+ captures mouse clicks, blocking drag.
        .focusable(interactions: .activate)
        .focused($focusedListID, equals: list.id)
        .accessibilityIdentifier("SidebarListCell_\(list.name)")
        .accessibilityLabel("\(list.name)")
        .accessibilityValue("\(list.items.filter { !$0.isCrossedOut }.count) active, \(list.items.count) total items")
        .accessibilityHint("Double-tap to view list items")
        .draggable(list)
        .dropDestination(for: ItemTransferData.self) { droppedItems, _ in
            handleItemDrop(droppedItems, to: list)
        }
        .contextMenu {
            if list.isArchived {
                // Archived list context menu: Restore and Delete Permanently
                Button {
                    listToRestore = list
                    showingRestoreConfirmation = true
                } label: {
                    Label("Restore", systemImage: "arrow.uturn.backward")
                }

                Divider()

                Button(role: .destructive) {
                    onDeleteList(list)
                } label: {
                    Label("Delete Permanently", systemImage: "trash")
                }
            } else {
                // Active list context menu: Share and Delete (archive)
                Button("Share...") {
                    shareListFromSidebar(list)
                }
                Divider()
                Button("Delete") {
                    onDeleteList(list)
                }
            }
        }
    }

    /// Sync status footer view for reuse
    private var syncStatusFooter: some View {
        HStack {
            Image(systemName: "icloud")
                .font(.caption2)
                .foregroundStyle(.secondary)
            Text(lastSyncDisplayText)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .padding(.top, 8)
        .accessibilityLabel("Sync status: \(lastSyncDisplayText)")
    }

    var body: some View {
        SwiftUI.List(selection: isInSelectionMode ? .constant(nil) : $selectedList) {
            // MARK: - Active Lists Section
            Section {
                ForEach(activeLists) { list in
                    if isInSelectionMode {
                        selectionModeRow(for: list)
                    } else {
                        normalModeRow(for: list)
                    }
                }
                .onMove(perform: isInSelectionMode ? nil : moveList)
            } header: {
                Text("LISTS")
                    .font(.system(size: 9, weight: .semibold))
                    .tracking(1.2)
                    .foregroundColor(.secondary.opacity(0.5))
                    .textCase(.uppercase)
            }
            .collapsible(false)

            // MARK: - Archived Lists Section (Collapsible)
            if !archivedLists.isEmpty {
                Section {
                    // FIX: Always render ForEach but hide rows when collapsed
                    // Using conditional `if` breaks SwiftUI's view identity tracking
                    // when @AppStorage state changes, preventing proper re-render.
                    ForEach(archivedLists) { list in
                        Group {
                            if isInSelectionMode {
                                selectionModeRow(for: list)
                            } else {
                                normalModeRow(for: list)
                            }
                        }
                        .frame(height: isArchivedSectionExpanded ? nil : 0)
                        .clipped()
                        .opacity(isArchivedSectionExpanded ? 1 : 0)
                    }
                    // No .onMove - archived lists cannot be reordered
                } header: {
                    // Clickable header with disclosure chevron
                    Button {
                        withAnimation(.easeInOut(duration: 0.15)) {
                            isArchivedSectionExpanded.toggle()
                        }
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "chevron.right")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.secondary)
                                .rotationEffect(.degrees(isArchivedSectionExpanded ? 90 : 0))
                            Text("Archived")
                        }
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Archived lists")
                    .accessibilityHint(isArchivedSectionExpanded ? "Double-tap to collapse" : "Double-tap to expand")
                } footer: {
                    // Only show sync status when expanded, otherwise it looks odd
                    if isArchivedSectionExpanded {
                        syncStatusFooter
                    }
                }
                .collapsible(false) // We handle collapsing ourselves
            }

            // Show sync status at bottom when archived section is collapsed or empty
            if archivedLists.isEmpty || !isArchivedSectionExpanded {
                Section {
                    EmptyView()
                } footer: {
                    syncStatusFooter
                }
                .collapsible(false)
            }
        }
        .listStyle(.sidebar)
        .accessibilityIdentifier("ListsSidebar")
        // MARK: - Keyboard Navigation Handlers (Task 11.1)
        .onKeyPress(.return) {
            // Enter key selects the focused list (only in normal mode)
            guard !isInSelectionMode else { return .ignored }
            if let focusedID = focusedListID,
               let list = allVisibleLists.first(where: { $0.id == focusedID }) {
                selectedList = list
                return .handled
            }
            return .ignored
        }
        .onKeyPress(.space) {
            // In selection mode, space toggles selection
            if isInSelectionMode {
                if let focusedID = focusedListID {
                    toggleSelection(for: focusedID)
                    return .handled
                }
                return .ignored
            }
            // In normal mode, space selects the focused list (macOS convention)
            if let focusedID = focusedListID,
               let list = allVisibleLists.first(where: { $0.id == focusedID }) {
                selectedList = list
                return .handled
            }
            return .ignored
        }
        .onKeyPress(.delete) {
            // In selection mode, determine action based on selected lists
            if isInSelectionMode && !selectedLists.isEmpty {
                // Check if any selected lists are archived
                let hasArchivedSelection = selectedLists.contains { id in
                    allVisibleLists.first(where: { $0.id == id })?.isArchived == true
                }
                if hasArchivedSelection {
                    // Has archived lists: permanently delete
                    showingPermanentDeleteConfirmation = true
                } else {
                    // All active lists: archive (recoverable)
                    showingArchiveConfirmation = true
                }
                return .handled
            }
            // In normal mode, delete focused list
            if let focusedID = focusedListID,
               let list = allVisibleLists.first(where: { $0.id == focusedID }) {
                onDeleteList(list)
                // Move focus to next list or nil
                moveFocusAfterDeletion(deletedId: focusedID)
                return .handled
            }
            return .ignored
        }
        .onKeyPress(.escape) {
            // Escape exits selection mode
            if isInSelectionMode {
                exitSelectionMode()
                return .handled
            }
            return .ignored
        }
        // Cmd+A to select all in selection mode
        .onKeyPress(characters: CharacterSet(charactersIn: "a")) { keyPress in
            guard keyPress.modifiers.contains(.command), isInSelectionMode else {
                return .ignored
            }
            selectAllLists()
            return .handled
        }
        // Sync focus with selection (bidirectional - Issue #2 fix from Critical Review)
        .onChange(of: selectedList) { _, newList in
            if let newList = newList {
                focusedListID = newList.id
            }
        }
        .onChange(of: focusedListID) { _, newFocusedID in
            // When arrow keys change focus, update selection (macOS convention) - only in normal mode
            guard !isInSelectionMode else { return }
            if let newFocusedID = newFocusedID,
               let list = allVisibleLists.first(where: { $0.id == newFocusedID }) {
                selectedList = list
            }
        }
        .toolbar {
            // Selection mode toolbar items
            if isInSelectionMode {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        exitSelectionMode()
                    }
                    .accessibilityIdentifier("CancelSelectionButton")
                    .accessibilityHint("Exits selection mode")
                }

                ToolbarItem(placement: .primaryAction) {
                    Menu {
                        Button(action: selectAllLists) {
                            Label("Select All", systemImage: "checkmark.circle")
                        }
                        .disabled(allVisibleLists.isEmpty)

                        Button(action: deselectAllLists) {
                            Label("Deselect All", systemImage: "circle")
                        }
                        .disabled(selectedLists.isEmpty)

                        Divider()

                        // Use extracted @ViewBuilder for type-checker performance
                        bulkActionButton
                    } label: {
                        Label("Actions", systemImage: "ellipsis.circle")
                    }
                    .accessibilityIdentifier("SelectionActionsMenu")
                    .accessibilityLabel("Selection actions")
                    .accessibilityHint("Shows selection actions menu")
                }
            } else {
                // Normal mode toolbar items
                ToolbarItem(placement: .primaryAction) {
                    HStack(spacing: 4) {
                        // Refresh button with last sync time tooltip
                        Button(action: {
                            coreDataManager.forceRefresh()
                            dataManager.loadData()
                        }) {
                            Label("Refresh", systemImage: "arrow.clockwise")
                        }
                        .accessibilityIdentifier("RefreshButton")
                        .accessibilityLabel("Refresh data from iCloud")
                        .accessibilityHint("Manually syncs data from CloudKit")
                        .help(lastSyncTooltip)

                        Button(action: enterSelectionMode) {
                            Label("Select", systemImage: "checklist")
                        }
                        .help("Select Multiple Lists")
                        .accessibilityIdentifier("SelectListsButton")
                        .accessibilityHint("Enter selection mode to select multiple lists")

                        Button(action: onCreateList) {
                            Label("Add List", systemImage: "plus")
                        }
                        .accessibilityIdentifier("AddListButton")
                        .accessibilityHint("Opens sheet to create new list")
                    }
                }
            }
        }
        .sheet(isPresented: $showingSharePopover) {
            if let list = listToShare {
                MacShareFormatPickerView(
                    list: list,
                    onDismiss: {
                        showingSharePopover = false
                        listToShare = nil
                    }
                )
            }
        }
        // Archive confirmation alert (for active lists)
        .alert("Archive Lists", isPresented: $showingArchiveConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Archive", role: .destructive) {
                archiveSelectedLists()
            }
        } message: {
            Text("Archive \(selectedLists.count) \(selectedLists.count == 1 ? "list" : "lists")? You can restore them later from archived lists.")
        }
        // Permanent delete confirmation alert (for archived lists)
        .alert("Delete Permanently", isPresented: $showingPermanentDeleteConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Delete Permanently", role: .destructive) {
                permanentlyDeleteSelectedLists()
            }
        } message: {
            Text("Permanently delete \(selectedLists.count) \(selectedLists.count == 1 ? "list" : "lists")? This action cannot be undone. All items and images will be permanently deleted.")
        }
        // Task 15.4: Delete active lists confirmation alert
        .alert("Delete Lists", isPresented: $showingDeleteActiveListsConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) {
                permanentlyDeleteSelectedLists()
            }
        } message: {
            Text("Permanently delete \(selectedLists.count) \(selectedLists.count == 1 ? "list" : "lists")? This action cannot be undone and bypasses archiving.")
        }
        // MARK: - Restore Confirmation Alert (Task 13.1)
        .alert("Restore List", isPresented: $showingRestoreConfirmation) {
            Button("Cancel", role: .cancel) {
                listToRestore = nil
            }
            Button("Restore") {
                if let list = listToRestore {
                    // Use MainViewModel pattern for restore
                    dataManager.restoreList(withId: list.id)
                    // Refresh data to update UI
                    dataManager.loadArchivedData()
                    dataManager.loadData()
                    // Clear selection - the restored list moves to active lists
                    // and the stale struct copy has isArchived = true
                    selectedList = nil
                }
                listToRestore = nil
            }
        } message: {
            if let list = listToRestore {
                Text("Do you want to restore \"\(list.name)\" to your active lists?")
            } else {
                Text("Do you want to restore this list to your active lists?")
            }
        }
        // MARK: - Restore Keyboard Shortcut Handler (Task 13.1)
        // Responds to Cmd+Shift+R from AppCommands menu
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("RestoreSelectedList"))) { _ in
            // Only process if selected list is archived
            guard let list = selectedList, list.isArchived else { return }
            // Trigger restore confirmation
            listToRestore = list
            showingRestoreConfirmation = true
        }
        // MARK: - Archived Section Collapse Handler
        // Clear selection when archived section is collapsed to prevent invisible selection
        .onChange(of: isArchivedSectionExpanded) { _, isExpanded in
            if !isExpanded {
                // Clear selection if currently selected list is archived
                if let current = selectedList, current.isArchived {
                    selectedList = nil
                }
                // Clear focus if on archived list
                if let focusedID = focusedListID,
                   archivedLists.contains(where: { $0.id == focusedID }) {
                    focusedListID = nil
                }
                // Exit selection mode and clear multi-select if any archived lists were selected
                if selectedLists.contains(where: { id in
                    archivedLists.contains(where: { $0.id == id })
                }) {
                    selectedLists.removeAll()
                    isInSelectionMode = false
                }
            }
        }
    }

    // MARK: - Drag-and-Drop Handlers

    /// Handle item drop on a list in the sidebar (moves item to that list)
    private func handleItemDrop(_ droppedItems: [ItemTransferData], to targetList: List) -> Bool {
        print("📦 Sidebar handleItemDrop called with \(droppedItems.count) items to list '\(targetList.name)'")
        var didMoveAny = false

        for itemData in droppedItems {
            print("📦 Processing dropped item: \(itemData.itemId), sourceListId: \(String(describing: itemData.sourceListId))")

            // Skip if item is already in the target list
            guard itemData.sourceListId != targetList.id else {
                print("📦 Drop skipped: item already in target list")
                continue
            }

            // Validate sourceListId exists
            guard let sourceListId = itemData.sourceListId else {
                print("❌ Sidebar drop failed: sourceListId is nil for item \(itemData.itemId)")
                continue
            }

            // Find the item in DataManager
            let items = dataManager.getItems(forListId: sourceListId)
            guard let item = items.first(where: { $0.id == itemData.itemId }) else {
                print("❌ Sidebar drop failed: could not find item \(itemData.itemId) in source list \(sourceListId)")
                continue
            }

            // Move item to the target list
            dataRepository.moveItem(item, to: targetList)
            didMoveAny = true
            print("📦 Moved item '\(item.title)' to list '\(targetList.name)'")
        }

        if didMoveAny {
            dataManager.loadData()
        }

        return didMoveAny
    }

    /// Handle list reordering via drag-and-drop (only for active lists section)
    private func moveList(from source: IndexSet, to destination: Int) {
        // Get current order (displayedLists = activeLists only)
        var reorderedLists = displayedLists

        // Perform the move
        reorderedLists.move(fromOffsets: source, toOffset: destination)

        // Update order numbers - must modify array elements directly (value types!)
        for index in reorderedLists.indices {
            reorderedLists[index].orderNumber = index
            reorderedLists[index].modifiedAt = Date()
        }

        print("📦 Reordering lists: \(reorderedLists.map { "\($0.name):\($0.orderNumber)" })")

        // Persist the new order
        dataManager.updateListsOrder(reorderedLists)
        dataManager.loadData()

        print("📦 Reordered lists via drag-and-drop")
    }

    /// Shows share popover for a list from sidebar context menu
    private func shareListFromSidebar(_ list: List) {
        listToShare = list
        showingSharePopover = true
    }

    // MARK: - Keyboard Navigation Helpers (Task 11.1)

    /// Moves focus to the next or previous list after deletion
    private func moveFocusAfterDeletion(deletedId: UUID) {
        let lists = allVisibleLists
        guard let currentIndex = lists.firstIndex(where: { $0.id == deletedId }) else {
            focusedListID = nil
            return
        }

        // Try next list first, then previous
        if currentIndex < lists.count - 1 {
            focusedListID = lists[currentIndex + 1].id
        } else if currentIndex > 0 {
            focusedListID = lists[currentIndex - 1].id
        } else {
            focusedListID = nil
        }
    }
}
