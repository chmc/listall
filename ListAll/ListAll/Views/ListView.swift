import SwiftUI

struct ListView: View {
    @State var list: List
    @ObservedObject var mainViewModel: MainViewModel
    @StateObject var viewModel: ListViewModel
    @StateObject var sharingService = SharingService()
    @StateObject var tooltipManager = TooltipManager.shared
    @Environment(\.presentationMode) var presentationMode
    @State var editMode: EditMode = .inactive
    @State var showingCreateItem = false
    @State var showingEditItem = false
    @State var showingEditList = false
    @State var selectedItem: Item?
    @State var showingShareFormatPicker = false
    @State var showingShareSheet = false
    @State var selectedShareFormat: ShareFormat = .plainText
    @State var shareOptions: ShareOptions = .default
    @State var shareFileURL: URL?
    @State var shareItems: [Any] = []
    @State var showingDeleteConfirmation = false
    @State var showingMoveDestinationPicker = false
    @State var showingCopyDestinationPicker = false
    @State var showingMoveConfirmation = false
    @State var showingCopyConfirmation = false
    @State var selectedDestinationList: List?
    @AppStorage(Constants.UserDefaultsKeys.addButtonPosition) var addButtonPositionRaw: String = Constants.AddButtonPosition.right.rawValue
    @Environment(\.horizontalSizeClass) var horizontalSizeClass

    var addButtonPosition: Constants.AddButtonPosition {
        Constants.AddButtonPosition(rawValue: addButtonPositionRaw) ?? .right
    }

    var isRegularWidth: Bool {
        horizontalSizeClass == .regular
    }

    /// Use fullScreenCover instead of sheet in screenshot mode to avoid dark dimming bands
    var isScreenshotMode: Bool {
        ProcessInfo.processInfo.arguments.contains("UITEST_SCREENSHOT_MODE")
    }

    // Computed property for edit mode binding to simplify type-checking
    private var editModeBinding: Binding<EditMode> {
        if viewModel.currentSortOption == .orderNumber && viewModel.isInSelectionMode {
            return .constant(.active)
        } else {
            return $editMode
        }
    }

    init(list: List, mainViewModel: MainViewModel) {
        self.list = list
        self.mainViewModel = mainViewModel
        self._viewModel = StateObject(wrappedValue: ListViewModel(list: list))
    }

    private var itemsList: some View {
        SwiftUI.List {
            // Header section
            Section {
                editableListNameHeader
                    .listRowInsets(EdgeInsets())
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)

                HStack {
                    Text("\(viewModel.activeItems.count)/\(viewModel.items.count) items")
                        .font(Theme.Typography.caption)
                        .foregroundColor(Theme.Colors.secondary)
                        .numericContentTransition()

                    // Watch sync indicator (subtle)
                    if viewModel.isSyncingFromWatch {
                        HStack(spacing: 4) {
                            Image(systemName: "applewatch")
                                .font(.system(size: 10))
                            Text("syncing...")
                                .font(.caption2)
                        }
                        .foregroundColor(.secondary)
                        .transition(.opacity)
                    }

                    Spacer()
                }
                .listRowInsets(EdgeInsets(top: 4, leading: Theme.Spacing.md, bottom: Theme.Spacing.sm, trailing: Theme.Spacing.md))
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)

                filterPillsView
                    .listRowInsets(EdgeInsets(top: 0, leading: Theme.Spacing.md, bottom: Theme.Spacing.sm, trailing: Theme.Spacing.md))
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
            }
            .listSectionSeparator(.hidden)

            // Items section
            Section {
                ForEach(viewModel.filteredItems) { item in
                    ItemRowView(
                        item: item,
                        viewModel: viewModel,
                        onToggle: {
                            viewModel.toggleItemCrossedOut(item)
                        },
                        onEdit: {
                            selectedItem = item
                            showingEditItem = true
                        },
                        onDuplicate: {
                            viewModel.duplicateItem(item)
                        },
                        onDelete: {
                            viewModel.deleteItem(item)
                        }
                    )
                    .listRowInsets(EdgeInsets(top: 2, leading: 14, bottom: 2, trailing: 14))
                    .listRowSeparator(.hidden)
                    .listRowBackground(Color.clear)
                }
                .onDelete(perform: viewModel.isInSelectionMode ? nil : deleteItems)
                .onMove(perform: viewModel.currentSortOption == .orderNumber ? viewModel.moveItems : nil)
            }
        }
        .listStyle(.plain)
        .environment(\.editMode, editModeBinding)
        .refreshable {
            viewModel.loadItems()
        }
    }

    var body: some View {
        ZStack {
            if viewModel.isLoading {
                ProgressView("Loading items...")
            } else if viewModel.filteredItems.isEmpty {
                VStack(spacing: 0) {
                    editableListNameHeader

                    HStack {
                        Text("\(viewModel.activeItems.count)/\(viewModel.items.count) items")
                            .font(Theme.Typography.caption)
                            .foregroundColor(Theme.Colors.secondary)
                            .numericContentTransition()
                        Spacer()
                    }
                    .padding(.horizontal, Theme.Spacing.md)
                    .padding(.top, 4)
                    .padding(.bottom, Theme.Spacing.sm)

                    filterPillsView
                        .padding(.horizontal, Theme.Spacing.md)
                        .padding(.bottom, Theme.Spacing.sm)

                    ItemsEmptyStateView(
                        hasItems: !viewModel.items.isEmpty,
                        onAddItem: {
                            showingCreateItem = true
                        }
                    )
                    .padding(.top, 40)
                }
            } else {
                itemsList
            }

            // Undo Complete Banner
            if viewModel.showUndoButton, let item = viewModel.recentlyCompletedItem {
                VStack {
                    Spacer()
                    UndoBanner(
                        itemName: item.displayTitle,
                        onUndo: {
                            viewModel.undoComplete()
                        },
                        onDismiss: {
                            viewModel.hideUndoButton()
                        }
                    )
                    .padding(.horizontal, Theme.Spacing.md)
                    .padding(.bottom, Theme.Spacing.md)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .animation(Theme.Animation.spring, value: viewModel.showUndoButton)
                }
            }

            // Undo Delete Banner
            if viewModel.showDeleteUndoButton, let item = viewModel.recentlyDeletedItem {
                VStack {
                    Spacer()
                    DeleteUndoBanner(
                        itemName: item.displayTitle,
                        onUndo: {
                            viewModel.undoDeleteItem()
                        },
                        onDismiss: {
                            viewModel.hideDeleteUndoButton()
                        }
                    )
                    .padding(.horizontal, Theme.Spacing.md)
                    .padding(.bottom, Theme.Spacing.md)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .animation(Theme.Animation.spring, value: viewModel.showDeleteUndoButton)
                }
            }

            // Add Item Button (floating above tab bar) - only show when list has items
            // On iPad (regular width), the Add Item button is in the toolbar instead
            if !viewModel.items.isEmpty && !isRegularWidth {
                VStack {
                    Spacer()
                    HStack(spacing: 0) {
                        if addButtonPosition == .left {
                            addItemButton
                                .padding(.leading, Theme.Spacing.lg)
                            Spacer()
                        } else {
                            Spacer()
                            addItemButton
                                .padding(.trailing, Theme.Spacing.lg)
                        }
                    }
                    .padding(.bottom, (viewModel.showUndoButton || viewModel.showDeleteUndoButton) ? 130 : 65)
                }
            }
        }
        .searchable(text: $viewModel.searchText, placement: .navigationBarDrawer(displayMode: .automatic), prompt: "Search items")
        .navigationBarTitleDisplayMode(.inline)
        .navigationTitle(viewModel.isInSelectionMode ? "\(viewModel.selectedItems.count) Selected" : "")
        .toolbar {
            listViewToolbar
        }
        .background(sheetsAndAlerts)
        .onAppear {
            viewModel.loadItems()
            HandoffService.shared.startViewingListActivity(list: list)
            let itemCount = viewModel.items.count
            if itemCount >= 5 {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    tooltipManager.showIfNeeded(.searchFunctionality)
                }
            }
            if itemCount >= 7 {
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                    tooltipManager.showIfNeeded(.sortFilterOptions)
                }
            }
            if itemCount >= 3 {
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                    tooltipManager.showIfNeeded(.swipeActions)
                }
            }
        }
        .onDisappear {
            mainViewModel.loadLists()
        }
        .onChange(of: showingCreateItem) { _ in
            if !showingCreateItem {
                viewModel.loadItems()
            }
        }
        .onChange(of: showingEditItem) { _ in
            if !showingEditItem {
                selectedItem = nil
                viewModel.loadItems()
            }
        }
        .onChange(of: showingEditList) { _ in
            if !showingEditList {
                mainViewModel.loadLists()
                if let updatedList = mainViewModel.lists.first(where: { $0.id == list.id }) {
                    list = updatedList
                }
            }
        }
    }

    func handleShare(format: ShareFormat, options: ShareOptions) {
        DispatchQueue.global(qos: .userInitiated).async { [weak sharingService] in
            guard let shareResult = sharingService?.shareList(list, format: format, options: options) else {
                return
            }

            DispatchQueue.main.async {
                if let fileURL = shareResult.content as? URL {
                    let filename = shareResult.fileName ?? "export.json"
                    let itemSource = FileActivityItemSource(fileURL: fileURL, filename: filename)
                    self.shareFileURL = nil
                    self.shareItems = [itemSource]
                } else if let text = shareResult.content as? String {
                    let itemSource = TextActivityItemSource(text: text, subject: list.name)
                    self.shareFileURL = nil
                    self.shareItems = [itemSource]
                }

                self.showingShareSheet = true
            }
        }
    }

    private func deleteItems(offsets: IndexSet) {
        for index in offsets {
            let item = viewModel.filteredItems[index]
            viewModel.deleteItem(item)
        }
    }

    var editableListNameHeader: some View {
        Button(action: {
            showingEditList = true
        }) {
            HStack(spacing: Theme.Spacing.sm) {
                Text(list.name)
                    .font(Theme.Typography.headline)
                    .foregroundColor(.primary)

                Image(systemName: "pencil")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.primary)

                Spacer()
            }
            .padding(.horizontal, Theme.Spacing.md)
            .padding(.vertical, 12)
            .background(Color(UIColor.secondarySystemGroupedBackground))
            .cornerRadius(Theme.CornerRadius.md)
        }
        .buttonStyle(EditableHeaderButtonStyle())
        .accessibilityLabel("Edit list name: \(list.name)")
        .accessibilityHint("Double tap to edit")
        .padding(.horizontal, Theme.Spacing.md)
        .padding(.top, Theme.Spacing.sm)
        .padding(.bottom, 4)
    }

    // MARK: - Inline Filter Pills

    private static let inlineFilterOptions: [(label: String, option: ItemFilterOption)] = [
        ("All", .all),
        ("Active", .active),
        ("Done", .completed)
    ]

    private var filterPillsView: some View {
        HStack(spacing: Theme.Spacing.sm) {
            ForEach(Self.inlineFilterOptions, id: \.option) { pill in
                let isSelected = viewModel.currentFilterOption == pill.option
                Button {
                    viewModel.updateFilterOption(pill.option)
                } label: {
                    Text(pill.label)
                        .font(.system(size: 13, weight: isSelected ? .semibold : .regular))
                        .foregroundColor(isSelected ? .white : .secondary)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 6)
                        .background(
                            Capsule()
                                .fill(isSelected ? Theme.Colors.primary : Color.clear)
                        )
                        .overlay(
                            Capsule()
                                .strokeBorder(isSelected ? Color.clear : Color.secondary.opacity(0.3), lineWidth: 1)
                        )
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(isSelected ? .isSelected : [])
            }
            Spacer()
        }
    }

    private var addItemButton: some View {
        Button(action: {
            showingCreateItem = true
        }) {
            HStack(spacing: 6) {
                Image(systemName: Constants.UI.addIcon)
                    .font(.system(size: 18, weight: .semibold))
                Text(String(localized: "Item"))
                    .font(.system(size: 16, weight: .semibold))
            }
            .foregroundColor(.primary)
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(
                Capsule()
                    .fill(Color(UIColor.tertiarySystemGroupedBackground))
                    .shadow(color: Color.black.opacity(0.15), radius: 6, x: 0, y: 3)
            )
            .overlay(
                Capsule()
                    .strokeBorder(Color(UIColor.separator).opacity(0.5), lineWidth: 0.5)
            )
        }
        .hoverEffect(.lift)
        .accessibilityLabel("Add new item")
        .accessibilityIdentifier("AddItemButton")
        .keyboardShortcut("n", modifiers: [.command, .shift])
    }
}

#Preview {
    NavigationView {
        ListView(list: List(name: "Sample List"), mainViewModel: MainViewModel())
    }
}
