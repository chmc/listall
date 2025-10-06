import SwiftUI

struct ListView: View {
    let list: List
    @ObservedObject var mainViewModel: MainViewModel
    @StateObject private var viewModel: ListViewModel
    @StateObject private var sharingService = SharingService()
    @State private var editMode: EditMode = .inactive
    @State private var showingCreateItem = false
    @State private var showingEditItem = false
    @State private var showingEditList = false
    @State private var selectedItem: Item?
    @State private var showingShareFormatPicker = false
    @State private var showingShareSheet = false
    @State private var selectedShareFormat: ShareFormat = .plainText
    @State private var shareOptions: ShareOptions = .default
    @State private var shareFileURL: URL?
    @State private var shareItems: [Any] = []
    @State private var showingDeleteConfirmation = false
    @AppStorage(Constants.UserDefaultsKeys.addButtonPosition) private var addButtonPositionRaw: String = Constants.AddButtonPosition.right.rawValue
    
    private var addButtonPosition: Constants.AddButtonPosition {
        Constants.AddButtonPosition(rawValue: addButtonPositionRaw) ?? .right
    }
    
    init(list: List, mainViewModel: MainViewModel) {
        self.list = list
        self.mainViewModel = mainViewModel
        self._viewModel = StateObject(wrappedValue: ListViewModel(list: list))
    }
    
    var body: some View {
        ZStack {
            VStack(spacing: 0) {
                // List name header
                HStack {
                    Text(list.name)
                        .font(Theme.Typography.headline)
                        .foregroundColor(.primary)
                    
                    Button(action: {
                        showingEditList = true
                    }) {
                        Image(systemName: "pencil.circle")
                            .foregroundColor(.secondary)
                            .imageScale(.medium)
                    }
                    .accessibilityLabel("Edit list details")
                    
                    Spacer()
                }
                .padding(.horizontal, Theme.Spacing.md)
                .padding(.top, Theme.Spacing.sm)
                .padding(.bottom, 4)
                .background(Color(UIColor.systemGroupedBackground))
                
                // Item count subtitle
                HStack {
                    Text("\(list.activeItemCount)/\(list.itemCount) items")
                        .font(Theme.Typography.caption)
                        .foregroundColor(Theme.Colors.secondary)
                    Spacer()
                }
                .padding(.horizontal, Theme.Spacing.md)
                .padding(.bottom, Theme.Spacing.sm)
                .background(Color(UIColor.systemGroupedBackground))
                
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
                            viewModel: viewModel,
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
                    .onDelete(perform: viewModel.isInSelectionMode ? nil : deleteItems)
                    // Only allow manual reordering when sorted by order number (and not in selection mode)
                    .onMove(perform: (viewModel.currentSortOption == .orderNumber && !viewModel.isInSelectionMode) ? viewModel.moveItems : nil)
                }
                .environment(\.editMode, viewModel.isInSelectionMode ? .constant(.inactive) : $editMode)
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
            
            // Add Item Button (floating above tab bar)
            VStack {
                Spacer()
                HStack(spacing: 0) {
                    if addButtonPosition == .left {
                        addItemButton
                            .padding(.leading, Theme.Spacing.lg)
                        Spacer()
                    } else {
                        Spacer()
                        addItemButton
                            .padding(.trailing, Theme.Spacing.lg)
                    }
                }
                .padding(.bottom, viewModel.showUndoButton ? 130 : 65)
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                if !viewModel.items.isEmpty && viewModel.isInSelectionMode {
                    // Selection mode: Show Select All/None
                    Button(viewModel.selectedItems.count == viewModel.filteredItems.count ? "Deselect All" : "Select All") {
                        withAnimation {
                            if viewModel.selectedItems.count == viewModel.filteredItems.count {
                                viewModel.deselectAll()
                            } else {
                                viewModel.selectAll()
                            }
                        }
                    }
                }
            }
            
            ToolbarItemGroup(placement: .navigationBarTrailing) {
                if !viewModel.items.isEmpty {
                    if viewModel.isInSelectionMode {
                        // Selection mode: Show Delete and Done buttons
                        if !viewModel.selectedItems.isEmpty {
                            Button(action: {
                                showingDeleteConfirmation = true
                            }) {
                                Image(systemName: "trash")
                                    .foregroundColor(.red)
                            }
                        }
                        
                        Button("Done") {
                            withAnimation {
                                viewModel.exitSelectionMode()
                            }
                        }
                    } else {
                        // Normal mode: Show Share, Sort/Filter, Eye, and Edit buttons
                        Button(action: {
                            showingShareFormatPicker = true
                        }) {
                            Image(systemName: "square.and.arrow.up")
                                .foregroundColor(.primary)
                        }
                        .help("Share list")
                        
                        Button(action: {
                            viewModel.showingOrganizationOptions = true
                        }) {
                            Image(systemName: "arrow.up.arrow.down")
                                .foregroundColor(.primary)
                        }
                        .help("Sort and filter options")
                        
                        Button(action: {
                            viewModel.toggleShowCrossedOutItems()
                        }) {
                            Image(systemName: viewModel.showCrossedOutItems ? "eye" : "eye.slash")
                                .foregroundColor(viewModel.showCrossedOutItems ? .primary : .secondary)
                        }
                        .help(viewModel.showCrossedOutItems ? "Hide crossed out items" : "Show crossed out items")
                        
                        Button(action: {
                            withAnimation {
                                viewModel.enterSelectionMode()
                            }
                        }) {
                            Image(systemName: "pencil")
                        }
                        .help("Edit items")
                    }
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
        .sheet(isPresented: $showingEditList) {
            EditListView(list: list, mainViewModel: mainViewModel)
        }
        .sheet(isPresented: $viewModel.showingOrganizationOptions) {
            ItemOrganizationView(viewModel: viewModel)
        }
        .sheet(isPresented: $showingShareFormatPicker) {
            ShareFormatPickerView(
                selectedFormat: $selectedShareFormat,
                shareOptions: $shareOptions,
                onShare: { format, options in
                    handleShare(format: format, options: options)
                }
            )
        }
        .background(
            Group {
                if showingShareSheet && !shareItems.isEmpty {
                    ActivityViewController(activityItems: shareItems) {
                        showingShareSheet = false
                        shareItems = []
                    }
                }
            }
        )
        .alert("Share Error", isPresented: .constant(sharingService.shareError != nil)) {
            Button("OK") {
                sharingService.clearError()
            }
        } message: {
            Text(sharingService.shareError ?? "")
        }
        .alert("Delete Items", isPresented: $showingDeleteConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) {
                withAnimation {
                    viewModel.deleteSelectedItems()
                    viewModel.exitSelectionMode()
                }
            }
        } message: {
            Text("Are you sure you want to delete \(viewModel.selectedItems.count) item(s)? This action cannot be undone.")
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
        .onChange(of: showingEditList) { _ in
            if !showingEditList {
                // Refresh main view after editing list details
                mainViewModel.loadLists()
            }
        }
    }
    
    private func handleShare(format: ShareFormat, options: ShareOptions) {
        // Create share content asynchronously
        DispatchQueue.global(qos: .userInitiated).async { [weak sharingService] in
            guard let shareResult = sharingService?.shareList(list, format: format, options: options) else {
                return
            }
            
            // Update UI on main thread
            DispatchQueue.main.async {
                // Use UIActivityItemSource for proper iOS sharing
                if let fileURL = shareResult.content as? URL {
                    // File-based sharing (JSON)
                    let filename = shareResult.fileName ?? "export.json"
                    let itemSource = FileActivityItemSource(fileURL: fileURL, filename: filename)
                    self.shareFileURL = nil
                    self.shareItems = [itemSource]
                } else if let text = shareResult.content as? String {
                    // Text-based sharing (Plain Text)
                    let itemSource = TextActivityItemSource(text: text, subject: list.name)
                    self.shareFileURL = nil
                    self.shareItems = [itemSource]
                }
                
                // Present immediately - no delay needed with direct presentation
                self.showingShareSheet = true
            }
        }
    }
    
    private func deleteItems(offsets: IndexSet) {
        for index in offsets {
            let item = viewModel.filteredItems[index]
            viewModel.deleteItem(item)
        }
    }
    
    private var addItemButton: some View {
        Button(action: {
            showingCreateItem = true
        }) {
            HStack(spacing: 6) {
                Image(systemName: Constants.UI.addIcon)
                    .font(.system(size: 18, weight: .semibold))
                Text("Item")
                    .font(.system(size: 16, weight: .semibold))
            }
            .foregroundColor(.primary)
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(
                Capsule()
                    .fill(Color(UIColor.tertiarySystemGroupedBackground))
                    .shadow(color: Color.black.opacity(0.15), radius: 6, x: 0, y: 3)
            )
            .overlay(
                Capsule()
                    .strokeBorder(Color(UIColor.separator).opacity(0.5), lineWidth: 0.5)
            )
        }
        .accessibilityLabel("Add new item")
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
        ListView(list: List(name: "Sample List"), mainViewModel: MainViewModel())
    }
}
