//
//  WatchListView.swift
//  ListAllWatch Watch App
//
//  Created by AI Assistant on 21.10.2025.
//

import SwiftUI
#if os(watchOS)
import WatchKit
#endif

/// Detail view showing items in a list on watchOS
struct WatchListView: View {
    @StateObject private var viewModel: WatchListViewModel
    
    init(list: List) {
        _viewModel = StateObject(wrappedValue: WatchListViewModel(list: list))
    }
    
    var body: some View {
        Group {
            if let errorMessage = viewModel.errorMessage {
                // Show error state
                WatchErrorView(message: errorMessage) {
                    Task {
                        await viewModel.refresh()
                    }
                }
            } else if viewModel.isLoading && viewModel.items.isEmpty {
                // Show loading indicator on initial load
                WatchLoadingView(message: "Loading items...")
            } else if viewModel.sortedItems.isEmpty {
                // Show empty state (respects current filter)
                emptyStateView
            } else {
                // Show items
                itemsContent
            }
        }
        .navigationTitle(viewModel.list.name)
        .navigationBarTitleDisplayMode(.inline)
        .overlay(alignment: .bottom) {
            if viewModel.isSyncingFromiOS {
                syncIndicator
            }
        }
    }
    
    // MARK: - Sync Indicator
    private var syncIndicator: some View {
        WatchSyncLoadingView()
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(Color.blue.opacity(0.9))
            .foregroundColor(.white)
            .cornerRadius(20)
            .padding(.bottom, 8)
            .transition(.move(edge: .bottom).combined(with: .opacity))
            .animation(WatchAnimationManager.syncIndicator, value: viewModel.isSyncingFromiOS)
    }
    
    // MARK: - Items Content
    private var itemsContent: some View {
        WatchPullToRefreshView {
            ScrollView {
                LazyVStack(spacing: 0) {
                    // Filter picker and item count summary at top
                    HStack {
                        WatchFilterPicker(
                            selectedFilter: $viewModel.currentFilter
                        ) { newFilter in
                            viewModel.setFilter(newFilter)
                        }
                        
                        Spacer()
                    }
                    .padding(.horizontal)
                    .padding(.top, 8)
                    .padding(.bottom, 4)
                    
                    itemCountSummary
                        .padding(.horizontal)
                        .padding(.bottom, 8)
                    
                    // Items list
                    ForEach(viewModel.sortedItems) { item in
                        WatchItemRowView(item: item) {
                            withAnimation(WatchAnimationManager.itemToggle) {
                                viewModel.toggleItemCompletion(item)
                            }
                        }
                        .padding(.horizontal, 4)
                        
                        Divider()
                            .padding(.leading, 36)
                    }
                }
            }
        } onRefresh: {
            WatchHapticManager.shared.playRefresh()
            await viewModel.refresh()
        }
    }
    
    // MARK: - Item Count Summary
    private var itemCountSummary: some View {
        HStack(spacing: 12) {
            // Active items count
            if viewModel.activeItemCount > 0 {
                HStack(spacing: 4) {
                    Image(systemName: "circle")
                        .font(.caption2)
                    Text("\(viewModel.activeItemCount)")
                        .font(.caption)
                }
                .foregroundColor(.blue)
            }
            
            // Completed items count
            if viewModel.completedItemCount > 0 {
                HStack(spacing: 4) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.caption2)
                    Text("\(viewModel.completedItemCount)")
                        .font(.caption)
                }
                .foregroundColor(.green)
            }
            
            Spacer()
            
            // Total count
            Text("\(viewModel.totalItemCount) total")
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Color.secondary.opacity(0.1))
        .cornerRadius(8)
    }
    
    // MARK: - Empty State
    private var emptyStateView: some View {
        VStack(spacing: 12) {
            Image(systemName: emptyStateIcon)
                .font(.system(size: 40))
                .foregroundColor(.secondary)
            
            Text(emptyStateTitle)
                .font(.headline)
            
            Text(emptyStateMessage)
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding()
    }
    
    // MARK: - Empty State Content
    
    private var emptyStateIcon: String {
        if viewModel.items.isEmpty {
            return "list.bullet"
        }
        
        switch viewModel.currentFilter {
        case .all:
            return "list.bullet"
        case .active:
            return "circle"
        case .completed:
            return "checkmark.circle"
        case .hasDescription:
            return "text.alignleft"
        case .hasImages:
            return "photo"
        }
    }
    
    private var emptyStateTitle: String {
        if viewModel.items.isEmpty {
            return "No Items"
        }
        
        switch viewModel.currentFilter {
        case .all:
            return "No Items"
        case .active:
            return "No Active Items"
        case .completed:
            return "No Completed Items"
        case .hasDescription:
            return "No Items with Description"
        case .hasImages:
            return "No Items with Images"
        }
    }
    
    private var emptyStateMessage: String {
        if viewModel.items.isEmpty {
            return "Add items on your iPhone"
        }
        
        switch viewModel.currentFilter {
        case .all:
            return "Add items on your iPhone"
        case .active:
            return "All items are completed"
        case .completed:
            return "No completed items yet"
        case .hasDescription:
            return "No items have descriptions"
        case .hasImages:
            return "No items have images"
        }
    }
}

// MARK: - Preview
#Preview("With Items") {
    NavigationStack {
        WatchListView(list: List(name: "Shopping List"))
    }
}

#Preview("Empty List") {
    NavigationStack {
        WatchListView(list: List(name: "Empty List"))
    }
}

