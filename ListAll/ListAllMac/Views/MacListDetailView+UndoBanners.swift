//
//  MacListDetailView+UndoBanners.swift
//  ListAllMac
//
//  Undo banner overlays for item completion, deletion, and bulk deletion.
//

import SwiftUI

extension MacListDetailView {

    // MARK: - Undo Banners

    @ViewBuilder
    var undoBannersOverlay: some View {
        if viewModel.showUndoButton, let item = viewModel.recentlyCompletedItem {
            MacUndoBanner(
                itemName: item.displayTitle,
                onUndo: { viewModel.undoComplete() },
                onDismiss: { viewModel.hideUndoButton() }
            )
            .frame(maxWidth: 400)
            .padding(.horizontal, 20)
            .padding(.bottom, 20)
            .transition(.move(edge: .bottom).combined(with: .opacity))
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: viewModel.showUndoButton)
            .accessibilityIdentifier("UndoCompleteBanner")
        }

        if viewModel.showDeleteUndoButton, let item = viewModel.recentlyDeletedItem {
            MacDeleteUndoBanner(
                itemName: item.displayTitle,
                onUndo: { viewModel.undoDeleteItem() },
                onDismiss: { viewModel.hideDeleteUndoButton() }
            )
            .frame(maxWidth: 400)
            .padding(.horizontal, 20)
            .padding(.bottom, 20)
            .transition(.move(edge: .bottom).combined(with: .opacity))
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: viewModel.showDeleteUndoButton)
            .accessibilityIdentifier("UndoDeleteBanner")
        }

        if viewModel.showBulkDeleteUndoBanner {
            MacBulkDeleteUndoBanner(
                itemCount: viewModel.deletedItemsCount,
                onUndo: {
                    viewModel.undoBulkDelete()
                    dataManager.loadData()
                },
                onDismiss: { viewModel.hideBulkDeleteUndoBanner() }
            )
            .frame(maxWidth: 400)
            .padding(.horizontal, 20)
            .padding(.bottom, 20)
            .transition(.move(edge: .bottom).combined(with: .opacity))
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: viewModel.showBulkDeleteUndoBanner)
            .accessibilityIdentifier("BulkDeleteUndoBanner")
        }
    }
}
