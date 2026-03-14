//
//  MacSidebarView+Rows.swift
//  ListAllMac
//
//  Sidebar row building methods for selection and normal modes.
//

import SwiftUI

extension MacSidebarView {

    // MARK: - List Row Content

    /// Helper to format item count display
    func itemCountText(for list: List) -> String {
        MacSidebarFormatting.itemCountText(for: list)
    }

    /// Returns active and total counts for a list
    func itemCounts(for list: List) -> (active: Int, total: Int) {
        let activeCount = list.items.filter { !$0.isCrossedOut }.count
        return (activeCount, list.items.count)
    }

    /// Whether a list is currently selected
    func isSelected(_ list: List) -> Bool {
        selectedList?.id == list.id
    }

    /// Builds a list row for selection mode
    @ViewBuilder
    func selectionModeRow(for list: List) -> some View {
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
    func sidebarRowContent(for list: List) -> some View {
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
    func normalModeRow(for list: List) -> some View {
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
    var syncStatusFooter: some View {
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
}
