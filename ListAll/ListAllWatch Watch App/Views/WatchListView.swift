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
                WatchLoadingView(message: watchLocalizedString("Loading items...", comment: "watchOS loading message when loading items"))
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
            Text(String.localizedStringWithFormat(
                watchLocalizedString("%lld total", comment: "watchOS item count - total items"),
                Int64(viewModel.totalItemCount)
            ))
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
            return watchLocalizedString("No Items", comment: "watchOS empty state title when there are no items")
        }
        
        switch viewModel.currentFilter {
        case .all:
            return watchLocalizedString("No Items", comment: "watchOS empty state title when there are no items")
        case .active:
            return watchLocalizedString("No Active Items", comment: "watchOS empty state title when there are no active items")
        case .completed:
            return watchLocalizedString("No Completed Items", comment: "watchOS empty state title when there are no completed items")
        case .hasDescription:
            return watchLocalizedString("No Items with Description", comment: "watchOS empty state title when there are no items with description")
        case .hasImages:
            return watchLocalizedString("No Items with Images", comment: "watchOS empty state title when there are no items with images")
        }
    }
    
    private var emptyStateMessage: String {
        if viewModel.items.isEmpty {
            return watchLocalizedString("Add items on your iPhone", comment: "watchOS empty state message for items")
        }
        
        switch viewModel.currentFilter {
        case .all:
            return watchLocalizedString("Add items on your iPhone", comment: "watchOS empty state message for items")
        case .active:
            return watchLocalizedString("All items are completed", comment: "watchOS empty state message when all items are completed")
        case .completed:
            return watchLocalizedString("No completed items yet", comment: "watchOS empty state message when there are no completed items")
        case .hasDescription:
            return watchLocalizedString("No items have descriptions", comment: "watchOS empty state message when no items have descriptions")
        case .hasImages:
            return watchLocalizedString("No items have images", comment: "watchOS empty state message when no items have images")
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

