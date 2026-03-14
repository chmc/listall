//
//  MacListDetailView+Filters.swift
//  ListAllMac
//
//  Filter, sort controls and active filters bar for the detail view.
//

import SwiftUI

extension MacListDetailView {

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
                            viewModel.items = items
                        }
                    )
                }

                // Clear All button (Task 12.12)
                if activeFilterCount > 1 {
                    Button(action: {
                        viewModel.clearAllFilters()
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
