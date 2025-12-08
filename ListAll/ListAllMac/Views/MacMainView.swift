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

    var body: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
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
        } detail: {
            // Detail view for selected list
            if let list = selectedList {
                MacListDetailView(list: list)
                    .id(list.id) // Force refresh when selection changes
            } else {
                MacEmptyStateView(onCreateList: { showingCreateListSheet = true })
            }
        }
        .frame(minWidth: 800, minHeight: 600)
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
            dataManager.loadData()
        }
        .onReceive(NotificationCenter.default.publisher(for: .coreDataRemoteChange)) { _ in
            print("🌐 macOS: Received Core Data remote change notification - refreshing UI")
            dataManager.loadData()
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

        syncPollingTimer = Timer.scheduledTimer(withTimeInterval: syncPollingInterval, repeats: true) { _ in
            print("🔄 macOS: Polling for CloudKit changes (timer-based fallback)")

            // Force Core Data to check for remote changes
            viewContext.perform {
                viewContext.refreshAllObjects()
            }

            // Reload data to update UI
            dataManager.loadData()
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
                            Text("\(list.items.count)")
                                .foregroundColor(.secondary)
                                .font(.caption)
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
    @EnvironmentObject var dataManager: DataManager

    // State for item management
    @State private var showingAddItemSheet = false
    @State private var showingEditItemSheet = false
    @State private var selectedItem: Item?
    @State private var showingEditListSheet = false

    // State for Quick Look
    @State private var quickLookItem: Item?

    // DataRepository for drag-and-drop operations
    private let dataRepository = DataRepository()

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

    var body: some View {
        VStack(spacing: 0) {
            // Header with list name and actions
            HStack {
                Text(displayName)
                    .font(.largeTitle)
                    .fontWeight(.bold)

                Spacer()

                Button(action: { showingEditListSheet = true }) {
                    Image(systemName: "pencil")
                }
                .buttonStyle(.plain)
                .help("Edit List")
            }
            .padding()

            Divider()

            if items.isEmpty {
                // Empty state for list with no items - also accepts drops
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
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .dropDestination(for: ItemTransferData.self) { droppedItems, _ in
                    handleItemDrop(droppedItems)
                }
            } else {
                // Items list with MacItemRowView
                SwiftUI.List(selection: $quickLookItem) {
                    ForEach(items) { item in
                        MacItemRowView(
                            item: item,
                            onToggle: { toggleItem(item) },
                            onEdit: {
                                selectedItem = item
                                showingEditItemSheet = true
                            },
                            onDelete: { deleteItem(item) },
                            onQuickLook: { showQuickLook(for: item) }
                        )
                        .draggable(item) // Enable dragging items
                        .tag(item)
                    }
                    .onMove(perform: moveItem) // Handle item reordering within list
                }
                .listStyle(.inset)
                .dropDestination(for: ItemTransferData.self) { droppedItems, _ in
                    handleItemDrop(droppedItems)
                }
                // Spacebar handler for Quick Look
                .onKeyPress(.space) {
                    if let item = quickLookItem, item.hasImages {
                        showQuickLook(for: item)
                        return .handled
                    }
                    return .ignored
                }
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
        .sheet(isPresented: $showingEditItemSheet) {
            if let item = selectedItem {
                MacEditItemSheet(
                    item: item,
                    onSave: { title, quantity, description, images in
                        updateItem(item, title: title, quantity: quantity, description: description, images: images)
                        showingEditItemSheet = false
                        selectedItem = nil
                    },
                    onCancel: {
                        showingEditItemSheet = false
                        selectedItem = nil
                    }
                )
            }
        }
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

    /// Handle item reordering within this list via drag-and-drop
    private func moveItem(from source: IndexSet, to destination: Int) {
        // Get current order
        var reorderedItems = items

        // Perform the move
        reorderedItems.move(fromOffsets: source, toOffset: destination)

        // Update order numbers - must modify array elements directly (value types!)
        for index in reorderedItems.indices {
            reorderedItems[index].orderNumber = index
            reorderedItems[index].modifiedAt = Date()
        }

        print("📦 Reordering items: \(reorderedItems.map { "\($0.title):\($0.orderNumber)" })")

        // Persist the new order using DataRepository
        if let targetList = currentList {
            dataRepository.updateItemOrderNumbers(for: targetList, items: reorderedItems)
        }

        dataManager.loadData()

        print("📦 Reordered items within list via drag-and-drop")
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
        .contentShape(Rectangle())
        .onHover { hovering in
            isHovering = hovering
        }
        .onTapGesture(count: 2) {
            onEdit()
        }
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

    init(item: Item, onSave: @escaping (String, Int, String?, [ItemImage]) -> Void, onCancel: @escaping () -> Void) {
        self.item = item
        self.onSave = onSave
        self.onCancel = onCancel
        _title = State(initialValue: item.title)
        _quantity = State(initialValue: item.quantity)
        _description = State(initialValue: item.itemDescription ?? "")
        _images = State(initialValue: item.images)
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

                // Image Gallery Section
                VStack(alignment: .leading, spacing: 4) {
                    Text("Images:")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    MacImageGalleryView(
                        images: $images,
                        itemId: item.id,
                        itemTitle: item.title
                    )
                    .frame(height: 200)
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

#Preview {
    MacMainView()
        .environmentObject(DataManager.shared)
        .environment(\.managedObjectContext, CoreDataManager.shared.viewContext)
}
