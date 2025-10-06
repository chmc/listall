import SwiftUI

struct MainView: View {
    @StateObject private var viewModel = MainViewModel()
    @StateObject private var cloudKitService = CloudKitService()
    @StateObject private var conflictManager = SyncConflictManager(cloudKitService: CloudKitService())
    @StateObject private var sharingService = SharingService()
    @State private var selectedTab = 0
    @State private var showingCreateList = false
    @State private var editMode: EditMode = .inactive
    @State private var showingDeleteConfirmation = false
    @State private var showingShareFormatPicker = false
    @State private var showingShareSheet = false
    @State private var selectedShareFormat: ShareFormat = .plainText
    @State private var shareFileURL: URL?
    @State private var shareItems: [Any] = []
    
    var body: some View {
        TabView(selection: $selectedTab) {
            // Lists Tab
            NavigationView {
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
                    } else if viewModel.lists.isEmpty {
                        VStack(spacing: Theme.Spacing.lg) {
                            Image(systemName: Constants.UI.listIcon)
                                .font(.system(size: 60))
                                .foregroundColor(Theme.Colors.secondary)
                            
                            Text("No Lists Yet")
                                .font(Theme.Typography.title)
                            
                            Text("Create your first list to get started")
                                .font(Theme.Typography.body)
                                .emptyStateStyle()
                        }
                    } else {
                        SwiftUI.List {
                            ForEach(viewModel.lists) { list in
                                ListRowView(list: list, mainViewModel: viewModel)
                                    .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0))
                            }
                            .onMove(perform: viewModel.moveList)
                        }
                        .environment(\.editMode, $editMode)
                        .listStyle(.plain)
                        .padding(.top, 8)
                    }
                }
                .navigationTitle("Lists")
                .toolbar {
                    ToolbarItem(placement: .navigationBarLeading) {
                        HStack {
                            if !viewModel.isInSelectionMode {
                                // Share all data button
                                if !viewModel.lists.isEmpty {
                                    Button(action: {
                                        showingShareFormatPicker = true
                                    }) {
                                        Image(systemName: "square.and.arrow.up")
                                    }
                                    .help("Share all data")
                                }
                                
                                Button(action: {
                                    Task {
                                        await cloudKitService.sync()
                                    }
                                }) {
                                    Image(systemName: Constants.UI.syncIcon)
                                }
                                .disabled(cloudKitService.isSyncing)
                            }
                            
                            if !viewModel.lists.isEmpty {
                                if viewModel.isInSelectionMode {
                                    // Selection mode: Show Select All/None
                                    Button(viewModel.selectedLists.count == viewModel.lists.count ? "Deselect All" : "Select All") {
                                        withAnimation {
                                            if viewModel.selectedLists.count == viewModel.lists.count {
                                                viewModel.deselectAll()
                                            } else {
                                                viewModel.selectAll()
                                            }
                                        }
                                    }
                                } else {
                                    // Normal mode: Show Edit button
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
                    
                    ToolbarItem(placement: .navigationBarTrailing) {
                        HStack {
                            if viewModel.isInSelectionMode {
                                // Selection mode: Show Delete and Done buttons
                                if !viewModel.selectedLists.isEmpty {
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
                                        editMode = .inactive
                                    }
                                }
                            } else {
                                // Normal mode: Show Add button
                                Button(action: {
                                    showingCreateList = true
                                }) {
                                    Image(systemName: Constants.UI.addIcon)
                                }
                                .accessibilityIdentifier("AddListButton")
                            }
                        }
                    }
                }
            }
            .tabItem {
                Image(systemName: Constants.UI.listIcon)
                Text("Lists")
            }
            .tag(0)
            
            // Settings Tab
            SettingsView()
                .tabItem {
                    Image(systemName: Constants.UI.settingsIcon)
                    Text("Settings")
                }
                .tag(1)
        }
        .onAppear {
            viewModel.loadLists()
            Task {
                await conflictManager.checkForConflicts()
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
        .onReceive(NotificationCenter.default.publisher(for: .switchToListsTab)) { _ in
            // Switch to Lists tab after import
            selectedTab = 0
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
        .alert("Delete Lists", isPresented: $showingDeleteConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) {
                withAnimation {
                    viewModel.deleteSelectedLists()
                    editMode = .inactive
                    viewModel.exitSelectionMode()
                }
            }
        } message: {
            let count = viewModel.selectedLists.count
            Text("Are you sure you want to delete \(count) \(count == 1 ? "list" : "lists")? This action cannot be undone.")
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

#Preview {
    MainView()
}
