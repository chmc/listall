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
                return watchLocalizedString("No Items", comment: "watchOS list row: no items label")
        } else if activeCount == totalCount {
            // All items are active
                return String.localizedStringWithFormat(
                    watchLocalizedString("%lld items", comment: "watchOS list row: total items count"),
                    Int64(totalCount)
                )
        } else {
            // Show active count with total in parentheses
                return String.localizedStringWithFormat(
                    watchLocalizedString("%lld (%lld) items", comment: "watchOS list row: active and total items count"),
                    Int64(activeCount),
                    Int64(totalCount)
                )
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

