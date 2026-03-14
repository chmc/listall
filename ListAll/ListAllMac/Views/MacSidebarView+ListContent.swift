//
//  MacSidebarView+ListContent.swift
//  ListAllMac
//
//  Sidebar list sections: active lists, archived lists, and section headers.
//

import SwiftUI

extension MacSidebarView {

    // MARK: - List Content

    var sidebarListContent: some View {
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

    var archivedSectionHeader: some View {
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
}
