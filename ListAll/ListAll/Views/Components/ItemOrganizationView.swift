import SwiftUI

struct ItemOrganizationView: View {
    @ObservedObject var viewModel: ListViewModel
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            Form {
                // Sort Options Section
                Section {
                    VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                        Text(String(localized: "Sort By"))
                            .font(Theme.Typography.headline)
                        
                        LazyVGrid(columns: [
                            GridItem(.flexible()),
                            GridItem(.flexible())
                        ], spacing: Theme.Spacing.sm) {
                            ForEach(ItemSortOption.allCases) { option in
                                Button(action: {
                                    viewModel.updateSortOption(option)
                                }) {
                                    HStack {
                                        Image(systemName: option.systemImage)
                                        Text(option.displayName)
                                        Spacer()
                                        if viewModel.currentSortOption == option {
                                            Image(systemName: "checkmark")
                                                .foregroundColor(.blue)
                                        }
                                    }
                                    .padding(Theme.Spacing.sm)
                                    .background(
                                        RoundedRectangle(cornerRadius: Theme.CornerRadius.sm)
                                            .fill(viewModel.currentSortOption == option ? 
                                                  Color.blue.opacity(0.1) : Color.gray.opacity(0.1))
                                    )
                                }
                                .buttonStyle(PlainButtonStyle())
                                .foregroundColor(.primary)
                            }
                        }
                        
                        // Sort Direction
                        HStack {
                            Text(String(localized: "Direction"))
                                .font(Theme.Typography.body)
                            
                            Spacer()
                            
                            Button(action: {
                                viewModel.updateSortDirection(
                                    viewModel.currentSortDirection == .ascending ? .descending : .ascending
                                )
                            }) {
                                HStack {
                                    Image(systemName: viewModel.currentSortDirection.systemImage)
                                    Text(viewModel.currentSortDirection.displayName)
                                }
                                .padding(.horizontal, Theme.Spacing.md)
                                .padding(.vertical, Theme.Spacing.sm)
                                .background(
                                    RoundedRectangle(cornerRadius: Theme.CornerRadius.sm)
                                        .fill(Color.blue.opacity(0.1))
                                )
                            }
                            .buttonStyle(PlainButtonStyle())
                            .foregroundColor(.blue)
                        }
                        
                        // Manual reordering note
                        if viewModel.currentSortOption == .orderNumber {
                            HStack(spacing: Theme.Spacing.sm) {
                                Image(systemName: "hand.draw")
                                    .foregroundColor(.green)
                                Text(String(localized: "Drag-to-reorder enabled"))
                                    .font(Theme.Typography.caption)
                                    .foregroundColor(.secondary)
                            }
                            .padding(.top, Theme.Spacing.xs)
                        } else {
                            HStack(spacing: Theme.Spacing.sm) {
                                Image(systemName: "hand.raised.slash")
                                    .foregroundColor(.orange)
                                Text(String(localized: "Drag-to-reorder disabled (change to 'Order' to enable)"))
                                    .font(Theme.Typography.caption)
                                    .foregroundColor(.secondary)
                            }
                            .padding(.top, Theme.Spacing.xs)
                        }
                    }
                } header: {
                    Label(String(localized: "Sorting"), systemImage: "arrow.up.arrow.down")
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
                                    Spacer()
                                    if viewModel.currentFilterOption == option {
                                        Image(systemName: "checkmark")
                                            .foregroundColor(.blue)
                                    }
                                }
                                .padding(Theme.Spacing.sm)
                                .background(
                                    RoundedRectangle(cornerRadius: Theme.CornerRadius.sm)
                                        .fill(viewModel.currentFilterOption == option ? 
                                              Color.blue.opacity(0.1) : Color.gray.opacity(0.1))
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
                                .foregroundColor(.blue)
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
            .navigationTitle(String(localized: "Organization"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(String(localized: "Done")) {
                        dismiss()
                    }
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
