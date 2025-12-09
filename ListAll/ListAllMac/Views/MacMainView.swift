//
//  MacMainView.swift
//  ListAllMac
//
//  Main view for macOS app using NavigationSplitView.
//

import SwiftUI
import CoreData
import UniformTypeIdentifiers
import Quartz

/// Main view for macOS app with sidebar navigation.
/// This is the macOS equivalent of iOS ContentView, using NavigationSplitView
/// for the standard macOS three-column layout.
struct MacMainView: View {
    @EnvironmentObject var dataManager: DataManager
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.scenePhase) private var scenePhase

    @State private var selectedList: List?
    @State private var columnVisibility: NavigationSplitViewVisibility = .all

    // Menu command observers
    @State private var showingCreateListSheet = false
    @State private var showingArchivedLists = false

    // MARK: - CloudKit Sync Polling (macOS fallback)
    // Apple's CloudKit notifications on macOS can be unreliable when the app is frontmost.
    // This timer serves as a safety net to ensure data refreshes even if notifications miss.
    @State private var syncPollingTimer: Timer?
    private let syncPollingInterval: TimeInterval = 30.0 // Poll every 30 seconds

    // MARK: - Edit State Protection
    // Flag to prevent background sync from interrupting sheet presentation
    // Set via notification from MacListDetailView when editing starts/stops
    @State private var isEditingAnyItem = false

    // MARK: - Edit Item State (for native sheet presenter)
    // NOTE: We use MacNativeSheetPresenter instead of SwiftUI's .sheet() modifier
    // because SwiftUI sheets have RunLoop mode issues that prevent presentation until app deactivation
    @State private var selectedEditItem: Item?

    // MARK: - Navigation Path for Animation Fix
    // CRITICAL FIX: Apple-confirmed bug in NavigationSplitView (Xcode 14.3+)
    // Without a NavigationPath with explicit animation, ALL animations in the app break.
    // This includes .sheet() presentation - sheets queue but never display until app deactivates.
    // See: https://developer.apple.com/forums/thread/728132
    @State private var navigationPath = NavigationPath()

    var body: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
            // CRITICAL FIX: Wrap sidebar in NavigationStack with animated path
            // This restores SwiftUI's animation system that NavigationSplitView breaks
            NavigationStack(path: $navigationPath.animation(.linear(duration: 0))) {
                // Sidebar with lists
                // CRITICAL: Pass showingArchivedLists flag and let sidebar observe dataManager directly
                // Passing array by value breaks SwiftUI observation chain on macOS
                MacSidebarView(
                    showingArchivedLists: $showingArchivedLists,
                    selectedList: $selectedList,
                    onCreateList: { showingCreateListSheet = true },
                    onDeleteList: deleteList
                )
                .navigationSplitViewColumnWidth(min: 200, ideal: 250, max: 350)
            }
        } detail: {
            // Detail view for selected list
            if let list = selectedList {
                MacListDetailView(
                    list: list,
                    onEditItem: { item in
                        // CRITICAL: Use native AppKit sheet presentation (bypasses SwiftUI's RunLoop issues)
                        // SwiftUI sheets have a known bug where they only present after app deactivation
                        // This is caused by RunLoop mode conflicts during event handling
                        print("🎯 MacMainView: Received edit request for item: \(item.title)")
                        isEditingAnyItem = true
                        selectedEditItem = item

                        // Define cancel action (used by both Cancel button and ESC key)
                        let cancelAction = {
                            MacNativeSheetPresenter.shared.dismissSheet()
                            selectedEditItem = nil
                            isEditingAnyItem = false
                        }

                        // Present using native AppKit sheet (works immediately)
                        MacNativeSheetPresenter.shared.presentSheet(
                            MacEditItemSheet(
                                item: item,
                                onSave: { title, quantity, description, images in
                                    updateEditedItem(item, title: title, quantity: quantity, description: description, images: images)
                                    MacNativeSheetPresenter.shared.dismissSheet()
                                    selectedEditItem = nil
                                    isEditingAnyItem = false
                                },
                                onCancel: cancelAction
                            )
                            .environment(\.managedObjectContext, viewContext),
                            onCancel: cancelAction  // ESC key support via SheetHostingController
                        ) {
                            // Completion handler when sheet dismisses
                            isEditingAnyItem = false
                            selectedEditItem = nil
                            dataManager.loadData()
                        }
                        print("✅ MacMainView: Native sheet presenter called")
                    }
                )
                .id(list.id) // Force refresh when selection changes
            } else {
                MacEmptyStateView(onCreateList: { showingCreateListSheet = true })
            }
        }
        .frame(minWidth: 800, minHeight: 600)
        // NOTE: Edit item sheet now uses native MacNativeSheetPresenter (bypasses SwiftUI RunLoop issues)
        // The SwiftUI .sheet() modifier was removed because it only presents after app deactivation
        .sheet(isPresented: $showingCreateListSheet) {
            MacCreateListSheet(
                onSave: { name in
                    createList(name: name)
                    showingCreateListSheet = false
                },
                onCancel: { showingCreateListSheet = false }
            )
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("CreateNewList"))) { _ in
            showingCreateListSheet = true
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("ToggleArchivedLists"))) { _ in
            showingArchivedLists.toggle()
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("RefreshData"))) { _ in
            // Defer to next run loop to prevent layout recursion during view updates
            DispatchQueue.main.async {
                dataManager.loadData()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .coreDataRemoteChange)) { _ in
            // Skip if user is editing - prevents sheet state corruption during CloudKit sync
            guard !isEditingAnyItem else {
                print("🛡️ macOS: Skipping main view refresh - user is editing item")
                return
            }
            print("🌐 macOS: Received Core Data remote change notification - refreshing UI")
            // CRITICAL: Defer to next run loop to prevent layout recursion
            // This breaks the cycle where notifications trigger state changes during ongoing layout
            DispatchQueue.main.async {
                dataManager.loadData()
            }
        }
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .active {
                // Refresh data when window becomes active (handles macOS app switching)
                print("🖥️ macOS: Window became active - refreshing data and starting sync polling")
                dataManager.loadData()
                startSyncPolling()
            } else if newPhase == .background || newPhase == .inactive {
                // Stop polling when app goes to background (saves resources)
                stopSyncPolling()
            }
        }
        .onAppear {
            startSyncPolling()
            // Start Handoff activity for browsing lists (if no list is selected)
            if selectedList == nil {
                HandoffService.shared.startBrowsingListsActivity()
            }
        }
        .onDisappear {
            stopSyncPolling()
        }
        // Listen for edit state changes from MacListDetailView
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("ItemEditingStarted"))) { _ in
            isEditingAnyItem = true
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("ItemEditingEnded"))) { _ in
            isEditingAnyItem = false
            // Refresh data now that editing is complete to catch any missed updates
            // Defer to prevent layout recursion during sheet dismissal animation
            DispatchQueue.main.async {
                dataManager.loadData()
            }
        }
        .onChange(of: selectedList) { oldValue, newValue in
            // Update Handoff activity based on selection
            if let list = newValue {
                HandoffService.shared.startViewingListActivity(list: list)
            } else {
                HandoffService.shared.startBrowsingListsActivity()
            }
        }
    }

    // MARK: - Sync Polling Methods

    /// Starts a timer that periodically refreshes data from Core Data.
    /// This is a fallback for macOS where CloudKit notifications may not reliably
    /// trigger when the app is frontmost and active.
    private func startSyncPolling() {
        // Don't start if already running
        guard syncPollingTimer == nil else { return }

        print("🔄 macOS: Starting sync polling timer (every \(Int(syncPollingInterval))s)")

        syncPollingTimer = Timer.scheduledTimer(withTimeInterval: syncPollingInterval, repeats: true) { [self] _ in
            // Skip polling if user is editing - prevents UI interruption during sheet presentation
            guard !isEditingAnyItem else {
                print("🛡️ macOS: Skipping poll - user is editing item")
                return
            }

            print("🔄 macOS: Polling for CloudKit changes (timer-based fallback)")

            // Force Core Data to check for remote changes
            viewContext.perform {
                viewContext.refreshAllObjects()
            }

            // Reload data to update UI - use async to prevent layout recursion
            // if timer happens to fire during an ongoing layout pass
            DispatchQueue.main.async {
                dataManager.loadData()
            }
        }
    }

    /// Stops the sync polling timer (when app goes to background or view disappears)
    private func stopSyncPolling() {
        syncPollingTimer?.invalidate()
        syncPollingTimer = nil
        print("🔄 macOS: Stopped sync polling timer")
    }

    // MARK: - Actions

    private func createList(name: String) {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else { return }

        let newList = List(name: trimmedName)
        dataManager.addList(newList)
        dataManager.loadData()

        // Select the newly created list
        if let createdList = dataManager.lists.first(where: { $0.name == trimmedName }) {
            selectedList = createdList
        }
    }

    private func deleteList(_ list: List) {
        if selectedList?.id == list.id {
            selectedList = nil
        }
        dataManager.deleteList(withId: list.id)
        dataManager.loadData()
    }

    /// Update an item from the edit sheet (called from MacMainView-level sheet)
    private func updateEditedItem(_ item: Item, title: String, quantity: Int, description: String?, images: [ItemImage]? = nil) {
        var updatedItem = item
        updatedItem.title = title
        updatedItem.quantity = quantity
        updatedItem.itemDescription = description
        if let images = images {
            updatedItem.images = images
        }
        updatedItem.modifiedAt = Date()
        dataManager.updateItem(updatedItem)
    }
}

// MARK: - Sidebar View

private struct MacSidebarView: View {
    // CRITICAL: Observe dataManager directly instead of receiving array by value
    // Passing [List] by value breaks SwiftUI observation chain on macOS
    @EnvironmentObject var dataManager: DataManager

    @Binding var showingArchivedLists: Bool
    @Binding var selectedList: List?
    let onCreateList: () -> Void
    let onDeleteList: (List) -> Void

    // DataRepository for drag-and-drop operations
    private let dataRepository = DataRepository()

    // Compute lists directly from @Published source for proper reactivity
    private var displayedLists: [List] {
        if showingArchivedLists {
            return dataManager.lists.filter { $0.isArchived }
                .sorted { $0.orderNumber < $1.orderNumber }
        } else {
            return dataManager.lists.filter { !$0.isArchived }
                .sorted { $0.orderNumber < $1.orderNumber }
        }
    }

    var body: some View {
        SwiftUI.List(selection: $selectedList) {
            Section {
                ForEach(displayedLists) { list in
                    NavigationLink(value: list) {
                        HStack {
                            Text(list.name)
                            Spacer()
                            // Show active count (total) - matching detail view format
                            let activeCount = list.items.filter { !$0.isCrossedOut }.count
                            let totalCount = list.items.count
                            if activeCount < totalCount {
                                Text("\(activeCount) (\(totalCount))")
                                    .foregroundColor(.secondary)
                                    .font(.caption)
                            } else {
                                Text("\(totalCount)")
                                    .foregroundColor(.secondary)
                                    .font(.caption)
                            }
                        }
                    }
                    // MARK: Drag-and-Drop Support
                    .draggable(list) // Enable dragging lists to reorder
                    .dropDestination(for: ItemTransferData.self) { droppedItems, _ in
                        // Handle items dropped on this list (move item to different list)
                        handleItemDrop(droppedItems, to: list)
                    }
                    .contextMenu {
                        Button("Delete") {
                            onDeleteList(list)
                        }
                    }
                }
                .onMove(perform: moveList) // Handle list reordering
            } header: {
                HStack {
                    Text(showingArchivedLists ? "Archived Lists" : "Lists")
                    Spacer()
                    Button(action: {
                        showingArchivedLists.toggle()
                    }) {
                        Image(systemName: showingArchivedLists ? "tray.full" : "archivebox")
                            .font(.caption)
                    }
                    .buttonStyle(.plain)
                    .help(showingArchivedLists ? "Show Active Lists" : "Show Archived Lists")
                }
            }
        }
        .listStyle(.sidebar)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button(action: onCreateList) {
                    Label("Add List", systemImage: "plus")
                }
            }
        }
    }

    // MARK: - Drag-and-Drop Handlers

    /// Handle item drop on a list in the sidebar (moves item to that list)
    private func handleItemDrop(_ droppedItems: [ItemTransferData], to targetList: List) -> Bool {
        var didMoveAny = false

        for itemData in droppedItems {
            // Skip if item is already in the target list
            guard itemData.sourceListId != targetList.id else { continue }

            // Find the item in DataManager
            let items = dataManager.getItems(forListId: itemData.sourceListId ?? UUID())
            guard let item = items.first(where: { $0.id == itemData.itemId }) else { continue }

            // Move item to the target list
            dataRepository.moveItem(item, to: targetList)
            didMoveAny = true
            print("📦 Moved item '\(item.title)' to list '\(targetList.name)'")
        }

        if didMoveAny {
            dataManager.loadData()
        }

        return didMoveAny
    }

    /// Handle list reordering via drag-and-drop
    private func moveList(from source: IndexSet, to destination: Int) {
        guard !showingArchivedLists else { return } // Don't reorder archived lists

        // Get current order
        var reorderedLists = displayedLists

        // Perform the move
        reorderedLists.move(fromOffsets: source, toOffset: destination)

        // Update order numbers - must modify array elements directly (value types!)
        for index in reorderedLists.indices {
            reorderedLists[index].orderNumber = index
            reorderedLists[index].modifiedAt = Date()
        }

        print("📦 Reordering lists: \(reorderedLists.map { "\($0.name):\($0.orderNumber)" })")

        // Persist the new order
        dataManager.updateListsOrder(reorderedLists)
        dataManager.loadData()

        print("📦 Reordered lists via drag-and-drop")
    }
}

// MARK: - List Detail View

private struct MacListDetailView: View {
    let list: List  // Original list from selection (may become stale)
    let onEditItem: (Item) -> Void  // Callback to parent for edit sheet (prevents state loss)
    @EnvironmentObject var dataManager: DataManager

    // ViewModel for filtering, sorting, and item management
    @StateObject private var viewModel: ListViewModel

    // State for item management (NOTE: edit sheet state moved to MacMainView)
    @State private var showingAddItemSheet = false
    @State private var showingEditListSheet = false

    // State for filter/sort popover
    @State private var showingOrganizationPopover = false

    // State for Quick Look
    @State private var quickLookItem: Item?

    // DataRepository for drag-and-drop operations
    private let dataRepository = DataRepository()

    init(list: List, onEditItem: @escaping (Item) -> Void) {
        self.list = list
        self.onEditItem = onEditItem
        _viewModel = StateObject(wrappedValue: ListViewModel(list: list))
    }

    // CRITICAL: Compute current list and items directly from @Published source
    // Using @State copy breaks SwiftUI observation chain on macOS
    // This ensures the view updates immediately when CloudKit syncs remote changes

    /// Get the current version of this list from DataManager (may have been updated by CloudKit)
    private var currentList: List? {
        dataManager.lists.first(where: { $0.id == list.id })
    }

    /// Get items directly from DataManager for proper reactivity
    private var items: [Item] {
        dataManager.getItems(forListId: list.id)
            .sorted { $0.orderNumber < $1.orderNumber }
    }

    /// Display name from current data (falls back to original if list not found)
    private var displayName: String {
        currentList?.name ?? list.name
    }

    /// Whether any filter is active (non-default filter, sort, or search)
    private var hasActiveFilters: Bool {
        viewModel.currentFilterOption != .all ||
        viewModel.currentSortOption != .orderNumber ||
        !viewModel.searchText.isEmpty
    }

    // MARK: - Header View

    @ViewBuilder
    private var headerView: some View {
        HStack {
            Text(displayName)
                .font(.largeTitle)
                .fontWeight(.bold)

            Spacer()

            searchFieldView
            filterSortButton
            editListButton
        }
        .padding()
    }

    @ViewBuilder
    private var searchFieldView: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.secondary)
            TextField("Search items...", text: $viewModel.searchText)
                .textFieldStyle(.plain)
                .frame(width: 150)
            if !viewModel.searchText.isEmpty {
                Button(action: { viewModel.searchText = "" }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Color.secondary.opacity(0.1))
        .cornerRadius(6)
    }

    @ViewBuilder
    private var filterSortButton: some View {
        Button(action: { showingOrganizationPopover.toggle() }) {
            Image(systemName: "arrow.up.arrow.down")
        }
        .buttonStyle(.plain)
        .help("Filter & Sort")
        .popover(isPresented: $showingOrganizationPopover) {
            MacItemOrganizationView(viewModel: viewModel)
        }
    }

    @ViewBuilder
    private var editListButton: some View {
        Button(action: { showingEditListSheet = true }) {
            Image(systemName: "pencil")
        }
        .buttonStyle(.plain)
        .help("Edit List")
    }

    // MARK: - Active Filters Bar

    @ViewBuilder
    private var activeFiltersBar: some View {
        if hasActiveFilters {
            HStack(spacing: 12) {
                if !viewModel.searchText.isEmpty {
                    FilterBadge(
                        icon: "magnifyingglass",
                        text: "Search: \"\(viewModel.searchText)\"",
                        onClear: {
                            viewModel.searchText = ""
                            // CRITICAL: Refresh items from DataManager when clearing search
                            viewModel.items = items
                        }
                    )
                }

                if viewModel.currentFilterOption != .all {
                    FilterBadge(
                        icon: viewModel.currentFilterOption.systemImage,
                        text: viewModel.currentFilterOption.displayName,
                        onClear: {
                            viewModel.updateFilterOption(.all)
                            // CRITICAL: Refresh items from DataManager when clearing filter
                            viewModel.items = items
                        }
                    )
                }

                if viewModel.currentSortOption != .orderNumber {
                    let sortText = "\(viewModel.currentSortOption.displayName) (\(viewModel.currentSortDirection.displayName))"
                    FilterBadge(
                        icon: viewModel.currentSortOption.systemImage,
                        text: sortText,
                        onClear: {
                            viewModel.updateSortOption(.orderNumber)
                            // CRITICAL: Refresh items from DataManager when clearing sort
                            viewModel.items = items
                        }
                    )
                }

                Spacer()

                Text("\(viewModel.filteredItems.count) of \(viewModel.items.count) items")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal)
            .padding(.bottom, 8)
        }
    }

    // MARK: - Empty State Views

    @ViewBuilder
    private var emptyListView: some View {
        VStack(spacing: 16) {
            Image(systemName: "tray")
                .font(.system(size: 48))
                .foregroundColor(.secondary)

            Text("No items in this list")
                .font(.title3)
                .foregroundColor(.secondary)

            Text("Drag items here or add a new one")
                .font(.caption)
                .foregroundColor(.secondary)

            Button("Add First Item") {
                showingAddItemSheet = true
            }
            .buttonStyle(.borderedProminent)
        }
    }

    @ViewBuilder
    private var noMatchingItemsView: some View {
        VStack(spacing: 16) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 48))
                .foregroundColor(.secondary)

            Text("No matching items")
                .font(.title3)
                .foregroundColor(.secondary)

            Text("Try adjusting your filter or search criteria")
                .font(.caption)
                .foregroundColor(.secondary)

            Button("Clear Filters") {
                viewModel.searchText = ""
                viewModel.updateFilterOption(.all)
                // CRITICAL: Refresh items from DataManager when clearing all filters
                viewModel.items = items
            }
            .buttonStyle(.borderedProminent)
        }
    }

    // MARK: - Items List View

    /// Whether drag-to-reorder is enabled (only when sorted by orderNumber)
    private var canReorderItems: Bool {
        viewModel.currentSortOption == .orderNumber
    }

    /// The items to display, using ViewModel's filtered list
    private var displayedItems: [Item] {
        viewModel.filteredItems
    }

    private var itemsListView: some View {
        SwiftUI.List {
            ForEach(displayedItems) { item in
                makeItemRow(item: item)
                    .draggable(item)
            }
            .onMove(perform: handleMoveItem)
        }
        .listStyle(.inset)
    }

    private func handleMoveItem(from source: IndexSet, to destination: Int) {
        guard canReorderItems else { return }
        viewModel.moveItems(from: source, to: destination)
    }

    private func makeItemRow(item: Item) -> some View {
        MacItemRowView(
            item: item,
            onToggle: { toggleItem(item) },
            onEdit: {
                // CRITICAL FIX: Delegate to parent (MacMainView) for sheet presentation
                // Sheet state inside NavigationSplitView detail pane is lost during view invalidation
                // caused by @EnvironmentObject changes from CloudKit sync.
                // By calling parent's callback, sheet state lives OUTSIDE NavigationSplitView.
                print("🎯 MacListDetailView: Forwarding edit request to MacMainView for item: \(item.title)")
                onEditItem(item)
            },
            onDelete: { deleteItem(item) },
            onQuickLook: { showQuickLook(for: item) }
        )
    }

    private func handleSpacebarPress() -> KeyPress.Result {
        if let item = quickLookItem, item.hasImages {
            showQuickLook(for: item)
            return .handled
        }
        return .ignored
    }

    // MARK: - Main Body

    var body: some View {
        VStack(spacing: 0) {
            headerView
            activeFiltersBar
            Divider()

            if viewModel.filteredItems.isEmpty {
                Group {
                    if items.isEmpty {
                        emptyListView
                    } else {
                        noMatchingItemsView
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .dropDestination(for: ItemTransferData.self) { droppedItems, _ in
                    handleItemDrop(droppedItems)
                }
            } else {
                itemsListView
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .navigationTitle(displayName)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button(action: { showingAddItemSheet = true }) {
                    Label("Add Item", systemImage: "plus")
                }
            }
        }
        // Sync ViewModel items with DataManager for proper reactivity
        .onChange(of: items) { _, newItems in
            // NOTE: Edit state protection is now handled at MacMainView level (isEditingAnyItem)
            // which blocks dataManager.loadData() calls during editing
            viewModel.items = newItems
        }
        .onAppear {
            // Initialize ViewModel with current items
            viewModel.items = items
        }
        // CRITICAL: Observe DataManager changes directly to keep ViewModel in sync
        // When clearing search/filter, we need fresh data from DataManager
        .onReceive(NotificationCenter.default.publisher(for: .coreDataRemoteChange)) { _ in
            // NOTE: Edit state protection is now handled at MacMainView level (isEditingAnyItem)
            // CRITICAL: Defer to next run loop to prevent layout recursion
            // Notifications can fire during layout passes, causing the error:
            // "It's not legal to call -layoutSubtreeIfNeeded on a view already being laid out"
            DispatchQueue.main.async {
                // Force refresh ViewModel items when Core Data syncs remote changes
                viewModel.items = items
            }
        }
        .sheet(isPresented: $showingAddItemSheet) {
            MacAddItemSheet(
                listId: list.id,
                onSave: { title, quantity, description in
                    addItem(title: title, quantity: quantity, description: description)
                    showingAddItemSheet = false
                },
                onCancel: { showingAddItemSheet = false }
            )
        }
        // NOTE: Edit item sheet has been moved to MacMainView (outside NavigationSplitView)
        // to prevent state loss during CloudKit sync view invalidation
        .sheet(isPresented: $showingEditListSheet) {
            MacEditListSheet(
                list: currentList ?? list,
                onSave: { name in
                    updateListName(name)
                    showingEditListSheet = false
                },
                onCancel: { showingEditListSheet = false }
            )
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("CreateNewItem"))) { _ in
            showingAddItemSheet = true
        }
        .onAppear {
            // Advertise Handoff activity for viewing this specific list
            HandoffService.shared.startViewingListActivity(list: list)
        }
    }

    // MARK: - Item Actions

    private func toggleItem(_ item: Item) {
        var updatedItem = item
        updatedItem.isCrossedOut.toggle()
        updatedItem.modifiedAt = Date()
        dataManager.updateItem(updatedItem)
    }

    private func addItem(title: String, quantity: Int, description: String?) {
        var newItem = Item(title: title, listId: list.id)
        newItem.quantity = quantity
        newItem.itemDescription = description
        newItem.orderNumber = items.count
        dataManager.addItem(newItem, to: list.id)
        dataManager.loadData()
    }

    private func updateItem(_ item: Item, title: String, quantity: Int, description: String?, images: [ItemImage]? = nil) {
        var updatedItem = item
        updatedItem.title = title
        updatedItem.quantity = quantity
        updatedItem.itemDescription = description
        if let images = images {
            updatedItem.images = images
        }
        updatedItem.modifiedAt = Date()
        dataManager.updateItem(updatedItem)
    }

    private func deleteItem(_ item: Item) {
        dataManager.deleteItem(withId: item.id, from: list.id)
    }

    private func updateListName(_ name: String) {
        guard var updatedList = currentList else { return }
        updatedList.name = name
        dataManager.updateList(updatedList)
    }

    // MARK: - Quick Look

    /// Shows Quick Look preview for an item's images
    private func showQuickLook(for item: Item) {
        guard item.hasImages else {
            print("⚠️ Quick Look: Item '\(item.displayTitle)' has no images")
            return
        }

        // Use the shared QuickLookController to show preview
        QuickLookController.shared.preview(item: item)
        print("📷 Quick Look: Showing preview for '\(item.displayTitle)' with \(item.imageCount) images")
    }

    // MARK: - Drag-and-Drop Handlers

    /// Handle item drop on this list's detail view (moves item from another list)
    private func handleItemDrop(_ droppedItems: [ItemTransferData]) -> Bool {
        var didMoveAny = false

        for itemData in droppedItems {
            // Skip if item is already in this list
            guard itemData.sourceListId != list.id else { continue }

            // Find the item in DataManager
            let sourceItems = dataManager.getItems(forListId: itemData.sourceListId ?? UUID())
            guard let item = sourceItems.first(where: { $0.id == itemData.itemId }) else { continue }
            guard let targetList = currentList else { continue }

            // Move item to this list
            dataRepository.moveItem(item, to: targetList)
            didMoveAny = true
            print("📦 Moved item '\(item.title)' to list '\(targetList.name)'")
        }

        if didMoveAny {
            dataManager.loadData()
        }

        return didMoveAny
    }

}

// MARK: - Item Row View

private struct MacItemRowView: View {
    let item: Item
    let onToggle: () -> Void
    let onEdit: () -> Void
    let onDelete: () -> Void
    let onQuickLook: () -> Void

    @State private var isHovering = false

    var body: some View {
        HStack(spacing: 12) {
            // Checkbox button
            Button(action: onToggle) {
                Image(systemName: item.isCrossedOut ? "checkmark.circle.fill" : "circle")
                    .font(.title2)
                    .foregroundColor(item.isCrossedOut ? .green : .secondary)
            }
            .buttonStyle(.plain)

            // Image thumbnail (if item has images)
            if item.hasImages, let firstImage = item.sortedImages.first, let nsImage = firstImage.nsImage {
                Button(action: onQuickLook) {
                    ZStack(alignment: .bottomTrailing) {
                        Image(nsImage: nsImage)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: 36, height: 36)
                            .clipShape(RoundedRectangle(cornerRadius: 4))
                            .overlay(
                                RoundedRectangle(cornerRadius: 4)
                                    .stroke(Color.secondary.opacity(0.3), lineWidth: 0.5)
                            )

                        // Badge for multiple images
                        if item.imageCount > 1 {
                            Text("\(item.imageCount)")
                                .font(.system(size: 8, weight: .bold))
                                .foregroundColor(.white)
                                .padding(.horizontal, 3)
                                .padding(.vertical, 1)
                                .background(Color.black.opacity(0.7))
                                .clipShape(Capsule())
                                .offset(x: 2, y: 2)
                        }
                    }
                }
                .buttonStyle(.plain)
                .help("Quick Look (Space)")
            }

            // Item content
            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    Text(item.title)
                        .font(.body)
                        .strikethrough(item.isCrossedOut)
                        .foregroundColor(item.isCrossedOut ? .secondary : .primary)

                    if item.quantity > 1 {
                        Text("×\(item.quantity)")
                            .font(.caption)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.secondary.opacity(0.2))
                            .cornerRadius(4)
                    }

                    // Show photo icon only when no thumbnail (fallback indicator)
                    if item.hasImages && item.sortedImages.first?.nsImage == nil {
                        Image(systemName: "photo")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }

                if let description = item.itemDescription, !description.isEmpty {
                    Text(description)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
            }

            Spacer()

            // Hover actions
            if isHovering {
                HStack(spacing: 8) {
                    // Quick Look button (only if item has images)
                    if item.hasImages {
                        Button(action: onQuickLook) {
                            Image(systemName: "eye")
                        }
                        .buttonStyle(.plain)
                        .help("Quick Look (Space)")
                    }

                    Button(action: onEdit) {
                        Image(systemName: "pencil")
                    }
                    .buttonStyle(.plain)
                    .help("Edit Item")

                    Button(action: onDelete) {
                        Image(systemName: "trash")
                            .foregroundColor(.red)
                    }
                    .buttonStyle(.plain)
                    .help("Delete Item")
                }
            }
        }
        .padding(.vertical, 4)
        .onHover { hovering in
            isHovering = hovering
        }
        // CRITICAL: Use native AppKit double-click handler instead of .onTapGesture(count: 2)
        // SwiftUI's gesture system blocks the run loop on macOS, causing sheets to only
        // appear after app deactivation. This native handler fires immediately.
        .onDoubleClick {
            onEdit()
        }
        .contentShape(Rectangle())  // Move contentShape AFTER onDoubleClick so it doesn't block events
        .listRowBackground(Color.clear)  // Disable default selection overlay
        .contextMenu {
            Button("Edit") { onEdit() }
            Button(item.isCrossedOut ? "Mark as Active" : "Mark as Complete") { onToggle() }

            if item.hasImages {
                Divider()
                Button("Quick Look") {
                    onQuickLook()
                }
                .keyboardShortcut(.space, modifiers: [])
            }

            Divider()
            Button("Delete", role: .destructive) { onDelete() }
        }
    }
}

// MARK: - Add Item Sheet

private struct MacAddItemSheet: View {
    let listId: UUID
    let onSave: (String, Int, String?) -> Void
    let onCancel: () -> Void

    @State private var title = ""
    @State private var quantity = 1
    @State private var description = ""

    var body: some View {
        VStack(spacing: 20) {
            Text("Add Item")
                .font(.title2)
                .fontWeight(.semibold)

            VStack(alignment: .leading, spacing: 12) {
                TextField("Item Name", text: $title)
                    .textFieldStyle(.roundedBorder)

                HStack {
                    Text("Quantity:")
                    Stepper(value: $quantity, in: 1...999) {
                        Text("\(quantity)")
                            .frame(width: 40)
                    }
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text("Notes (optional):")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    TextEditor(text: $description)
                        .frame(height: 60)
                        .border(Color.secondary.opacity(0.3))
                }
            }
            .frame(width: 300)

            HStack(spacing: 16) {
                Button("Cancel") {
                    onCancel()
                }
                .keyboardShortcut(.escape)

                Button("Add") {
                    onSave(title, quantity, description.isEmpty ? nil : description)
                }
                .keyboardShortcut(.return)
                .buttonStyle(.borderedProminent)
                .disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .padding(30)
        .frame(minWidth: 400)
    }
}

// MARK: - Edit Item Sheet

private struct MacEditItemSheet: View {
    let item: Item
    let onSave: (String, Int, String?, [ItemImage]) -> Void
    let onCancel: () -> Void

    @State private var title: String
    @State private var quantity: Int
    @State private var description: String
    @State private var images: [ItemImage]

    // Defer gallery loading to allow sheet to appear faster
    // The gallery is the heaviest component - loading it after initial layout
    // significantly reduces perceived delay when opening the edit sheet
    @State private var isGalleryReady = false

    init(item: Item, onSave: @escaping (String, Int, String?, [ItemImage]) -> Void, onCancel: @escaping () -> Void) {
        self.item = item
        self.onSave = onSave
        self.onCancel = onCancel
        _title = State(initialValue: item.title)
        _quantity = State(initialValue: item.quantity)
        _description = State(initialValue: item.itemDescription ?? "")
        // CRITICAL: Initialize images as empty to defer heavy copy operation
        // The gallery will load them asynchronously after sheet appears
        _images = State(initialValue: [])
        // Defer the actual image loading to after sheet is visible
        _isGalleryReady = State(initialValue: false)
    }

    var body: some View {
        VStack(spacing: 20) {
            Text("Edit Item")
                .font(.title2)
                .fontWeight(.semibold)

            VStack(alignment: .leading, spacing: 12) {
                TextField("Item Name", text: $title)
                    .textFieldStyle(.roundedBorder)

                HStack {
                    Text("Quantity:")
                    Stepper(value: $quantity, in: 1...999) {
                        Text("\(quantity)")
                            .frame(width: 40)
                    }
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text("Notes (optional):")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    TextEditor(text: $description)
                        .frame(height: 60)
                        .border(Color.secondary.opacity(0.3))
                }

                // Image Gallery Section - deferred loading for faster sheet appearance
                VStack(alignment: .leading, spacing: 4) {
                    Text("Images:")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    if isGalleryReady {
                        MacImageGalleryView(
                            images: $images,
                            itemId: item.id,
                            itemTitle: item.title
                        )
                        .frame(height: 200)
                    } else {
                        // Placeholder while gallery loads
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.secondary.opacity(0.1))
                            .frame(height: 200)
                            .overlay(
                                ProgressView()
                                    .scaleEffect(0.8)
                            )
                    }
                }
            }
            .frame(width: 400)

            HStack(spacing: 16) {
                Button("Cancel") {
                    onCancel()
                }
                .keyboardShortcut(.escape)

                Button("Save") {
                    onSave(title, quantity, description.isEmpty ? nil : description, images)
                }
                .keyboardShortcut(.return)
                .buttonStyle(.borderedProminent)
                .disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .padding(30)
        .frame(minWidth: 500)
        .onAppear {
            // Defer gallery loading until after sheet animation completes
            // This makes the sheet appear much faster by splitting the work:
            // 1. Sheet appears immediately with placeholder
            // 2. On next run loop cycle, load images
            // 3. Gallery renders progressively without blocking sheet presentation
            DispatchQueue.main.async {
                // Use withTransaction to disable implicit animations during load
                // This prevents animation conflicts that cause layout recursion
                withTransaction(Transaction(animation: nil)) {
                    // Load actual images from item
                    self.images = item.images
                    // Enable gallery rendering
                    isGalleryReady = true
                }
            }
        }
    }
}

// MARK: - Edit List Sheet

private struct MacEditListSheet: View {
    let list: List
    let onSave: (String) -> Void
    let onCancel: () -> Void

    @State private var name: String

    init(list: List, onSave: @escaping (String) -> Void, onCancel: @escaping () -> Void) {
        self.list = list
        self.onSave = onSave
        self.onCancel = onCancel
        _name = State(initialValue: list.name)
    }

    var body: some View {
        VStack(spacing: 20) {
            Text("Edit List")
                .font(.title2)
                .fontWeight(.semibold)

            TextField("List Name", text: $name)
                .textFieldStyle(.roundedBorder)
                .frame(width: 300)
                .onSubmit {
                    if !name.isEmpty {
                        onSave(name)
                    }
                }

            HStack(spacing: 16) {
                Button("Cancel") {
                    onCancel()
                }
                .keyboardShortcut(.escape)

                Button("Save") {
                    onSave(name)
                }
                .keyboardShortcut(.return)
                .buttonStyle(.borderedProminent)
                .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .padding(30)
        .frame(minWidth: 350)
    }
}

// MARK: - Empty State View

private struct MacEmptyStateView: View {
    let onCreateList: () -> Void

    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "list.bullet.clipboard")
                .font(.system(size: 64))
                .foregroundColor(.secondary)

            Text("No List Selected")
                .font(.title2)
                .foregroundColor(.secondary)

            Text("Select a list from the sidebar or create a new one.")
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)

            Button("Create New List") {
                onCreateList()
            }
            .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Filter Badge

private struct FilterBadge: View {
    let icon: String
    let text: String
    let onClear: () -> Void

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.caption)
            Text(text)
                .font(.caption)
            Button(action: onClear) {
                Image(systemName: "xmark.circle.fill")
                    .font(.caption)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Color.accentColor.opacity(0.1))
        .cornerRadius(12)
    }
}

// MARK: - Create List Sheet

private struct MacCreateListSheet: View {
    @State private var listName = ""
    let onSave: (String) -> Void
    let onCancel: () -> Void

    var body: some View {
        VStack(spacing: 20) {
            Text("New List")
                .font(.title2)
                .fontWeight(.semibold)

            TextField("List Name", text: $listName)
                .textFieldStyle(.roundedBorder)
                .frame(width: 300)
                .onSubmit {
                    if !listName.isEmpty {
                        onSave(listName)
                    }
                }

            HStack(spacing: 16) {
                Button("Cancel") {
                    onCancel()
                }
                .keyboardShortcut(.escape)

                Button("Create") {
                    onSave(listName)
                }
                .keyboardShortcut(.return)
                .buttonStyle(.borderedProminent)
                .disabled(listName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .padding(30)
        .frame(minWidth: 350)
    }
}

// MARK: - Native Double-Click Handler
// Uses NSEvent.addLocalMonitorForEvents to detect double-clicks without blocking the run loop.
//
// KEY INSIGHT (from deep research): The reason sheets only appear after app deactivation:
// 1. During event handling, the run loop is in "event tracking" mode
// 2. DispatchQueue.main.async only executes in "default" mode
// 3. So sheet presentation is queued but never runs until mode changes
// 4. App deactivation forces a mode change, which finally presents the sheet
//
// SOLUTION: Use performSelector(afterDelay:) which works in ALL run loop modes,
// not just the default mode like DispatchQueue.main.async

/// View modifier that adds reliable double-click detection using event monitoring
private struct DoubleClickHandler: ViewModifier {
    let handler: () -> Void

    func body(content: Content) -> some View {
        content.background(
            DoubleClickMonitorView(handler: handler)
        )
    }
}

/// NSViewRepresentable that installs an event monitor for double-clicks
private struct DoubleClickMonitorView: NSViewRepresentable {
    let handler: () -> Void

    func makeNSView(context: Context) -> DoubleClickMonitorNSView {
        DoubleClickMonitorNSView(handler: handler)
    }

    func updateNSView(_ nsView: DoubleClickMonitorNSView, context: Context) {
        nsView.handler = handler
    }
}

/// NSView that monitors for double-clicks using local event monitor
/// This approach doesn't block events and works with all run loop modes
private class DoubleClickMonitorNSView: NSView {
    var handler: () -> Void
    private var eventMonitor: Any?

    init(handler: @escaping () -> Void) {
        self.handler = handler
        super.init(frame: .zero)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()

        if window != nil {
            installEventMonitor()
        } else {
            removeEventMonitor()
        }
    }

    private func installEventMonitor() {
        guard eventMonitor == nil else { return }

        eventMonitor = NSEvent.addLocalMonitorForEvents(matching: .leftMouseDown) { [weak self] event in
            guard let self = self,
                  let window = self.window,
                  event.window == window,
                  event.clickCount == 2 else {
                return event
            }

            // Convert event location to view coordinates
            let locationInWindow = event.locationInWindow
            let locationInView = self.convert(locationInWindow, from: nil)

            // Check if click is within our bounds
            if self.bounds.contains(locationInView) {
                // CRITICAL FIX: Use performSelector(afterDelay:) instead of DispatchQueue.main.async
                // performSelector works in ALL run loop modes (including event tracking mode)
                // This breaks the deadlock where sheets only appear after app deactivation
                self.perform(#selector(self.invokeHandler), with: nil, afterDelay: 0)
            }

            return event  // Let event continue to other handlers
        }
    }

    @objc private func invokeHandler() {
        handler()
    }

    private func removeEventMonitor() {
        if let monitor = eventMonitor {
            NSEvent.removeMonitor(monitor)
            eventMonitor = nil
        }
    }

    deinit {
        removeEventMonitor()
    }
}

/// Extension to make double-click handler easy to use
extension View {
    func onDoubleClick(perform action: @escaping () -> Void) -> some View {
        modifier(DoubleClickHandler(handler: action))
    }
}

#Preview {
    MacMainView()
        .environmentObject(DataManager.shared)
        .environment(\.managedObjectContext, CoreDataManager.shared.viewContext)
}
