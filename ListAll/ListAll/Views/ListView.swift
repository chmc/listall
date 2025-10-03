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
        ZStack {
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
                        .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0))
                    }
                    .onDelete(perform: deleteItems)
                    // Only allow manual reordering when sorted by order number
                    .onMove(perform: viewModel.currentSortOption == .orderNumber ? viewModel.moveItems : nil)
                }
                .refreshable {
                    viewModel.loadItems()
                }
            }
            }
            
            // Undo Complete Banner
            if viewModel.showUndoButton, let item = viewModel.recentlyCompletedItem {
                VStack {
                    Spacer()
                    UndoBanner(
                        itemName: item.displayTitle,
                        onUndo: {
                            viewModel.undoComplete()
                        }
                    )
                    .padding(.horizontal, Theme.Spacing.md)
                    .padding(.bottom, Theme.Spacing.md)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .animation(Theme.Animation.spring, value: viewModel.showUndoButton)
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

// MARK: - Undo Banner Component

struct UndoBanner: View {
    let itemName: String
    let onUndo: () -> Void
    
    var body: some View {
        HStack(spacing: Theme.Spacing.md) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundColor(Theme.Colors.success)
                .font(.title3)
            
            VStack(alignment: .leading, spacing: 2) {
                Text("Completed")
                    .font(Theme.Typography.caption)
                    .foregroundColor(.secondary)
                
                Text(itemName)
                    .font(Theme.Typography.body)
                    .fontWeight(.medium)
                    .lineLimit(1)
            }
            
            Spacer()
            
            Button(action: onUndo) {
                Text("Undo")
                    .font(Theme.Typography.headline)
                    .foregroundColor(.white)
                    .padding(.horizontal, Theme.Spacing.lg)
                    .padding(.vertical, Theme.Spacing.sm)
                    .background(Theme.Colors.primary)
                    .cornerRadius(Theme.CornerRadius.md)
            }
        }
        .padding(Theme.Spacing.md)
        .background(
            RoundedRectangle(cornerRadius: Theme.CornerRadius.lg)
                .fill(Theme.Colors.background)
                .shadow(color: Theme.Shadow.largeColor, radius: Theme.Shadow.largeRadius, x: Theme.Shadow.largeX, y: Theme.Shadow.largeY)
        )
    }
}

#Preview {
    NavigationView {
        ListView(list: List(name: "Sample List"))
    }
}
