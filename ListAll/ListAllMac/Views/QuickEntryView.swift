//
//  QuickEntryView.swift
//  ListAllMac
//
//  Created for Task 12.10: Add Quick Entry Window
//  Things 3-style Quick Entry feature for power users.
//

import SwiftUI

// MARK: - QuickEntryViewModel

/// ViewModel for the Quick Entry window.
/// Manages the state for quickly adding items to lists.
final class QuickEntryViewModel: ObservableObject {

    // MARK: - Published Properties

    /// The title of the item being created
    @Published var itemTitle: String = ""

    /// The selected list ID to add the item to
    @Published var selectedListId: UUID?

    /// Available lists to choose from
    @Published var lists: [ListAll.List] = []

    // MARK: - Dependencies

    /// DataManager for persisting items (uses protocol for testability)
    private let dataManager: any DataManaging

    // MARK: - Computed Properties

    /// Whether the current state allows saving
    var canSave: Bool {
        let trimmedTitle = itemTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        return !trimmedTitle.isEmpty && selectedListId != nil
    }

    // MARK: - Initialization

    /// Creates a new QuickEntryViewModel
    /// - Parameter dataManager: The data manager for persistence (defaults to shared instance)
    init(dataManager: any DataManaging = DataManager.shared) {
        self.dataManager = dataManager
        loadLists()
        selectDefaultList()
    }

    // MARK: - Public Methods

    /// Saves the current item to the selected list
    /// - Returns: True if the item was saved successfully, false otherwise
    @discardableResult
    func saveItem() -> Bool {
        let trimmedTitle = itemTitle.trimmingCharacters(in: .whitespacesAndNewlines)

        // Validate title
        guard !trimmedTitle.isEmpty else {
            print("QuickEntry: Cannot save - empty title")
            return false
        }

        // Validate list selection
        guard let listId = selectedListId else {
            print("QuickEntry: Cannot save - no list selected")
            return false
        }

        // Get existing items to determine order number
        let existingItems = dataManager.getItems(forListId: listId)
        let maxOrderNumber = existingItems.map { $0.orderNumber }.max() ?? -1

        // Create and add the item
        var newItem = Item(title: trimmedTitle, listId: listId)
        newItem.orderNumber = maxOrderNumber + 1

        dataManager.addItem(newItem, to: listId)

        // Refresh the UI
        dataManager.loadData()

        print("QuickEntry: Added item '\(trimmedTitle)' to list")
        return true
    }

    /// Clears the current entry (resets for another item)
    func clear() {
        itemTitle = ""
    }

    /// Refreshes the lists from the data manager
    func refresh() {
        loadLists()
        // Keep current selection if still valid, otherwise select default
        if let currentId = selectedListId,
           !lists.contains(where: { $0.id == currentId }) {
            selectDefaultList()
        }
    }

    // MARK: - Private Methods

    /// Loads lists from the data manager
    private func loadLists() {
        dataManager.loadData()
        // Get only non-archived lists
        lists = dataManager.lists.filter { !$0.isArchived }
    }

    /// Selects a default list (first available list)
    private func selectDefaultList() {
        // Try to use the first available list
        // Future enhancement: remember last used list in UserDefaults
        if selectedListId == nil || !lists.contains(where: { $0.id == selectedListId }) {
            selectedListId = lists.first?.id
        }
    }
}

// MARK: - QuickEntryView

/// A minimal floating window for quickly adding items to lists.
/// Designed to be invoked via keyboard shortcut for power users.
struct QuickEntryView: View {

    // MARK: - Environment

    @Environment(\.dismiss) private var dismiss

    // MARK: - State

    @StateObject private var viewModel: QuickEntryViewModel
    @FocusState private var isTitleFocused: Bool

    // MARK: - Initialization

    /// Creates a QuickEntryView with the default shared DataManager
    init() {
        _viewModel = StateObject(wrappedValue: QuickEntryViewModel())
    }

    /// Creates a QuickEntryView with a custom DataManager (for testing)
    init(dataManager: any DataManaging) {
        _viewModel = StateObject(wrappedValue: QuickEntryViewModel(dataManager: dataManager))
    }

    // MARK: - Body

    var body: some View {
        VStack(spacing: 16) {
            // Header with close button
            HStack {
                Text("Quick Entry")
                    .font(.headline)
                    .foregroundColor(.secondary)

                Spacer()

                Button(action: { dismiss() }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                        .imageScale(.large)
                }
                .buttonStyle(.plain)
                .help("Close (Escape)")
                .accessibilityIdentifier("QuickEntryCloseButton")
            }

            // Item title text field
            TextField("Item title", text: $viewModel.itemTitle)
                .textFieldStyle(.plain)
                .font(.title2)
                .focused($isTitleFocused)
                .onSubmit {
                    saveAndDismiss()
                }
                .accessibilityIdentifier("QuickEntryTitleField")

            Divider()

            // Bottom row: List picker and Save button
            HStack {
                // List picker
                Picker("Add to:", selection: $viewModel.selectedListId) {
                    if viewModel.lists.isEmpty {
                        Text("No lists available")
                            .tag(nil as UUID?)
                    } else {
                        ForEach(viewModel.lists) { list in
                            Text(list.name)
                                .tag(list.id as UUID?)
                        }
                    }
                }
                .pickerStyle(.menu)
                .frame(maxWidth: 200)
                .accessibilityIdentifier("QuickEntryListPicker")

                Spacer()

                // Save button
                Button(action: saveAndDismiss) {
                    Text("Add Item")
                        .frame(minWidth: 80)
                }
                .keyboardShortcut(.return, modifiers: [])
                .disabled(!viewModel.canSave)
                .accessibilityIdentifier("QuickEntryAddButton")
            }
        }
        .padding(20)
        .frame(width: 500, height: 150)
        .background(VisualEffectBackground())
        .onAppear {
            // Focus the text field when the window appears
            isTitleFocused = true
            viewModel.refresh()
        }
        .onExitCommand {
            // Handle Escape key
            dismiss()
        }
        .accessibilityIdentifier("QuickEntryView")
    }

    // MARK: - Private Methods

    /// Saves the item and dismisses the window
    private func saveAndDismiss() {
        if viewModel.saveItem() {
            viewModel.clear()
            dismiss()
        }
    }
}

// MARK: - Visual Effect Background

/// A NSVisualEffectView wrapper for the frosted glass appearance
struct VisualEffectBackground: NSViewRepresentable {
    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = .hudWindow
        view.blendingMode = .behindWindow
        view.state = .active
        return view
    }

    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {}
}

// MARK: - Preview

#if DEBUG
struct QuickEntryView_Previews: PreviewProvider {
    static var previews: some View {
        QuickEntryView()
    }
}
#endif
