//
//  WatchItemRowView.swift
//  ListAllWatch Watch App
//
//  Created by AI Assistant on 21.10.2025.
//

import SwiftUI

/// A row component displaying an item with completion status
struct WatchItemRowView: View {
    let item: Item
    let onToggle: () -> Void
    
    var body: some View {
        Button(action: onToggle) {
            HStack(spacing: 8) {
                // Completion indicator
                Image(systemName: item.isCrossedOut ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 20))
                    .foregroundColor(item.isCrossedOut ? .green : .blue)
                
                // Item content
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 4) {
                        // Title
                        Text(item.displayTitle)
                            .font(.body)
                            .foregroundColor(item.isCrossedOut ? .secondary : .primary)
                            .strikethrough(item.isCrossedOut)
                        
                        // Quantity indicator (if > 1)
                        if item.quantity > 1 {
                            Text("×\(item.quantity)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    // Description (if available)
                    if item.hasDescription {
                        Text(item.displayDescription)
                            .font(.caption2)
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.vertical, 4)
            .opacity(item.isCrossedOut ? 0.6 : 1.0)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Preview
#Preview("Active Item") {
    SwiftUI.List {
        WatchItemRowView(
            item: Item(title: "Milk"),
            onToggle: {}
        )
    }
}

#Preview("Completed Item") {
    var item = Item(title: "Bread")
    item.isCrossedOut = true
    return SwiftUI.List {
        WatchItemRowView(
            item: item,
            onToggle: {}
        )
    }
}

#Preview("Item with Quantity") {
    var item = Item(title: "Apples")
    item.quantity = 5
    return SwiftUI.List {
        WatchItemRowView(
            item: item,
            onToggle: {}
        )
    }
}

#Preview("Item with Description") {
    var item = Item(title: "Cheese")
    item.itemDescription = "Cheddar or Swiss"
    return SwiftUI.List {
        WatchItemRowView(
            item: item,
            onToggle: {}
        )
    }
}

