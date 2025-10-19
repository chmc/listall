import SwiftUI

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
    @State private var showingShareFormatPicker = false
    @State private var showingShareSheet = false
    @State private var selectedShareFormat: ShareFormat = .plainText
    @State private var shareFileURL: URL?
    @State private var shareItems: [Any] = []
    
    var body: some View {
        ZStack {
            // Main Content - Lists View with Navigation
            NavigationView {
                ZStack {
                    VStack(spacing: 0) {
                        // Sync Status Bar
                        if cloudKitService.syncStatus != .available || cloudKitService.isSyncing {
                            SyncStatusView(cloudKitService: cloudKitService)
                                .padding(.horizontal)
                                .padding(.top, 8)
                                .padding(.bottom, 12)
                        }
                        
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
                            ForEach(viewModel.displayedLists) { list in
                                ListRowView(list: list, mainViewModel: viewModel)
                                    .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0))
                            }
                            .onMove(perform: viewModel.showingArchivedLists ? nil : viewModel.moveList)
                        }
                        .environment(\.editMode, $editMode)
                        .listStyle(.plain)
                        .padding(.top, 8)
                    }
                    
                    // Programmatic navigation for auto-opening newly created list
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
                                .help(viewModel.showingArchivedLists ? "Show Active Lists" : "Show Archived Lists")
                                
                                // Share all data button (only for active lists)
                                if !viewModel.showingArchivedLists && !viewModel.lists.isEmpty {
                                    Button(action: {
                                        showingShareFormatPicker = true
                                    }) {
                                        Image(systemName: "square.and.arrow.up")
                                    }
                                    .help("Share all data")
                                }
                                
                                // Sync button (only for active lists)
                                if !viewModel.showingArchivedLists {
                                    Button(action: {
                                        Task {
                                            await cloudKitService.sync()
                                        }
                                    }) {
                                        Image(systemName: Constants.UI.syncIcon)
                                    }
                                    .disabled(cloudKitService.isSyncing)
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
                                            withAnimation {
                                                viewModel.enterSelectionMode()
                                                editMode = .active
                                            }
                                        }) {
                                            Image(systemName: "pencil")
                                        }
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
                            .accessibilityIdentifier("AddListButton")
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
            .navigationBarTitleDisplayMode(.large)
        .onAppear {
            viewModel.loadLists()
            Task {
                await conflictManager.checkForConflicts()
            }
            
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
        }
        .onChange(of: scenePhase) { newPhase in
            // Restore navigation when app becomes active
            if newPhase == .active {
                // Restore navigation to the list user was viewing
                if let listIdString = selectedListIdString,
                   let listId = UUID(uuidString: listIdString) {
                    // Reload lists to ensure we have the latest data
                    viewModel.loadLists()
                    
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
            }
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
                    Text("Lists")
                        .font(.system(size: 10))
                        .foregroundColor(.blue)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
            }
            .accessibilityLabel("Lists")
            
            // Settings Button
            Button(action: onSettingsTap) {
                VStack(spacing: 4) {
                    Image(systemName: Constants.UI.settingsIcon)
                        .font(.system(size: 24))
                        .foregroundColor(.gray)
                    Text("Settings")
                        .font(.system(size: 10))
                        .foregroundColor(.gray)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
            }
            .accessibilityLabel("Settings")
        }
        .frame(height: 50)
        .padding(.bottom, 8)
    }
}

#Preview {
    MainView()
}
