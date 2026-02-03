import SwiftUI

/// Main view showing all lists on watchOS
struct WatchListsView: View {
    @StateObject private var viewModel = WatchMainViewModel()
    @EnvironmentObject private var localizationManager: WatchLocalizationManager
    
    var body: some View {
        NavigationStack {
            Group {
                if let errorMessage = viewModel.errorMessage {
                    // Show error state
                    WatchErrorView(message: errorMessage) {
                        Task {
                            await viewModel.refresh()
                        }
                    }
                } else if viewModel.isLoading && viewModel.lists.isEmpty {
                    // Show loading indicator on initial load
                    WatchLoadingView(message: watchLocalizedString("Loading lists...", comment: "watchOS loading message when loading lists"))
                } else if viewModel.lists.isEmpty {
                    // Show empty state
                    WatchEmptyStateView()
                } else {
                    // Show lists
                    listsContent
                }
            }
        .navigationTitle(watchLocalizedString("Lists", comment: "watchOS navigation title for lists view"))
        .navigationBarTitleDisplayMode(.inline)
        .overlay(alignment: .bottom) {
            if viewModel.isSyncingFromiOS {
                syncIndicator
            }
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
            .accessibilityIdentifier("WatchSyncIndicator")
    }
    
    // MARK: - Lists Content
    private var listsContent: some View {
        WatchPullToRefreshView {
            SwiftUI.List {
                // Lists section
                Section {
                    ForEach(viewModel.lists) { list in
                        NavigationLink(value: list) {
                            WatchListRowView(list: list)
                        }
                        .listRowBackground(Color.clear)
                        .accessibilityIdentifier("WatchListRow_\(list.id.uuidString)")
                        .accessibilityLabel("\(list.name) " + watchLocalizedString("list", comment: "watchOS accessibility label suffix for list"))
                        .accessibilityHint(watchLocalizedString("Tap to view items in this list", comment: "watchOS accessibility hint for list row"))
                    }
                }
            }
            .navigationDestination(for: List.self) { list in
                WatchListView(list: list)
            }
        } onRefresh: {
            WatchHapticManager.shared.playRefresh()
            await viewModel.refresh()
        }
    }
}

// MARK: - Preview
#Preview("With Lists") {
    WatchListsView()
}

#Preview("Empty State") {
    WatchListsView()
}

