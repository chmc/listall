//
//  MacListDetailView+ItemsList.swift
//  ListAllMac
//
//  Items list view with row construction and drag-drop support.
//

import SwiftUI

extension MacListDetailView {

    // MARK: - Items List View

    /// Whether drag-to-reorder is enabled (only when sorted by orderNumber)
    var canReorderItems: Bool {
        viewModel.currentSortOption == .orderNumber
    }

    /// The items to display, using ViewModel's filtered list
    var displayedItems: [Item] {
        viewModel.filteredItems
    }

    var itemsListView: some View {
        itemsKeyboardHandlers(
            SwiftUI.List {
                ForEach(displayedItems) { item in
                    makeItemRow(item: item)
                        .modifier(ConditionalDraggable(item: item, isEnabled: !isCurrentListArchived))
                        // MARK: Keyboard Navigation (Task 11.1)
                        .focusable(interactions: .activate)
                        .focused($focusedItemID, equals: item.id)
                        // MARK: Cmd+Click and Shift+Click Multi-Select (Task 12.1)
                        .onModifierClick(
                            command: {
                                guard !isCurrentListArchived else { return }
                                viewModel.toggleSelection(for: item.id)
                            },
                            shift: {
                                guard !isCurrentListArchived else { return }
                                viewModel.selectRange(to: item.id)
                            }
                        )
                        .accessibilityIdentifier("ItemRow_\(item.title)")
                        .listRowSeparator(.hidden)
                        .listRowInsets(EdgeInsets(top: 2, leading: 10, bottom: 2, trailing: 10))
                }
                .onMove(perform: isCurrentListArchived ? nil : handleMoveItem)
            }
            .listStyle(.inset)
            .dropDestination(for: ItemTransferData.self) { droppedItems, _ in
                guard !isCurrentListArchived else { return false }
                return handleItemDrop(droppedItems)
            }
            .accessibilityIdentifier("ItemsList")
        )
    }

    func handleMoveItem(from source: IndexSet, to destination: Int) {
        guard canReorderItems else { return }
        viewModel.moveItems(from: source, to: destination)
    }

    @ViewBuilder
    func makeItemRow(item: Item) -> some View {
        MacItemRowView(
            item: item,
            isInSelectionMode: viewModel.isInSelectionMode,
            isSelected: viewModel.selectedItems.contains(item.id),
            isArchivedList: isCurrentListArchived,
            onToggle: { toggleItem(item) },
            onEdit: {
                print("🎯 MacListDetailView: Forwarding edit request to MacMainView for item: \(item.title)")
                onEditItem(item)
            },
            onDuplicate: { viewModel.duplicateItem(item) },
            onDelete: { deleteItem(item) },
            onQuickLook: { showQuickLook(for: item) },
            onToggleSelection: { viewModel.toggleSelection(for: item.id) }
        )
    }
}
