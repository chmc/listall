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
            } else if viewModel.items.isEmpty {
                VStack(spacing: Theme.Spacing.lg) {
                    Image(systemName: "list.bullet.rectangle")
                        .font(.system(size: 60))
                        .foregroundColor(Theme.Colors.secondary)
                    
                    Text("No Items Yet")
                        .font(Theme.Typography.title)
                    
                    Text("Add your first item to get started")
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
                    ForEach(viewModel.items) { item in
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
            let item = viewModel.items[index]
            viewModel.deleteItem(item)
        }
    }
}

#Preview {
    NavigationView {
        ListView(list: List(name: "Sample List"))
    }
}
