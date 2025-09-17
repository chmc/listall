import SwiftUI

struct MainView: View {
    @StateObject private var viewModel = MainViewModel()
    @StateObject private var cloudKitService = CloudKitService()
    @StateObject private var conflictManager = SyncConflictManager(cloudKitService: CloudKitService())
    @State private var selectedTab = 0
    
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
                                ListRowView(list: list)
                            }
                        }
                    }
                }
                .navigationTitle("Lists")
                .toolbar {
                    ToolbarItem(placement: .navigationBarLeading) {
                        Button(action: {
                            Task {
                                await cloudKitService.sync()
                            }
                        }) {
                            Image(systemName: Constants.UI.syncIcon)
                        }
                        .disabled(cloudKitService.isSyncing)
                    }
                    
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button(action: {
                            // TODO: Add create list functionality
                        }) {
                            Image(systemName: Constants.UI.addIcon)
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
    }
}

#Preview {
    MainView()
}
