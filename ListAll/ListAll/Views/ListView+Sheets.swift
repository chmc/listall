import SwiftUI

// MARK: - ListView Sheets, Alerts & Lifecycle

extension ListView {
    @ViewBuilder
    var sheetsAndAlerts: some View {
        EmptyView()
            .sheet(isPresented: isScreenshotMode ? .constant(false) : $showingCreateItem) {
                ItemEditView(list: list)
            }
            .fullScreenCover(isPresented: isScreenshotMode ? $showingCreateItem : .constant(false)) {
                ItemEditView(list: list)
            }
            .sheet(isPresented: $showingEditItem) {
                if let item = selectedItem {
                    ItemEditView(list: list, item: item)
                }
            }
            .sheet(isPresented: $showingEditList) {
                EditListView(list: list, mainViewModel: mainViewModel)
            }
            .sheet(isPresented: isScreenshotMode ? .constant(false) : $viewModel.showingOrganizationOptions) {
                ItemOrganizationView(viewModel: viewModel)
            }
            .fullScreenCover(isPresented: isScreenshotMode ? $viewModel.showingOrganizationOptions : .constant(false)) {
                ItemOrganizationView(viewModel: viewModel)
            }
            .sheet(isPresented: $showingShareFormatPicker) {
                ShareFormatPickerView(
                    selectedFormat: $selectedShareFormat,
                    shareOptions: $shareOptions,
                    onShare: { format, options in
                        handleShare(format: format, options: options)
                    }
                )
            }
            .background(
                Group {
                    if showingShareSheet && !shareItems.isEmpty {
                        ActivityViewController(activityItems: shareItems) {
                            showingShareSheet = false
                            shareItems = []
                        }
                    }
                }
            )
            .alert("Share Error", isPresented: .constant(sharingService.shareError != nil)) {
                Button("OK") {
                    sharingService.clearError()
                }
            } message: {
                Text(sharingService.shareError ?? "")
            }
            .alert("Delete Items", isPresented: $showingDeleteConfirmation) {
                Button("Cancel", role: .cancel) { }
                Button("Delete", role: .destructive) {
                    withAnimation {
                        viewModel.deleteSelectedItems()
                        viewModel.exitSelectionMode()
                    }
                }
            } message: {
                Text("Are you sure you want to delete \(viewModel.selectedItems.count) item(s)? This action cannot be undone.")
            }
            .alert("Move Items", isPresented: $showingMoveConfirmation) {
                Button("Cancel", role: .cancel) {
                    selectedDestinationList = nil
                }
                Button("Move", role: .destructive) {
                    if let destination = selectedDestinationList {
                        viewModel.moveSelectedItems(to: destination)
                        viewModel.exitSelectionMode()
                        mainViewModel.loadLists()
                        presentationMode.wrappedValue.dismiss()
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                            if let refreshedDestination = mainViewModel.lists.first(where: { $0.id == destination.id }) {
                                mainViewModel.selectedListForNavigation = refreshedDestination
                            }
                        }
                    }
                    selectedDestinationList = nil
                }
            } message: {
                if let destination = selectedDestinationList {
                    Text("Move \(viewModel.selectedItems.count) item(s) to \"\(destination.name)\"? Items will be removed from this list.")
                }
            }
            .alert("Copy Items", isPresented: $showingCopyConfirmation) {
                Button("Cancel", role: .cancel) {
                    selectedDestinationList = nil
                }
                Button("Copy") {
                    if let destination = selectedDestinationList {
                        viewModel.copySelectedItems(to: destination)
                        viewModel.exitSelectionMode()
                        mainViewModel.loadLists()
                        presentationMode.wrappedValue.dismiss()
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                            if let refreshedDestination = mainViewModel.lists.first(where: { $0.id == destination.id }) {
                                mainViewModel.selectedListForNavigation = refreshedDestination
                            }
                        }
                    }
                    selectedDestinationList = nil
                }
            } message: {
                if let destination = selectedDestinationList {
                    Text("Copy \(viewModel.selectedItems.count) item(s) to \"\(destination.name)\"? Items will remain in this list.")
                }
            }
            .sheet(isPresented: $showingMoveDestinationPicker, onDismiss: {
                if selectedDestinationList != nil {
                    showingMoveConfirmation = true
                }
            }) {
                DestinationListPickerView(
                    action: .move,
                    itemCount: viewModel.selectedItems.count,
                    currentListId: list.id,
                    onSelect: { destinationList in
                        selectedDestinationList = destinationList
                        showingMoveDestinationPicker = false
                    },
                    onCancel: {
                        selectedDestinationList = nil
                        showingMoveDestinationPicker = false
                    },
                    mainViewModel: mainViewModel
                )
            }
            .sheet(isPresented: $showingCopyDestinationPicker, onDismiss: {
                if selectedDestinationList != nil {
                    showingCopyConfirmation = true
                }
            }) {
                DestinationListPickerView(
                    action: .copy,
                    itemCount: viewModel.selectedItems.count,
                    currentListId: list.id,
                    onSelect: { destinationList in
                        selectedDestinationList = destinationList
                        showingCopyDestinationPicker = false
                    },
                    onCancel: {
                        selectedDestinationList = nil
                        showingCopyDestinationPicker = false
                    },
                    mainViewModel: mainViewModel
                )
            }
    }

}
