import SwiftUI
import UIKit

struct ItemDetailView: View {
    let item: Item
    @StateObject private var viewModel: ItemViewModel
    @State private var showingEditView = false
    
    init(item: Item) {
        self.item = item
        self._viewModel = StateObject(wrappedValue: ItemViewModel(item: item))
    }
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.Spacing.lg) {
                // Main Title Section
                VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                    Text(viewModel.item.displayTitle)
                        .font(Theme.Typography.largeTitle)
                        .fontWeight(.bold)
                        .strikethrough(viewModel.item.isCrossedOut, color: Theme.Colors.secondary)
                        .foregroundColor(viewModel.item.isCrossedOut ? Theme.Colors.secondary : .primary)
                        .animation(Theme.Animation.quick, value: viewModel.item.isCrossedOut)
                    
                    // Status indicator
                    HStack(spacing: Theme.Spacing.sm) {
                        Image(systemName: viewModel.item.isCrossedOut ? Constants.UI.checkmarkIcon : Constants.UI.circleIcon)
                            .foregroundColor(viewModel.item.isCrossedOut ? Theme.Colors.success : Theme.Colors.secondary)
                            .font(.title3)
                        
                        Text(viewModel.item.isCrossedOut ? "Completed" : "Pending")
                            .font(Theme.Typography.callout)
                            .foregroundColor(viewModel.item.isCrossedOut ? Theme.Colors.success : Theme.Colors.secondary)
                    }
                    .animation(Theme.Animation.quick, value: viewModel.item.isCrossedOut)
                }
                
                Divider()
                
                // Description Section
                if viewModel.item.hasDescription {
                    VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                        Text("Description")
                            .font(Theme.Typography.headline)
                            .foregroundColor(Theme.Colors.secondary)
                        
                        MixedTextView(
                            text: viewModel.item.displayDescription,
                            font: Theme.Typography.body,
                            textColor: .primary,
                            linkColor: .blue,
                            isCrossedOut: viewModel.item.isCrossedOut,
                            opacity: viewModel.item.isCrossedOut ? 0.7 : 1.0
                        )
                        .multilineTextAlignment(.leading)
                        .lineLimit(nil) // Allow unlimited lines
                        .fixedSize(horizontal: false, vertical: true)
                    }
                    .cardStyle()
                    .padding(Theme.Spacing.md)
                }
                
                // Details Grid
                LazyVGrid(columns: [
                    GridItem(.flexible()),
                    GridItem(.flexible())
                ], spacing: Theme.Spacing.md) {
                    
                    // Quantity
                    DetailCard(
                        title: "Quantity",
                        value: "\(viewModel.item.quantity)",
                        icon: "number",
                        color: Theme.Colors.info
                    )
                    
                    // Images count
                    DetailCard(
                        title: "Images",
                        value: "\(viewModel.item.imageCount)",
                        icon: "photo",
                        color: Theme.Colors.warning
                    )
                }
                
                // Images Section (if available)
                if viewModel.item.hasImages {
                    ImageGalleryView(images: viewModel.item.sortedImages)
                        .cardStyle()
                        .padding(Theme.Spacing.md)
                }
                
                
                Spacer(minLength: Theme.Spacing.xl)
            }
            .padding(Theme.Spacing.md)
        }
        .navigationTitle("Item Details")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                HStack(spacing: Theme.Spacing.md) {
                    Button(action: {
                        viewModel.toggleCrossedOut()
                    }) {
                        Image(systemName: viewModel.item.isCrossedOut ? Constants.UI.checkmarkIcon : Constants.UI.circleIcon)
                            .foregroundColor(viewModel.item.isCrossedOut ? Theme.Colors.success : Theme.Colors.secondary)
                    }
                    
                    Button(action: {
                        showingEditView = true
                    }) {
                        Image(systemName: "pencil")
                    }
                }
                .padding(.horizontal, Theme.Spacing.sm)
            }
        }
        .sheet(isPresented: $showingEditView) {
            if let listId = viewModel.item.listId,
               let list = DataManager.shared.lists.first(where: { $0.id == listId }) {
                ItemEditView(list: list, item: viewModel.item)
            } else {
                Text("Unable to edit item - list not found")
                    .padding()
            }
        }
        .onChange(of: showingEditView) { _ in
            if !showingEditView {
                viewModel.refreshItem() // Refresh item after editing
            }
        }
    }
}

// MARK: - Supporting Views

struct DetailCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(spacing: Theme.Spacing.sm) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(color)
            
            Text(value)
                .font(Theme.Typography.title)
                .fontWeight(.semibold)
            
            Text(title)
                .font(Theme.Typography.caption)
                .foregroundColor(Theme.Colors.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(Theme.Spacing.md)
        .cardStyle()
    }
}

struct MetadataRow: View {
    let label: String
    let value: String
    
    var body: some View {
        HStack {
            Text(label)
                .font(Theme.Typography.callout)
                .foregroundColor(Theme.Colors.secondary)
            
            Spacer()
            
            Text(value)
                .font(Theme.Typography.callout)
                .foregroundColor(.primary)
        }
    }
}

#Preview {
    NavigationView {
        ItemDetailView(item: Item(title: "Sample Item"))
    }
}
