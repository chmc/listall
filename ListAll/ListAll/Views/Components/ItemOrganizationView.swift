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
                        Text("Sort By")
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
                                        Text(option.rawValue)
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
                            Text("Direction")
                                .font(Theme.Typography.body)
                            
                            Spacer()
                            
                            Button(action: {
                                viewModel.updateSortDirection(
                                    viewModel.currentSortDirection == .ascending ? .descending : .ascending
                                )
                            }) {
                                HStack {
                                    Image(systemName: viewModel.currentSortDirection.systemImage)
                                    Text(viewModel.currentSortDirection.rawValue)
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
                                Text("Drag-to-reorder enabled")
                                    .font(Theme.Typography.caption)
                                    .foregroundColor(.secondary)
                            }
                            .padding(.top, Theme.Spacing.xs)
                        } else {
                            HStack(spacing: Theme.Spacing.sm) {
                                Image(systemName: "hand.raised.slash")
                                    .foregroundColor(.orange)
                                Text("Drag-to-reorder disabled (change to 'Order' to enable)")
                                    .font(Theme.Typography.caption)
                                    .foregroundColor(.secondary)
                            }
                            .padding(.top, Theme.Spacing.xs)
                        }
                    }
                } header: {
                    Label("Sorting", systemImage: "arrow.up.arrow.down")
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
                                    Text(option.rawValue)
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
                    Label("Filtering", systemImage: "line.3.horizontal.decrease")
                }
                
                // Current Status Section
                Section {
                    VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                        HStack {
                            Text("Total Items:")
                            Spacer()
                            Text("\(viewModel.items.count)")
                                .foregroundColor(.secondary)
                        }
                        
                        HStack {
                            Text("Filtered Items:")
                            Spacer()
                            Text("\(viewModel.filteredItems.count)")
                                .foregroundColor(.blue)
                        }
                        
                        HStack {
                            Text("Active Items:")
                            Spacer()
                            Text("\(viewModel.activeItems.count)")
                                .foregroundColor(.green)
                        }
                        
                        HStack {
                            Text("Completed Items:")
                            Spacer()
                            Text("\(viewModel.completedItems.count)")
                                .foregroundColor(.orange)
                        }
                    }
                } header: {
                    Label("Summary", systemImage: "chart.bar")
                }
            }
            .navigationTitle("Organization")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
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
