import SwiftUI
import Combine

struct MainView: View {
    @StateObject private var viewModel = MainViewModel()
    @StateObject private var cloudKitService = CloudKitService()
    @StateObject private var conflictManager = SyncConflictManager(cloudKitService: CloudKitService())
    @StateObject private var sharingService = SharingService()
    @StateObject private var tooltipManager = TooltipManager.shared
    @Environment(\.scenePhase) private var scenePhase

    // State restoration: Persist which list user was viewing
    @SceneStorage("selectedListId") private var selectedListIdString: String?
    @State private var hasRestoredNavigation = false

    @State private var showingCreateList = false
    @State private var showingSettings = false
    @State private var editMode: EditMode = .inactive
    @State private var showingDeleteConfirmation = false

    // MARK: - CloudKit Sync Polling (iOS fallback)
    // Apple's CloudKit push notifications on iOS can be unreliable when the app is frontmost.
    // This timer serves as a safety net to ensure data refreshes even if notifications miss.
    // Using Timer.publish with .onReceive is the correct SwiftUI pattern (not Timer.scheduledTimer).
    @State private var isSyncPollingActive = false
    private let syncPollingTimer = Timer.publish(every: 30.0, on: .main, in: .common).autoconnect()

    @State private var showingShareFormatPicker = false
    @State private var showingShareSheet = false
    @State private var selectedShareFormat: ShareFormat = .plainText
    @State private var shareFileURL: URL?
    @State private var shareItems: [Any] = []

    // MARK: - Task 16.11: Sync Status UI
    /// Sync button image with rotation animation on iOS 18+, fallback for older versions
    @ViewBuilder
    private var syncButtonImage: some View {
        if #available(iOS 18.0, *) {
            Image(systemName: Constants.UI.syncIcon)
                .symbolEffect(.rotate, isActive: cloudKitService.isSyncing)
        } else {
            // Fallback for iOS 17: use rotationEffect with animation
            Image(systemName: Constants.UI.syncIcon)
                .rotationEffect(.degrees(cloudKitService.isSyncing ? 360 : 0))
                .animation(
                    cloudKitService.isSyncing
                        ? .linear(duration: 1.0).repeatForever(autoreverses: false)
                        : .default,
                    value: cloudKitService.isSyncing
                )
        }
    }

    /// Dynamic accessibility label for sync button showing current sync state
    private var syncAccessibilityLabel: String {
        if cloudKitService.isSyncing {
            return String(localized: "Syncing with iCloud")
        } else if cloudKitService.syncError != nil {
            return String(localized: "Sync error. Tap to retry")
        } else {
            return String(localized: "Sync with iCloud")
        }
    }

    var body: some View {
        ZStack {
            // Main Content - Lists View with Navigation
            NavigationView {
                ZStack {
                    VStack(spacing: 0) {
                        // Main Content
                        if viewModel.isLoading {
                            ProgressView("Loading lists...")
                                .padding(.top, 16)
                        } else if viewModel.displayedLists.isEmpty {
                            if viewModel.showingArchivedLists {
                                // Simple empty state for archived lists
                                VStack(spacing: Theme.Spacing.lg) {
                                    Image(systemName: "archivebox")
                                        .font(.system(size: 60))
                                        .foregroundColor(Theme.Colors.secondary)
                                    
                                    Text("No Archived Lists")
                                        .font(Theme.Typography.title)
                                    
                                    Text("Archived lists will appear here")
                                        .font(Theme.Typography.body)
                                        .emptyStateStyle()
                                }
                                .padding(.top, 40)
                            } else {
                                // Engaging empty state for active lists with sample templates
                                ListsEmptyStateView(
                                    onCreateSampleList: { template in
                                        let createdList = viewModel.createSampleList(from: template)
                                        // Auto-navigate to the newly created list
                                        viewModel.selectedListForNavigation = createdList
                                    },
                                    onCreateCustomList: {
                                        showingCreateList = true
                                    }
                                )
                            }
                        } else {
                        SwiftUI.List {
                            // CRITICAL: Use viewModel.displayedLists computed property (same pattern as ListView.filteredItems)
                            // Computed property forces SwiftUI to re-evaluate from @Published backing storage
                            // This prevents drag animation desync after reordering
                            Section {
                                ForEach(viewModel.displayedLists) { list in
                                    ListRowView(list: list, mainViewModel: viewModel)
                                        .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0))
                                }
                                .onDelete { indexSet in
                                    // Archive lists (same as swipe-to-delete)
                                    for index in indexSet {
                                        let list = viewModel.displayedLists[index]
                                        viewModel.archiveList(list)
                                    }
                                }
                                .onMove(perform: viewModel.moveList)
                            }
                        }
                        .environment(\.editMode, $editMode)
                        .listStyle(.plain)
                        .id(viewModel.listsReorderTrigger) // CRITICAL: Force rebuild on reorder
                        .padding(.top, 8)
                        .refreshable {
                            // Sync with CloudKit
                            await cloudKitService.sync()
                            // Sync with Apple Watch
                            viewModel.manualSync()
                        }
                    }
                    
                    // Programmatic navigation for auto-opening newly created list
                    // Using deprecated NavigationLink API to maintain iOS 16 compatibility
                    // NavigationStack requires iOS 16+, current deployment target is iOS 15
                    // Warning suppressed until iOS 16 becomes minimum deployment target
                    NavigationLink(
                        destination: viewModel.selectedListForNavigation.map { list in
                            ListView(list: list, mainViewModel: viewModel)
                                .onDisappear {
                                    // Only clear stored list ID when user explicitly navigates back
                                    // Don't clear on system-initiated view hierarchy changes
                                    if viewModel.selectedListForNavigation == nil {
                                        selectedListIdString = nil
                                    }
                                }
                        },
                        isActive: Binding(
                            get: { viewModel.selectedListForNavigation != nil },
                            set: { newValue in
                                if !newValue {
                                    // User navigated back - clear the view model state
                                    viewModel.selectedListForNavigation = nil
                                    // Don't clear selectedListIdString here - let onDisappear handle it
                                } else if let list = viewModel.selectedListForNavigation {
                                    // Save list ID for state restoration
                                    selectedListIdString = list.id.uuidString
                                }
                            }
                        )
                    ) {
                        EmptyView()
                    }
                    .hidden()
                    }
                    .navigationTitle(viewModel.isInSelectionMode ? "\(viewModel.selectedLists.count) Selected" : (viewModel.showingArchivedLists ? "Archived Lists" : "Lists"))
                    .navigationBarTitleDisplayMode(.large)
                    .toolbar {
                    ToolbarItem(placement: .navigationBarLeading) {
                        HStack(spacing: Theme.Spacing.md) {
                            if !viewModel.isInSelectionMode {
                                // Archive toggle button
                                Button(action: {
                                    withAnimation {
                                        viewModel.toggleArchivedView()
                                    }
                                }) {
                                    Image(systemName: viewModel.showingArchivedLists ? "tray" : "archivebox")
                                }
                                .hoverEffect(.highlight)  // Task 16.16: iPad trackpad hover effect
                                .keyboardShortcut("a", modifiers: [.command, .shift])  // Task 15.8: iPad Cmd+Shift+A
                                .help(viewModel.showingArchivedLists ? "Show Active Lists" : "Show Archived Lists")
                                
                                // Share all data button (only for active lists)
                                if !viewModel.showingArchivedLists && !viewModel.lists.isEmpty {
                                    Button(action: {
                                        showingShareFormatPicker = true
                                    }) {
                                        Image(systemName: "square.and.arrow.up")
                                    }
                                    .hoverEffect(.highlight)  // Task 16.16: iPad trackpad hover effect
                                    .help("Share all data")
                                }
                                
                                // Sync button (only for active lists)
                                // Syncs with both CloudKit and Apple Watch
                                // Task 16.11: Enhanced with animation and status feedback
                                if !viewModel.showingArchivedLists {
                                    Button(action: {
                                        // Sync with CloudKit
                                        Task {
                                            await cloudKitService.sync()
                                        }
                                        // Sync with Apple Watch
                                        viewModel.manualSync()
                                    }) {
                                        syncButtonImage
                                    }
                                    .hoverEffect(.highlight)  // Task 16.16: iPad trackpad hover effect
                                    .foregroundColor(cloudKitService.syncError != nil ? .red : nil)  // Red if error
                                    .disabled(cloudKitService.isSyncing || viewModel.isSyncingFromWatch)
                                    .keyboardShortcut("r", modifiers: .command)  // Task 15.8: iPad Cmd+R
                                    .accessibilityLabel(syncAccessibilityLabel)
                                    .help("Sync with iCloud and Apple Watch")
                                }
                            }
                            
                            if !viewModel.displayedLists.isEmpty {
                                if viewModel.isInSelectionMode {
                                    // Selection mode: Show Cancel button
                                    Button("Cancel") {
                                        withAnimation {
                                            viewModel.exitSelectionMode()
                                            editMode = .inactive
                                        }
                                    }
                                } else {
                                    // Normal mode: Show Edit button (only for active lists)
                                    if !viewModel.showingArchivedLists {
                                        Button(action: {
                                            print("🟢 Edit button pressed in MainView")
                                            print("   Current editMode: \(editMode)")
                                            print("   Current isInSelectionMode: \(viewModel.isInSelectionMode)")
                                            withAnimation {
                                                viewModel.enterSelectionMode()
                                                editMode = .active
                                            }
                                            print("   New editMode: \(editMode)")
                                            print("   New isInSelectionMode: \(viewModel.isInSelectionMode)")
                                        }) {
                                            Image(systemName: "pencil")
                                        }
                                        .hoverEffect(.highlight)  // Task 16.16: iPad trackpad hover effect
                                    }
                                }
                            }
                        }
                        .padding(.horizontal, Theme.Spacing.sm)
                    }
                    
                    ToolbarItem(placement: .navigationBarTrailing) {
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
                                .disabled(viewModel.selectedLists.isEmpty)
                                
                                Divider()
                                
                                Button(role: .destructive, action: {
                                    showingDeleteConfirmation = true
                                }) {
                                    Label("Delete Lists", systemImage: "trash")
                                }
                                .disabled(viewModel.selectedLists.isEmpty)
                            } label: {
                                Image(systemName: "ellipsis.circle")
                                    .foregroundColor(.primary)
                            }
                            .padding(.horizontal, Theme.Spacing.sm)
                        } else if !viewModel.showingArchivedLists {
                            // Normal mode: Show Add button (only for active lists)
                            Button(action: {
                                showingCreateList = true
                            }) {
                                Image(systemName: Constants.UI.addIcon)
                                    .imageScale(.large)
                                    .aspectRatio(1.0, contentMode: .fit)
                                    .padding(.horizontal, -2)
                            }
                            .buttonStyle(.plain)
                            .hoverEffect(.highlight)  // Task 16.16: iPad trackpad hover effect
                            .accessibilityIdentifier("AddListButton")
                            .keyboardShortcut("n", modifiers: .command)  // Task 15.8: iPad Cmd+N
                            .padding(.horizontal, Theme.Spacing.sm)
                        }
                    }
                    }
                    
                    // Archive Notification Banner
                    if viewModel.showArchivedNotification, let list = viewModel.recentlyArchivedList {
                        VStack {
                            Spacer()
                            ArchiveBanner(
                                listName: list.name,
                                onUndo: {
                                    viewModel.undoArchive()
                                },
                                onDismiss: {
                                    viewModel.hideArchiveNotification()
                                }
                            )
                            .padding(.horizontal, Theme.Spacing.md)
                            .padding(.bottom, 60) // Space for bottom toolbar
                            .transition(.move(edge: .bottom).combined(with: .opacity))
                            .animation(Theme.Animation.spring, value: viewModel.showArchivedNotification)
                        }
                    }
                    
                    // Custom Bottom Toolbar - Only visible on this main screen
                    VStack {
                        Spacer()
                        CustomBottomToolbar(
                            onListsTap: {
                                // Already on lists view - no action needed
                            },
                            onSettingsTap: {
                                showingSettings = true
                            }
                        )
                        .background(Color(.systemBackground))
                        .shadow(color: Color.black.opacity(0.1), radius: 8, x: 0, y: -2)
                    }
                    .edgesIgnoringSafeArea(.bottom)
                }
            }
            // iPad uses split view by default, but stack for screenshots
            // iPhone always uses stack navigation
            .modifier(NavigationStyleModifier())
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
                    showingSettings = true
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
        }
        .sheet(isPresented: $showingSettings) {
            SettingsView()
        }
    }
    
    private func handleShareAllData(format: ShareFormat) {
        // Create share content asynchronously
        DispatchQueue.global(qos: .userInitiated).async { [weak sharingService] in
            guard let shareResult = sharingService?.shareAllData(format: format) else {
                return
            }
            
            // Update UI on main thread
            DispatchQueue.main.async {
                // Use UIActivityItemSource for proper iOS sharing
                if let fileURL = shareResult.content as? URL {
                    // File-based sharing (JSON)
                    let filename = shareResult.fileName ?? "ListAll-Export.json"
                    let itemSource = FileActivityItemSource(fileURL: fileURL, filename: filename)
                    self.shareFileURL = nil
                    self.shareItems = [itemSource]
                } else if let text = shareResult.content as? String {
                    // Text-based sharing (Plain Text)
                    let itemSource = TextActivityItemSource(text: text, subject: "ListAll Export")
                    self.shareFileURL = nil
                    self.shareItems = [itemSource]
                }
                
                // Present immediately - no delay needed with direct presentation
                self.showingShareSheet = true
            }
        }
    }
}

// MARK: - Archive Banner Component
struct ArchiveBanner: View {
    let listName: String
    let onUndo: () -> Void
    let onDismiss: () -> Void
    
    var body: some View {
        HStack(spacing: Theme.Spacing.md) {
            Image(systemName: "archivebox.fill")
                .foregroundColor(.orange)
                .font(.title3)
            
            VStack(alignment: .leading, spacing: 2) {
                Text("Archived")
                    .font(Theme.Typography.caption)
                    .foregroundColor(.secondary)
                
                Text(listName)
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

// MARK: - Custom Bottom Toolbar Component
struct CustomBottomToolbar: View {
    let onListsTap: () -> Void
    let onSettingsTap: () -> Void
    
    var body: some View {
        HStack(spacing: 0) {
            // Lists Button (Active/Selected)
            Button(action: onListsTap) {
                VStack(spacing: 4) {
                    Image(systemName: Constants.UI.listIcon)
                        .font(.system(size: 24))
                        .foregroundColor(.blue)
                    Text(String(localized: "Lists"))
                        .font(.system(size: 10))
                        .foregroundColor(.blue)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
            }
            .hoverEffect(.highlight)  // Task 16.16: iPad trackpad hover effect
            .accessibilityLabel(String(localized: "Lists"))

            // Settings Button
            Button(action: onSettingsTap) {
                VStack(spacing: 4) {
                    Image(systemName: Constants.UI.settingsIcon)
                        .font(.system(size: 24))
                        .foregroundColor(.gray)
                    Text(String(localized: "Settings"))
                        .font(.system(size: 10))
                        .foregroundColor(.gray)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
            }
            .hoverEffect(.highlight)  // Task 16.16: iPad trackpad hover effect
            .accessibilityLabel(String(localized: "Settings"))
            .accessibilityIdentifier("SettingsButton")
        }
        .frame(height: 50)
        .padding(.bottom, 8)
    }
}

// MARK: - Navigation Style Modifier (Task 15.2)
/// Controls NavigationView style based on device and context:
/// - iPhone: Always uses stack navigation
/// - iPad in UITEST_MODE: Uses stack for consistent App Store screenshots
/// - iPad normally: Uses default (split view) for better multitasking UX
private struct NavigationStyleModifier: ViewModifier {
    private var shouldUseStackNavigation: Bool {
        #if os(iOS)
        // iPhone always uses stack navigation
        if UIDevice.current.userInterfaceIdiom == .phone {
            return true
        }
        // iPad uses stack for screenshots (UITEST_MODE), otherwise split view
        return UITestDataService.isUITesting
        #else
        return true
        #endif
    }

    func body(content: Content) -> some View {
        if shouldUseStackNavigation {
            content.navigationViewStyle(.stack)
        } else {
            content // Use default (automatic) style - enables split view on iPad
        }
    }
}

#Preview {
    MainView()
}
