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
    @AppStorage("archivedSectionExpanded") var isArchivedSectionExpanded = false

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
            Button(role: .destructive, action: { showingPermanentDeleteConfirmation = true }) {
                Label("Delete Permanently", systemImage: "trash")
            }
            .disabled(selectedLists.isEmpty)
        } else {
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
        sidebarSheetsAndAlerts(
            sidebarFocusSyncHandlers(
                sidebarKeyboardHandlers(
                    sidebarListContent
                        .listStyle(.sidebar)
                        .accessibilityIdentifier("ListsSidebar")
                )
            )
            .toolbar {
                sidebarToolbarContent
            }
        )
    }

    // MARK: - List Content

    private var sidebarListContent: some View {
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
                } header: {
                    archivedSectionHeader
                } footer: {
                    if isArchivedSectionExpanded {
                        syncStatusFooter
                    }
                }
                .collapsible(false)
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
    }

    // MARK: - Archived Section Header

    private var archivedSectionHeader: some View {
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
    }

    // MARK: - Toolbar Content

    @ToolbarContentBuilder
    private var sidebarToolbarContent: some ToolbarContent {
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

                    bulkActionButton
                } label: {
                    Label("Actions", systemImage: "ellipsis.circle")
                }
                .accessibilityIdentifier("SelectionActionsMenu")
                .accessibilityLabel("Selection actions")
                .accessibilityHint("Shows selection actions menu")
            }
        } else {
            ToolbarItem(placement: .primaryAction) {
                HStack(spacing: 4) {
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
}
