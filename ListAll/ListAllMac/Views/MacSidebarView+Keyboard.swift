//
//  MacSidebarView+Keyboard.swift
//  ListAllMac
//
//  Keyboard navigation handlers for the sidebar view.
//

import SwiftUI

extension MacSidebarView {

    // MARK: - Keyboard Navigation Handlers (Task 11.1)

    /// Applies all keyboard navigation handlers to the sidebar list
    func sidebarKeyboardHandlers<V: View>(_ content: V) -> some View {
        content
            .onKeyPress(.return) {
                guard !isInSelectionMode else { return .ignored }
                if let focusedID = focusedListID,
                   let list = allVisibleLists.first(where: { $0.id == focusedID }) {
                    selectedList = list
                    return .handled
                }
                return .ignored
            }
            .onKeyPress(.space) {
                if isInSelectionMode {
                    if let focusedID = focusedListID {
                        toggleSelection(for: focusedID)
                        return .handled
                    }
                    return .ignored
                }
                if let focusedID = focusedListID,
                   let list = allVisibleLists.first(where: { $0.id == focusedID }) {
                    selectedList = list
                    return .handled
                }
                return .ignored
            }
            .onKeyPress(.delete) {
                if isInSelectionMode && !selectedLists.isEmpty {
                    let hasArchivedSelection = selectedLists.contains { id in
                        allVisibleLists.first(where: { $0.id == id })?.isArchived == true
                    }
                    if hasArchivedSelection {
                        showingPermanentDeleteConfirmation = true
                    } else {
                        showingArchiveConfirmation = true
                    }
                    return .handled
                }
                if let focusedID = focusedListID,
                   let list = allVisibleLists.first(where: { $0.id == focusedID }) {
                    onDeleteList(list)
                    moveFocusAfterDeletion(deletedId: focusedID)
                    return .handled
                }
                return .ignored
            }
            .onKeyPress(.escape) {
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
    }

    // MARK: - Focus/Selection Sync Handlers

    /// Applies onChange handlers that sync focus with selection
    func sidebarFocusSyncHandlers<V: View>(_ content: V) -> some View {
        content
            .onChange(of: selectedList) { _, newList in
                if let newList = newList {
                    focusedListID = newList.id
                }
            }
            .onChange(of: focusedListID) { _, newFocusedID in
                guard !isInSelectionMode else { return }
                if let newFocusedID = newFocusedID,
                   let list = allVisibleLists.first(where: { $0.id == newFocusedID }) {
                    selectedList = list
                }
            }
    }
}
