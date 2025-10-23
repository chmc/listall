//
//  WatchListRowView.swift
//  ListAllWatch Watch App
//
//  Created by AI Assistant on 20.10.2025.
//

import SwiftUI

/// A row component displaying a list with its name and item counts
struct WatchListRowView: View {
    let list: List
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(list.name)
                .font(.headline)
                .lineLimit(2)
                .foregroundColor(.primary)
            
            // Show item count in iOS format: "7 (22) items"
            Text(itemCountText)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 4)
    }
    
    /// Format item count like iOS: "7 (22) items"
    private var itemCountText: String {
        let activeCount = list.activeItemCount
        let totalCount = list.itemCount
        
        if totalCount == 0 {
            return "No items"
        } else if activeCount == totalCount {
            // All items are active
            return "\(totalCount) \(totalCount == 1 ? "item" : "items")"
        } else {
            // Show active count with total in parentheses
            return "\(activeCount) (\(totalCount)) \(totalCount == 1 ? "item" : "items")"
        }
    }
}

// MARK: - Preview
#Preview("Single List") {
    SwiftUI.List {
        WatchListRowView(list: List(name: "Groceries"))
    }
}

#Preview("List with Items") {
    let list = List(name: "Shopping List")
    // Note: In a real preview, we'd populate with items
    SwiftUI.List {
        WatchListRowView(list: list)
    }
}

