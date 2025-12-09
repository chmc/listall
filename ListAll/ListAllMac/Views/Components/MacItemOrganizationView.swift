//
//  MacItemOrganizationView.swift
//  ListAllMac
//
//  macOS-specific filter and sort controls for items.
//  Reuses shared ListViewModel logic for filtering/sorting.
//

import SwiftUI

/// macOS filter and sort controls popover view.
/// This is the macOS equivalent of iOS ItemOrganizationView,
/// designed for popover presentation from the toolbar.
struct MacItemOrganizationView: View {
    @ObservedObject var viewModel: ListViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // MARK: - Sort Section
            sortSection

            Divider()

            // MARK: - Filter Section
            filterSection

            Divider()

            // MARK: - Summary Section
            summarySection

            // MARK: - Drag-to-reorder indicator
            if viewModel.currentSortOption == .orderNumber {
                dragReorderIndicator
            }
        }
        .padding(16)
        .frame(width: 320)
    }

    // MARK: - Sort Section

    private var sortSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Sorting", systemImage: "arrow.up.arrow.down")
                .font(.headline)
                .foregroundColor(.primary)

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
            }
            .padding(.top, 4)
        }
    }

    // MARK: - Filter Section

    private var filterSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Filtering", systemImage: "line.3.horizontal.decrease")
                .font(.headline)
                .foregroundColor(.primary)

            // Filter options (vertical list)
            VStack(spacing: 6) {
                ForEach(ItemFilterOption.allCases, id: \.self) { option in
                    FilterOptionButton(
                        option: option,
                        isSelected: viewModel.currentFilterOption == option,
                        onTap: { viewModel.updateFilterOption(option) }
                    )
                }
            }
        }
    }

    // MARK: - Summary Section

    private var summarySection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Summary", systemImage: "info.circle")
                .font(.headline)
                .foregroundColor(.primary)

            VStack(spacing: 4) {
                SummaryRow(
                    label: "Total Items",
                    value: viewModel.items.count,
                    color: .secondary
                )
                SummaryRow(
                    label: "Filtered Items",
                    value: viewModel.filteredItems.count,
                    color: .accentColor
                )
                SummaryRow(
                    label: "Active Items",
                    value: viewModel.items.filter { !$0.isCrossedOut }.count,
                    color: .green
                )
                SummaryRow(
                    label: "Completed Items",
                    value: viewModel.items.filter { $0.isCrossedOut }.count,
                    color: .orange
                )
            }
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
    }
}

// MARK: - Filter Option Button

private struct FilterOptionButton: View {
    let option: ItemFilterOption
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 8) {
                Image(systemName: option.systemImage)
                    .font(.system(size: 14))
                    .foregroundColor(isSelected ? .accentColor : .secondary)
                    .frame(width: 20)

                Text(option.displayName)
                    .font(.subheadline)
                    .foregroundColor(isSelected ? .primary : .secondary)

                Spacer()

                if isSelected {
                    Image(systemName: "checkmark")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.accentColor)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(isSelected ? Color.accentColor.opacity(0.1) : Color.secondary.opacity(0.05))
            .cornerRadius(6)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Summary Row

private struct SummaryRow: View {
    let label: String
    let value: Int
    let color: Color

    var body: some View {
        HStack {
            Text(label)
                .font(.subheadline)
                .foregroundColor(.secondary)
            Spacer()
            Text("\(value)")
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(color)
        }
    }
}

#Preview {
    MacItemOrganizationView(viewModel: ListViewModel(list: List(name: "Preview List")))
}
