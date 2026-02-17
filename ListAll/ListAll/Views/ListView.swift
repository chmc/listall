import SwiftUI

struct ListView: View {
    @State private var list: List
    @ObservedObject var mainViewModel: MainViewModel
    @StateObject private var viewModel: ListViewModel
    @StateObject private var sharingService = SharingService()
    @StateObject private var tooltipManager = TooltipManager.shared
    @Environment(\.presentationMode) var presentationMode
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
    @State private var showingMoveDestinationPicker = false
    @State private var showingCopyDestinationPicker = false
    @State private var showingMoveConfirmation = false
    @State private var showingCopyConfirmation = false
    @State private var selectedDestinationList: List?
    @AppStorage(Constants.UserDefaultsKeys.addButtonPosition) private var addButtonPositionRaw: String = Constants.AddButtonPosition.right.rawValue
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    private var addButtonPosition: Constants.AddButtonPosition {
        Constants.AddButtonPosition(rawValue: addButtonPositionRaw) ?? .right
    }

    private var isRegularWidth: Bool {
        horizontalSizeClass == .regular
    }
    
    /// Use fullScreenCover instead of sheet in screenshot mode to avoid dark dimming bands
    private var isScreenshotMode: Bool {
        ProcessInfo.processInfo.arguments.contains("UITEST_SCREENSHOT_MODE")
    }

    // Computed property for edit mode binding to simplify type-checking
    private var editModeBinding: Binding<EditMode> {
        if viewModel.currentSortOption == .orderNumber && viewModel.isInSelectionMode {
            return .constant(.active)
        } else {
            return $editMode
        }
    }
    
    init(list: List, mainViewModel: MainViewModel) {
        self.list = list
        self.mainViewModel = mainViewModel
        self._viewModel = StateObject(wrappedValue: ListViewModel(list: list))
    }
    
    private var itemsList: some View {
        SwiftUI.List {
            // Header section
            Section {
                editableListNameHeader
                    .listRowInsets(EdgeInsets())
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
                
                HStack {
                    Text("\(viewModel.activeItems.count)/\(viewModel.items.count) items")
                        .font(Theme.Typography.caption)
                        .foregroundColor(Theme.Colors.secondary)
                    
                    // Watch sync indicator (subtle)
                    if viewModel.isSyncingFromWatch {
                        HStack(spacing: 4) {
                            Image(systemName: "applewatch")
                                .font(.system(size: 10))
                            Text("syncing...")
                                .font(.caption2)
                        }
                        .foregroundColor(.secondary)
                        .transition(.opacity)
                    }
                    
                    Spacer()
                }
                .listRowInsets(EdgeInsets(top: 4, leading: Theme.Spacing.md, bottom: Theme.Spacing.sm, trailing: Theme.Spacing.md))
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
            }
            .listSectionSeparator(.hidden)
            
            // Items section
            Section {
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
                .onMove(perform: viewModel.currentSortOption == .orderNumber ? viewModel.moveItems : nil)
            }
        }
        .listStyle(.plain)
        .environment(\.editMode, editModeBinding)
        .refreshable {
            viewModel.loadItems()
        }
    }
    
    var body: some View {
        ZStack {
            if viewModel.isLoading {
                ProgressView("Loading items...")
            } else if viewModel.filteredItems.isEmpty {
                VStack(spacing: 0) {
                    // List name header - entire row is tappable for better UX
                    editableListNameHeader
                    
                    // Item count subtitle
                    HStack {
                        Text("\(viewModel.activeItems.count)/\(viewModel.items.count) items")
                            .font(Theme.Typography.caption)
                            .foregroundColor(Theme.Colors.secondary)
                        Spacer()
                    }
                    .padding(.horizontal, Theme.Spacing.md)
                    .padding(.top, 4)
                    .padding(.bottom, Theme.Spacing.sm)
                    
                    // Use new engaging empty state with tips and celebration
                    ItemsEmptyStateView(
                        hasItems: !viewModel.items.isEmpty,
                        onAddItem: {
                            showingCreateItem = true
                        }
                    )
                    .padding(.top, 40)
                }
            } else {
                itemsList
            }
            
            // Undo Complete Banner
            if viewModel.showUndoButton, let item = viewModel.recentlyCompletedItem {
                VStack {
                    Spacer()
                    UndoBanner(
                        itemName: item.displayTitle,
                        onUndo: {
                            viewModel.undoComplete()
                        },
                        onDismiss: {
                            viewModel.hideUndoButton()
                        }
                    )
                    .padding(.horizontal, Theme.Spacing.md)
                    .padding(.bottom, Theme.Spacing.md)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .animation(Theme.Animation.spring, value: viewModel.showUndoButton)
                }
            }
            
            // Undo Delete Banner
            if viewModel.showDeleteUndoButton, let item = viewModel.recentlyDeletedItem {
                VStack {
                    Spacer()
                    DeleteUndoBanner(
                        itemName: item.displayTitle,
                        onUndo: {
                            viewModel.undoDeleteItem()
                        },
                        onDismiss: {
                            viewModel.hideDeleteUndoButton()
                        }
                    )
                    .padding(.horizontal, Theme.Spacing.md)
                    .padding(.bottom, Theme.Spacing.md)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .animation(Theme.Animation.spring, value: viewModel.showDeleteUndoButton)
                }
            }
            
            // Add Item Button (floating above tab bar) - only show when list has items
            // On iPad (regular width), the Add Item button is in the toolbar instead
            if !viewModel.items.isEmpty && !isRegularWidth {
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
                    .padding(.bottom, (viewModel.showUndoButton || viewModel.showDeleteUndoButton) ? 130 : 65)
                }
            }
        }
        .searchable(text: $viewModel.searchText, placement: .navigationBarDrawer(displayMode: .automatic), prompt: "Search items")
        .navigationBarTitleDisplayMode(.inline)
        .navigationTitle(viewModel.isInSelectionMode ? "\(viewModel.selectedItems.count) Selected" : "")
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                if !viewModel.items.isEmpty && viewModel.isInSelectionMode {
                    // Selection mode: Show Cancel button
                    Button("Cancel") {
                        withAnimation {
                            viewModel.exitSelectionMode()
                        }
                    }
                }
            }
            
            ToolbarItem(placement: .navigationBarTrailing) {
                if !viewModel.items.isEmpty {
                    HStack(spacing: Theme.Spacing.md) {
                        if viewModel.isInSelectionMode {
                            // Selection mode: Show actions menu (always visible)
                            Menu {
                                Button(action: {
                                    viewModel.selectAll()
                                }) {
                                    Label("Select All", systemImage: "checkmark.circle")
                                }
                                
                                Button(action: {
                                    viewModel.deselectAll()
                                }) {
                                    Label("Deselect All", systemImage: "circle")
                                }
                                .disabled(viewModel.selectedItems.isEmpty)
                                
                                Divider()
                                
                                Button(action: {
                                    showingMoveDestinationPicker = true
                                }) {
                                    Label("Move Items", systemImage: "arrow.right.square")
                                }
                                .disabled(viewModel.selectedItems.isEmpty)
                                
                                Button(action: {
                                    showingCopyDestinationPicker = true
                                }) {
                                    Label("Copy Items", systemImage: "doc.on.doc")
                                }
                                .disabled(viewModel.selectedItems.isEmpty)
                                
                                Divider()
                                
                                Button(role: .destructive, action: {
                                    showingDeleteConfirmation = true
                                }) {
                                    Label("Delete Items", systemImage: "trash")
                                }
                                .disabled(viewModel.selectedItems.isEmpty)
                            } label: {
                                Image(systemName: "ellipsis.circle")
                                    .foregroundColor(.primary)
                            }
                        } else {
                            // Normal mode: Show Share, Sort/Filter, Eye, and Edit buttons
                            Button(action: {
                                showingShareFormatPicker = true
                            }) {
                                Image(systemName: "square.and.arrow.up")
                                    .foregroundColor(.primary)
                            }
                            .hoverEffect(.highlight)  // Task 16.16: iPad trackpad hover effect
                            .help("Share list")

                            Button(action: {
                                viewModel.showingOrganizationOptions = true
                            }) {
                                Image(systemName: "arrow.up.arrow.down")
                                    .foregroundColor(.primary)
                            }
                            .hoverEffect(.highlight)  // Task 16.16: iPad trackpad hover effect
                            .help(String(localized: "Sort and filter options"))

                            Button(action: {
                                viewModel.toggleShowCrossedOutItems()
                            }) {
                                Image(systemName: viewModel.showCrossedOutItems ? "eye" : "eye.slash")
                                    .foregroundColor(viewModel.showCrossedOutItems ? .primary : .secondary)
                            }
                            .hoverEffect(.highlight)  // Task 16.16: iPad trackpad hover effect
                            .help(viewModel.showCrossedOutItems ? "Hide crossed out items" : "Show crossed out items")

                            Button(action: {
                                withAnimation {
                                    viewModel.enterSelectionMode()
                                }
                            }) {
                                Image(systemName: "pencil")
                            }
                            .hoverEffect(.highlight)  // Task 16.16: iPad trackpad hover effect
                            .help("Edit items")
                        }
                    }
                    .padding(.horizontal, Theme.Spacing.sm)
                }
            }

            // Add Item toolbar button for iPad (regular width)
            ToolbarItem(placement: .navigationBarTrailing) {
                if isRegularWidth && !viewModel.items.isEmpty && !viewModel.isInSelectionMode {
                    Button(action: {
                        showingCreateItem = true
                    }) {
                        Label("Add Item", systemImage: "plus")
                    }
                    .accessibilityIdentifier("AddItemToolbarButton")
                    .keyboardShortcut("n", modifiers: [.command, .shift])
                }
            }
        }
        .sheet(isPresented: isScreenshotMode ? .constant(false) : $showingCreateItem) {
            ItemEditView(list: list)
        }
        .fullScreenCover(isPresented: isScreenshotMode ? $showingCreateItem : .constant(false)) {
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
        .alert("Move Items", isPresented: $showingMoveConfirmation) {
            Button("Cancel", role: .cancel) {
                selectedDestinationList = nil
            }
            Button("Move", role: .destructive) {
                if let destination = selectedDestinationList {
                    // Perform the move operation
                    viewModel.moveSelectedItems(to: destination)
                    viewModel.exitSelectionMode()
                    
                    // Refresh main view to pick up changes
                    mainViewModel.loadLists()
                    
                    // Dismiss current view first
                    presentationMode.wrappedValue.dismiss()
                    
                    // Trigger navigation after a brief moment for dismiss animation
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                        if let refreshedDestination = mainViewModel.lists.first(where: { $0.id == destination.id }) {
                            mainViewModel.selectedListForNavigation = refreshedDestination
                        }
                    }
                }
                selectedDestinationList = nil
            }
        } message: {
            if let destination = selectedDestinationList {
                Text("Move \(viewModel.selectedItems.count) item(s) to \"\(destination.name)\"? Items will be removed from this list.")
            }
        }
        .alert("Copy Items", isPresented: $showingCopyConfirmation) {
            Button("Cancel", role: .cancel) {
                selectedDestinationList = nil
            }
            Button("Copy") {
                if let destination = selectedDestinationList {
                    // Perform the copy operation
                    viewModel.copySelectedItems(to: destination)
                    viewModel.exitSelectionMode()
                    
                    // Refresh main view to pick up changes
                    mainViewModel.loadLists()
                    
                    // Dismiss current view first
                    presentationMode.wrappedValue.dismiss()
                    
                    // Trigger navigation after a brief moment for dismiss animation
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                        if let refreshedDestination = mainViewModel.lists.first(where: { $0.id == destination.id }) {
                            mainViewModel.selectedListForNavigation = refreshedDestination
                        }
                    }
                }
                selectedDestinationList = nil
            }
        } message: {
            if let destination = selectedDestinationList {
                Text("Copy \(viewModel.selectedItems.count) item(s) to \"\(destination.name)\"? Items will remain in this list.")
            }
        }
        .sheet(isPresented: $showingMoveDestinationPicker, onDismiss: {
            // When sheet is dismissed, show alert if a destination was selected
            if selectedDestinationList != nil {
                showingMoveConfirmation = true
            }
        }) {
            DestinationListPickerView(
                action: .move,
                itemCount: viewModel.selectedItems.count,
                currentListId: list.id,
                onSelect: { destinationList in
                    selectedDestinationList = destinationList
                    showingMoveDestinationPicker = false
                    // Alert will be shown in onDismiss callback
                },
                onCancel: {
                    selectedDestinationList = nil
                    showingMoveDestinationPicker = false
                },
                mainViewModel: mainViewModel
            )
        }
        .sheet(isPresented: $showingCopyDestinationPicker, onDismiss: {
            // When sheet is dismissed, show alert if a destination was selected
            if selectedDestinationList != nil {
                showingCopyConfirmation = true
            }
        }) {
            DestinationListPickerView(
                action: .copy,
                itemCount: viewModel.selectedItems.count,
                currentListId: list.id,
                onSelect: { destinationList in
                    selectedDestinationList = destinationList
                    showingCopyDestinationPicker = false
                    // Alert will be shown in onDismiss callback
                },
                onCancel: {
                    selectedDestinationList = nil
                    showingCopyDestinationPicker = false
                },
                mainViewModel: mainViewModel
            )
        }
        .onAppear {
            viewModel.loadItems()

            // Advertise Handoff activity for viewing this list
            HandoffService.shared.startViewingListActivity(list: list)

            // Show tooltips based on list state
            let itemCount = viewModel.items.count
            
            // Show search tooltip when user has 5+ items
            if itemCount >= 5 {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    tooltipManager.showIfNeeded(.searchFunctionality)
                }
            }
            
            // Show sort/filter tooltip when user has 7+ items
            if itemCount >= 7 {
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                    tooltipManager.showIfNeeded(.sortFilterOptions)
                }
            }
            
            // Show swipe actions tooltip when user has 3+ items
            if itemCount >= 3 {
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                    tooltipManager.showIfNeeded(.swipeActions)
                }
            }
        }
        .onDisappear {
            // Refresh main view lists when navigating back to ensure counts are updated
            mainViewModel.loadLists()
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
                
                // Update the local list reference to reflect the updated name
                if let updatedList = mainViewModel.lists.first(where: { $0.id == list.id }) {
                    list = updatedList
                }
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
    
    private var editableListNameHeader: some View {
        Button(action: {
            showingEditList = true
        }) {
            HStack(spacing: Theme.Spacing.sm) {
                Text(list.name)
                    .font(Theme.Typography.headline)
                    .foregroundColor(.primary)
                
                Image(systemName: "pencil")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.primary)
                
                Spacer()
            }
            .padding(.horizontal, Theme.Spacing.md)
            .padding(.vertical, 12)
            .background(Color(UIColor.secondarySystemGroupedBackground))
            .cornerRadius(Theme.CornerRadius.md)
        }
        .buttonStyle(EditableHeaderButtonStyle())
        .accessibilityLabel("Edit list name: \(list.name)")
        .accessibilityHint("Double tap to edit")
        .padding(.horizontal, Theme.Spacing.md)
        .padding(.top, Theme.Spacing.sm)
        .padding(.bottom, 4)
    }
    
    private var addItemButton: some View {
        Button(action: {
            showingCreateItem = true
        }) {
            HStack(spacing: 6) {
                Image(systemName: Constants.UI.addIcon)
                    .font(.system(size: 18, weight: .semibold))
                Text(String(localized: "Item"))
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
        .hoverEffect(.lift)  // Task 16.16: iPad trackpad hover effect
        .accessibilityLabel("Add new item")
        .accessibilityIdentifier("AddItemButton")
        .keyboardShortcut("n", modifiers: [.command, .shift])  // Task 15.8: iPad Cmd+Shift+N
    }
}

// MARK: - Custom Button Style for Editable Header

struct EditableHeaderButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
            .opacity(configuration.isPressed ? 0.9 : 1.0)
            .animation(Theme.Animation.quick, value: configuration.isPressed)
    }
}

// MARK: - Undo Banner Component

struct UndoBanner: View {
    let itemName: String
    let onUndo: () -> Void
    let onDismiss: () -> Void
    
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
            
            Button(action: onDismiss) {
                Image(systemName: "xmark")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(Theme.Spacing.sm)
            }
            .accessibilityLabel("Dismiss")
        }
        .padding(Theme.Spacing.md)
        .background(
            RoundedRectangle(cornerRadius: Theme.CornerRadius.lg)
                .fill(Theme.Colors.background)
                .shadow(color: Theme.Shadow.largeColor, radius: Theme.Shadow.largeRadius, x: Theme.Shadow.largeX, y: Theme.Shadow.largeY)
        )
    }
}

// MARK: - Delete Undo Banner Component

struct DeleteUndoBanner: View {
    let itemName: String
    let onUndo: () -> Void
    let onDismiss: () -> Void
    
    var body: some View {
        HStack(spacing: Theme.Spacing.md) {
            Image(systemName: "trash.circle.fill")
                .foregroundColor(.red)
                .font(.title3)
            
            VStack(alignment: .leading, spacing: 2) {
                Text("Deleted")
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
            
            Button(action: onDismiss) {
                Image(systemName: "xmark")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(Theme.Spacing.sm)
            }
            .accessibilityLabel("Dismiss")
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
