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
            
            HStack(spacing: 8) {
                // Active items count
                if list.activeItemCount > 0 {
                    Label("\(list.activeItemCount) active", systemImage: "circle")
                        .font(.caption2)
                        .foregroundColor(.blue)
                }
                
                // Completed items count
                if list.crossedOutItemCount > 0 {
                    Label("\(list.crossedOutItemCount) done", systemImage: "checkmark.circle.fill")
                        .font(.caption2)
                        .foregroundColor(.green)
                }
                
                // Show message if no items
                if list.itemCount == 0 {
                    Text("No items")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(.vertical, 4)
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

