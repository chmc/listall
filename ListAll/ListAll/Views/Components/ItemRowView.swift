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
            HStack {
                // Checkbox
                Button(action: {
                    viewModel.toggleCrossedOut()
                }) {
                    Image(systemName: item.isCrossedOut ? Constants.UI.checkmarkIcon : Constants.UI.circleIcon)
                        .foregroundColor(item.isCrossedOut ? Theme.Colors.success : Theme.Colors.secondary)
                        .font(.title2)
                }
                .buttonStyle(PlainButtonStyle())
                
                // Content
                VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                    Text(item.title)
                        .font(Theme.Typography.body)
                        .strikethrough(item.isCrossedOut)
                        .foregroundColor(item.isCrossedOut ? Theme.Colors.secondary : .primary)
                    
                    if let description = item.itemDescription, !description.isEmpty {
                        Text(description)
                            .font(Theme.Typography.caption)
                            .foregroundColor(Theme.Colors.secondary)
                            .lineLimit(2)
                    }
                    
                    if item.quantity > 1 {
                        Text("Qty: \(item.quantity)")
                            .font(Theme.Typography.caption)
                            .foregroundColor(Theme.Colors.secondary)
                    }
                }
                
                Spacer()
                
                // Quantity badge
                if item.quantity > 1 {
                    Text("\(item.quantity)")
                        .font(Theme.Typography.caption)
                        .fontWeight(.medium)
                        .foregroundColor(.white)
                        .padding(.horizontal, Theme.Spacing.sm)
                        .padding(.vertical, Theme.Spacing.xs)
                        .background(Theme.Colors.info)
                        .clipShape(Capsule())
                }
            }
            .padding(.vertical, 2)
        }
    }
}

#Preview {
    SwiftUI.List {
        ItemRowView(item: Item(title: "Sample Item"))
    }
}
