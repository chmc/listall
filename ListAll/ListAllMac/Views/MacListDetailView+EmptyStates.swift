//
//  MacListDetailView+EmptyStates.swift
//  ListAllMac
//
//  Empty state views for the detail view.
//

import SwiftUI

extension MacListDetailView {

    // MARK: - Empty State Views (Task 12.7)

    /// Empty state view for lists with no items
    @ViewBuilder
    var emptyListView: some View {
        MacItemsEmptyStateView(
            hasItems: false,
            isArchived: isCurrentListArchived,
            onAddItem: {
                showingAddItemSheet = true
            }
        )
        .accessibilityIdentifier("ItemsEmptyStateView")
    }

    /// Empty state view for search with no results
    @ViewBuilder
    var searchEmptyStateView: some View {
        MacSearchEmptyStateView(
            searchText: viewModel.searchText,
            onClear: {
                viewModel.searchText = ""
                // Refresh items after clearing search
                viewModel.items = items
            }
        )
    }

    /// Empty state view when filters return no matching items
    @ViewBuilder
    var noMatchingItemsView: some View {
        VStack(spacing: 16) {
            Image(systemName: "line.3.horizontal.decrease.circle")
                .font(.system(size: 48))
                .foregroundColor(.secondary)
                .accessibilityHidden(true)

            Text(String(localized: "No Matching Items"))
                .font(.title3)
                .foregroundColor(.secondary)
                .accessibilityAddTraits(.isHeader)

            Text(String(localized: "Try adjusting your filter settings"))
                .font(.caption)
                .foregroundColor(.secondary)

            Button(String(localized: "Clear Filters")) {
                viewModel.searchText = ""
                viewModel.updateFilterOption(.all)
                // CRITICAL: Refresh items from DataManager when clearing all filters
                viewModel.items = items
            }
            .buttonStyle(.borderedProminent)
            .accessibilityLabel("Clear filters")
            .accessibilityHint("Clears all active filters to show all items")
        }
        .accessibilityIdentifier("NoMatchingItemsView")
    }
}
