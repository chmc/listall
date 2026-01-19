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
import Combine

/// Main view for macOS app with sidebar navigation.
/// This is the macOS equivalent of iOS ContentView, using NavigationSplitView
/// for the standard macOS three-column layout.
struct MacMainView: View {
    @EnvironmentObject var dataManager: DataManager
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.scenePhase) private var scenePhase

    // Access CoreDataManager for sync status (lastSyncDate) and manual refresh
    @ObservedObject private var coreDataManager = CoreDataManager.shared

    // MARK: - Proactive Feature Tips (Task 12.5)
    @ObservedObject private var tooltipManager = MacTooltipManager.shared

    // MARK: - CloudKit Sync Status (Task 12.6)
    @ObservedObject private var cloudKitService = CloudKitService.shared

    @State private var selectedList: List?
    @State private var columnVisibility: NavigationSplitViewVisibility = .all

    // MARK: - Focus State for Keyboard Navigation (Task 11.1)
    /// Tracks which major section has keyboard focus
    enum FocusSection: Hashable {
        case sidebar
        case detail
    }
    @FocusState private var focusedSection: FocusSection?

    // Menu command observers
    @State private var showingCreateListSheet = false
    @State private var showingArchivedLists = false
    @State private var showingSharePopover = false
    @State private var showingExportAllSheet = false

    // MARK: - CloudKit Sync Polling (macOS fallback)
    // Apple's CloudKit notifications on macOS can be unreliable when the app is frontmost.
    // This timer serves as a safety net to ensure data refreshes even if notifications miss.
    // Using Timer.publish with .onReceive is the correct SwiftUI pattern (not Timer.scheduledTimer).
    // LEARNING: Timer.scheduledTimer with [self] capture in SwiftUI Views captures a COPY of the struct,
    // causing the timer callback to operate on stale state. Timer.publish integrates with SwiftUI lifecycle.
    @State private var isSyncPollingActive = false
    private let syncPollingTimer = Timer.publish(every: 30.0, on: .main, in: .common).autoconnect()

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

    // MARK: - Sync Status Indicator (Task 12.6)

    /// Sync button image with rotation animation on macOS 15+, fallback for older versions
    @ViewBuilder
    private var syncButtonImage: some View {
        if #available(macOS 15.0, *) {
            Image(systemName: "arrow.triangle.2.circlepath")
                .symbolEffect(.rotate, isActive: cloudKitService.isSyncing)
        } else {
            // Fallback for macOS 14: use rotationEffect with animation
            Image(systemName: "arrow.triangle.2.circlepath")
                .rotationEffect(.degrees(cloudKitService.isSyncing ? 360 : 0))
                .animation(
                    cloudKitService.isSyncing
                        ? .linear(duration: 1.0).repeatForever(autoreverses: false)
                        : .default,
                    value: cloudKitService.isSyncing
                )
        }
    }

    /// Tooltip text for sync status button in toolbar
    /// Shows syncing state, last sync time, or error message
    private var syncTooltipText: String {
        if cloudKitService.isSyncing {
            return "Syncing with iCloud..."
        } else if let error = cloudKitService.syncError {
            return "Sync error: \(error) - Click to retry"
        } else if let lastSync = coreDataManager.lastSyncDate {
            let formatter = RelativeDateTimeFormatter()
            formatter.unitsStyle = .short
            return "Last synced \(formatter.localizedString(for: lastSync, relativeTo: Date())) - Click to sync"
        } else {
            return "Click to sync with iCloud"
        }
    }

    var body: some View {
        ZStack(alignment: .topTrailing) {
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
            }
            // Apply column width to NavigationStack wrapper (not inside it)
            .navigationSplitViewColumnWidth(min: 220, ideal: 260, max: 400)
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
                // Show different empty states based on whether any lists exist
                if dataManager.lists.isEmpty {
                    // No lists at all - show welcome with sample templates
                    MacListsEmptyStateView(
                        onCreateSampleList: { template in
                            createSampleList(from: template)
                        },
                        onCreateCustomList: { showingCreateListSheet = true }
                    )
                } else {
                    // Lists exist but none selected - simple prompt
                    MacNoListSelectedView(onCreateList: { showingCreateListSheet = true })
                }
            }
        }
        .frame(minWidth: 800, minHeight: 600)
        // MARK: - Sync Status Indicator in Toolbar (Task 12.6)
        // Prominent toolbar sync button with animation during sync
        // Placed at NavigationSplitView level so it's always visible in main window toolbar
        .toolbar {
            ToolbarItem(placement: .automatic) {
                Button(action: {
                    Task { await cloudKitService.sync() }
                }) {
                    syncButtonImage
                }
                .help(syncTooltipText)
                .foregroundColor(cloudKitService.syncError != nil ? .red : .primary)
                .disabled(cloudKitService.isSyncing)
                .accessibilityIdentifier("SyncStatusButton")
                .accessibilityLabel(cloudKitService.isSyncing ? "Syncing with iCloud" : "Sync with iCloud")
            }
        }
        // MARK: - Global Cmd+F Handler (Task 12.2)
        // Handles Cmd+F from ANY focus location (sidebar or detail view)
        // Posts notification to MacListDetailView to focus search field
        .onKeyPress(characters: CharacterSet(charactersIn: "f")) { keyPress in
            guard keyPress.modifiers.contains(.command) else {
                return .ignored
            }

            // If no list selected, select the first one (if available)
            if selectedList == nil, let firstList = dataManager.lists.first {
                selectedList = firstList
                // Slight delay to allow detail view to appear before focusing search
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    NotificationCenter.default.post(name: NSNotification.Name("FocusSearchField"), object: nil)
                }
            } else if selectedList != nil {
                // List already selected, just focus search
                NotificationCenter.default.post(name: NSNotification.Name("FocusSearchField"), object: nil)
            }
            return .handled
        }
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
        .onChange(of: showingArchivedLists) { _, newValue in
            if newValue {
                // Load archived lists when switching to archived view
                dataManager.loadArchivedData()
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
        // Share menu command handlers
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("ShareSelectedList"))) { _ in
            if selectedList != nil {
                showingSharePopover = true
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("ExportAllLists"))) { _ in
            showingExportAllSheet = true
        }
        // MARK: - Sync Polling Timer (Timer.publish pattern)
        // This is the SwiftUI-native pattern that properly integrates with view lifecycle
        // See: ios-cloudkit-sync-polling-timer.md learning for why Timer.scheduledTimer fails
        .onReceive(syncPollingTimer) { _ in
            guard isSyncPollingActive else { return }
            performSyncPoll()
        }
        .sheet(isPresented: $showingSharePopover) {
            if let list = selectedList {
                MacShareFormatPickerView(
                    list: list,
                    onDismiss: { showingSharePopover = false }
                )
            }
        }
        .sheet(isPresented: $showingExportAllSheet) {
            MacExportAllListsSheet(onDismiss: { showingExportAllSheet = false })
        }

            // MARK: - Proactive Feature Tips Overlay (Task 12.5)
            // Toast-style notification in top-right corner
            if tooltipManager.isShowingTooltip, let tip = tooltipManager.currentTooltip {
                MacTooltipNotificationView(tip: tip) {
                    withAnimation(.easeOut(duration: 0.2)) {
                        tooltipManager.dismissCurrentTooltip()
                    }
                }
                .padding(.top, 60) // Below toolbar
                .padding(.trailing, 20)
                .transition(.asymmetric(
                    insertion: .move(edge: .trailing).combined(with: .opacity),
                    removal: .opacity
                ))
                .zIndex(100) // Ensure it appears above other content
            }
        } // End ZStack
        // MARK: - Proactive Tip Triggers (Task 12.5)
        // Show contextual tips based on app state with delays
        .onAppear {
            triggerProactiveTips()
        }
    }

    // MARK: - Sync Polling Methods

    /// Enables the sync polling timer (when window becomes active)
    /// Timer.publish runs continuously but we control whether to act via isSyncPollingActive flag
    private func startSyncPolling() {
        guard !isSyncPollingActive else { return }
        isSyncPollingActive = true
        print("🔄 macOS: Sync polling enabled (every 30s)")
    }

    /// Disables the sync polling timer (when app goes to background or view disappears)
    /// Timer continues publishing but the .onReceive handler will skip processing
    private func stopSyncPolling() {
        isSyncPollingActive = false
        print("🔄 macOS: Sync polling disabled")
    }

    /// Performs the actual sync polling work (called from .onReceive modifier)
    private func performSyncPoll() {
        // Skip polling if user is editing - prevents UI interruption during sheet presentation
        guard !isEditingAnyItem else {
            print("🛡️ macOS: Skipping poll - user is editing item")
            return
        }

        print("🔄 macOS: Polling for CloudKit changes (timer-based fallback)")

        // CRITICAL FIX: Use performAndWait (synchronous) to ensure refreshAllObjects()
        // completes BEFORE loadData() fetches. This prevents race conditions where
        // loadData() could fetch stale data before refreshAllObjects() completed.
        viewContext.performAndWait {
            viewContext.refreshAllObjects()
        }

        // ENHANCEMENT: Trigger a background context operation to encourage CloudKit
        // sync engine to wake up and check for pending operations
        CoreDataManager.shared.triggerCloudKitSync()

        // Now safe to load data - viewContext has been refreshed
        // Use async to prevent layout recursion if timer fires during layout pass
        DispatchQueue.main.async {
            dataManager.loadData()
        }
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

    private func createSampleList(from template: SampleDataService.SampleListTemplate) {
        // Use SampleDataService to create and populate the list
        let createdList = SampleDataService.saveTemplateList(template, using: dataManager)

        // Select the newly created list
        selectedList = createdList
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

    // MARK: - Proactive Feature Tips (Task 12.5)

    /// Triggers proactive feature tips based on current app state
    /// Tips are shown with delays to avoid overwhelming new users
    private func triggerProactiveTips() {
        // Skip if user is editing (don't interrupt workflows)
        guard !isEditingAnyItem else { return }

        // 0.8s delay: Keyboard shortcuts tip for new users
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
            withAnimation(.easeIn(duration: 0.3)) {
                _ = tooltipManager.showIfNeeded(.keyboardShortcuts)
            }
        }

        // 1.2s delay: Add list tip if no lists exist
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
            if dataManager.lists.isEmpty {
                withAnimation(.easeIn(duration: 0.3)) {
                    _ = tooltipManager.showIfNeeded(.addListButton)
                }
            }
        }

        // 1.5s delay: Archive tip if user has 3+ lists
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            if dataManager.lists.count >= 3 {
                withAnimation(.easeIn(duration: 0.3)) {
                    _ = tooltipManager.showIfNeeded(.archiveFunctionality)
                }
            }
        }
    }
}

// MARK: - Sidebar View

private struct MacSidebarView: View {
    // CRITICAL: Observe dataManager directly instead of receiving array by value
    // Passing [List] by value breaks SwiftUI observation chain on macOS
    @EnvironmentObject var dataManager: DataManager

    // Access CoreDataManager for sync status and manual refresh
    @ObservedObject private var coreDataManager = CoreDataManager.shared

    @Binding var showingArchivedLists: Bool
    @Binding var selectedList: List?
    let onCreateList: () -> Void
    let onDeleteList: (List) -> Void

    // State for share popover from context menu
    @State private var listToShare: List?
    @State private var showingSharePopover = false

    // DataRepository for drag-and-drop operations
    private let dataRepository = DataRepository()

    // MARK: - Multi-Select Mode State
    @State private var isInSelectionMode = false
    @State private var selectedLists: Set<UUID> = []
    @State private var showingArchiveConfirmation = false
    @State private var showingPermanentDeleteConfirmation = false

    // MARK: - Keyboard Navigation (Task 11.1)
    /// Focus state for individual list rows - enables arrow key navigation
    @FocusState private var focusedListID: UUID?

    // Compute lists directly from @Published source for proper reactivity
    // Uses dataManager.archivedLists (populated via loadArchivedData()) for archived lists
    // Uses dataManager.lists (populated via loadData()) for active lists
    private var displayedLists: [List] {
        if showingArchivedLists {
            // Use cached archivedLists property - sorted by modifiedAt descending (most recent first)
            return dataManager.archivedLists
        } else {
            return dataManager.lists.filter { !$0.isArchived }
                .sorted { $0.orderNumber < $1.orderNumber }
        }
    }

    /// Tooltip text showing last sync time for refresh button
    private var lastSyncTooltip: String {
        if let lastSync = coreDataManager.lastSyncDate {
            let formatter = RelativeDateTimeFormatter()
            formatter.unitsStyle = .abbreviated
            return "Last synced: \(formatter.localizedString(for: lastSync, relativeTo: Date()))"
        } else {
            return "Refresh - Click to sync with iCloud"
        }
    }

    /// Formatted last sync time for display in UI
    private var lastSyncDisplayText: String {
        if let lastSync = coreDataManager.lastSyncDate {
            let formatter = RelativeDateTimeFormatter()
            formatter.unitsStyle = .short
            return "Synced \(formatter.localizedString(for: lastSync, relativeTo: Date()))"
        } else {
            return "Not synced yet"
        }
    }

    // MARK: - Selection Mode Methods

    private func enterSelectionMode() {
        isInSelectionMode = true
        selectedLists.removeAll()
    }

    private func exitSelectionMode() {
        isInSelectionMode = false
        selectedLists.removeAll()
    }

    private func toggleSelection(for listId: UUID) {
        if selectedLists.contains(listId) {
            selectedLists.remove(listId)
        } else {
            selectedLists.insert(listId)
        }
    }

    private func selectAllLists() {
        selectedLists = Set(displayedLists.map { $0.id })
    }

    private func deselectAllLists() {
        selectedLists.removeAll()
    }

    /// Archives selected lists (moves to archived, can be restored)
    private func archiveSelectedLists() {
        // Store selected IDs before modifying
        let listsToArchive = selectedLists

        for listId in listsToArchive {
            // deleteList actually archives (sets isArchived = true)
            dataManager.deleteList(withId: listId)
        }
        dataManager.loadData()

        // Clear detail selection if archived list was selected
        if let currentSelection = selectedList, listsToArchive.contains(currentSelection.id) {
            selectedList = nil
        }

        selectedLists.removeAll()
        isInSelectionMode = false
    }

    /// Permanently deletes selected lists (irreversible, for archived lists view)
    private func permanentlyDeleteSelectedLists() {
        // Store selected IDs before modifying
        let listsToDelete = selectedLists

        for listId in listsToDelete {
            dataManager.permanentlyDeleteList(withId: listId)
        }
        dataManager.loadData()

        // Clear detail selection if deleted list was selected
        if let currentSelection = selectedList, listsToDelete.contains(currentSelection.id) {
            selectedList = nil
        }

        selectedLists.removeAll()
        isInSelectionMode = false
    }

    // MARK: - Bulk Action Button (extracted for type-checker performance)

    /// Builds the appropriate bulk action button based on current view
    @ViewBuilder
    private var bulkActionButton: some View {
        if showingArchivedLists {
            // Archived lists view: permanent deletion
            Button(role: .destructive, action: { showingPermanentDeleteConfirmation = true }) {
                Label("Delete Permanently", systemImage: "trash")
            }
            .disabled(selectedLists.isEmpty)
        } else {
            // Active lists view: archive (recoverable)
            Button(role: .destructive, action: { showingArchiveConfirmation = true }) {
                Label("Archive Lists", systemImage: "archivebox")
            }
            .disabled(selectedLists.isEmpty)
        }
    }

    // MARK: - List Row Content (extracted for type-checker performance)

    /// Helper to format item count display
    private func itemCountText(for list: List) -> String {
        let activeCount = list.items.filter { !$0.isCrossedOut }.count
        let totalCount = list.items.count
        if activeCount < totalCount {
            return "\(activeCount) (\(totalCount))"
        } else {
            return "\(totalCount)"
        }
    }

    /// Builds a list row for selection mode
    @ViewBuilder
    private func selectionModeRow(for list: List) -> some View {
        Button(action: { toggleSelection(for: list.id) }) {
            HStack(spacing: 8) {
                Image(systemName: selectedLists.contains(list.id) ? "checkmark.circle.fill" : "circle")
                    .foregroundColor(selectedLists.contains(list.id) ? .blue : .gray)
                    .font(.title3)
                Text(list.name)
                    .foregroundColor(.primary)
                Spacer()
                Text(itemCountText(for: list))
                    .foregroundColor(.secondary)
                    .font(.caption)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        // CRITICAL: Use .activate interactions to allow sidebar drag-drop to work.
        // Default .focusable() on macOS Sonoma+ captures mouse clicks.
        .focusable(interactions: .activate)
        .focused($focusedListID, equals: list.id)
        .accessibilityIdentifier("SidebarListCell_\(list.name)")
        .accessibilityLabel("\(list.name)")
        .accessibilityValue(selectedLists.contains(list.id) ? "selected" : "not selected")
        .accessibilityHint("Double-tap to toggle selection")
    }

    /// Builds a list row for normal navigation mode
    @ViewBuilder
    private func normalModeRow(for list: List) -> some View {
        NavigationLink(value: list) {
            HStack {
                Text(list.name)
                Spacer()
                Text(itemCountText(for: list))
                    .foregroundColor(.secondary)
                    .font(.caption)
            }
        }
        // CRITICAL: Use .activate interactions to allow list drag-drop to work.
        // Default .focusable() on macOS Sonoma+ captures mouse clicks, blocking drag.
        .focusable(interactions: .activate)
        .focused($focusedListID, equals: list.id)
        .accessibilityIdentifier("SidebarListCell_\(list.name)")
        .accessibilityLabel("\(list.name)")
        .accessibilityValue("\(list.items.filter { !$0.isCrossedOut }.count) active, \(list.items.count) total items")
        .accessibilityHint("Double-tap to view list items")
        .draggable(list)
        .dropDestination(for: ItemTransferData.self) { droppedItems, _ in
            handleItemDrop(droppedItems, to: list)
        }
        .contextMenu {
            Button("Share...") {
                shareListFromSidebar(list)
            }
            Divider()
            Button("Delete") {
                onDeleteList(list)
            }
        }
    }

    var body: some View {
        SwiftUI.List(selection: isInSelectionMode ? .constant(nil) : $selectedList) {
            Section {
                ForEach(displayedLists) { list in
                    if isInSelectionMode {
                        selectionModeRow(for: list)
                    } else {
                        normalModeRow(for: list)
                    }
                }
                .onMove(perform: isInSelectionMode ? nil : moveList) // Disable reorder during selection mode
            } header: {
                HStack {
                    Text(showingArchivedLists ? "Archived Lists" : "Lists")
                    Spacer()
                    if !isInSelectionMode {
                        Button(action: {
                            showingArchivedLists.toggle()
                        }) {
                            Image(systemName: showingArchivedLists ? "tray.full" : "archivebox")
                                .font(.caption)
                        }
                        .buttonStyle(.plain)
                        .help(showingArchivedLists ? "Show Active Lists" : "Show Archived Lists")
                        .accessibilityLabel(showingArchivedLists ? "Hide archived lists" : "Show archived lists")
                        .accessibilityIdentifier("ArchivedListsButton")
                    }
                }
            } footer: {
                // Show last sync time in sidebar footer
                HStack {
                    Image(systemName: "icloud")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    Text(lastSyncDisplayText)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                .padding(.top, 8)
                .accessibilityLabel("Sync status: \(lastSyncDisplayText)")
            }
        }
        .listStyle(.sidebar)
        .accessibilityIdentifier("ListsSidebar")
        // MARK: - Keyboard Navigation Handlers (Task 11.1)
        .onKeyPress(.return) {
            // Enter key selects the focused list (only in normal mode)
            guard !isInSelectionMode else { return .ignored }
            if let focusedID = focusedListID,
               let list = displayedLists.first(where: { $0.id == focusedID }) {
                selectedList = list
                return .handled
            }
            return .ignored
        }
        .onKeyPress(.space) {
            // In selection mode, space toggles selection
            if isInSelectionMode {
                if let focusedID = focusedListID {
                    toggleSelection(for: focusedID)
                    return .handled
                }
                return .ignored
            }
            // In normal mode, space selects the focused list (macOS convention)
            if let focusedID = focusedListID,
               let list = displayedLists.first(where: { $0.id == focusedID }) {
                selectedList = list
                return .handled
            }
            return .ignored
        }
        .onKeyPress(.delete) {
            // In selection mode, archive or permanently delete selected lists
            if isInSelectionMode && !selectedLists.isEmpty {
                if showingArchivedLists {
                    // Viewing archived lists: permanently delete
                    showingPermanentDeleteConfirmation = true
                } else {
                    // Viewing active lists: archive (recoverable)
                    showingArchiveConfirmation = true
                }
                return .handled
            }
            // In normal mode, delete focused list
            if let focusedID = focusedListID,
               let list = displayedLists.first(where: { $0.id == focusedID }) {
                onDeleteList(list)
                // Move focus to next list or nil
                moveFocusAfterDeletion(deletedId: focusedID)
                return .handled
            }
            return .ignored
        }
        .onKeyPress(.escape) {
            // Escape exits selection mode
            if isInSelectionMode {
                exitSelectionMode()
                return .handled
            }
            return .ignored
        }
        // Cmd+A to select all in selection mode
        .onKeyPress(characters: CharacterSet(charactersIn: "a")) { keyPress in
            guard keyPress.modifiers.contains(.command), isInSelectionMode else {
                return .ignored
            }
            selectAllLists()
            return .handled
        }
        // Sync focus with selection (bidirectional - Issue #2 fix from Critical Review)
        .onChange(of: selectedList) { _, newList in
            if let newList = newList {
                focusedListID = newList.id
            }
        }
        .onChange(of: focusedListID) { _, newFocusedID in
            // When arrow keys change focus, update selection (macOS convention) - only in normal mode
            guard !isInSelectionMode else { return }
            if let newFocusedID = newFocusedID,
               let list = displayedLists.first(where: { $0.id == newFocusedID }) {
                selectedList = list
            }
        }
        .toolbar {
            // Selection mode toolbar items
            if isInSelectionMode {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        exitSelectionMode()
                    }
                    .accessibilityIdentifier("CancelSelectionButton")
                    .accessibilityHint("Exits selection mode")
                }

                ToolbarItem(placement: .primaryAction) {
                    Menu {
                        Button(action: selectAllLists) {
                            Label("Select All", systemImage: "checkmark.circle")
                        }
                        .disabled(displayedLists.isEmpty)

                        Button(action: deselectAllLists) {
                            Label("Deselect All", systemImage: "circle")
                        }
                        .disabled(selectedLists.isEmpty)

                        Divider()

                        // Use extracted @ViewBuilder for type-checker performance
                        bulkActionButton
                    } label: {
                        Label("Actions", systemImage: "ellipsis.circle")
                    }
                    .accessibilityIdentifier("SelectionActionsMenu")
                    .accessibilityLabel("Selection actions")
                    .accessibilityHint("Shows selection actions menu")
                }
            } else {
                // Normal mode toolbar items
                ToolbarItem(placement: .primaryAction) {
                    HStack(spacing: 4) {
                        // Refresh button with last sync time tooltip
                        Button(action: {
                            coreDataManager.forceRefresh()
                            dataManager.loadData()
                        }) {
                            Label("Refresh", systemImage: "arrow.clockwise")
                        }
                        .accessibilityIdentifier("RefreshButton")
                        .accessibilityLabel("Refresh data from iCloud")
                        .accessibilityHint("Manually syncs data from CloudKit")
                        .help(lastSyncTooltip)

                        Button(action: enterSelectionMode) {
                            Label("Select", systemImage: "checklist")
                        }
                        .help("Select Multiple Lists")
                        .accessibilityIdentifier("SelectListsButton")
                        .accessibilityHint("Enter selection mode to select multiple lists")

                        Button(action: onCreateList) {
                            Label("Add List", systemImage: "plus")
                        }
                        .accessibilityIdentifier("AddListButton")
                        .accessibilityHint("Opens sheet to create new list")
                    }
                }
            }
        }
        .sheet(isPresented: $showingSharePopover) {
            if let list = listToShare {
                MacShareFormatPickerView(
                    list: list,
                    onDismiss: {
                        showingSharePopover = false
                        listToShare = nil
                    }
                )
            }
        }
        // Archive confirmation alert (for active lists)
        .alert("Archive Lists", isPresented: $showingArchiveConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Archive", role: .destructive) {
                archiveSelectedLists()
            }
        } message: {
            Text("Archive \(selectedLists.count) \(selectedLists.count == 1 ? "list" : "lists")? You can restore them later from archived lists.")
        }
        // Permanent delete confirmation alert (for archived lists)
        .alert("Delete Permanently", isPresented: $showingPermanentDeleteConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Delete Permanently", role: .destructive) {
                permanentlyDeleteSelectedLists()
            }
        } message: {
            Text("Permanently delete \(selectedLists.count) \(selectedLists.count == 1 ? "list" : "lists")? This action cannot be undone. All items and images will be permanently deleted.")
        }
    }

    // MARK: - Drag-and-Drop Handlers

    /// Handle item drop on a list in the sidebar (moves item to that list)
    private func handleItemDrop(_ droppedItems: [ItemTransferData], to targetList: List) -> Bool {
        print("📦 Sidebar handleItemDrop called with \(droppedItems.count) items to list '\(targetList.name)'")
        var didMoveAny = false

        for itemData in droppedItems {
            print("📦 Processing dropped item: \(itemData.itemId), sourceListId: \(String(describing: itemData.sourceListId))")

            // Skip if item is already in the target list
            guard itemData.sourceListId != targetList.id else {
                print("📦 Drop skipped: item already in target list")
                continue
            }

            // Validate sourceListId exists
            guard let sourceListId = itemData.sourceListId else {
                print("❌ Sidebar drop failed: sourceListId is nil for item \(itemData.itemId)")
                continue
            }

            // Find the item in DataManager
            let items = dataManager.getItems(forListId: sourceListId)
            guard let item = items.first(where: { $0.id == itemData.itemId }) else {
                print("❌ Sidebar drop failed: could not find item \(itemData.itemId) in source list \(sourceListId)")
                continue
            }

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

    /// Shows share popover for a list from sidebar context menu
    private func shareListFromSidebar(_ list: List) {
        listToShare = list
        showingSharePopover = true
    }

    // MARK: - Keyboard Navigation Helpers (Task 11.1)

    /// Moves focus to the next or previous list after deletion
    private func moveFocusAfterDeletion(deletedId: UUID) {
        let lists = displayedLists
        guard let currentIndex = lists.firstIndex(where: { $0.id == deletedId }) else {
            focusedListID = nil
            return
        }

        // Try next list first, then previous
        if currentIndex < lists.count - 1 {
            focusedListID = lists[currentIndex + 1].id
        } else if currentIndex > 0 {
            focusedListID = lists[currentIndex - 1].id
        } else {
            focusedListID = nil
        }
    }
}

// MARK: - List Detail View

private struct MacListDetailView: View {
    let list: List  // Original list from selection (may become stale)
    let onEditItem: (Item) -> Void  // Callback to parent for edit sheet (prevents state loss)
    @EnvironmentObject var dataManager: DataManager

    // MARK: - Proactive Feature Tips (Task 12.5)
    @ObservedObject private var tooltipManager = MacTooltipManager.shared

    // ViewModel for filtering, sorting, and item management
    @StateObject private var viewModel: ListViewModel

    // State for item management (NOTE: edit sheet state moved to MacMainView)
    @State private var showingAddItemSheet = false
    @State private var showingEditListSheet = false

    // State for filter/sort popover
    @State private var showingOrganizationPopover = false

    // State for share popover
    @State private var showingSharePopover = false

    // State for multi-select mode
    @State private var showingMoveItemsPicker = false
    @State private var showingCopyItemsPicker = false
    // showingDeleteConfirmation removed (Task 12.8) - now uses undo banner instead
    @State private var selectedDestinationList: List?
    @State private var showingMoveConfirmation = false
    @State private var showingCopyConfirmation = false

    // State for Quick Look
    @State private var quickLookItem: Item?

    // DataRepository for drag-and-drop operations
    private let dataRepository = DataRepository()

    // MARK: - Keyboard Navigation (Task 11.1)
    /// Focus state for individual item rows - enables arrow key navigation
    @FocusState private var focusedItemID: UUID?
    /// Focus state for search field
    @FocusState private var isSearchFieldFocused: Bool

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

    /// Count of active filters (for showing "Clear All" button when multiple active)
    private var activeFilterCount: Int {
        var count = 0
        if !viewModel.searchText.isEmpty { count += 1 }
        if viewModel.currentFilterOption != .all { count += 1 }
        if viewModel.currentSortOption != .orderNumber { count += 1 }
        return count
    }

    // MARK: - Header View

    @ViewBuilder
    private var headerView: some View {
        HStack {
            Spacer()

            if viewModel.isInSelectionMode {
                // Selection mode header controls
                selectionModeControls
            } else {
                // Normal mode header controls
                searchFieldView
                filterSortControls
                shareButton
                selectionModeButton
                editListButton
            }
        }
        .padding()
    }

    // MARK: - Selection Mode Button

    @ViewBuilder
    private var selectionModeButton: some View {
        Button(action: { viewModel.enterSelectionMode() }) {
            Image(systemName: "checklist")
        }
        .buttonStyle(.plain)
        .help("Select Multiple Items")
        .accessibilityIdentifier("SelectItemsButton")
        .accessibilityLabel("Enter selection mode")
        .accessibilityHint("Enables multi-item selection for bulk operations")
    }

    // MARK: - Selection Mode Controls

    @ViewBuilder
    private var selectionModeControls: some View {
        HStack(spacing: 12) {
            // Selection count
            Text("\(viewModel.selectedItems.count) selected")
                .foregroundColor(.secondary)
                .font(.subheadline)

            // Ellipsis menu for bulk actions
            Menu {
                Section {
                    Button("Select All") {
                        viewModel.selectAll()
                    }
                    .keyboardShortcut("a", modifiers: .command)

                    Button("Deselect All") {
                        viewModel.deselectAll()
                    }
                }

                Divider()

                Section {
                    Button("Move Items...") {
                        showingMoveItemsPicker = true
                    }
                    .disabled(viewModel.selectedItems.isEmpty)

                    Button("Copy Items...") {
                        showingCopyItemsPicker = true
                    }
                    .disabled(viewModel.selectedItems.isEmpty)
                }

                Divider()

                Section {
                    Button("Delete Items", role: .destructive) {
                        // Task 12.8: Use undo banner instead of confirmation dialog
                        viewModel.deleteSelectedItemsWithUndo()
                        dataManager.loadData()
                    }
                    .disabled(viewModel.selectedItems.isEmpty)
                }
            } label: {
                Image(systemName: "ellipsis.circle")
                    .font(.title3)
            }
            .menuStyle(.borderlessButton)
            .fixedSize()
            .help("Bulk Actions")
            .accessibilityIdentifier("SelectionActionsMenu")
            .accessibilityLabel("Selection actions menu")

            // Cancel button
            Button("Cancel") {
                viewModel.exitSelectionMode()
            }
            .keyboardShortcut(.escape)
            .accessibilityIdentifier("CancelSelectionButton")
            .accessibilityLabel("Exit selection mode")
        }
    }

    @ViewBuilder
    private var shareButton: some View {
        Button(action: { showingSharePopover.toggle() }) {
            Image(systemName: "square.and.arrow.up")
        }
        .buttonStyle(.plain)
        .help("Share List (⇧⌘S)")
        .accessibilityIdentifier("ShareListButton")
        .accessibilityLabel("Share list")
        .popover(isPresented: $showingSharePopover) {
            MacShareFormatPickerView(
                list: currentList ?? list,
                onDismiss: { showingSharePopover = false }
            )
        }
    }

    @ViewBuilder
    private var searchFieldView: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.secondary)
                .accessibilityHidden(true)
            TextField(String(localized: "Search items") + "...", text: $viewModel.searchText)
                .textFieldStyle(.plain)
                .frame(width: 150)
                .focused($isSearchFieldFocused)
                .accessibilityIdentifier("ListSearchField")
                .accessibilityLabel("Search items")
                .onExitCommand {
                    // Enhanced Escape behavior (Task 12.12):
                    // 1. First press: clears search text (if not empty)
                    // 2. Second press: clears all filters (if search was empty but filters active)
                    if !viewModel.searchText.isEmpty {
                        // First: clear search text
                        viewModel.searchText = ""
                        viewModel.items = items
                    } else if viewModel.hasActiveFilters {
                        // Second: clear all filters when search is already empty
                        viewModel.clearAllFilters()
                        viewModel.items = items
                    }
                    isSearchFieldFocused = false
                }
            if !viewModel.searchText.isEmpty {
                Button(action: {
                    viewModel.searchText = ""
                    viewModel.items = items
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Clear search")
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Color.secondary.opacity(0.1))
        .cornerRadius(6)
    }

    // MARK: - Filter & Sort Controls (Task 12.4)
    // Redesigned from iOS-style popover to native macOS pattern:
    // - Segmented control for filters (always visible, single click)
    // - Sort button with popover for less-frequent sort options

    @ViewBuilder
    private var filterSortControls: some View {
        HStack(spacing: 8) {
            // Filter segmented control - always visible, single click
            Picker("Filter", selection: $viewModel.currentFilterOption) {
                Text("All").tag(ItemFilterOption.all)
                Text("Active").tag(ItemFilterOption.active)
                Text("Done").tag(ItemFilterOption.completed)
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .frame(width: 180)
            .help("Filter items by status (Cmd+1/2/3)")
            .accessibilityIdentifier("FilterSegmentedControl")
            .onChange(of: viewModel.currentFilterOption) { _, newValue in
                // Sync showCrossedOutItems state when filter changes via Picker
                // This ensures "All" filter properly shows all items
                viewModel.updateFilterOption(newValue)
            }

            // Sort button - keeps popover for less-frequent sort options
            Button(action: { showingOrganizationPopover.toggle() }) {
                Image(systemName: "arrow.up.arrow.down")
            }
            .buttonStyle(.plain)
            .help("Sort Options")
            .accessibilityIdentifier("SortButton")
            .accessibilityLabel("Sort items")
            .accessibilityHint("Opens sort options")
            .popover(isPresented: $showingOrganizationPopover) {
                MacSortOnlyView(viewModel: viewModel)
            }
        }
    }

    @ViewBuilder
    private var editListButton: some View {
        Button(action: { showingEditListSheet = true }) {
            Image(systemName: "pencil")
        }
        .buttonStyle(.plain)
        .help("Edit List")
        .accessibilityIdentifier("EditListButton")
        .accessibilityLabel("Edit list name")
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

                // Clear All button (Task 12.12)
                // Shows when multiple filters are active or as a convenience
                if activeFilterCount > 1 {
                    Button(action: {
                        viewModel.clearAllFilters()
                        // CRITICAL: Refresh items from DataManager when clearing all filters
                        viewModel.items = items
                    }) {
                        Text("Clear All")
                            .font(.caption)
                    }
                    .buttonStyle(.plain)
                    .foregroundColor(.accentColor)
                    .help("Clear all filters (Cmd+Shift+Delete)")
                    .accessibilityIdentifier("ClearAllFiltersButton")
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

    // MARK: - Empty State Views (Task 12.7: Consistent Empty State Components)
    // Replaced inline emptyListView with comprehensive MacItemsEmptyStateView component
    // Added dedicated search empty state (MacSearchEmptyStateView) for search-specific messaging

    /// Empty state view for lists with no items
    /// Uses the comprehensive MacItemsEmptyStateView component for consistency
    @ViewBuilder
    private var emptyListView: some View {
        MacItemsEmptyStateView(
            hasItems: false,
            onAddItem: {
                showingAddItemSheet = true
            }
        )
        .accessibilityIdentifier("ItemsEmptyStateView")
    }

    /// Empty state view for search with no results
    /// Dedicated messaging for search context (Task 12.7)
    @ViewBuilder
    private var searchEmptyStateView: some View {
        MacSearchEmptyStateView(
            searchText: viewModel.searchText,
            onClear: {
                viewModel.searchText = ""
                // Refresh items after clearing search
                viewModel.items = items
            }
        )
    }

    /// Empty state view when filters return no matching items
    /// Used when items exist but filter/sort hides all of them
    @ViewBuilder
    private var noMatchingItemsView: some View {
        VStack(spacing: 16) {
            Image(systemName: "line.3.horizontal.decrease.circle")
                .font(.system(size: 48))
                .foregroundColor(.secondary)
                .accessibilityHidden(true)

            Text(String(localized: "No Matching Items"))
                .font(.title3)
                .foregroundColor(.secondary)
                .accessibilityAddTraits(.isHeader)

            Text(String(localized: "Try adjusting your filter settings"))
                .font(.caption)
                .foregroundColor(.secondary)

            Button(String(localized: "Clear Filters")) {
                viewModel.searchText = ""
                viewModel.updateFilterOption(.all)
                // CRITICAL: Refresh items from DataManager when clearing all filters
                viewModel.items = items
            }
            .buttonStyle(.borderedProminent)
            .accessibilityLabel("Clear filters")
            .accessibilityHint("Clears all active filters to show all items")
        }
        .accessibilityIdentifier("NoMatchingItemsView")
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
                    // MARK: Keyboard Navigation (Task 11.1)
                    // CRITICAL: Use .activate interactions to prevent focus from capturing
                    // mouse clicks that should initiate drag gestures. Without this,
                    // .focusable() on macOS Sonoma+ captures all click interactions,
                    // blocking drag-and-drop from starting.
                    .focusable(interactions: .activate)
                    .focused($focusedItemID, equals: item.id)
                    // MARK: Cmd+Click and Shift+Click Multi-Select (Task 12.1)
                    // Uses NSEvent monitoring to detect modifier keys without blocking drag-and-drop
                    .onModifierClick(
                        command: {
                            // Cmd+Click: Toggle selection of this item
                            viewModel.toggleSelection(for: item.id)
                        },
                        shift: {
                            // Shift+Click: Select range from anchor to this item
                            viewModel.selectRange(to: item.id)
                        }
                    )
                    .accessibilityIdentifier("ItemRow_\(item.title)")
            }
            .onMove(perform: handleMoveItem)
        }
        .listStyle(.inset)
        // MARK: - Drop Destination for Cross-List Item Moves
        // Enable dropping items from other lists onto this list
        // (Restored: this was accidentally removed, breaking item drag between lists)
        .dropDestination(for: ItemTransferData.self) { droppedItems, _ in
            handleItemDrop(droppedItems)
        }
        .accessibilityIdentifier("ItemsList")
        // MARK: - Keyboard Navigation Handlers (Task 11.1)
        .onKeyPress(.space) {
            // In selection mode, space toggles selection of focused item
            if viewModel.isInSelectionMode {
                guard let focusedID = focusedItemID else {
                    return .ignored
                }
                viewModel.toggleSelection(for: focusedID)
                return .handled
            }
            // Normal mode: Space toggles completion state of focused item
            guard let focusedID = focusedItemID,
                  let item = displayedItems.first(where: { $0.id == focusedID }) else {
                return .ignored
            }
            // Check if item has images - if so, show Quick Look instead
            if item.hasImages {
                showQuickLook(for: item)
            } else {
                toggleItem(item)
            }
            return .handled
        }
        .onKeyPress(.return) {
            // Enter opens edit sheet for focused item (not in selection mode)
            guard !viewModel.isInSelectionMode else {
                return .ignored
            }
            guard let focusedID = focusedItemID,
                  let item = displayedItems.first(where: { $0.id == focusedID }) else {
                return .ignored
            }
            onEditItem(item)
            return .handled
        }
        .onKeyPress(.delete) {
            // In selection mode, delete selected items with undo (Task 12.8)
            if viewModel.isInSelectionMode && !viewModel.selectedItems.isEmpty {
                viewModel.deleteSelectedItemsWithUndo()
                dataManager.loadData()
                return .handled
            }
            // Normal mode: Delete removes the focused item
            guard let focusedID = focusedItemID,
                  let item = displayedItems.first(where: { $0.id == focusedID }) else {
                return .ignored
            }
            deleteItem(item)
            moveFocusAfterItemDeletion(deletedId: focusedID)
            return .handled
        }
        .onKeyPress(.escape) {
            // Escape exits selection mode
            if viewModel.isInSelectionMode {
                viewModel.exitSelectionMode()
                return .handled
            }
            return .ignored
        }
        .onKeyPress(characters: CharacterSet(charactersIn: "a")) { keyPress in
            // Cmd+A selects all items in selection mode
            guard keyPress.modifiers.contains(.command) && viewModel.isInSelectionMode else {
                return .ignored
            }
            viewModel.selectAll()
            return .handled
        }
        .onKeyPress(characters: CharacterSet(charactersIn: "c")) { keyPress in
            // 'C' key toggles completion (alternative to Space for items with images)
            // Issue #9 fix: Ignore if modifier keys are pressed (don't capture Cmd+C)
            guard keyPress.modifiers.isEmpty else {
                return .ignored
            }
            guard let focusedID = focusedItemID,
                  let item = displayedItems.first(where: { $0.id == focusedID }) else {
                return .ignored
            }
            toggleItem(item)
            return .handled
        }
        // MARK: - Keyboard Reordering (Task 12.11)
        // Use onKeyPress with key set and check modifiers inside closure
        .onKeyPress(keys: [.upArrow]) { keyPress in
            // Cmd+Option+Up moves focused item up one position
            guard keyPress.modifiers.contains(.command),
                  keyPress.modifiers.contains(.option) else {
                return .ignored
            }
            guard viewModel.canReorderWithKeyboard else { return .ignored }
            guard let focusedID = focusedItemID else { return .ignored }
            viewModel.moveItemUp(focusedID)
            return .handled
        }
        .onKeyPress(keys: [.downArrow]) { keyPress in
            // Cmd+Option+Down moves focused item down one position
            guard keyPress.modifiers.contains(.command),
                  keyPress.modifiers.contains(.option) else {
                return .ignored
            }
            guard viewModel.canReorderWithKeyboard else { return .ignored }
            guard let focusedID = focusedItemID else { return .ignored }
            viewModel.moveItemDown(focusedID)
            return .handled
        }
        // MARK: - Clear All Filters Shortcut (Task 12.12)
        // Cmd+Shift+Backspace (delete) clears all active filters
        .onKeyPress(keys: [.delete]) { keyPress in
            guard keyPress.modifiers.contains(.command),
                  keyPress.modifiers.contains(.shift) else {
                return .ignored
            }
            viewModel.clearAllFilters()
            return .handled
        }
    }

    private func handleMoveItem(from source: IndexSet, to destination: Int) {
        guard canReorderItems else { return }
        viewModel.moveItems(from: source, to: destination)
    }

    @ViewBuilder
    private func makeItemRow(item: Item) -> some View {
        MacItemRowView(
            item: item,
            isInSelectionMode: viewModel.isInSelectionMode,
            isSelected: viewModel.selectedItems.contains(item.id),
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
            onQuickLook: { showQuickLook(for: item) },
            onToggleSelection: { viewModel.toggleSelection(for: item.id) }
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
        ZStack(alignment: .bottom) {
            // Main content
            VStack(spacing: 0) {
                headerView
                activeFiltersBar
                Divider()

                // MARK: - Empty State Logic (Task 12.7)
                // Three-way decision for empty states:
                // 1. No items in list at all -> MacItemsEmptyStateView (comprehensive)
                // 2. Search returned no results -> MacSearchEmptyStateView (search-specific)
                // 3. Filter removed all items -> noMatchingItemsView (filter-specific)
                if viewModel.filteredItems.isEmpty {
                    Group {
                        if items.isEmpty {
                            // No items in list at all - show comprehensive empty state
                            emptyListView
                        } else if !viewModel.searchText.isEmpty {
                            // Search returned no results - show search-specific empty state
                            searchEmptyStateView
                        } else {
                            // Filter removed all items - show filter-specific empty state
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

            // MARK: - Undo Banners Overlay
            // Undo Complete Banner - shows when item is marked as completed
            if viewModel.showUndoButton, let item = viewModel.recentlyCompletedItem {
                MacUndoBanner(
                    itemName: item.displayTitle,
                    onUndo: {
                        viewModel.undoComplete()
                    },
                    onDismiss: {
                        viewModel.hideUndoButton()
                    }
                )
                .frame(maxWidth: 400)
                .padding(.horizontal, 20)
                .padding(.bottom, 20)
                .transition(.move(edge: .bottom).combined(with: .opacity))
                .animation(.spring(response: 0.3, dampingFraction: 0.7), value: viewModel.showUndoButton)
                .accessibilityIdentifier("UndoCompleteBanner")
            }

            // Undo Delete Banner - shows when single item is deleted
            if viewModel.showDeleteUndoButton, let item = viewModel.recentlyDeletedItem {
                MacDeleteUndoBanner(
                    itemName: item.displayTitle,
                    onUndo: {
                        viewModel.undoDeleteItem()
                    },
                    onDismiss: {
                        viewModel.hideDeleteUndoButton()
                    }
                )
                .frame(maxWidth: 400)
                .padding(.horizontal, 20)
                .padding(.bottom, 20)
                .transition(.move(edge: .bottom).combined(with: .opacity))
                .animation(.spring(response: 0.3, dampingFraction: 0.7), value: viewModel.showDeleteUndoButton)
                .accessibilityIdentifier("UndoDeleteBanner")
            }

            // Bulk Delete Undo Banner - shows when multiple items are deleted (Task 12.8)
            if viewModel.showBulkDeleteUndoBanner {
                MacBulkDeleteUndoBanner(
                    itemCount: viewModel.deletedItemsCount,
                    onUndo: {
                        viewModel.undoBulkDelete()
                        dataManager.loadData()
                    },
                    onDismiss: {
                        viewModel.hideBulkDeleteUndoBanner()
                    }
                )
                .frame(maxWidth: 400)
                .padding(.horizontal, 20)
                .padding(.bottom, 20)
                .transition(.move(edge: .bottom).combined(with: .opacity))
                .animation(.spring(response: 0.3, dampingFraction: 0.7), value: viewModel.showBulkDeleteUndoBanner)
                .accessibilityIdentifier("BulkDeleteUndoBanner")
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .navigationTitle(displayName)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button(action: { showingAddItemSheet = true }) {
                    Label("Add Item", systemImage: "plus")
                }
                .accessibilityIdentifier("AddItemButton")
                .accessibilityHint("Opens sheet to add new item")
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
            // MARK: - Item-Related Proactive Tips (Task 12.5)
            triggerItemRelatedTips()
        }
        // Trigger tips when items change (e.g., user adds items)
        .onChange(of: items.count) { oldCount, newCount in
            if newCount > oldCount {
                triggerItemRelatedTips()
            }
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
        // MARK: - Move/Copy Item Sheets
        .sheet(isPresented: $showingMoveItemsPicker, onDismiss: {
            // When sheet is dismissed, show confirmation if a destination was selected
            if selectedDestinationList != nil {
                showingMoveConfirmation = true
            }
        }) {
            MacDestinationListPickerSheet(
                action: .move,
                itemCount: viewModel.selectedItems.count,
                currentListId: list.id,
                onSelect: { destinationList in
                    selectedDestinationList = destinationList
                    showingMoveItemsPicker = false
                },
                onCancel: {
                    selectedDestinationList = nil
                    showingMoveItemsPicker = false
                }
            )
        }
        .sheet(isPresented: $showingCopyItemsPicker, onDismiss: {
            // When sheet is dismissed, show confirmation if a destination was selected
            if selectedDestinationList != nil {
                showingCopyConfirmation = true
            }
        }) {
            MacDestinationListPickerSheet(
                action: .copy,
                itemCount: viewModel.selectedItems.count,
                currentListId: list.id,
                onSelect: { destinationList in
                    selectedDestinationList = destinationList
                    showingCopyItemsPicker = false
                },
                onCancel: {
                    selectedDestinationList = nil
                    showingCopyItemsPicker = false
                }
            )
        }
        // MARK: - Move/Copy Confirmation Alerts
        .alert("Move Items", isPresented: $showingMoveConfirmation) {
            Button("Cancel", role: .cancel) {
                selectedDestinationList = nil
            }
            Button("Move", role: .destructive) {
                if let destination = selectedDestinationList {
                    viewModel.moveSelectedItems(to: destination)
                    viewModel.exitSelectionMode()
                    dataManager.loadData()
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
                    viewModel.copySelectedItems(to: destination)
                    viewModel.exitSelectionMode()
                    dataManager.loadData()
                }
                selectedDestinationList = nil
            }
        } message: {
            if let destination = selectedDestinationList {
                Text("Copy \(viewModel.selectedItems.count) item(s) to \"\(destination.name)\"? Items will remain in this list.")
            }
        }
        // MARK: - Delete Confirmation Alert removed (Task 12.8)
        // Bulk delete now uses undo banner instead of confirmation dialog
        // for consistency with individual delete operations
        // MARK: - Keyboard Shortcuts (Task 11.1)
        .onKeyPress(characters: CharacterSet(charactersIn: "f")) { keyPress in
            // Cmd+F focuses the search field
            guard keyPress.modifiers.contains(.command) else {
                return .ignored
            }
            isSearchFieldFocused = true
            return .handled
        }
        .onAppear {
            // Advertise Handoff activity for viewing this specific list
            HandoffService.shared.startViewingListActivity(list: list)
        }
        // MARK: - Global Cmd+F Notification Receiver (Task 12.2)
        // Receives notification from MacMainView's global Cmd+F handler
        // Focuses the search field regardless of where focus was before
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("FocusSearchField"))) { _ in
            isSearchFieldFocused = true
        }
        // MARK: - View Menu Filter Shortcuts (Task 12.4)
        // Receives notifications from View menu filter commands (Cmd+1/2/3)
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("SetFilterAll"))) { _ in
            viewModel.updateFilterOption(.all)
            // Refresh items from DataManager when changing filter
            viewModel.items = items
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("SetFilterActive"))) { _ in
            viewModel.updateFilterOption(.active)
            viewModel.items = items
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("SetFilterCompleted"))) { _ in
            viewModel.updateFilterOption(.completed)
            viewModel.items = items
        }
    }

    // MARK: - Item Actions

    /// Toggles item completion state using ViewModel to enable undo functionality.
    /// When completing an item, a 5-second undo banner appears at the bottom.
    private func toggleItem(_ item: Item) {
        // Use ViewModel's toggleItemCrossedOut to enable undo banner
        // This triggers showUndoForCompletedItem when marking as complete
        viewModel.toggleItemCrossedOut(item)
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

    /// Deletes item using ViewModel to enable undo functionality.
    /// A 5-second undo banner appears at the bottom allowing restoration.
    private func deleteItem(_ item: Item) {
        // Use ViewModel's deleteItem to enable undo banner
        // This stores the item for potential restoration and shows the delete undo banner
        viewModel.deleteItem(item)
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

    // MARK: - Keyboard Navigation Helpers (Task 11.1)

    /// Moves focus to the next or previous item after deletion
    private func moveFocusAfterItemDeletion(deletedId: UUID) {
        let items = displayedItems
        guard let currentIndex = items.firstIndex(where: { $0.id == deletedId }) else {
            focusedItemID = nil
            return
        }

        // Try next item first, then previous
        if currentIndex < items.count - 1 {
            focusedItemID = items[currentIndex + 1].id
        } else if currentIndex > 0 {
            focusedItemID = items[currentIndex - 1].id
        } else {
            focusedItemID = nil
        }
    }

    // MARK: - Drag-and-Drop Handlers

    /// Handle item drop on this list's detail view (moves item from another list)
    private func handleItemDrop(_ droppedItems: [ItemTransferData]) -> Bool {
        print("📦 handleItemDrop called with \(droppedItems.count) items")
        var didMoveAny = false

        for itemData in droppedItems {
            print("📦 Processing dropped item: \(itemData.itemId), sourceListId: \(String(describing: itemData.sourceListId))")

            // Skip if item is already in this list
            guard itemData.sourceListId != list.id else {
                print("📦 Drop skipped: item already in this list")
                continue
            }

            // Validate sourceListId exists
            guard let sourceListId = itemData.sourceListId else {
                print("❌ Drop failed: sourceListId is nil for item \(itemData.itemId)")
                continue
            }

            // Find the item in DataManager
            let sourceItems = dataManager.getItems(forListId: sourceListId)
            guard let item = sourceItems.first(where: { $0.id == itemData.itemId }) else {
                print("❌ Drop failed: could not find item \(itemData.itemId) in source list \(sourceListId)")
                continue
            }
            guard let targetList = currentList else {
                print("❌ Drop failed: currentList is nil")
                continue
            }

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

    // MARK: - Proactive Feature Tips for Items (Task 12.5)

    /// Triggers item-related feature tips based on item count
    /// Tips help users discover features as they add more items
    private func triggerItemRelatedTips() {
        let itemCount = items.count

        // 5+ items: Show search tip
        if itemCount >= 5 {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                withAnimation(.easeIn(duration: 0.3)) {
                    _ = tooltipManager.showIfNeeded(.searchFunctionality)
                }
            }
        }

        // 7+ items: Show sort/filter tip
        if itemCount >= 7 {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.7) {
                withAnimation(.easeIn(duration: 0.3)) {
                    _ = tooltipManager.showIfNeeded(.sortFilterOptions)
                }
            }
        }

        // 2+ items: Show context menu tip
        if itemCount >= 2 {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                withAnimation(.easeIn(duration: 0.3)) {
                    _ = tooltipManager.showIfNeeded(.contextMenuActions)
                }
            }
        }
    }
}

// MARK: - Item Row View

private struct MacItemRowView: View {
    let item: Item
    let isInSelectionMode: Bool
    let isSelected: Bool
    let onToggle: () -> Void
    let onEdit: () -> Void
    let onDelete: () -> Void
    let onQuickLook: () -> Void
    let onToggleSelection: () -> Void

    @State private var isHovering = false

    /// Combined accessibility label for VoiceOver
    private var itemAccessibilityLabel: String {
        var label = item.title
        if isInSelectionMode {
            label = (isSelected ? "Selected, " : "Unselected, ") + label
        }
        label += ", \(item.isCrossedOut ? "completed" : "active")"
        if item.quantity > 1 {
            label += ", quantity \(item.quantity)"
        }
        if item.hasImages {
            label += ", \(item.imageCount) \(item.imageCount == 1 ? "image" : "images")"
        }
        if let description = item.itemDescription, !description.isEmpty {
            label += ", \(description)"
        }
        return label
    }

    var body: some View {
        HStack(spacing: 12) {
            // Selection checkbox (shown in selection mode)
            if isInSelectionMode {
                Button(action: onToggleSelection) {
                    Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                        .font(.title2)
                        .foregroundColor(isSelected ? .accentColor : .secondary)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(isSelected ? "Selected" : "Not selected")
                .accessibilityHint("Double-tap to toggle selection")
            }

            // Completion checkbox button (hidden in selection mode)
            if !isInSelectionMode {
                Button(action: onToggle) {
                    Image(systemName: item.isCrossedOut ? "checkmark.circle.fill" : "circle")
                        .font(.title2)
                        .foregroundColor(item.isCrossedOut ? .green : .secondary)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("\(item.title), \(item.isCrossedOut ? "completed" : "active")")
                .accessibilityHint("Double-tap to toggle completion status")
            }

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

                        // Badge for multiple images (dark mode compatible)
                        if item.imageCount > 1 {
                            Text("\(item.imageCount)")
                                .font(.system(size: 8, weight: .bold))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 3)
                                .padding(.vertical, 1)
                                .background(.ultraThinMaterial.opacity(0.9))
                                .background(Color(nsColor: .darkGray))
                                .clipShape(Capsule())
                                .offset(x: 2, y: 2)
                                .accessibilityHidden(true)
                        }
                    }
                }
                .buttonStyle(.plain)
                .help("Quick Look (Space)")
                .accessibilityLabel("View \(item.imageCount) images")
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
                            .accessibilityHidden(true)
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

            // Hover actions (hidden in selection mode)
            if isHovering && !isInSelectionMode {
                HStack(spacing: 8) {
                    // Quick Look button (only if item has images)
                    if item.hasImages {
                        Button(action: onQuickLook) {
                            Image(systemName: "eye")
                        }
                        .buttonStyle(.plain)
                        .help("Quick Look (Space)")
                        .accessibilityLabel("Quick Look")
                        .accessibilityHint("Opens image preview")
                    }

                    Button(action: onEdit) {
                        Image(systemName: "pencil")
                    }
                    .buttonStyle(.plain)
                    .help("Edit Item")
                    .accessibilityLabel("Edit item")
                    .accessibilityHint("Opens edit sheet")

                    Button(action: onDelete) {
                        Image(systemName: "trash")
                            .foregroundColor(.red)
                    }
                    .buttonStyle(.plain)
                    .help("Delete Item")
                    .accessibilityLabel("Delete item")
                    .accessibilityHint("Permanently removes this item")
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
        // In selection mode, double-click toggles selection instead of editing
        .onDoubleClick {
            if isInSelectionMode {
                onToggleSelection()
            } else {
                onEdit()
            }
        }
        // NOTE: Do NOT add .onTapGesture or .simultaneousGesture(TapGesture()) here!
        // Any tap gesture handler captures mouse-down events and blocks drag initiation.
        // Selection mode uses the checkbox button, double-click, or context menu instead.
        .contentShape(Rectangle())  // Required for hit testing on entire row area
        .listRowBackground(isInSelectionMode && isSelected ? Color.accentColor.opacity(0.1) : Color.clear)
        // MARK: - Accessibility (Task 11.2)
        // Combine child elements into a single accessible element for cleaner VoiceOver navigation
        .accessibilityElement(children: .combine)
        .accessibilityLabel(itemAccessibilityLabel)
        .accessibilityHint(isInSelectionMode ? "Tap to toggle selection" : "Double-tap to edit. Use actions menu for more options.")
        .contextMenu {
            if isInSelectionMode {
                Button(isSelected ? "Deselect" : "Select") { onToggleSelection() }
            } else {
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
}

// MARK: - Add Item Sheet

private struct MacAddItemSheet: View {
    let listId: UUID
    let onSave: (String, Int, String?) -> Void
    let onCancel: () -> Void

    @EnvironmentObject var dataManager: DataManager

    @State private var title = ""
    @State private var quantity = 1
    @State private var description = ""

    // Suggestion state
    @StateObject private var suggestionService = SuggestionService()
    @State private var showingSuggestions = false
    @State private var showAllSuggestions = false

    /// Get the current list from DataManager for suggestions context
    private var currentList: List? {
        dataManager.lists.first(where: { $0.id == listId })
    }

    var body: some View {
        VStack(spacing: 20) {
            Text("Add Item")
                .font(.title2)
                .fontWeight(.semibold)
                .accessibilityAddTraits(.isHeader)

            VStack(alignment: .leading, spacing: 12) {
                // Title field with suggestions
                VStack(alignment: .leading, spacing: 4) {
                    TextField("Item Name", text: $title)
                        .textFieldStyle(.roundedBorder)
                        .accessibilityLabel("Item name")
                        .onChange(of: title) { _, newValue in
                            handleTitleChange(newValue)
                        }

                    // Suggestions
                    if showingSuggestions && !suggestionService.suggestions.isEmpty {
                        MacSuggestionListView(
                            suggestions: suggestionService.suggestions,
                            onSuggestionTapped: applySuggestion
                        )
                        .transition(.opacity.combined(with: .move(edge: .top)))
                    }
                }

                HStack {
                    Text("\(String(localized: "Quantity")):")
                    Stepper(value: $quantity, in: 1...999) {
                        Text("\(quantity)")
                            .frame(width: 40)
                    }
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text("\(String(localized: "Notes")) (\(String(localized: "optional"))):")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    TextEditor(text: $description)
                        .frame(height: 60)
                        .border(Color.secondary.opacity(0.3))
                }
            }
            .frame(width: 350)

            HStack(spacing: 16) {
                Button("Cancel") {
                    onCancel()
                }
                .keyboardShortcut(.escape)
                .accessibilityHint("Discards changes")

                Button("Add") {
                    onSave(title, quantity, description.isEmpty ? nil : description)
                }
                .keyboardShortcut(.return)
                .buttonStyle(.borderedProminent)
                .disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                .accessibilityHint("Saves new item")
            }
        }
        .padding(30)
        .frame(minWidth: 450)
        .animation(.easeInOut(duration: 0.2), value: showingSuggestions)
    }

    // MARK: - Suggestion Handling

    private func handleTitleChange(_ newValue: String) {
        let trimmedValue = newValue.trimmingCharacters(in: .whitespacesAndNewlines)

        if trimmedValue.count >= 2 {
            // Get suggestions from current list context
            suggestionService.getSuggestions(for: trimmedValue, in: currentList)
            withAnimation(.easeInOut(duration: 0.2)) {
                showingSuggestions = true
            }
        } else {
            withAnimation(.easeInOut(duration: 0.2)) {
                showingSuggestions = false
            }
            suggestionService.clearSuggestions()
        }
    }

    private func applySuggestion(_ suggestion: ItemSuggestion) {
        // Apply suggestion data
        title = suggestion.title
        quantity = suggestion.quantity
        if let desc = suggestion.description {
            description = desc
        }

        // Hide suggestions
        withAnimation(.easeInOut(duration: 0.2)) {
            showingSuggestions = false
            showAllSuggestions = false
        }
        suggestionService.clearSuggestions()
    }
}

// MARK: - Edit Item Sheet

private struct MacEditItemSheet: View {
    let item: Item
    let onSave: (String, Int, String?, [ItemImage]) -> Void
    let onCancel: () -> Void

    @EnvironmentObject var dataManager: DataManager

    @State private var title: String
    @State private var quantity: Int
    @State private var description: String
    @State private var images: [ItemImage]

    // Defer gallery loading to allow sheet to appear faster
    // The gallery is the heaviest component - loading it after initial layout
    // significantly reduces perceived delay when opening the edit sheet
    @State private var isGalleryReady = false

    // Suggestion state
    @StateObject private var suggestionService = SuggestionService()
    @State private var showingSuggestions = false

    /// Get the current list from DataManager for suggestions context
    private var currentList: List? {
        dataManager.lists.first(where: { $0.id == item.listId })
    }

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
                .accessibilityAddTraits(.isHeader)

            VStack(alignment: .leading, spacing: 12) {
                // Title field with suggestions
                VStack(alignment: .leading, spacing: 4) {
                    TextField("Item Name", text: $title)
                        .textFieldStyle(.roundedBorder)
                        .accessibilityLabel("Item name")
                        .onChange(of: title) { _, newValue in
                            handleTitleChange(newValue)
                        }

                    // Suggestions
                    if showingSuggestions && !suggestionService.suggestions.isEmpty {
                        MacSuggestionListView(
                            suggestions: suggestionService.suggestions,
                            onSuggestionTapped: applySuggestion
                        )
                        .transition(.opacity.combined(with: .move(edge: .top)))
                    }
                }

                HStack {
                    Text("\(String(localized: "Quantity")):")
                    Stepper(value: $quantity, in: 1...999) {
                        Text("\(quantity)")
                            .frame(width: 40)
                    }
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text("\(String(localized: "Notes")) (\(String(localized: "optional"))):")
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
                .accessibilityHint("Discards changes")

                Button("Save") {
                    onSave(title, quantity, description.isEmpty ? nil : description, images)
                }
                .keyboardShortcut(.return)
                .buttonStyle(.borderedProminent)
                .disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                .accessibilityHint("Saves changes")
            }
        }
        .padding(30)
        .frame(minWidth: 500)
        .animation(.easeInOut(duration: 0.2), value: showingSuggestions)
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

    // MARK: - Suggestion Handling

    private func handleTitleChange(_ newValue: String) {
        let trimmedValue = newValue.trimmingCharacters(in: .whitespacesAndNewlines)

        if trimmedValue.count >= 2 {
            // Get suggestions, excluding the current item being edited
            suggestionService.getSuggestions(for: trimmedValue, in: currentList, excludeItemId: item.id)
            withAnimation(.easeInOut(duration: 0.2)) {
                showingSuggestions = true
            }
        } else {
            withAnimation(.easeInOut(duration: 0.2)) {
                showingSuggestions = false
            }
            suggestionService.clearSuggestions()
        }
    }

    private func applySuggestion(_ suggestion: ItemSuggestion) {
        // Apply suggestion data
        title = suggestion.title
        quantity = suggestion.quantity
        if let desc = suggestion.description {
            description = desc
        }
        // Note: Images are NOT copied from suggestions in edit mode
        // to preserve the current item's images

        // Hide suggestions
        withAnimation(.easeInOut(duration: 0.2)) {
            showingSuggestions = false
        }
        suggestionService.clearSuggestions()
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
                .accessibilityAddTraits(.isHeader)

            TextField("List Name", text: $name)
                .textFieldStyle(.roundedBorder)
                .frame(width: 300)
                .accessibilityLabel("List name")
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
                .accessibilityHint("Discards changes")

                Button("Save") {
                    onSave(name)
                }
                .keyboardShortcut(.return)
                .buttonStyle(.borderedProminent)
                .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                .accessibilityHint("Saves changes")
            }
        }
        .padding(30)
        .frame(minWidth: 350)
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

// MARK: - Undo Complete Banner (macOS)

/// macOS-styled undo banner for completed items.
/// Shows a green checkmark, item name, and undo/dismiss buttons.
/// Uses material background for modern macOS appearance.
private struct MacUndoBanner: View {
    let itemName: String
    let onUndo: () -> Void
    let onDismiss: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            // Green checkmark icon
            Image(systemName: "checkmark.circle.fill")
                .foregroundColor(.green)
                .font(.title2)
                .accessibilityHidden(true)

            // Status text and item name
            VStack(alignment: .leading, spacing: 2) {
                Text("Completed")
                    .font(.caption)
                    .foregroundColor(.secondary)

                Text(itemName)
                    .font(.body)
                    .fontWeight(.medium)
                    .lineLimit(1)
            }

            Spacer()

            // Undo button (blue)
            Button(action: onUndo) {
                Text("Undo")
                    .font(.headline)
                    .foregroundColor(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 6)
                    .background(Color.accentColor)
                    .cornerRadius(6)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Undo completion")
            .accessibilityHint("Marks item as active again")

            // Dismiss button
            Button(action: onDismiss) {
                Image(systemName: "xmark")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(6)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Dismiss")
            .accessibilityHint("Hides this notification")
        }
        .padding(12)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .shadow(color: Color.black.opacity(0.15), radius: 4, x: 0, y: 2)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Completed \(itemName)")
        .accessibilityHint("Use undo button to mark as active")
    }
}

// MARK: - Undo Delete Banner (macOS)

/// macOS-styled undo banner for deleted items.
/// Shows a red trash icon, item name, and undo/dismiss buttons.
/// Uses material background for modern macOS appearance.
private struct MacDeleteUndoBanner: View {
    let itemName: String
    let onUndo: () -> Void
    let onDismiss: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            // Red trash icon
            Image(systemName: "trash.circle.fill")
                .foregroundColor(.red)
                .font(.title2)
                .accessibilityHidden(true)

            // Status text and item name
            VStack(alignment: .leading, spacing: 2) {
                Text("Deleted")
                    .font(.caption)
                    .foregroundColor(.secondary)

                Text(itemName)
                    .font(.body)
                    .fontWeight(.medium)
                    .lineLimit(1)
            }

            Spacer()

            // Undo button (red for restore)
            Button(action: onUndo) {
                Text("Undo")
                    .font(.headline)
                    .foregroundColor(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 6)
                    .background(Color.red)
                    .cornerRadius(6)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Undo deletion")
            .accessibilityHint("Restores the deleted item")

            // Dismiss button
            Button(action: onDismiss) {
                Image(systemName: "xmark")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(6)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Dismiss")
            .accessibilityHint("Hides this notification")
        }
        .padding(12)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .shadow(color: Color.black.opacity(0.15), radius: 4, x: 0, y: 2)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Deleted \(itemName)")
        .accessibilityHint("Use undo button to restore item")
    }
}

// MARK: - Bulk Delete Undo Banner (macOS) - Task 12.8

/// macOS-styled undo banner for bulk deleted items.
/// Shows a red trash icon, item count, and undo/dismiss buttons.
/// Uses material background for modern macOS appearance.
/// This replaces the confirmation dialog for bulk delete operations.
private struct MacBulkDeleteUndoBanner: View {
    let itemCount: Int
    let onUndo: () -> Void
    let onDismiss: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            // Red trash icon
            Image(systemName: "trash.circle.fill")
                .foregroundColor(.red)
                .font(.title2)
                .accessibilityHidden(true)

            // Status text and item count
            VStack(alignment: .leading, spacing: 2) {
                Text("Deleted")
                    .font(.caption)
                    .foregroundColor(.secondary)

                Text("\(itemCount) items")
                    .font(.body)
                    .fontWeight(.medium)
            }

            Spacer()

            // Undo button (red for restore)
            Button(action: onUndo) {
                Text("Undo")
                    .font(.headline)
                    .foregroundColor(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 6)
                    .background(Color.red)
                    .cornerRadius(6)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Undo deletion")
            .accessibilityHint("Restores all \(itemCount) deleted items")
            .accessibilityIdentifier("BulkDeleteUndoButton")

            // Dismiss button
            Button(action: onDismiss) {
                Image(systemName: "xmark")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(6)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Dismiss")
            .accessibilityHint("Hides this notification")
        }
        .padding(12)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .shadow(color: Color.black.opacity(0.15), radius: 4, x: 0, y: 2)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Deleted \(itemCount) items")
        .accessibilityHint("Use undo button to restore all items")
        .accessibilityIdentifier("BulkDeleteUndoBanner")
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
                .accessibilityAddTraits(.isHeader)

            TextField("List Name", text: $listName)
                .textFieldStyle(.roundedBorder)
                .frame(width: 300)
                .accessibilityLabel("List name")
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
                .accessibilityHint("Discards changes")

                Button("Create") {
                    onSave(listName)
                }
                .keyboardShortcut(.return)
                .buttonStyle(.borderedProminent)
                .disabled(listName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                .accessibilityHint("Creates new list")
            }
        }
        .padding(30)
        .frame(minWidth: 350)
    }
}

// MARK: - Export All Lists Sheet

private struct MacExportAllListsSheet: View {
    let onDismiss: () -> Void

    @State private var selectedFormat: ShareFormat = .json
    @State private var exportOptions: ExportOptions = .default
    @State private var exportError: String?

    private let sharingService = SharingService()

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header
            HStack {
                Text("Export All Lists")
                    .font(.headline)
                Spacer()
                Button(action: onDismiss) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            }

            Divider()

            // Format Selection
            VStack(alignment: .leading, spacing: 8) {
                Text("Format")
                    .font(.subheadline)
                    .foregroundColor(.secondary)

                Picker("Format", selection: $selectedFormat) {
                    Text("JSON").tag(ShareFormat.json)
                    Text("Plain Text").tag(ShareFormat.plainText)
                }
                .pickerStyle(.radioGroup)
            }

            Divider()

            // Options
            VStack(alignment: .leading, spacing: 8) {
                Text("Options")
                    .font(.subheadline)
                    .foregroundColor(.secondary)

                Toggle("Include crossed-out items", isOn: $exportOptions.includeCrossedOutItems)
                Toggle("Include archived lists", isOn: $exportOptions.includeArchivedLists)
                Toggle("Include images", isOn: $exportOptions.includeImages)
                    .disabled(selectedFormat == .plainText)
                    .help(selectedFormat == .plainText ? "Images cannot be included in plain text format" : "Include item images in export")
            }

            // Error display
            if let error = exportError {
                HStack {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.orange)
                    Text(error)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            Divider()

            // Actions
            HStack {
                Button("Copy to Clipboard") {
                    copyAllToClipboard()
                }
                .buttonStyle(.bordered)

                Spacer()

                Button("Cancel") {
                    onDismiss()
                }
                .keyboardShortcut(.escape)

                Button("Export...") {
                    exportToFile()
                }
                .keyboardShortcut(.return)
                .buttonStyle(.borderedProminent)
            }
        }
        .padding()
        .frame(width: 360)
    }

    private func copyAllToClipboard() {
        exportError = nil

        guard let result = sharingService.shareAllData(format: selectedFormat, exportOptions: exportOptions) else {
            exportError = sharingService.shareError ?? "Failed to export data"
            return
        }

        let success: Bool
        if let text = result.content as? String {
            success = sharingService.copyToClipboard(text: text)
        } else if let nsString = result.content as? NSString {
            success = sharingService.copyToClipboard(text: nsString as String)
        } else if let url = result.content as? URL,
                  let data = try? Data(contentsOf: url),
                  let text = String(data: data, encoding: .utf8) {
            success = sharingService.copyToClipboard(text: text)
        } else {
            exportError = "Unknown content type"
            return
        }

        if success {
            onDismiss()
        } else {
            exportError = "Failed to copy to clipboard"
        }
    }

    private func exportToFile() {
        exportError = nil

        guard let result = sharingService.shareAllData(format: selectedFormat, exportOptions: exportOptions) else {
            exportError = sharingService.shareError ?? "Failed to export data"
            return
        }

        // Show save panel
        let savePanel = NSSavePanel()
        savePanel.allowedContentTypes = selectedFormat == .json ?
            [.json] : [.plainText]
        savePanel.nameFieldStringValue = result.fileName ?? "ListAll-Export"
        savePanel.canCreateDirectories = true

        savePanel.begin { response in
            guard response == .OK, let url = savePanel.url else { return }

            do {
                if let sourceURL = result.content as? URL {
                    try FileManager.default.copyItem(at: sourceURL, to: url)
                } else if let text = result.content as? String {
                    try text.write(to: url, atomically: true, encoding: .utf8)
                } else if let nsString = result.content as? NSString {
                    try (nsString as String).write(to: url, atomically: true, encoding: .utf8)
                }

                DispatchQueue.main.async {
                    onDismiss()
                }
            } catch {
                DispatchQueue.main.async {
                    exportError = "Failed to save file: \(error.localizedDescription)"
                }
            }
        }
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

// MARK: - Modifier Click Handler (Cmd+Click, Shift+Click)

/// View modifier that adds Cmd+Click and Shift+Click detection using event monitoring
/// Does NOT block drag-and-drop - uses mouseUp detection with distance threshold
private struct ModifierClickHandler: ViewModifier {
    let onCommandClick: () -> Void
    let onShiftClick: () -> Void

    func body(content: Content) -> some View {
        content.background(
            ModifierClickMonitorView(
                onCommandClick: onCommandClick,
                onShiftClick: onShiftClick
            )
        )
    }
}

/// NSViewRepresentable that installs an event monitor for modified clicks
private struct ModifierClickMonitorView: NSViewRepresentable {
    let onCommandClick: () -> Void
    let onShiftClick: () -> Void

    func makeNSView(context: Context) -> ModifierClickMonitorNSView {
        ModifierClickMonitorNSView(
            onCommandClick: onCommandClick,
            onShiftClick: onShiftClick
        )
    }

    func updateNSView(_ nsView: ModifierClickMonitorNSView, context: Context) {
        nsView.onCommandClick = onCommandClick
        nsView.onShiftClick = onShiftClick
    }
}

/// NSView that monitors for modifier clicks (Cmd+Click, Shift+Click) using local event monitor
/// Uses mouseUp detection with distance threshold to distinguish clicks from drags
/// This approach does NOT block drag-and-drop since it only observes mouseUp events
private class ModifierClickMonitorNSView: NSView {
    var onCommandClick: () -> Void
    var onShiftClick: () -> Void
    private var eventMonitor: Any?
    private var mouseDownLocation: NSPoint?
    private var mouseDownTime: Date?

    init(onCommandClick: @escaping () -> Void, onShiftClick: @escaping () -> Void) {
        self.onCommandClick = onCommandClick
        self.onShiftClick = onShiftClick
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

        // Monitor both mouseDown and mouseUp to detect clicks vs drags
        eventMonitor = NSEvent.addLocalMonitorForEvents(matching: [.leftMouseDown, .leftMouseUp]) { [weak self] event in
            guard let self = self,
                  let window = self.window,
                  event.window == window else {
                return event
            }

            let locationInWindow = event.locationInWindow
            let locationInView = self.convert(locationInWindow, from: nil)

            // Check if event is within our bounds
            guard self.bounds.contains(locationInView) else {
                self.mouseDownLocation = nil
                self.mouseDownTime = nil
                return event
            }

            if event.type == .leftMouseDown {
                // Only track single clicks (not double-clicks which are handled by onDoubleClick)
                if event.clickCount == 1 {
                    self.mouseDownLocation = locationInView
                    self.mouseDownTime = Date()
                }
            } else if event.type == .leftMouseUp {
                defer {
                    self.mouseDownLocation = nil
                    self.mouseDownTime = nil
                }

                // Check if this was a click (not a drag)
                // A click is: short duration (<300ms) AND minimal movement (<5 points)
                guard let downLocation = self.mouseDownLocation,
                      let downTime = self.mouseDownTime else {
                    return event
                }

                let timeDelta = Date().timeIntervalSince(downTime)
                let distance = hypot(locationInView.x - downLocation.x,
                                    locationInView.y - downLocation.y)

                let isClick = timeDelta < 0.3 && distance < 5

                if isClick && event.clickCount == 1 {
                    let modifiers = event.modifierFlags

                    if modifiers.contains(.command) {
                        // Cmd+Click: Toggle selection
                        self.perform(#selector(self.invokeCommandClick), with: nil, afterDelay: 0)
                    } else if modifiers.contains(.shift) {
                        // Shift+Click: Range selection
                        self.perform(#selector(self.invokeShiftClick), with: nil, afterDelay: 0)
                    }
                    // NOTE: Plain click (no modifiers) intentionally NOT handled here
                    // to avoid interfering with SwiftUI List's native selection behavior
                }
            }

            return event  // CRITICAL: Let event continue to other handlers (including drag)
        }
    }

    @objc private func invokeCommandClick() {
        onCommandClick()
    }

    @objc private func invokeShiftClick() {
        onShiftClick()
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

/// Extension to make modifier-click handler easy to use
extension View {
    /// Adds Cmd+Click and Shift+Click detection to a view
    /// - Parameters:
    ///   - command: Action to perform on Cmd+Click
    ///   - shift: Action to perform on Shift+Click
    /// - Note: Does NOT block drag-and-drop functionality
    func onModifierClick(
        command: @escaping () -> Void,
        shift: @escaping () -> Void
    ) -> some View {
        modifier(ModifierClickHandler(
            onCommandClick: command,
            onShiftClick: shift
        ))
    }
}

#Preview {
    MacMainView()
        .environmentObject(DataManager.shared)
        .environment(\.managedObjectContext, CoreDataManager.shared.viewContext)
}
