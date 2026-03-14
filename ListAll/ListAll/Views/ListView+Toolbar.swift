import SwiftUI

// MARK: - ListView Toolbar

extension ListView {
    @ToolbarContentBuilder
    var listViewToolbar: some ToolbarContent {
        ToolbarItem(placement: .navigationBarLeading) {
            if !viewModel.items.isEmpty && viewModel.isInSelectionMode {
                Button("Cancel") {
                    withAnimation {
                        viewModel.exitSelectionMode()
                    }
                }
            }
        }

        ToolbarItem(placement: .navigationBarTrailing) {
            if !viewModel.items.isEmpty {
                HStack(spacing: Theme.Spacing.md) {
                    if viewModel.isInSelectionMode {
                        selectionModeMenu
                    } else {
                        normalModeToolbarButtons
                    }
                }
                .padding(.horizontal, Theme.Spacing.sm)
            }
        }

        // Add Item toolbar button for iPad (regular width)
        ToolbarItem(placement: .navigationBarTrailing) {
            if isRegularWidth && !viewModel.items.isEmpty && !viewModel.isInSelectionMode {
                Button(action: {
                    showingCreateItem = true
                }) {
                    Label("Add Item", systemImage: "plus")
                }
                .accessibilityIdentifier("AddItemToolbarButton")
                .keyboardShortcut("n", modifiers: [.command, .shift])
            }
        }
    }

    // MARK: - Selection Mode Menu

    @ViewBuilder
    private var selectionModeMenu: some View {
        Menu {
            Button(action: {
                viewModel.selectAll()
            }) {
                Label("Select All", systemImage: "checkmark.circle")
            }

            Button(action: {
                viewModel.deselectAll()
            }) {
                Label("Deselect All", systemImage: "circle")
            }
            .disabled(viewModel.selectedItems.isEmpty)

            Divider()

            Button(action: {
                showingMoveDestinationPicker = true
            }) {
                Label("Move Items", systemImage: "arrow.right.square")
            }
            .disabled(viewModel.selectedItems.isEmpty)

            Button(action: {
                showingCopyDestinationPicker = true
            }) {
                Label("Copy Items", systemImage: "doc.on.doc")
            }
            .disabled(viewModel.selectedItems.isEmpty)

            Divider()

            Button(role: .destructive, action: {
                showingDeleteConfirmation = true
            }) {
                Label("Delete Items", systemImage: "trash")
            }
            .disabled(viewModel.selectedItems.isEmpty)
        } label: {
            Image(systemName: "ellipsis.circle")
                .monochromeSymbol()
                .foregroundColor(.primary)
        }
    }

    // MARK: - Normal Mode Toolbar Buttons

    @ViewBuilder
    private var normalModeToolbarButtons: some View {
        Button(action: {
            showingShareFormatPicker = true
        }) {
            Image(systemName: "square.and.arrow.up")
                .monochromeSymbol()
                .foregroundColor(.primary)
        }
        .hoverEffect(.highlight)
        .help("Share list")

        Button(action: {
            viewModel.showingOrganizationOptions = true
        }) {
            Image(systemName: "arrow.up.arrow.down")
                .monochromeSymbol()
                .foregroundColor(.primary)
        }
        .accessibilityIdentifier("SortFilterButton")
        .hoverEffect(.highlight)
        .help(String(localized: "Sort and filter options"))

        Button(action: {
            viewModel.toggleShowCrossedOutItems()
        }) {
            Image(systemName: viewModel.showCrossedOutItems ? "eye" : "eye.slash")
                .monochromeSymbol()
                .foregroundColor(viewModel.showCrossedOutItems ? .primary : .secondary)
        }
        .hoverEffect(.highlight)
        .help(viewModel.showCrossedOutItems ? "Hide crossed out items" : "Show crossed out items")

        Button(action: {
            withAnimation {
                viewModel.enterSelectionMode()
            }
        }) {
            Image(systemName: "pencil")
                .monochromeSymbol()
        }
        .hoverEffect(.highlight)
        .help("Edit items")
    }
}
