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
            .overlay(alignment: .bottom) {
                if viewModel.isSyncingFromiOS {
                    syncIndicator
                }
            }
        }
    }
    
    // MARK: - Sync Indicator
    private var syncIndicator: some View {
        HStack(spacing: 8) {
            ProgressView()
                .scaleEffect(0.7)
            Text("Syncing...")
                .font(.caption2)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(Color.blue.opacity(0.9))
        .foregroundColor(.white)
        .cornerRadius(20)
        .padding(.bottom, 8)
        .transition(.move(edge: .bottom).combined(with: .opacity))
        .animation(.spring(), value: viewModel.isSyncingFromiOS)
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

