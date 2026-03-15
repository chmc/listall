import SwiftUI

// MARK: - MainView Content Sub-Views

extension MainView {

    /// Main list content for iPhone: loading state, empty states, and the list of lists
    @ViewBuilder
    var mainListContent: some View {
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
    }

    /// Binding that drives programmatic navigation for auto-opening newly created list (iPhone only)
    /// iPad uses NavigationSplitView detail column instead
    var isNavigatingToList: Binding<Bool> {
        Binding(
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
    }

    /// Navigation destination view for the selected list
    @ViewBuilder
    var navigationDestinationView: some View {
        if let list = viewModel.selectedListForNavigation {
            ListView(list: list, mainViewModel: viewModel)
                .onDisappear {
                    // Only clear stored list ID when user explicitly navigates back
                    // Don't clear on system-initiated view hierarchy changes
                    if viewModel.selectedListForNavigation == nil {
                        selectedListIdString = nil
                    }
                }
        }
    }

    // MARK: - iPad Sidebar Content

    /// Sidebar content for iPad NavigationSplitView layout
    @ViewBuilder
    var sidebarContent: some View {
        if viewModel.isLoading {
            ProgressView("Loading lists...")
                .padding(.top, 16)
        } else if viewModel.displayedLists.isEmpty {
            if viewModel.showingArchivedLists {
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
                // Compact empty state for iPad sidebar
                VStack(spacing: Theme.Spacing.md) {
                    Image(systemName: Constants.UI.listIcon)
                        .font(.system(size: 50))
                        .foregroundColor(Theme.Colors.secondary)
                    Text(String(localized: "No Lists"))
                        .font(Theme.Typography.title)
                    Text(String(localized: "Tap + to create your first list"))
                        .font(Theme.Typography.body)
                        .emptyStateStyle()
                }
                .padding(.top, 40)
            }
        } else {
            SwiftUI.List {
                Section {
                    ForEach(viewModel.displayedLists) { list in
                        // ListRowView already handles its own tap (sets selectedListForNavigation)
                        ListRowView(list: list, mainViewModel: viewModel)
                            .listRowBackground(Color.clear)
                            .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0))
                    }
                    .onDelete { indexSet in
                        for index in indexSet {
                            let list = viewModel.displayedLists[index]
                            viewModel.archiveList(list)
                        }
                    }
                    .onMove(perform: viewModel.moveList)
                }

                // Settings row in sidebar (replaces bottom toolbar on iPad)
                Section {
                    Button(action: {
                        viewModel.selectedListForNavigation = nil
                        showingSettingsInDetail = true
                    }) {
                        Label("Settings", systemImage: "gear")
                    }
                    .accessibilityIdentifier("SidebarSettingsButton")
                    .listRowBackground(
                        showingSettingsInDetail
                            ? Color.accentColor.opacity(0.15)
                            : Color.clear
                    )
                }
            }
            .environment(\.editMode, $editMode)
            .listStyle(.sidebar)
            .id(viewModel.listsReorderTrigger)
            .refreshable {
                await cloudKitService.sync()
                viewModel.manualSync()
            }
        }
    }

    /// Detail column for iPad NavigationSplitView
    @ViewBuilder
    var detailContent: some View {
        if showingSettingsInDetail {
            SettingsView()
        } else if let list = viewModel.selectedListForNavigation {
            if list.isArchived {
                ArchivedListView(list: list, mainViewModel: viewModel)
            } else {
                ListView(list: list, mainViewModel: viewModel)
                    .id(list.id)  // Force recreation when selection changes
            }
        } else {
            if viewModel.displayedLists.isEmpty && !viewModel.showingArchivedLists {
                ListsEmptyStateView(
                    onCreateSampleList: { template in
                        let createdList = viewModel.createSampleList(from: template)
                        viewModel.selectedListForNavigation = createdList
                    },
                    onCreateCustomList: {
                        showingCreateList = true
                    }
                )
            } else {
                // No list selected — show branded empty state
                VStack(spacing: Theme.Spacing.lg) {
                    // Icon in circle
                    Image(systemName: "line.3.horizontal")
                        .font(.system(size: 32, weight: .medium))
                        .foregroundColor(.secondary.opacity(0.4))
                        .frame(width: 64, height: 64)
                        .background(
                            Circle()
                                .fill(Color(.secondarySystemFill))
                        )

                    Text(String(localized: "Select a List"))
                        .font(Theme.Typography.title)
                        .fontWeight(.bold)

                    Text(String(localized: "Choose a list from the sidebar to view its items."))
                        .font(Theme.Typography.body)
                        .foregroundColor(Theme.Colors.secondary)
                        .multilineTextAlignment(.center)

                    Button(action: {
                        showingCreateList = true
                    }) {
                        Text(String(localized: "Create New List"))
                            .font(Theme.Typography.headline)
                            .foregroundColor(.white)
                            .padding(.horizontal, 24)
                            .padding(.vertical, 12)
                            .background(Theme.Colors.brandGradient)
                            .cornerRadius(Theme.CornerRadius.md)
                    }
                }
                .padding(.horizontal, 40)
            }
        }
    }
}
