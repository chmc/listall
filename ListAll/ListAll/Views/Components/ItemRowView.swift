import SwiftUI
import UIKit

struct ItemRowView: View {
    let item: Item
    let onToggle: (() -> Void)?
    let onEdit: (() -> Void)?
    let onDuplicate: (() -> Void)?
    let onDelete: (() -> Void)?
    
    init(item: Item, 
         onToggle: (() -> Void)? = nil,
         onEdit: (() -> Void)? = nil,
         onDuplicate: (() -> Void)? = nil,
         onDelete: (() -> Void)? = nil) {
        self.item = item
        self.onToggle = onToggle
        self.onEdit = onEdit
        self.onDuplicate = onDuplicate
        self.onDelete = onDelete
    }
    
    var body: some View {
        HStack(spacing: Theme.Spacing.md) {
            // Main content area - entire area tappable to complete item
            VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                // Title with strikethrough animation
                Text(item.displayTitle)
                    .font(Theme.Typography.body)
                    .strikethrough(item.isCrossedOut, color: Theme.Colors.secondary)
                    .foregroundColor(item.isCrossedOut ? Theme.Colors.secondary : .primary)
                    .animation(Theme.Animation.quick, value: item.isCrossedOut)
                
                // Description (if available) - with proper mixed text and URL handling
                if item.hasDescription {
                    MixedTextView(
                        text: item.displayDescription,
                        font: Theme.Typography.caption,
                        textColor: Theme.Colors.secondary,
                        linkColor: .blue,
                        isCrossedOut: item.isCrossedOut,
                        opacity: item.isCrossedOut ? 0.6 : 1.0
                    )
                    .multilineTextAlignment(.leading)
                    .lineLimit(nil) // Allow unlimited lines
                    .fixedSize(horizontal: false, vertical: true)
                    .allowsHitTesting(true) // Allow URL links to be tapped with higher priority
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
                    
                    Spacer()
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle()) // Make entire content area tappable
            .onTapGesture {
                onToggle?()
            }
            
            // Right-side edit button
            Button(action: {
                onEdit?()
            }) {
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(Theme.Colors.secondary)
            }
            .buttonStyle(PlainButtonStyle())
        }
        .padding(.vertical, Theme.Spacing.xs)
        .contentShape(Rectangle()) // Makes entire row tappable
        .contextMenu {
            // Context menu actions
            Button(action: {
                onEdit?()
            }) {
                Label("Edit", systemImage: "pencil")
            }
            
            Button(action: {
                onDuplicate?()
            }) {
                Label("Duplicate", systemImage: "doc.on.doc")
            }
            
            Divider()
            
            Button(action: {
                onDelete?()
            }) {
                Label("Delete", systemImage: "trash")
            }
            .foregroundColor(.red)
        }
        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
            Button(action: {
                onDelete?()
            }) {
                Label("Delete", systemImage: "trash")
            }
            .tint(.red)
            
            Button(action: {
                onDuplicate?()
            }) {
                Label("Duplicate", systemImage: "doc.on.doc")
            }
            .tint(.blue)
            
            Button(action: {
                onEdit?()
            }) {
                Label("Edit", systemImage: "pencil")
            }
            .tint(.orange)
        }
    }
}

#Preview {
    SwiftUI.List {
        ItemRowView(item: Item(title: "Sample Item"))
    }
}
