import SwiftUI

struct ListView: View {
    let list: List
    @StateObject private var viewModel: ListViewModel
    @State private var showingCreateItem = false
    @State private var showingEditItem = false
    @State private var selectedItem: Item?
    
    init(list: List) {
        self.list = list
        self._viewModel = StateObject(wrappedValue: ListViewModel(list: list))
    }
    
    var body: some View {
        VStack {
            if viewModel.isLoading {
                ProgressView("Loading items...")
            } else if viewModel.filteredItems.isEmpty {
                VStack(spacing: Theme.Spacing.lg) {
                    Image(systemName: "list.bullet.rectangle")
                        .font(.system(size: 60))
                        .foregroundColor(Theme.Colors.secondary)
                    
                    Text(viewModel.items.isEmpty ? "No Items Yet" : "No Active Items")
                        .font(Theme.Typography.title)
                    
                    Text(viewModel.items.isEmpty ? "Add your first item to get started" : "All items are crossed out. Toggle the eye icon to show them.")
                        .font(Theme.Typography.body)
                        .emptyStateStyle()
                    
                    Button(action: {
                        showingCreateItem = true
                    }) {
                        HStack {
                            Image(systemName: Constants.UI.addIcon)
                            Text("Add Item")
                        }
                        .font(Theme.Typography.headline)
                        .foregroundColor(.white)
                        .padding()
                        .background(Theme.Colors.primary)
                        .cornerRadius(Theme.CornerRadius.md)
                    }
                }
            } else {
                SwiftUI.List {
                    ForEach(viewModel.filteredItems) { item in
                        ItemRowView(
                            item: item,
                            onToggle: {
                                viewModel.toggleItemCrossedOut(item)
                            },
                            onEdit: {
                                selectedItem = item
                                showingEditItem = true
                            },
                            onDuplicate: {
                                viewModel.duplicateItem(item)
                            },
                            onDelete: {
                                viewModel.deleteItem(item)
                            }
                        )
                    }
                    .onDelete(perform: deleteItems)
                    .onMove(perform: viewModel.moveItems)
                }
                .refreshable {
                    viewModel.loadItems()
                }
            }
        }
        .navigationTitle(list.name)
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItemGroup(placement: .navigationBarTrailing) {
                if !viewModel.items.isEmpty {
                    // Organization options button
                    Button(action: {
                        viewModel.showingOrganizationOptions = true
                    }) {
                        Image(systemName: "arrow.up.arrow.down")
                            .foregroundColor(.primary)
                    }
                    .help("Sort and filter options")
                    
                    // Show/Hide crossed out items toggle (legacy support)
                    Button(action: {
                        viewModel.toggleShowCrossedOutItems()
                    }) {
                        Image(systemName: viewModel.showCrossedOutItems ? "eye" : "eye.slash")
                            .foregroundColor(viewModel.showCrossedOutItems ? .primary : .secondary)
                    }
                    .help(viewModel.showCrossedOutItems ? "Hide crossed out items" : "Show crossed out items")
                    
                    EditButton()
                }
                
                Button(action: {
                    showingCreateItem = true
                }) {
                    Image(systemName: Constants.UI.addIcon)
                }
            }
        }
        .sheet(isPresented: $showingCreateItem) {
            ItemEditView(list: list)
        }
        .sheet(isPresented: $showingEditItem) {
            if let item = selectedItem {
                ItemEditView(list: list, item: item)
            }
        }
        .sheet(isPresented: $viewModel.showingOrganizationOptions) {
            ItemOrganizationView(viewModel: viewModel)
        }
        .onAppear {
            viewModel.loadItems()
        }
        .onChange(of: showingCreateItem) { _ in
            if !showingCreateItem {
                viewModel.loadItems() // Refresh after creating
            }
        }
        .onChange(of: showingEditItem) { _ in
            if !showingEditItem {
                selectedItem = nil
                viewModel.loadItems() // Refresh after editing
            }
        }
    }
    
    private func deleteItems(offsets: IndexSet) {
        for index in offsets {
            let item = viewModel.filteredItems[index]
            viewModel.deleteItem(item)
        }
    }
}

#Preview {
    NavigationView {
        ListView(list: List(name: "Sample List"))
    }
}
