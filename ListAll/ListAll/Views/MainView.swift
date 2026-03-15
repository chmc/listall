import SwiftUI
import Combine

struct MainView: View {
    @StateObject var viewModel = MainViewModel()
    @StateObject var cloudKitService = CloudKitService.shared
    @StateObject var conflictManager = SyncConflictManager(cloudKitService: CloudKitService.shared)
    @StateObject var sharingService = SharingService()
    @StateObject var tooltipManager = TooltipManager.shared
    @Environment(\.scenePhase) var scenePhase

    // MARK: - iPad NavigationSplitView Support (Phase 1)
    @Environment(\.horizontalSizeClass) var horizontalSizeClass
    @State var columnVisibility: NavigationSplitViewVisibility = .all
    // CRITICAL FIX: Apple-confirmed bug in NavigationSplitView (Xcode 14.3+)
    // Without a NavigationPath with explicit animation, ALL animations in the app break.
    // This includes .sheet() presentation - sheets queue but never display until app deactivates.
    // See: https://developer.apple.com/forums/thread/728132
    @State var navigationPath = NavigationPath()

    // State restoration: Persist which list user was viewing
    @SceneStorage("selectedListId") var selectedListIdString: String?
    @State var hasRestoredNavigation = false

    @State var showingCreateList = false
    @State var showingSettings = false
    @State var showingSettingsInDetail = false  // iPad: show Settings in detail column
    @State var editMode: EditMode = .inactive
    @State var showingDeleteConfirmation = false

    // MARK: - CloudKit Sync Polling (iOS fallback)
    // Apple's CloudKit push notifications on iOS can be unreliable when the app is frontmost.
    // This timer serves as a safety net to ensure data refreshes even if notifications miss.
    // Using Timer.publish with .onReceive is the correct SwiftUI pattern (not Timer.scheduledTimer).
    @State var isSyncPollingActive = false
    let syncPollingTimer = Timer.publish(every: 30.0, on: .main, in: .common).autoconnect()

    @State var showingShareFormatPicker = false
    @State var showingShareSheet = false
    @State var selectedShareFormat: ShareFormat = .plainText
    @State var shareFileURL: URL?
    @State var shareItems: [Any] = []

    /// Whether the current layout is regular width (iPad)
    var isRegularWidth: Bool {
        horizontalSizeClass == .regular
    }

    // MARK: - Body

    var body: some View {
        ZStack {
            if isRegularWidth {
                iPadBody
            } else {
                iPhoneBody
            }
        }
        .overlay(alignment: .top) {
            // Watch Sync Indicator - as overlay to avoid affecting navigation bar layout
            if viewModel.isSyncingFromWatch {
                HStack(spacing: 6) {
                    Image(systemName: "applewatch")
                        .font(.system(size: 12))
                    Text(String(localized: "Syncing with Watch..."))
                        .font(.caption)
                }
                .foregroundColor(.secondary)
                .padding(.horizontal)
                .padding(.vertical, 4)
                .background(.ultraThinMaterial)
                .cornerRadius(8)
                .padding(.top, 8)
                .transition(.opacity.combined(with: .move(edge: .top)))
                .animation(.easeInOut(duration: 0.3), value: viewModel.isSyncingFromWatch)
            }
        }
        .onAppear {
            viewModel.loadLists()
            Task {
                await conflictManager.checkForConflicts()
            }

            // Enable sync polling timer (fallback for unreliable CloudKit push notifications)
            isSyncPollingActive = true

            // Advertise Handoff activity for browsing lists
            HandoffService.shared.startBrowsingListsActivity()

            // Show add list tooltip if user has no lists and hasn't seen it
            if viewModel.lists.isEmpty {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    tooltipManager.showIfNeeded(.addListButton)
                }
            }

            // Show archive tooltip if user has 3+ lists and hasn't seen it
            if viewModel.lists.count >= 3 {
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                    tooltipManager.showIfNeeded(.archiveFunctionality)
                }
            }
            #if DEBUG
            // Deterministic auto-opening of Settings for UI screenshot tests
            if ProcessInfo.processInfo.environment["UITEST_OPEN_SETTINGS_ON_LAUNCH"] == "1" {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                    if isRegularWidth {
                        // iPad: Show settings in detail column
                        showingSettingsInDetail = true
                        viewModel.selectedListForNavigation = nil
                    } else {
                        // iPhone: Show settings as sheet
                        showingSettings = true
                    }
                }
            }
            #endif
        }
        .onChange(of: editMode) { newEditMode in
            // CRITICAL: Track edit mode to block sync during potential drag operations
            // isDragging in ViewModel is only set when drop completes, but we need to
            // block sync from the moment edit mode is active (when drag becomes possible)
            viewModel.setEditModeActive(newEditMode.isEditing)
        }
        .onChange(of: scenePhase) { newPhase in
            if newPhase == .active {
                // CRITICAL: Refresh data when app becomes active to catch CloudKit changes
                // This handles changes made on other devices while iOS was in background
                print("🔄 iOS: App became active - refreshing data from CloudKit")
                let viewContext = CoreDataManager.shared.viewContext
                viewContext.performAndWait {
                    viewContext.refreshAllObjects()
                }
                viewModel.loadLists()

                // Enable sync polling timer when app is active
                isSyncPollingActive = true
                print("🔄 iOS: Sync polling enabled")

                // Restore navigation to the list user was viewing
                if let listIdString = selectedListIdString,
                   let listId = UUID(uuidString: listIdString) {
                    // Find the list in loaded lists
                    if let list = viewModel.lists.first(where: { $0.id == listId }) {
                        // Only restore if we're not already viewing that list
                        if viewModel.selectedListForNavigation?.id != listId {
                            // Delay navigation slightly to ensure view hierarchy is ready
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                                viewModel.selectedListForNavigation = list
                            }
                        }
                    } else {
                        // List no longer exists, clear the stored ID
                        selectedListIdString = nil
                    }
                }
            } else if newPhase == .background || newPhase == .inactive {
                // Disable polling to save battery when app is not active
                isSyncPollingActive = false
                print("🔄 iOS: Sync polling disabled")
            }
        }
        .onChange(of: viewModel.selectedListForNavigation) { newList in
            // State restoration: Save selected list ID when sidebar selection changes
            selectedListIdString = newList?.id.uuidString

            // iPad: Clear settings detail when a list is selected
            if newList != nil && showingSettingsInDetail {
                showingSettingsInDetail = false
            }
        }
        .onReceive(syncPollingTimer) { _ in
            // Only poll when app is active (controlled by scenePhase)
            guard isSyncPollingActive else { return }

            print("🔄 iOS: Polling for CloudKit changes (timer-based fallback)")

            // CRITICAL FIX: Use performAndWait (synchronous) to ensure refreshAllObjects()
            // completes BEFORE loadLists() fetches. This matches the macOS fix pattern.
            let viewContext = CoreDataManager.shared.viewContext
            viewContext.performAndWait {
                viewContext.refreshAllObjects()
            }

            // Trigger CloudKit sync engine to wake up and check for pending operations
            CoreDataManager.shared.triggerCloudKitSync()

            // Now safe to load data - viewContext has been refreshed
            viewModel.loadLists()
        }
        .sheet(isPresented: $conflictManager.showingConflictResolution) {
            if let conflict = conflictManager.currentConflict {
                SyncConflictResolutionView(
                    conflictObject: conflict,
                    onResolve: { strategy in
                        Task {
                            await conflictManager.resolveConflict(with: strategy)
                        }
                    }
                )
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .NSPersistentStoreRemoteChange)) { _ in
            Task {
                await conflictManager.checkForConflicts()
            }
        }
        // CRITICAL: Observe Core Data remote changes (CloudKit sync from other devices)
        // This ensures iOS UI updates in real-time when macOS or other devices sync changes
        // Without this, iOS only refreshes when app goes to background and returns
        .onReceive(NotificationCenter.default.publisher(for: .coreDataRemoteChange)) { _ in
            print("🌐 iOS: Received Core Data remote change notification - refreshing UI")
            viewModel.loadLists()
        }
        .onReceive(NotificationCenter.default.publisher(for: .dataImported)) { _ in
            // Refresh lists after import
            viewModel.loadLists()
        }
        .onReceive(NotificationCenter.default.publisher(for: .itemDataChanged)) { _ in
            // Refresh lists when items are added, deleted, or modified
            viewModel.loadLists()
        }
        .sheet(isPresented: $showingCreateList) {
            CreateListView(mainViewModel: viewModel)
        }
        .sheet(isPresented: $showingShareFormatPicker) {
            ShareFormatPickerView(
                selectedFormat: $selectedShareFormat,
                shareOptions: .constant(.default),
                onShare: { format, _ in
                    handleShareAllData(format: format)
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
        .alert("Archive Lists", isPresented: $showingDeleteConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Archive", role: .destructive) {
                withAnimation {
                    for listId in viewModel.selectedLists {
                        if let list = viewModel.lists.first(where: { $0.id == listId }) {
                            viewModel.archiveList(list)
                        }
                    }
                    viewModel.selectedLists.removeAll()
                    editMode = .inactive
                    viewModel.exitSelectionMode()
                }
            }
        } message: {
            let count = viewModel.selectedLists.count
            Text("Archive \(count) \(count == 1 ? "list" : "lists")? You can restore them later from archived lists.")
        }
        // Tooltip overlay - shows above all content
        TooltipOverlay()
        .sheet(isPresented: $showingSettings) {
            SettingsView()
        }
    }
}

#Preview {
    MainView()
}
