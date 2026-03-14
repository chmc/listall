//
//  MacItemRowView+ContextMenu.swift
//  ListAllMac
//
//  Context menu and accessibility for item row views.
//

import SwiftUI

extension MacItemRowView {

    // MARK: - Context Menu

    @ViewBuilder
    var itemContextMenu: some View {
        // Task 13.2: Archived lists have read-only context menu (only Quick Look if images exist)
        if isArchivedList {
            if item.hasImages {
                Button("Quick Look") {
                    onQuickLook()
                }
                .keyboardShortcut(.space, modifiers: [])
            }
        } else if isInSelectionMode {
            Button(isSelected ? "Deselect" : "Select") { onToggleSelection() }
        } else {
            Button("Edit") { onEdit() }
            Button("Duplicate") { onDuplicate() }  // Task 16.3: Duplicate item action
            Button(item.isCrossedOut ? "Mark as Active" : "Mark as Complete") { onToggle() }

            if item.hasImages {
                Divider()
                Button("Quick Look") {
                    onQuickLook()
                }
                .keyboardShortcut(.space, modifiers: [])
            }

            Divider()
            Button("Delete", role: .destructive) { onDelete() }
        }
    }

    // MARK: - Accessibility

    /// Combined accessibility label for VoiceOver
    var itemAccessibilityLabel: String {
        var label = item.title
        if isInSelectionMode {
            label = (isSelected ? "Selected, " : "Unselected, ") + label
        }
        if isArchivedList {
            label += ", archived"
        }
        label += ", \(item.isCrossedOut ? "completed" : "active")"
        if item.quantity > 1 {
            label += ", quantity \(item.quantity)"
        }
        if item.hasImages {
            label += ", \(item.imageCount) \(item.imageCount == 1 ? "image" : "images")"
        }
        if let description = item.itemDescription, !description.isEmpty {
            label += ", \(description)"
        }
        return label
    }

    /// Accessibility hint based on list state
    var archivedAccessibilityHint: String {
        if isArchivedList {
            return item.hasImages ? "Use Space to view images. This item is read-only." : "This item is read-only."
        } else if isInSelectionMode {
            return "Tap to toggle selection"
        } else {
            return "Double-tap to edit. Use actions menu for more options."
        }
    }
}
