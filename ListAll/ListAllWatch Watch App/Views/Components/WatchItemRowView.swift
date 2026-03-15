import SwiftUI

/// A row component displaying an item with completion status
struct WatchItemRowView: View {
    let item: Item
    let onToggle: () -> Void

    // MARK: - Computed Properties (testable)

    var titleColor: Color {
        item.isCrossedOut ? .green : .primary
    }

    var showStrikethrough: Bool {
        item.isCrossedOut
    }

    var showQuantity: Bool {
        item.quantity > 1
    }

    var quantityText: String {
        "×\(item.quantity)"
    }

    var rowOpacity: Double {
        item.isCrossedOut ? 0.6 : 1.0
    }

    var body: some View {
        Button(action: {
            WatchHapticManager.shared.playItemToggle()
            onToggle()
        }) {
            HStack {
                // Title
                Text(item.displayTitle)
                    .font(.body)
                    .foregroundColor(titleColor)
                    .strikethrough(showStrikethrough)
                    .frame(maxWidth: .infinity, alignment: .leading)

                // Quantity (right-aligned, teal)
                if showQuantity {
                    Text(quantityText)
                        .font(.caption)
                        .foregroundColor(.accentColor)
                }
            }
            .padding(.vertical, 4)
            .opacity(rowOpacity)
            .contentShape(Rectangle())
            .itemToggleAnimation()
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("WatchItemRow_\(item.id.uuidString)")
        .accessibilityLabel(item.isCrossedOut ? "Completed: \(item.displayTitle)" : "Incomplete: \(item.displayTitle)")
        .accessibilityHint("Tap to toggle completion status")
        .accessibilityAddTraits(item.isCrossedOut ? .isSelected : [])
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

#Preview("Completed with Quantity") {
    var item = Item(title: "Chicken")
    item.isCrossedOut = true
    item.quantity = 2
    return SwiftUI.List {
        WatchItemRowView(
            item: item,
            onToggle: {}
        )
    }
}
