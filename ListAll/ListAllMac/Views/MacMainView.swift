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

    @State private var selectedList: List?
    @State private var columnVisibility: NavigationSplitViewVisibility = .all

    // Menu command observers
    @State private var showingCreateListSheet = false
    @State private var showingArchivedLists = false

    var body: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
            // Sidebar with lists
            MacSidebarView(
                lists: displayedLists,
                selectedList: $selectedList,
                showingArchivedLists: $showingArchivedLists,
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
    }

    // MARK: - Computed Properties

    private var displayedLists: [List] {
        if showingArchivedLists {
            return dataManager.loadArchivedLists()
        } else {
            return dataManager.lists.filter { !$0.isArchived }
                .sorted { $0.orderNumber < $1.orderNumber }
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
    let lists: [List]
    @Binding var selectedList: List?
    @Binding var showingArchivedLists: Bool
    let onCreateList: () -> Void
    let onDeleteList: (List) -> Void

    var body: some View {
        SwiftUI.List(selection: $selectedList) {
            Section {
                ForEach(lists) { list in
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

// MARK: - List Detail View (Placeholder)

private struct MacListDetailView: View {
    let list: List

    var body: some View {
        VStack {
            Text(list.name)
                .font(.largeTitle)
                .padding()

            if list.items.isEmpty {
                Text("No items in this list")
                    .foregroundColor(.secondary)
                    .padding()
            } else {
                SwiftUI.List(list.sortedItems) { item in
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
        .navigationTitle(list.name)
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
