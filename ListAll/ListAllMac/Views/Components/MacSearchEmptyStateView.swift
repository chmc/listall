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
            // Search icon in circle
            ZStack {
                Circle()
                    .fill(Color.secondary.opacity(0.1))
                    .frame(width: 80, height: 80)

                Image(systemName: "magnifyingglass")
                    .font(.system(size: 32))
                    .foregroundColor(.secondary.opacity(0.4))
            }
            .accessibilityHidden(true)

            // Title
            Text(String(localized: "No Results Found"))
                .font(.title2)
                .fontWeight(.bold)
                .accessibilityAddTraits(.isHeader)

            // Search query display - single line with teal term
            HStack(spacing: 4) {
                Text(String(localized: "No items matching"))
                    .font(.body)
                    .foregroundColor(.secondary)

                Text("\"\(searchText)\"")
                    .font(.body)
                    .fontWeight(.medium)
                    .foregroundColor(Theme.Colors.primary)
                    .lineLimit(1)
            }

            // Clear search button - bordered (not prominent) per mockup
            Button(action: onClear) {
                Text(String(localized: "Clear Search"))
                    .font(.callout)
            }
            .buttonStyle(.bordered)
            .accessibilityLabel("Clear search")
            .accessibilityHint("Clears the search text to show all items")

            // Tips - simple centered bullet text
            VStack(spacing: 6) {
                MacCenteredTipRow(text: String(localized: "Check spelling or try fewer words"))
                MacCenteredTipRow(text: String(localized: "Search matches item names and notes"))
                MacCenteredTipRow(text: String(localized: "Try searching in a different list"))
            }
            .padding(.top, 4)
        }
        .padding(.horizontal, 32)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("SearchEmptyStateView")
    }
}

// MARK: - Centered Tip Row

/// Simple centered bullet-point tip for search empty state.
struct MacCenteredTipRow: View {
    let text: String

    var body: some View {
        HStack(spacing: 6) {
            Text("\u{2022}")
                .font(.callout)
                .foregroundColor(.secondary.opacity(0.5))

            Text(text)
                .font(.callout)
                .foregroundColor(.secondary)
        }
    }
}

#Preview("Search Empty State") {
    MacSearchEmptyStateView(
        searchText: "avocado toast",
        onClear: { }
    )
    .frame(width: 500, height: 450)
}
