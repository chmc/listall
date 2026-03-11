//
//  MacSearchEmptyStateView.swift
//  ListAllMac
//
//  Empty state view shown when search returns no results.
//

import SwiftUI
import AppKit

// MARK: - Search Empty State View

/// Empty state view shown when search returns no results.
/// Provides clear messaging about the search query and option to clear search.
struct MacSearchEmptyStateView: View {
    let searchText: String
    let onClear: () -> Void

    var body: some View {
        VStack(spacing: 20) {
            // Search icon
            Image(systemName: "magnifyingglass")
                .font(.system(size: 48))
                .foregroundColor(.secondary)
                .accessibilityHidden(true)

            // Title
            Text(String(localized: "No Results Found"))
                .font(.title2)
                .fontWeight(.semibold)
                .accessibilityAddTraits(.isHeader)

            // Search query display
            VStack(spacing: 4) {
                Text(String(localized: "No items match"))
                    .font(.body)
                    .foregroundColor(.secondary)

                Text("\"\(searchText)\"")
                    .font(.body)
                    .fontWeight(.medium)
                    .foregroundColor(.primary)
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
            }

            // Clear search button
            Button(action: onClear) {
                HStack(spacing: 6) {
                    Image(systemName: "xmark.circle")
                    Text(String(localized: "Clear Search"))
                }
                .font(.headline)
            }
            .buttonStyle(.borderedProminent)
            .accessibilityLabel("Clear search")
            .accessibilityHint("Clears the search text to show all items")

            // Tips section
            VStack(alignment: .leading, spacing: 8) {
                Text(String(localized: "Search Tips"))
                    .font(.headline)
                    .padding(.top, 8)

                MacTipRow(icon: "textformat", text: String(localized: "Check for typos in your search"))
                MacTipRow(icon: "magnifyingglass", text: String(localized: "Try searching for part of the item name"))
                MacTipRow(icon: "line.3.horizontal.decrease", text: String(localized: "Check if filters are hiding results"))
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color(NSColor.controlBackgroundColor))
            )
        }
        .padding(.horizontal, 32)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("SearchEmptyStateView")
    }
}

#Preview("Search Empty State") {
    MacSearchEmptyStateView(
        searchText: "nonexistent item",
        onClear: { }
    )
    .frame(width: 500, height: 450)
}
