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
    @State var listToShare: List?
    @State var showingSharePopover = false

    // DataRepository for drag-and-drop operations
    let dataRepository = DataRepository()

    // MARK: - Multi-Select Mode State
    @State var isInSelectionMode = false
    @State var selectedLists: Set<UUID> = []
    @State var showingArchiveConfirmation = false
    @State var showingPermanentDeleteConfirmation = false
    @State var showingDeleteActiveListsConfirmation = false  // Task 15.4

    // MARK: - Restore Confirmation State (Task 13.1)
    @State var showingRestoreConfirmation = false
    @State var listToRestore: List? = nil

    // MARK: - Keyboard Navigation (Task 11.1)
    /// Focus state for individual list rows - enables arrow key navigation
    @FocusState var focusedListID: UUID?

    // MARK: - Archived Section Expansion State
    /// Persisted collapsed/expanded state for Archived section (collapsed by default)
    @AppStorage("archivedSectionExpanded") private var isArchivedSectionExpanded = false

    // MARK: - Computed List Properties

    /// Active (non-archived) lists sorted by order number
    var activeLists: [List] {
        dataManager.lists.filter { !$0.isArchived }
            .sorted { $0.orderNumber < $1.orderNumber }
    }

    /// Archived lists sorted by modification date (most recent first)
    var archivedLists: [List] {
        dataManager.archivedLists
    }

    /// All visible lists for keyboard navigation - only includes archived when section is expanded
    var allVisibleLists: [List] {
        if isArchivedSectionExpanded {
            return activeLists + archivedLists
        } else {
            return activeLists
        }
    }

    /// Legacy computed property for backwards compatibility (selection mode actions)
    /// Now returns only active lists (archived shown in separate section)
    var displayedLists: [List] {
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
    var lastSyncDisplayText: String {
        if let lastSync = coreDataManager.lastSyncDate {
            let formatter = RelativeDateTimeFormatter()
            formatter.unitsStyle = .short
            return "Synced \(formatter.localizedString(for: lastSync, relativeTo: Date()))"
        } else {
            return "Not synced yet"
        }
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
}
