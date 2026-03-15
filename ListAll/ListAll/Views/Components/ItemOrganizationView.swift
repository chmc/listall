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
                    VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                        ForEach(ItemFilterOption.allCases) { option in
                            Button(action: {
                                viewModel.updateFilterOption(option)
                            }) {
                                HStack {
                                    Image(systemName: option.systemImage)
                                        .frame(width: 20)
                                    Text(option.displayName)
                                        .lineLimit(2)
                                        .minimumScaleFactor(0.8)
                                    Spacer()
                                    if viewModel.currentFilterOption == option {
                                        Image(systemName: "checkmark")
                                            .foregroundColor(Theme.Colors.primary)
                                    }
                                }
                                .padding(Theme.Spacing.sm)
                                .background(
                                    RoundedRectangle(cornerRadius: Theme.CornerRadius.sm)
                                        .fill(viewModel.currentFilterOption == option ?
                                              Theme.Colors.primary.opacity(0.1) : Color.gray.opacity(0.1))
                                )
                            }
                            .buttonStyle(PlainButtonStyle())
                            .foregroundColor(.primary)
                        }
                    }
                } header: {
                    Label(String(localized: "Filtering"), systemImage: "line.3.horizontal.decrease")
                }
                
                // Current Status Section
                Section {
                    VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                        HStack {
                            Text(String(localized: "Total Items:"))
                            Spacer()
                            Text("\(viewModel.items.count)")
                                .foregroundColor(.secondary)
                        }
                        
                        HStack {
                            Text(String(localized: "Filtered Items:"))
                            Spacer()
                            Text("\(viewModel.filteredItems.count)")
                                .foregroundColor(Theme.Colors.primary)
                        }
                        
                        HStack {
                            Text(String(localized: "Active Items:"))
                            Spacer()
                            Text("\(viewModel.activeItems.count)")
                                .foregroundColor(.green)
                        }
                        
                        HStack {
                            Text(String(localized: "Completed Items:"))
                            Spacer()
                            Text("\(viewModel.completedItems.count)")
                                .foregroundColor(.orange)
                        }
                    }
                } header: {
                    Label(String(localized: "Summary"), systemImage: "chart.bar")
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

#Preview {
    let sampleList = List(name: "Sample List")
    let viewModel = ListViewModel(list: sampleList)
    
    return ItemOrganizationView(viewModel: viewModel)
}
