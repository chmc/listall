//
//  MacImportPreviewSheet.swift
//  ListAllMac
//
//  macOS-native import preview sheet showing summary of lists and items
//  to be imported, conflicts, and strategy info with confirm/cancel actions.
//

import SwiftUI

/// macOS-native import preview sheet
/// Shows summary of what will be imported before confirmation
struct MacImportPreviewSheet: View {
    let preview: ImportPreview
    @ObservedObject var viewModel: ImportViewModel

    /// Dismiss action for native sheet
    var onDismiss: (() -> Void)?

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            // Title
            Text("Import Preview")
                .font(.title2)
                .fontWeight(.bold)
                .accessibilityAddTraits(.isHeader)

            // Summary Section
            GroupBox {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Import Summary")
                        .font(.headline)
                        .foregroundColor(.secondary)

                    // Lists to create
                    if preview.listsToCreate > 0 {
                        HStack(spacing: 8) {
                            Image(systemName: "plus.circle.fill")
                                .foregroundColor(.green)
                                .accessibilityHidden(true)
                            if preview.listsToCreate == 1 {
                                Text("1 new list")
                            } else {
                                Text("\(preview.listsToCreate) new lists")
                            }
                            Spacer()
                        }
                        .accessibilityElement(children: .combine)
                    }

                    // Lists to update
                    if preview.listsToUpdate > 0 {
                        HStack(spacing: 8) {
                            Image(systemName: "arrow.triangle.2.circlepath")
                                .foregroundColor(.orange)
                                .accessibilityHidden(true)
                            if preview.listsToUpdate == 1 {
                                Text("1 list to update")
                            } else {
                                Text("\(preview.listsToUpdate) lists to update")
                            }
                            Spacer()
                        }
                        .accessibilityElement(children: .combine)
                    }

                    // Items to create
                    if preview.itemsToCreate > 0 {
                        HStack(spacing: 8) {
                            Image(systemName: "plus.circle.fill")
                                .foregroundColor(.green)
                                .accessibilityHidden(true)
                            if preview.itemsToCreate == 1 {
                                Text("1 new item")
                            } else {
                                Text("\(preview.itemsToCreate) new items")
                            }
                            Spacer()
                        }
                        .accessibilityElement(children: .combine)
                    }

                    // Items to update
                    if preview.itemsToUpdate > 0 {
                        HStack(spacing: 8) {
                            Image(systemName: "arrow.triangle.2.circlepath")
                                .foregroundColor(.orange)
                                .accessibilityHidden(true)
                            if preview.itemsToUpdate == 1 {
                                Text("1 item to update")
                            } else {
                                Text("\(preview.itemsToUpdate) items to update")
                            }
                            Spacer()
                        }
                        .accessibilityElement(children: .combine)
                    }

                    // Empty state
                    if preview.totalChanges == 0 {
                        HStack(spacing: 8) {
                            Image(systemName: "info.circle")
                                .foregroundColor(.blue)
                                .accessibilityHidden(true)
                            Text("No changes to import")
                                .foregroundColor(.secondary)
                        }
                    }
                }
                .padding(.vertical, 4)
            }

            // Conflicts Section
            if preview.hasConflicts {
                GroupBox {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack(spacing: 8) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundColor(.orange)
                                .accessibilityHidden(true)
                            Text("Conflicts (\(preview.conflicts.count))")
                                .font(.headline)
                        }
                        .accessibilityElement(children: .combine)
                        .accessibilityLabel("Conflicts: \(preview.conflicts.count)")

                        // Show up to 5 conflicts
                        ForEach(Array(preview.conflicts.prefix(5).enumerated()), id: \.offset) { _, conflict in
                            VStack(alignment: .leading, spacing: 4) {
                                Text(conflict.entityName)
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                Text(conflict.message)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            .padding(.vertical, 2)
                        }

                        if preview.conflicts.count > 5 {
                            Text("And \(preview.conflicts.count - 5) more...")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .italic()
                        }
                    }
                    .padding(.vertical, 4)
                }
            }

            // Strategy Info Section
            GroupBox {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Import Strategy")
                        .font(.headline)
                        .foregroundColor(.secondary)

                    HStack(spacing: 8) {
                        Image(systemName: viewModel.strategyIcon(viewModel.selectedStrategy))
                            .foregroundColor(.accentColor)
                            .accessibilityHidden(true)
                        Text(viewModel.strategyName(viewModel.selectedStrategy))
                            .font(.subheadline)
                            .fontWeight(.medium)
                    }

                    Text(viewModel.strategyDescription(viewModel.selectedStrategy))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(.vertical, 4)
            }

            Spacer()

            // Action Buttons
            HStack {
                Button("Cancel") {
                    dismissAndCancel()
                }
                .keyboardShortcut(.escape, modifiers: [])
                .accessibilityHint("Cancels the import and closes the preview")

                Spacer()

                Button("Confirm Import") {
                    dismissAndConfirm()
                }
                .keyboardShortcut(.return, modifiers: [])
                .buttonStyle(.borderedProminent)
                .disabled(preview.totalChanges == 0)
                .accessibilityHint("Confirms and starts the import operation")
            }
        }
        .padding(24)
        .frame(width: 400, height: 350)
    }

    // MARK: - Private Methods

    private func dismissAndCancel() {
        onDismiss?()
        viewModel.cancelPreview()
    }

    private func dismissAndConfirm() {
        onDismiss?()
        viewModel.confirmImport()
    }
}

// MARK: - Preview

#if DEBUG
struct MacImportPreviewSheet_Previews: PreviewProvider {
    static var previews: some View {
        // Preview with data
        let previewWithData = ImportPreview(
            listsToCreate: 3,
            listsToUpdate: 2,
            itemsToCreate: 15,
            itemsToUpdate: 5,
            conflicts: [
                ConflictDetail(
                    type: .listModified,
                    entityName: "Shopping List",
                    entityId: UUID(),
                    currentValue: "Shopping List",
                    incomingValue: "Groceries",
                    message: "List name will change from 'Shopping List' to 'Groceries'"
                ),
                ConflictDetail(
                    type: .itemModified,
                    entityName: "Milk",
                    entityId: UUID(),
                    currentValue: "Milk (qty: 1)",
                    incomingValue: "Milk (qty: 2)",
                    message: "Item 'Milk' will be updated"
                )
            ],
            errors: []
        )

        MacImportPreviewSheet(
            preview: previewWithData,
            viewModel: ImportViewModel()
        )
        .previewDisplayName("With Data")

        // Preview with no changes
        let previewEmpty = ImportPreview(
            listsToCreate: 0,
            listsToUpdate: 0,
            itemsToCreate: 0,
            itemsToUpdate: 0,
            conflicts: [],
            errors: []
        )

        MacImportPreviewSheet(
            preview: previewEmpty,
            viewModel: ImportViewModel()
        )
        .previewDisplayName("No Changes")
    }
}
#endif
