import SwiftUI

struct MainView: View {
    @StateObject private var viewModel = MainViewModel()
    @StateObject private var cloudKitService = CloudKitService()
    @StateObject private var conflictManager = SyncConflictManager(cloudKitService: CloudKitService())
    @State private var selectedTab = 0
    @State private var showingCreateList = false
    @State private var editMode: EditMode = .inactive
    @State private var showingDeleteConfirmation = false
    
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
                    }
                    
                    // Main Content
                    if viewModel.isLoading {
                        ProgressView("Loading lists...")
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
                            }
                            .onMove(perform: viewModel.moveList)
                        }
                        .environment(\.editMode, $editMode)
                    }
                }
                .navigationTitle("Lists")
                .toolbar {
                    ToolbarItem(placement: .navigationBarLeading) {
                        HStack {
                            if !viewModel.isInSelectionMode {
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
                                    Button("Edit") {
                                        withAnimation {
                                            viewModel.enterSelectionMode()
                                            editMode = .active
                                        }
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
        .sheet(isPresented: $showingCreateList) {
            CreateListView(mainViewModel: viewModel)
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
}

#Preview {
    MainView()
}
