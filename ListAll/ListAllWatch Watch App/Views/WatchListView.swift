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
            if viewModel.isLoading && viewModel.items.isEmpty {
                // Show loading indicator on initial load
                ProgressView("Loading...")
            } else if viewModel.items.isEmpty {
                // Show empty state
                emptyStateView
            } else {
                // Show items
                itemsContent
            }
        }
        .navigationTitle(viewModel.list.name)
        .navigationBarTitleDisplayMode(.inline)
    }
    
    // MARK: - Items Content
    private var itemsContent: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                // Item count summary at top
                itemCountSummary
                    .padding(.horizontal)
                    .padding(.vertical, 8)
                
                // Items list
                ForEach(viewModel.sortedItems) { item in
                    WatchItemRowView(item: item) {
                        // Toggle item completion with haptic feedback
                        #if os(watchOS)
                        WKInterfaceDevice.current().play(.click)
                        #endif
                        withAnimation(.easeInOut(duration: 0.2)) {
                            viewModel.toggleItemCompletion(item)
                        }
                    }
                    .padding(.horizontal, 4)
                    
                    Divider()
                        .padding(.leading, 36)
                }
            }
        }
        .refreshable {
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
            Image(systemName: "list.bullet")
                .font(.system(size: 40))
                .foregroundColor(.secondary)
            
            Text("No Items")
                .font(.headline)
            
            Text("Add items on your iPhone")
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding()
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

