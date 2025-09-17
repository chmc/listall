import SwiftUI

struct ItemRowView: View {
    let item: Item
    @StateObject private var viewModel: ItemViewModel
    
    init(item: Item) {
        self.item = item
        self._viewModel = StateObject(wrappedValue: ItemViewModel(item: item))
    }
    
    var body: some View {
        NavigationLink(destination: ItemDetailView(item: item)) {
            HStack(spacing: Theme.Spacing.md) {
                // Checkbox
                Button(action: {
                    viewModel.toggleCrossedOut()
                }) {
                    Image(systemName: item.isCrossedOut ? Constants.UI.checkmarkIcon : Constants.UI.circleIcon)
                        .foregroundColor(item.isCrossedOut ? Theme.Colors.success : Theme.Colors.secondary)
                        .font(.title2)
                        .animation(Theme.Animation.quick, value: item.isCrossedOut)
                }
                .buttonStyle(PlainButtonStyle())
                
                // Content
                VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                    // Title with strikethrough animation
                    Text(item.displayTitle)
                        .font(Theme.Typography.body)
                        .strikethrough(item.isCrossedOut, color: Theme.Colors.secondary)
                        .foregroundColor(item.isCrossedOut ? Theme.Colors.secondary : .primary)
                        .animation(Theme.Animation.quick, value: item.isCrossedOut)
                    
                    // Description (if available)
                    if item.hasDescription {
                        Text(item.displayDescription)
                            .font(Theme.Typography.caption)
                            .foregroundColor(Theme.Colors.secondary)
                            .lineLimit(2)
                            .opacity(item.isCrossedOut ? 0.6 : 1.0)
                    }
                    
                    // Secondary info row
                    HStack(spacing: Theme.Spacing.sm) {
                        // Quantity indicator (only if > 1)
                        if item.quantity > 1 {
                            Text(item.formattedQuantity)
                                .font(Theme.Typography.caption)
                                .foregroundColor(Theme.Colors.secondary)
                                .opacity(item.isCrossedOut ? 0.6 : 1.0)
                        }
                        
                        // Image count indicator (if item has images)
                        if item.hasImages {
                            HStack(spacing: 2) {
                                Image(systemName: "photo")
                                    .font(.caption2)
                                Text("\(item.imageCount)")
                                    .font(Theme.Typography.caption)
                            }
                            .foregroundColor(Theme.Colors.info)
                            .opacity(item.isCrossedOut ? 0.6 : 1.0)
                        }
                    }
                }
                
                Spacer()
                
                // Navigation chevron
                Image(systemName: Constants.UI.chevronIcon)
                    .font(.caption)
                    .foregroundColor(Theme.Colors.secondary)
                    .opacity(0.6)
            }
            .padding(.vertical, Theme.Spacing.xs)
            .contentShape(Rectangle()) // Makes entire row tappable
        }
        .buttonStyle(PlainButtonStyle())
    }
}

#Preview {
    SwiftUI.List {
        ItemRowView(item: Item(title: "Sample Item"))
    }
}
