//
//  MacSidebarView+Alerts.swift
//  ListAllMac
//
//  Sheet, alert, and notification handlers for the sidebar view.
//

import SwiftUI

extension MacSidebarView {

    // MARK: - Sheets & Alerts

    /// Applies all sheet, alert, and notification modifiers to the sidebar
    func sidebarSheetsAndAlerts<V: View>(_ content: V) -> some View {
        content
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
                        dataManager.restoreList(withId: list.id)
                        dataManager.loadArchivedData()
                        dataManager.loadData()
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
            .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("RestoreSelectedList"))) { _ in
                guard let list = selectedList, list.isArchived else { return }
                listToRestore = list
                showingRestoreConfirmation = true
            }
            // MARK: - Archived Section Collapse Handler
            .onChange(of: isArchivedSectionExpanded) { _, isExpanded in
                if !isExpanded {
                    if let current = selectedList, current.isArchived {
                        selectedList = nil
                    }
                    if let focusedID = focusedListID,
                       archivedLists.contains(where: { $0.id == focusedID }) {
                        focusedListID = nil
                    }
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
