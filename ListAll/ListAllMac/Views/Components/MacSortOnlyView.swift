//
//  MacSortOnlyView.swift
//  ListAllMac
//
//  Created for Task 12.4: Sort-only popover view for macOS.
//  Extracted from MacItemOrganizationView when filters moved to segmented control.
//

import SwiftUI

/// macOS sort-only controls popover view.
/// This is displayed when clicking the sort button in the toolbar.
/// Filters have been moved to a segmented control (Task 12.4), so this
/// view only shows sort options and drag-to-reorder indicator.
struct MacSortOnlyView: View {
    @ObservedObject var viewModel: ListViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // MARK: - Sort Section
            sortSection

            // MARK: - Drag-to-reorder indicator
            if viewModel.currentSortOption == .orderNumber {
                dragReorderIndicator
            }
        }
        .padding(16)
        .frame(width: 280)
    }

    // MARK: - Sort Section

    private var sortSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Sorting", systemImage: "arrow.up.arrow.down")
                .font(.headline)
                .foregroundColor(.primary)
                .accessibilityAddTraits(.isHeader)

            // Sort options grid (2 columns)
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 8) {
                ForEach(ItemSortOption.allCases, id: \.self) { option in
                    SortOptionButton(
                        option: option,
                        isSelected: viewModel.currentSortOption == option,
                        onTap: { viewModel.updateSortOption(option) }
                    )
                }
            }

            // Sort direction toggle
            HStack {
                Text("Direction:")
                    .font(.subheadline)
                    .foregroundColor(.secondary)

                Spacer()

                Button(action: {
                    let newDirection: SortDirection = viewModel.currentSortDirection == .ascending ? .descending : .ascending
                    viewModel.updateSortDirection(newDirection)
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: viewModel.currentSortDirection.systemImage)
                        Text(viewModel.currentSortDirection.displayName)
                    }
                    .font(.subheadline)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Color.accentColor.opacity(0.1))
                    .cornerRadius(6)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Sort direction")
                .accessibilityValue(viewModel.currentSortDirection.displayName)
            }
            .padding(.top, 4)
        }
    }

    // MARK: - Drag-to-reorder Indicator

    private var dragReorderIndicator: some View {
        HStack(spacing: 6) {
            Image(systemName: "hand.draw")
                .foregroundColor(.green)
            Text("Drag-to-reorder enabled")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(.top, 4)
    }
}

// MARK: - Sort Option Button

private struct SortOptionButton: View {
    let option: ItemSortOption
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 6) {
                Image(systemName: option.systemImage)
                    .font(.system(size: 12))
                    .foregroundColor(isSelected ? .accentColor : .secondary)

                Text(option.displayName)
                    .font(.subheadline)
                    .foregroundColor(isSelected ? .primary : .secondary)
                    .lineLimit(1)

                Spacer()

                if isSelected {
                    Image(systemName: "checkmark")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.accentColor)
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(isSelected ? Color.accentColor.opacity(0.1) : Color.secondary.opacity(0.05))
            .cornerRadius(6)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(option.displayName)
        .accessibilityValue(isSelected ? "Selected" : "")
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
    }
}

#Preview {
    MacSortOnlyView(viewModel: ListViewModel(list: List(name: "Preview List")))
}
