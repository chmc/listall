//
//  WatchListsView.swift
//  ListAllWatch Watch App
//
//  Created by AI Assistant on 20.10.2025.
//

import SwiftUI

/// Main view showing all lists on watchOS
struct WatchListsView: View {
    @StateObject private var viewModel = WatchMainViewModel()
    
    var body: some View {
        NavigationStack {
            Group {
                if viewModel.isLoading && viewModel.lists.isEmpty {
                    // Show loading indicator on initial load
                    ProgressView("Loading...")
                } else if viewModel.lists.isEmpty {
                    // Show empty state
                    WatchEmptyStateView()
                } else {
                    // Show lists
                    listsContent
                }
            }
            .navigationTitle("Lists")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
    
    // MARK: - Lists Content
    private var listsContent: some View {
        SwiftUI.List {
            ForEach(viewModel.lists) { list in
                NavigationLink(value: list) {
                    WatchListRowView(list: list)
                }
                .listRowBackground(Color.clear)
            }
        }
        .navigationDestination(for: List.self) { list in
            WatchListView(list: list)
        }
        .refreshable {
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

