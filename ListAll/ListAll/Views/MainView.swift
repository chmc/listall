import SwiftUI

struct MainView: View {
    @StateObject private var viewModel = MainViewModel()
    @StateObject private var cloudKitService = CloudKitService()
    @StateObject private var conflictManager = SyncConflictManager(cloudKitService: CloudKitService())
    
    var body: some View {
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
                    VStack(spacing: 20) {
                        Image(systemName: "list.bullet")
                            .font(.system(size: 60))
                            .foregroundColor(.secondary)
                        
                        Text("No Lists Yet")
                            .font(.title2)
                            .fontWeight(.medium)
                        
                        Text("Create your first list to get started")
                            .font(.body)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding()
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
                        Image(systemName: "arrow.clockwise")
                    }
                    .disabled(cloudKitService.isSyncing)
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        // TODO: Add create list functionality
                    }) {
                        Image(systemName: "plus")
                    }
                }
            }
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
