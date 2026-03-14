//
//  MacSidebarView+Toolbar.swift
//  ListAllMac
//
//  Toolbar content for sidebar: normal mode and selection mode.
//

import SwiftUI

extension MacSidebarView {

    // MARK: - Bulk Action Button (extracted for type-checker performance)

    /// Check if any selected lists are archived
    var hasArchivedSelection: Bool {
        selectedLists.contains { id in
            allVisibleLists.first(where: { $0.id == id })?.isArchived == true
        }
    }

    /// Builds the appropriate bulk action buttons based on selected lists
    @ViewBuilder
    var bulkActionButton: some View {
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

    // MARK: - Toolbar Content

    @ToolbarContentBuilder
    var sidebarToolbarContent: some ToolbarContent {
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
