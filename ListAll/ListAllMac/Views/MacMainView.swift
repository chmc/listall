//
//  MacMainView.swift
//  ListAllMac
//
//  Main view for macOS app using NavigationSplitView.
//

import SwiftUI
import CoreData

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
        }
        .onDisappear {
            stopSyncPolling()
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
                    .contextMenu {
                        Button("Delete") {
                            onDeleteList(list)
                        }
                    }
                }
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
}

// MARK: - List Detail View

private struct MacListDetailView: View {
    let list: List  // Original list from selection (may become stale)
    @EnvironmentObject var dataManager: DataManager

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
    }

    /// Display name from current data (falls back to original if list not found)
    private var displayName: String {
        currentList?.name ?? list.name
    }

    var body: some View {
        VStack {
            Text(displayName)
                .font(.largeTitle)
                .padding()

            if items.isEmpty {
                Text("No items in this list")
                    .foregroundColor(.secondary)
                    .padding()
            } else {
                SwiftUI.List(items) { item in
                    HStack {
                        Image(systemName: item.isCrossedOut ? "checkmark.circle.fill" : "circle")
                            .foregroundColor(item.isCrossedOut ? .green : .secondary)
                        Text(item.title)
                            .strikethrough(item.isCrossedOut)
                        if item.quantity > 1 {
                            Text("x\(item.quantity)")
                                .foregroundColor(.secondary)
                                .font(.caption)
                        }
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .navigationTitle(displayName)
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
