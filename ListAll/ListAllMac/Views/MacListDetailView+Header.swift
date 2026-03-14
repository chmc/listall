//
//  MacListDetailView+Header.swift
//  ListAllMac
//
//  Header, toolbar, filter controls, and empty state views for the detail view.
//

import SwiftUI

extension MacListDetailView {

    // MARK: - Header View

    @ViewBuilder
    var headerView: some View {
        HStack {
            // MARK: - Restore Button (Task 13.1 UX improvement)
            // Show Restore button instead of badge for better discoverability
            if isCurrentListArchived {
                restoreButton
            }

            Spacer()

            if viewModel.isInSelectionMode && !isCurrentListArchived {
                // Selection mode header controls (disabled for archived lists)
                selectionModeControls
            } else if !isCurrentListArchived {
                // Normal mode header controls (all editing disabled for archived lists)
                searchFieldView
                filterSortControls
                shareButton
                selectionModeButton
                editListButton
            } else {
                // Archived list: only show view-only controls
                searchFieldView
                filterSortControls
                shareButton
                // No selection mode or edit buttons for archived lists
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
            // Selection count
            Text("\(viewModel.selectedItems.count) selected")
                .foregroundColor(.secondary)
                .font(.subheadline)

            // Ellipsis menu for bulk actions
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
                        // Task 12.8: Use undo banner instead of confirmation dialog
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

            // Cancel button
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
                    // Enhanced Escape behavior (Task 12.12):
                    // 1. First press: clears search text (if not empty)
                    // 2. Second press: clears all filters (if search was empty but filters active)
                    if !viewModel.searchText.isEmpty {
                        // First: clear search text
                        viewModel.searchText = ""
                    } else if viewModel.hasActiveFilters {
                        // Second: clear all filters when search is already empty
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

    // MARK: - Filter & Sort Controls (Task 12.4)

    @ViewBuilder
    var filterSortControls: some View {
        HStack(spacing: 8) {
            // Filter segmented control - always visible, single click
            Picker("Filter", selection: $viewModel.currentFilterOption) {
                Text("All").tag(ItemFilterOption.all)
                Text("Active").tag(ItemFilterOption.active)
                Text("Done").tag(ItemFilterOption.completed)
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .frame(width: 180)
            .help("Filter items by status (Cmd+1/2/3)")
            .accessibilityIdentifier("FilterSegmentedControl")
            .onChange(of: viewModel.currentFilterOption) { _, newValue in
                // Sync showCrossedOutItems state when filter changes via Picker
                // This ensures "All" filter properly shows all items
                viewModel.updateFilterOption(newValue)
            }

            // Sort button - keeps popover for less-frequent sort options
            Button(action: { showingOrganizationPopover.toggle() }) {
                Image(systemName: "arrow.up.arrow.down")
            }
            .buttonStyle(.plain)
            .help("Sort Options")
            .accessibilityIdentifier("SortButton")
            .accessibilityLabel("Sort items")
            .accessibilityHint("Opens sort options")
            .popover(isPresented: $showingOrganizationPopover) {
                MacSortOnlyView(viewModel: viewModel)
            }
        }
    }

    @ViewBuilder
    var editListButton: some View {
        Button(action: { showingEditListSheet = true }) {
            Image(systemName: "pencil")
        }
        .buttonStyle(.plain)
        .help("Edit List")
        .accessibilityIdentifier("EditListButton")
        .accessibilityLabel("Edit list name")
    }

    // MARK: - Active Filters Bar

    @ViewBuilder
    var activeFiltersBar: some View {
        if hasActiveFilters {
            HStack(spacing: 12) {
                if !viewModel.searchText.isEmpty {
                    FilterBadge(
                        icon: "magnifyingglass",
                        text: "Search: \"\(viewModel.searchText)\"",
                        onClear: {
                            viewModel.searchText = ""
                            // CRITICAL: Refresh items from DataManager when clearing search
                            viewModel.items = items
                        }
                    )
                }

                if viewModel.currentFilterOption != .all {
                    FilterBadge(
                        icon: viewModel.currentFilterOption.systemImage,
                        text: viewModel.currentFilterOption.displayName,
                        onClear: {
                            viewModel.updateFilterOption(.all)
                            // CRITICAL: Refresh items from DataManager when clearing filter
                            viewModel.items = items
                        }
                    )
                }

                if viewModel.currentSortOption != .orderNumber {
                    let sortText = "\(viewModel.currentSortOption.displayName) (\(viewModel.currentSortDirection.displayName))"
                    FilterBadge(
                        icon: viewModel.currentSortOption.systemImage,
                        text: sortText,
                        onClear: {
                            viewModel.updateSortOption(.orderNumber)
                            // CRITICAL: Refresh items from DataManager when clearing sort
                            viewModel.items = items
                        }
                    )
                }

                // Clear All button (Task 12.12)
                // Shows when multiple filters are active or as a convenience
                if activeFilterCount > 1 {
                    Button(action: {
                        viewModel.clearAllFilters()
                        // CRITICAL: Refresh items from DataManager when clearing all filters
                        viewModel.items = items
                    }) {
                        Text("Clear All")
                            .font(.caption)
                    }
                    .buttonStyle(.plain)
                    .foregroundColor(.accentColor)
                    .help("Clear all filters (Cmd+Shift+Delete)")
                    .accessibilityIdentifier("ClearAllFiltersButton")
                }

                Spacer()

                Text("\(viewModel.filteredItems.count) of \(viewModel.items.count) items")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .numericContentTransition()
            }
            .padding(.horizontal)
            .padding(.bottom, 8)
        }
    }

}
