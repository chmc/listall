import SwiftUI

struct ItemOrganizationView: View {
    @ObservedObject var viewModel: ListViewModel
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            Form {
                // Sort Options Section
                Section {
                    LazyVGrid(columns: [
                        GridItem(.flexible()),
                        GridItem(.flexible()),
                        GridItem(.flexible())
                    ], spacing: Theme.Spacing.sm) {
                        ForEach(ItemSortOption.pillDisplayOrder) { option in
                            let isSelected = viewModel.currentSortOption == option
                            Button(action: {
                                viewModel.updateSortOption(option)
                            }) {
                                Text(option.shortDisplayName)
                                    .font(.subheadline.weight(.medium))
                                    .lineLimit(1)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, Theme.Spacing.sm)
                                    .padding(.horizontal, Theme.Spacing.xs)
                                    .foregroundColor(isSelected ? .white : .secondary)
                                    .background(
                                        Capsule()
                                            .fill(isSelected ? Theme.Colors.primary : Color.clear)
                                    )
                                    .overlay(
                                        Capsule()
                                            .strokeBorder(isSelected ? Color.clear : Color.secondary.opacity(0.3), lineWidth: 1)
                                    )
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                    }

                } header: {
                    Text(String(localized: "Sort By"))
                        .font(.caption)
                        .fontWeight(.semibold)
                        .tracking(0.8)
                        .foregroundColor(.secondary)
                        .textCase(.uppercase)
                }

                // Sort Direction Section
                Section {
                    HStack(spacing: Theme.Spacing.sm) {
                        ForEach(SortDirection.allCases) { direction in
                            let isSelected = viewModel.currentSortDirection == direction
                            Button(action: {
                                viewModel.updateSortDirection(direction)
                            }) {
                                Text(direction.displayName)
                                    .font(.subheadline.weight(.medium))
                                    .lineLimit(1)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, Theme.Spacing.sm)
                                    .padding(.horizontal, Theme.Spacing.xs)
                                    .foregroundColor(isSelected ? .white : .secondary)
                                    .background(
                                        Capsule()
                                            .fill(isSelected ? Theme.Colors.primary : Color.clear)
                                    )
                                    .overlay(
                                        Capsule()
                                            .strokeBorder(isSelected ? Color.clear : Color.secondary.opacity(0.3), lineWidth: 1)
                                    )
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                    }
                } header: {
                    Text(String(localized: "Sort Direction"))
                        .font(.caption)
                        .fontWeight(.semibold)
                        .tracking(0.8)
                        .foregroundColor(.secondary)
                        .textCase(.uppercase)
                }
                
                // Filter Options Section
                Section {
                    FilterChipFlowLayout(spacing: Theme.Spacing.sm) {
                        ForEach(ItemFilterOption.chipDisplayOrder) { option in
                            let isSelected = viewModel.currentFilterOption == option
                            Button(action: {
                                viewModel.updateFilterOption(option)
                            }) {
                                Text(option.chipDisplayName)
                                    .font(.subheadline.weight(.medium))
                                    .lineLimit(1)
                                    .padding(.vertical, Theme.Spacing.sm)
                                    .padding(.horizontal, Theme.Spacing.md)
                                    .foregroundColor(isSelected ? .white : .secondary)
                                    .background(
                                        Capsule()
                                            .fill(isSelected ? Theme.Colors.primary : Color.clear)
                                    )
                                    .overlay(
                                        Capsule()
                                            .strokeBorder(isSelected ? Color.clear : Color.secondary.opacity(0.3), lineWidth: 1)
                                    )
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                    }
                } header: {
                    Text(String(localized: "Filter"))
                        .font(.caption)
                        .fontWeight(.semibold)
                        .tracking(0.8)
                        .foregroundColor(.secondary)
                        .textCase(.uppercase)
                }
                
                // Summary Stat Cards Section
                Section {
                    HStack(spacing: 0) {
                        statCard(
                            value: viewModel.items.count,
                            label: String(localized: "Total"),
                            valueColor: .secondary
                        )
                        statCard(
                            value: viewModel.filteredItems.count,
                            label: String(localized: "Filtered"),
                            valueColor: .secondary
                        )
                        statCard(
                            value: viewModel.activeItems.count,
                            label: String(localized: "Active"),
                            valueColor: Theme.Colors.primary
                        )
                        statCard(
                            value: viewModel.completedItems.count,
                            label: String(localized: "Completed"),
                            valueColor: Theme.Colors.completedGreen
                        )
                    }
                    .padding(.vertical, Theme.Spacing.sm)
                } header: {
                    Text(String(localized: "Summary"))
                        .font(.caption)
                        .fontWeight(.semibold)
                        .tracking(0.8)
                        .foregroundColor(.secondary)
                        .textCase(.uppercase)
                }
            }
            .tint(Theme.Colors.primary)
            .navigationTitle(String(localized: "Sort & Filter"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    if viewModel.hasActiveFilters {
                        Button(action: {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                viewModel.clearAllFilters()
                            }
                        }) {
                            Text(String(localized: "Reset"))
                                .foregroundColor(.red)
                        }
                        .accessibilityLabel(String(localized: "Reset all filters and sorting to defaults"))
                        .accessibilityIdentifier("resetFiltersButton")
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(String(localized: "Done")) {
                        dismiss()
                    }
                    .foregroundColor(Theme.Colors.primary)
                    .accessibilityIdentifier("OrganizationDoneButton")
                }
            }
        }
    }
}

// MARK: - Stat Card Helper

extension ItemOrganizationView {
    func statCard(value: Int, label: String, valueColor: Color) -> some View {
        VStack(spacing: 2) {
            Text("\(value)")
                .font(.title2.weight(.bold).monospacedDigit())
                .foregroundColor(valueColor)
                .contentTransition(.numericText())
            Text(label)
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Flow Layout for Filter Chips

struct FilterChipFlowLayout: Layout {
    var spacing: CGFloat

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = arrangeSubviews(proposal: proposal, subviews: subviews)
        return result.size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = arrangeSubviews(proposal: ProposedViewSize(width: bounds.width, height: bounds.height), subviews: subviews)
        for (index, subview) in subviews.enumerated() {
            let point = CGPoint(x: bounds.minX + result.positions[index].x, y: bounds.minY + result.positions[index].y)
            subview.place(at: point, anchor: .topLeading, proposal: .unspecified)
        }
    }

    private func arrangeSubviews(proposal: ProposedViewSize, subviews: Subviews) -> (positions: [CGPoint], size: CGSize) {
        let maxWidth = proposal.width ?? .infinity
        var positions: [CGPoint] = []
        var currentX: CGFloat = 0
        var currentY: CGFloat = 0
        var rowHeight: CGFloat = 0
        var maxX: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if currentX + size.width > maxWidth && currentX > 0 {
                currentX = 0
                currentY += rowHeight + spacing
                rowHeight = 0
            }
            positions.append(CGPoint(x: currentX, y: currentY))
            rowHeight = max(rowHeight, size.height)
            currentX += size.width + spacing
            maxX = max(maxX, currentX - spacing)
        }

        return (positions, CGSize(width: maxX, height: currentY + rowHeight))
    }
}

#Preview {
    let sampleList = List(name: "Sample List")
    let viewModel = ListViewModel(list: sampleList)
    
    return ItemOrganizationView(viewModel: viewModel)
}
