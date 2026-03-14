//
//  MacMainView.swift
//  ListAllMac
//
//  Main view for macOS app using NavigationSplitView.
//

import SwiftUI
import CoreData
import Combine

/// Main view for macOS app with sidebar navigation.
/// This is the macOS equivalent of iOS ContentView, using NavigationSplitView
/// for the standard macOS three-column layout.
struct MacMainView: View {
    @EnvironmentObject var dataManager: DataManager
    @Environment(\.managedObjectContext) var viewContext
    @Environment(\.scenePhase) private var scenePhase

    // Access CoreDataManager for sync status (lastSyncDate) and manual refresh
    @ObservedObject var coreDataManager = CoreDataManager.shared

    // MARK: - Proactive Feature Tips (Task 12.5)
    @ObservedObject var tooltipManager = MacTooltipManager.shared

    // MARK: - CloudKit Sync Status (Task 12.6)
    @ObservedObject var cloudKitService = CloudKitService.shared

    @State var selectedList: List?
    @State private var columnVisibility: NavigationSplitViewVisibility = .all

    // MARK: - Focus State for Keyboard Navigation (Task 11.1)
    /// Tracks which major section has keyboard focus
    enum FocusSection: Hashable {
        case sidebar
        case detail
    }
    @FocusState private var focusedSection: FocusSection?

    // Menu command observers
    @State var showingCreateListSheet = false
    @State private var showingArchivedLists = false
    @State private var showingSharePopover = false
    @State private var showingExportAllSheet = false

    // MARK: - Restore Confirmation State (Task 13.1 UX improvement)
    @State var showingRestoreConfirmation = false
    @State var listToRestore: List? = nil

    // MARK: - CloudKit Sync Polling (macOS fallback)
    // Apple's CloudKit notifications on macOS can be unreliable when the app is frontmost.
    // This timer serves as a safety net to ensure data refreshes even if notifications miss.
    // Using Timer.publish with .onReceive is the correct SwiftUI pattern (not Timer.scheduledTimer).
    // LEARNING: Timer.scheduledTimer with [self] capture in SwiftUI Views captures a COPY of the struct,
    // causing the timer callback to operate on stale state. Timer.publish integrates with SwiftUI lifecycle.
    @State var isSyncPollingActive = false
    let syncPollingTimer = Timer.publish(every: 30.0, on: .main, in: .common).autoconnect()

    // MARK: - Edit State Protection
    // Flag to prevent background sync from interrupting sheet presentation
    // Set via notification from MacListDetailView when editing starts/stops
    @State var isEditingAnyItem = false

    // MARK: - Edit Item State (for native sheet presenter)
    // NOTE: We use MacNativeSheetPresenter instead of SwiftUI's .sheet() modifier
    // because SwiftUI sheets have RunLoop mode issues that prevent presentation until app deactivation
    @State var selectedEditItem: Item?

    // MARK: - Navigation Path for Animation Fix
    // CRITICAL FIX: Apple-confirmed bug in NavigationSplitView (Xcode 14.3+)
    // Without a NavigationPath with explicit animation, ALL animations in the app break.
    // This includes .sheet() presentation - sheets queue but never display until app deactivates.
    // See: https://developer.apple.com/forums/thread/728132
    @State private var navigationPath = NavigationPath()

    var body: some View {
        ZStack(alignment: .topTrailing) {
            NavigationSplitView(columnVisibility: $columnVisibility) {
            // CRITICAL FIX: Wrap sidebar in NavigationStack with animated path
            // This restores SwiftUI's animation system that NavigationSplitView breaks
            NavigationStack(path: $navigationPath.animation(.linear(duration: 0))) {
                // Sidebar with lists - two sections: Lists + Archived (Apple HIG pattern)
                // CRITICAL: Let sidebar observe dataManager directly
                // Passing array by value breaks SwiftUI observation chain on macOS
                MacSidebarView(
                    selectedList: $selectedList,
                    onCreateList: { showingCreateListSheet = true },
                    onDeleteList: deleteList
                )
            }
            // Apply column width to NavigationStack wrapper (not inside it)
            .navigationSplitViewColumnWidth(min: 220, ideal: 260, max: 400)
        } detail: {
            detailContent
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
        .overlay(alignment: .top) {
            if cloudKitService.shouldShowSyncErrorBanner {
                MacSyncErrorBanner(onDismiss: {
                    cloudKitService.dismissSyncErrorBanner()
                })
                .frame(maxWidth: 500)
                .padding(.horizontal, 20)
                .padding(.top, 12)
                .transition(.move(edge: .top).combined(with: .opacity))
                .animation(.spring(response: 0.3, dampingFraction: 0.7),
                           value: cloudKitService.shouldShowSyncErrorBanner)
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
                onCreateFromTemplate: { template in
                    createSampleList(from: template)
                    showingCreateListSheet = false
                },
                onCancel: { showingCreateListSheet = false }
            )
        }
        // MARK: - Restore List Confirmation Alert (Task 13.1 UX improvement)
        .alert("Restore List", isPresented: $showingRestoreConfirmation) {
            Button("Cancel", role: .cancel) {
                listToRestore = nil
            }
            Button("Restore") {
                if let list = listToRestore {
                    dataManager.restoreList(withId: list.id)
                    dataManager.loadArchivedData()
                    dataManager.loadData()
                    // Clear selection since list is moving to active lists
                    selectedList = nil
                }
                listToRestore = nil
            }
        } message: {
            if let list = listToRestore {
                Text("Do you want to restore \"\(list.name)\" to your active lists?")
            } else {
                Text("Do you want to restore this list?")
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("CreateNewList"))) { _ in
            showingCreateListSheet = true
        }
        // MARK: - Archive List Menu Command Handler (Task 15.1)
        // Responds to Lists > Archive List menu command
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("ArchiveSelectedList"))) { _ in
            // Only process if a list is selected and it's not already archived
            guard let list = selectedList, !list.isArchived else { return }
            // Archive the list using DataManager
            dataManager.deleteList(withId: list.id)  // deleteList actually archives
            // Clear selection since list moved to archived section
            selectedList = nil
            // Refresh data to show updated lists
            dataManager.loadData()
            dataManager.loadArchivedData()
        }
        // MARK: - Duplicate List Menu Command Handler (Task 16.9)
        // Responds to Lists > Duplicate List (Cmd+D) menu command
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("DuplicateSelectedList"))) { _ in
            guard let list = selectedList, !list.isArchived else { return }
            duplicateList(list)
        }
        // Note: ToggleArchivedLists handler removed - archived lists now always visible
        // in their own sidebar section (Apple HIG two-section pattern)
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
        .onChange(of: showingArchivedLists) { _, _ in
            // Legacy: showingArchivedLists is now only used for menu command compatibility
            // Both sections are always visible, so no selection clearing needed
        }
        .onAppear {
            startSyncPolling()
            // Load archived lists so both sections can display
            dataManager.loadArchivedData()
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

}


#Preview {
    MacMainView()
        .environmentObject(DataManager.shared)
        .environment(\.managedObjectContext, CoreDataManager.shared.viewContext)
}
