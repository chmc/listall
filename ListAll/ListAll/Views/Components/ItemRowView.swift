import SwiftUI
import UIKit

struct ItemRowView: View {
    let item: Item
    var viewModel: ListViewModel? = nil
    let onToggle: (() -> Void)?
    let onEdit: (() -> Void)?
    let onDuplicate: (() -> Void)?
    let onDelete: (() -> Void)?
    
    init(item: Item,
         viewModel: ListViewModel? = nil,
         onToggle: (() -> Void)? = nil,
         onEdit: (() -> Void)? = nil,
         onDuplicate: (() -> Void)? = nil,
         onDelete: (() -> Void)? = nil) {
        self.item = item
        self.viewModel = viewModel
        self.onToggle = onToggle
        self.onEdit = onEdit
        self.onDuplicate = onDuplicate
        self.onDelete = onDelete
    }
    
    private var isInSelectionMode: Bool {
        viewModel?.isInSelectionMode ?? false
    }
    
    private var isSelected: Bool {
        viewModel?.selectedItems.contains(item.id) ?? false
    }
    
    private var itemContent: some View {
        VStack(alignment: .leading, spacing: 1) {
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
            .contentShape(Rectangle())
    }
    
    var body: some View {
        HStack(spacing: Theme.Spacing.md) {
            // Selection indicator
            if isInSelectionMode {
                Button(action: {
                    viewModel?.toggleSelection(for: item.id)
                }) {
                    Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                        .foregroundColor(isSelected ? .blue : .gray)
                        .imageScale(.large)
                }
                .buttonStyle(BorderlessButtonStyle())
            }
            
            // Item content
            if isInSelectionMode {
                // In selection mode: Make entire row tappable for selection
                Button(action: {
                    viewModel?.toggleSelection(for: item.id)
                }) {
                    itemContent
                }
                .buttonStyle(PlainButtonStyle())
            } else {
                // Normal mode: Main content area tappable to complete item
                itemContent
                    .onTapGesture {
                        onToggle?()
                    }
                
                // Right-side edit button with larger clickable area
                Button(action: {
                    onEdit?()
                }) {
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundColor(Theme.Colors.secondary)
                        .frame(width: 44, height: 44)
                        .contentShape(Rectangle())
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
        .padding(.vertical, 8)
        .padding(.horizontal, Theme.Spacing.md)
        .contentShape(Rectangle())
        .if(!isInSelectionMode) { view in
            view.contextMenu {
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
        }
        .if(!isInSelectionMode) { view in
            view.swipeActions(edge: .trailing, allowsFullSwipe: false) {
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
}

#Preview {
    SwiftUI.List {
        ItemRowView(item: Item(title: "Sample Item"))
    }
}
