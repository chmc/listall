//
//  MacDestinationListPickerSheet.swift
//  ListAllMac
//
//  Sheet for selecting a destination list when moving or copying items.
//  This is the macOS equivalent of iOS DestinationListPickerView.
//

import SwiftUI

/// Action type for destination list picker (move or copy)
enum MacDestinationListAction {
    case move
    case copy

    var title: String {
        switch self {
        case .move: return String(localized: "Move Items")
        case .copy: return String(localized: "Copy Items")
        }
    }

    var verb: String {
        switch self {
        case .move: return String(localized: "move")
        case .copy: return String(localized: "copy")
        }
    }

    var systemImage: String {
        switch self {
        case .move: return "arrow.right.square"
        case .copy: return "doc.on.doc"
        }
    }
}

/// Sheet view for selecting a destination list when moving or copying items
struct MacDestinationListPickerSheet: View {
    let action: MacDestinationListAction
    let itemCount: Int
    let currentListId: UUID
    let onSelect: (List?) -> Void
    let onCancel: () -> Void

    @EnvironmentObject var dataManager: DataManager

    // State for creating new list inline
    @State private var showingCreateNewList = false
    @State private var newListName = ""
    @State private var validationError: String?
    @FocusState private var isTextFieldFocused: Bool

    /// Available lists (excluding the current list)
    private var availableLists: [List] {
        dataManager.lists.filter { $0.id != currentListId && !$0.isArchived }
            .sorted { $0.orderNumber < $1.orderNumber }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            headerView

            Divider()

            // List content
            if availableLists.isEmpty {
                emptyStateView
            } else {
                listSelectionView
            }

            Divider()

            // Footer with create new list and cancel buttons
            footerView
        }
        .frame(width: 400, height: 450)
        .sheet(isPresented: $showingCreateNewList) {
            createNewListSheet
        }
    }

    // MARK: - Header View

    @ViewBuilder
    private var headerView: some View {
        VStack(spacing: 8) {
            Image(systemName: action.systemImage)
                .font(.system(size: 32))
                .foregroundColor(.accentColor)
                .padding(.top, 20)

            Text(action.title)
                .font(.title2)
                .fontWeight(.semibold)

            Text("Select a destination list to \(action.verb) \(itemCount) item(s)")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 20)
                .padding(.bottom, 16)
        }
    }

    // MARK: - Empty State View

    @ViewBuilder
    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Spacer()

            Image(systemName: "tray")
                .font(.system(size: 48))
                .foregroundColor(.secondary)

            Text("No Other Lists")
                .font(.title3)
                .fontWeight(.medium)

            Text("Create a new list to \(action.verb) items to")
                .font(.body)
                .foregroundColor(.secondary)

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - List Selection View

    @ViewBuilder
    private var listSelectionView: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                ForEach(availableLists) { list in
                    Button(action: {
                        onSelect(list)
                    }) {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(list.name)
                                    .font(.body)
                                    .foregroundColor(.primary)

                                let activeCount = list.items.filter { !$0.isCrossedOut }.count
                                let totalCount = list.items.count
                                if activeCount < totalCount {
                                    Text("\(activeCount) active (\(totalCount) total)")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                } else {
                                    Text("\(totalCount) items")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }

                            Spacer()

                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .background(Color.primary.opacity(0.001)) // For hover detection
                    .accessibilityIdentifier("DestinationList_\(list.name)")

                    if list.id != availableLists.last?.id {
                        Divider()
                            .padding(.leading, 16)
                    }
                }
            }
        }
        .frame(maxHeight: .infinity)
    }

    // MARK: - Footer View

    @ViewBuilder
    private var footerView: some View {
        VStack(spacing: 12) {
            // Create new list button
            Button(action: {
                showingCreateNewList = true
            }) {
                HStack {
                    Image(systemName: "plus.circle.fill")
                        .font(.body)
                    Text("Create New List")
                        .font(.body)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
            }
            .buttonStyle(.borderedProminent)
            .padding(.horizontal, 16)
            .padding(.top, 12)

            // Cancel button
            Button(action: onCancel) {
                Text("Cancel")
                    .font(.body)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
            }
            .buttonStyle(.bordered)
            .padding(.horizontal, 16)
            .padding(.bottom, 16)
            .keyboardShortcut(.escape)
        }
    }

    // MARK: - Create New List Sheet

    @ViewBuilder
    private var createNewListSheet: some View {
        VStack(spacing: 20) {
            Text("Create New List")
                .font(.title2)
                .fontWeight(.semibold)
                .accessibilityAddTraits(.isHeader)

            Text("Create a new list to \(action.verb) items to")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)

            VStack(alignment: .leading, spacing: 8) {
                Text("List Name")
                    .font(.caption)
                    .foregroundColor(.secondary)

                TextField("Enter list name", text: $newListName)
                    .textFieldStyle(.roundedBorder)
                    .focused($isTextFieldFocused)
                    .onSubmit {
                        createNewList()
                    }
            }
            .frame(width: 300)

            if let error = validationError {
                Text(error)
                    .font(.caption)
                    .foregroundColor(.red)
            }

            HStack(spacing: 16) {
                Button("Cancel") {
                    newListName = ""
                    validationError = nil
                    showingCreateNewList = false
                }
                .keyboardShortcut(.escape)

                Button("Create") {
                    createNewList()
                }
                .keyboardShortcut(.return)
                .buttonStyle(.borderedProminent)
                .disabled(newListName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .padding(30)
        .frame(minWidth: 400)
        .onAppear {
            // Focus the text field when sheet appears
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                isTextFieldFocused = true
            }
        }
    }

    // MARK: - Actions

    private func createNewList() {
        let trimmedName = newListName.trimmingCharacters(in: .whitespacesAndNewlines)

        // Validate
        if trimmedName.isEmpty {
            validationError = String(localized: "Please enter a list name")
            return
        }

        if trimmedName.count > 100 {
            validationError = String(localized: "List name must be 100 characters or less")
            return
        }

        // Create the new list
        let newList = List(name: trimmedName)
        dataManager.addList(newList)
        dataManager.loadData()

        // Find the created list and select it
        if let createdList = dataManager.lists.first(where: { $0.name == trimmedName }) {
            // Reset state
            newListName = ""
            validationError = nil
            showingCreateNewList = false

            // Select the new list
            onSelect(createdList)
        }
    }
}

#Preview {
    MacDestinationListPickerSheet(
        action: .move,
        itemCount: 3,
        currentListId: UUID(),
        onSelect: { list in
            print("Selected list: \(list?.name ?? "nil")")
        },
        onCancel: {
            print("Cancelled")
        }
    )
    .environmentObject(DataManager.shared)
}
