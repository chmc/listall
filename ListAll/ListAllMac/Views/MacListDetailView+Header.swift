//
//  MacListDetailView+Header.swift
//  ListAllMac
//
//  Header, search field, and selection mode controls for the detail view.
//

import SwiftUI

extension MacListDetailView {

    // MARK: - Header View

    @ViewBuilder
    var headerView: some View {
        HStack {
            // MARK: - Restore Button (Task 13.1 UX improvement)
            if isCurrentListArchived {
                restoreButton
            }

            Spacer()

            if viewModel.isInSelectionMode && !isCurrentListArchived {
                selectionModeControls
            } else if !isCurrentListArchived {
                searchFieldView
                filterSortControls
                shareButton
                selectionModeButton
                editListButton
            } else {
                searchFieldView
                filterSortControls
                shareButton
            }
        }
        .padding()
    }

    // MARK: - Restore Button (Task 13.1 UX improvement)

    @ViewBuilder
    var restoreButton: some View {
        Button(action: onRestore) {
            HStack(spacing: 4) {
                Image(systemName: "arrow.uturn.backward")
                    .font(.caption)
                Text(String(localized: "Restore"))
                    .font(.caption.weight(.medium))
            }
        }
        .buttonStyle(.borderedProminent)
        .controlSize(.small)
        .accessibilityLabel("Restore this archived list")
        .accessibilityHint("Moves list back to active lists")
    }

    // MARK: - Selection Mode Button

    @ViewBuilder
    var selectionModeButton: some View {
        Button(action: { viewModel.enterSelectionMode() }) {
            Image(systemName: "checklist")
        }
        .buttonStyle(.plain)
        .help("Select Multiple Items")
        .accessibilityIdentifier("SelectItemsButton")
        .accessibilityLabel("Enter selection mode")
        .accessibilityHint("Enables multi-item selection for bulk operations")
    }

    // MARK: - Selection Mode Controls

    @ViewBuilder
    var selectionModeControls: some View {
        HStack(spacing: 12) {
            Text("\(viewModel.selectedItems.count) selected")
                .foregroundColor(.secondary)
                .font(.subheadline)

            Menu {
                Section {
                    Button("Select All") {
                        viewModel.selectAll()
                    }
                    .keyboardShortcut("a", modifiers: .command)

                    Button("Deselect All") {
                        viewModel.deselectAll()
                    }
                }

                Divider()

                Section {
                    Button("Move Items...") {
                        showingMoveItemsPicker = true
                    }
                    .disabled(viewModel.selectedItems.isEmpty)

                    Button("Copy Items...") {
                        showingCopyItemsPicker = true
                    }
                    .disabled(viewModel.selectedItems.isEmpty)
                }

                Divider()

                Section {
                    Button("Delete Items", role: .destructive) {
                        viewModel.deleteSelectedItemsWithUndo()
                        dataManager.loadData()
                    }
                    .disabled(viewModel.selectedItems.isEmpty)
                }
            } label: {
                Image(systemName: "ellipsis.circle")
                    .font(.title3)
            }
            .menuStyle(.borderlessButton)
            .fixedSize()
            .help("Bulk Actions")
            .accessibilityIdentifier("SelectionActionsMenu")
            .accessibilityLabel("Selection actions menu")

            Button("Cancel") {
                viewModel.exitSelectionMode()
            }
            .keyboardShortcut(.escape)
            .accessibilityIdentifier("CancelSelectionButton")
            .accessibilityLabel("Exit selection mode")
        }
    }

    @ViewBuilder
    var shareButton: some View {
        Button(action: { showingSharePopover.toggle() }) {
            Image(systemName: "square.and.arrow.up")
        }
        .buttonStyle(.plain)
        .help("Share List (⇧⌘S)")
        .accessibilityIdentifier("ShareListButton")
        .accessibilityLabel("Share list")
        .popover(isPresented: $showingSharePopover) {
            MacShareFormatPickerView(
                list: currentList ?? list,
                onDismiss: { showingSharePopover = false }
            )
        }
    }

    @ViewBuilder
    var searchFieldView: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.secondary)
                .accessibilityHidden(true)
            TextField(String(localized: "Search items") + "...", text: $viewModel.searchText)
                .textFieldStyle(.plain)
                .frame(width: 150)
                .focused($isSearchFieldFocused)
                .accessibilityIdentifier("ListSearchField")
                .accessibilityLabel("Search items")
                .onExitCommand {
                    if !viewModel.searchText.isEmpty {
                        viewModel.searchText = ""
                    } else if viewModel.hasActiveFilters {
                        viewModel.clearAllFilters()
                    }
                    isSearchFieldFocused = false
                }
            if !viewModel.searchText.isEmpty {
                Button(action: {
                    viewModel.searchText = ""
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Clear search")
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Color.secondary.opacity(0.1))
        .cornerRadius(6)
    }
}
