//
//  MacMainView+DetailContent.swift
//  ListAllMac
//
//  Detail view content and edit sheet presentation for MacMainView.
//

import SwiftUI

extension MacMainView {
    /// Detail pane content: shows the selected list, or an appropriate empty state.
    @ViewBuilder
    var detailContent: some View {
        if let list = selectedList {
            MacListDetailView(
                list: list,
                onEditItem: { item in
                    presentEditSheet(for: item)
                },
                onRestore: {
                    // Task 13.1 UX improvement: Restore button callback
                    listToRestore = list
                    showingRestoreConfirmation = true
                }
            )
            .id(list.id) // Force refresh when selection changes
        } else {
            // Show different empty states based on whether any lists exist
            if dataManager.lists.isEmpty {
                // No lists at all - show welcome with sample templates
                MacListsEmptyStateView(
                    onCreateSampleList: { template in
                        createSampleList(from: template)
                    },
                    onCreateCustomList: { showingCreateListSheet = true }
                )
            } else {
                // Lists exist but none selected - simple prompt
                MacNoListSelectedView(onCreateList: { showingCreateListSheet = true })
            }
        }
    }

    /// Presents the native AppKit edit sheet for the given item.
    ///
    /// Uses MacNativeSheetPresenter to bypass SwiftUI's RunLoop issues
    /// where `.sheet()` only presents after app deactivation.
    func presentEditSheet(for item: Item) {
        // CRITICAL: Use native AppKit sheet presentation (bypasses SwiftUI's RunLoop issues)
        // SwiftUI sheets have a known bug where they only present after app deactivation
        // This is caused by RunLoop mode conflicts during event handling
        print("🎯 MacMainView: Received edit request for item: \(item.title)")
        isEditingAnyItem = true
        selectedEditItem = item

        // Define cancel action (used by both Cancel button and ESC key)
        let cancelAction = {
            MacNativeSheetPresenter.shared.dismissSheet()
            selectedEditItem = nil
            isEditingAnyItem = false
        }

        // Present using native AppKit sheet (works immediately)
        MacNativeSheetPresenter.shared.presentSheet(
            MacEditItemSheet(
                item: item,
                onSave: { title, quantity, description, images in
                    updateEditedItem(item, title: title, quantity: quantity, description: description, images: images)
                    MacNativeSheetPresenter.shared.dismissSheet()
                    selectedEditItem = nil
                    isEditingAnyItem = false
                },
                onCancel: cancelAction
            )
            .environment(\.managedObjectContext, viewContext),
            onCancel: cancelAction  // ESC key support via SheetHostingController
        ) {
            // Completion handler when sheet dismisses
            isEditingAnyItem = false
            selectedEditItem = nil
            dataManager.loadData()
        }
        print("✅ MacMainView: Native sheet presenter called")
    }
}
