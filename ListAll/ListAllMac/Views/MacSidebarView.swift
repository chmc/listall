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
    @ObservedObject private(set) var coreDataManager = CoreDataManager.shared

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
    var lastSyncTooltip: String {
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
}
