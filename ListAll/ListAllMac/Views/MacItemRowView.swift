//
//  MacItemRowView.swift
//  ListAllMac
//
//  Row view for individual items in the list detail.
//

import SwiftUI
import AppKit

struct MacItemRowView: View {
    let item: Item
    let isInSelectionMode: Bool
    let isSelected: Bool
    let isArchivedList: Bool  // Task 13.2: Read-only mode for archived lists
    let onToggle: () -> Void
    let onEdit: () -> Void
    let onDuplicate: () -> Void  // Task 16.3: Duplicate item action
    let onDelete: () -> Void
    let onQuickLook: () -> Void
    let onToggleSelection: () -> Void

    @State private var isHovering = false
    @Environment(\.colorScheme) private var colorScheme

    /// Combined accessibility label for VoiceOver
    private var itemAccessibilityLabel: String {
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

    // MARK: - Checkbox View (macOS 20px diameter)

    @ViewBuilder
    private func checkboxView() -> some View {
        if item.isCrossedOut {
            ZStack {
                Circle()
                    .fill(Theme.Colors.completedGreen.opacity(0.2))
                Circle()
                    .strokeBorder(Theme.Colors.completedGreen.opacity(0.3), lineWidth: 2)
                Image(systemName: "checkmark")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(Theme.Colors.completedGreen)
            }
            .frame(width: 20, height: 20)
            .accessibilityLabel("Completed")
        } else {
            Circle()
                .strokeBorder(Theme.Colors.primary.opacity(0.4), lineWidth: 2)
                .frame(width: 20, height: 20)
                .accessibilityLabel("Active")
        }
    }

    // MARK: - Selection Mode Checkbox (macOS 20px diameter)

    @ViewBuilder
    private func selectionCheckboxView() -> some View {
        if isSelected {
            ZStack {
                Circle()
                    .fill(Theme.Colors.primary.opacity(0.2))
                Circle()
                    .strokeBorder(Theme.Colors.primary.opacity(0.4), lineWidth: 2)
                Image(systemName: "checkmark")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(Theme.Colors.primary)
            }
            .frame(width: 20, height: 20)
        } else {
            Circle()
                .strokeBorder(Color.gray.opacity(0.4), lineWidth: 2)
                .frame(width: 20, height: 20)
        }
    }

    // MARK: - Quantity Badge (teal capsule)

    @ViewBuilder
    private func quantityBadge() -> some View {
        if item.quantity > 1 {
            Text("\u{00D7}\(item.quantity)")
                .font(.caption.monospacedDigit().weight(.semibold))
                .foregroundColor(item.isCrossedOut
                    ? Theme.Colors.completedGreen.opacity(0.6)
                    : Theme.Colors.primary)
                .padding(.horizontal, 7)
                .padding(.vertical, 3)
                .background {
                    Capsule()
                        .fill(item.isCrossedOut
                            ? Theme.Colors.completedGreen.opacity(0.08)
                            : Theme.Colors.primary.opacity(0.1))
                        .overlay(
                            Capsule()
                                .strokeBorder(item.isCrossedOut
                                    ? Theme.Colors.completedGreen.opacity(0.15)
                                    : Theme.Colors.primary.opacity(0.2), lineWidth: 1)
                        )
                }
                .accessibilityLabel("Quantity \(item.quantity)")
        }
    }

    var body: some View {
        HStack(spacing: 12) {
            // Selection checkbox (shown in selection mode, but NOT for archived lists)
            if isInSelectionMode && !isArchivedList {
                Button(action: onToggleSelection) {
                    selectionCheckboxView()
                }
                .buttonStyle(.plain)
                .accessibilityLabel(isSelected ? "Selected" : "Not selected")
                .accessibilityHint("Double-tap to toggle selection")
            }

            // Completion checkbox button (hidden in selection mode AND archived lists)
            // Task 13.2: For archived lists, show read-only completion indicator
            if !isInSelectionMode {
                if isArchivedList {
                    // Read-only completion indicator (no button, just visual state)
                    checkboxView()
                        .opacity(0.6)
                        .accessibilityLabel("\(item.title), \(item.isCrossedOut ? "completed" : "active"), read-only")
                } else {
                    // Interactive completion toggle for active lists
                    Button(action: onToggle) {
                        checkboxView()
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("\(item.title), \(item.isCrossedOut ? "completed" : "active")")
                    .accessibilityHint("Double-tap to toggle completion status")
                }
            }

            // Image thumbnail (if item has images)
            if item.hasImages, let firstImage = item.sortedImages.first, let nsImage = firstImage.nsImage {
                Button(action: onQuickLook) {
                    ZStack(alignment: .bottomTrailing) {
                        Image(nsImage: nsImage)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: 36, height: 36)
                            .clipShape(RoundedRectangle(cornerRadius: 4))
                            .overlay(
                                RoundedRectangle(cornerRadius: 4)
                                    .stroke(Color.secondary.opacity(0.3), lineWidth: 0.5)
                            )

                        // Badge for multiple images (dark mode compatible)
                        if item.imageCount > 1 {
                            Text("\(item.imageCount)")
                                .font(.system(size: 8, weight: .bold))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 3)
                                .padding(.vertical, 1)
                                .background(.ultraThinMaterial.opacity(0.9))
                                .background(Color(nsColor: .darkGray))
                                .clipShape(Capsule())
                                .offset(x: 2, y: 2)
                                .accessibilityHidden(true)
                        }
                    }
                }
                .buttonStyle(.plain)
                .help("Quick Look (Space)")
                .accessibilityLabel("View \(item.imageCount) images")
            }

            // Item content
            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    Text(item.title)
                        .font(.body)
                        .fontWeight(.medium)
                        .strikethrough(item.isCrossedOut)
                        .foregroundColor(item.isCrossedOut ? .secondary : .primary)

                    // Show photo icon only when no thumbnail (fallback indicator)
                    if item.hasImages && item.sortedImages.first?.nsImage == nil {
                        Image(systemName: "photo")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }

                if let description = item.itemDescription, !description.isEmpty {
                    Text(description)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(3)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            Spacer()

            // Quantity badge (moved from inline to right-aligned capsule)
            quantityBadge()

            // Hover actions (hidden in selection mode)
            // Task 13.2: For archived lists, only show Quick Look (no edit/delete)
            if isHovering && !isInSelectionMode {
                HStack(spacing: 8) {
                    // Quick Look button (only if item has images) - ALWAYS visible for archived lists
                    if item.hasImages {
                        Button(action: onQuickLook) {
                            Image(systemName: "eye")
                        }
                        .buttonStyle(.plain)
                        .help("Quick Look (Space)")
                        .accessibilityLabel("Quick Look")
                        .accessibilityHint("Opens image preview")
                    }

                    // Edit and Delete buttons - hidden for archived lists
                    if !isArchivedList {
                        Button(action: onEdit) {
                            Image(systemName: "pencil")
                        }
                        .buttonStyle(.plain)
                        .help("Edit Item")
                        .accessibilityLabel("Edit item")
                        .accessibilityHint("Opens edit sheet")

                        Button(action: onDelete) {
                            Image(systemName: "trash")
                                .foregroundColor(.red)
                        }
                        .buttonStyle(.plain)
                        .help("Delete Item")
                        .accessibilityLabel("Delete item")
                        .accessibilityHint("Permanently removes this item")
                    }
                }
            }
        }
        .padding(.vertical, 11)
        .padding(.horizontal, 14)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(colorScheme == .dark
                    ? Color.white.opacity(isHovering ? 0.05 : 0.03)
                    : isHovering ? Color.black.opacity(0.02) : Color.white)
                .shadow(color: colorScheme == .dark ? .clear : .black.opacity(0.04), radius: 1, y: 1)
        )
        .overlay {
            if colorScheme == .dark {
                RoundedRectangle(cornerRadius: 10)
                    .strokeBorder(Color.primary.opacity(0.06), lineWidth: 1)
            }
        }
        .opacity(item.isCrossedOut ? 0.5 : 1.0)
        .onHover { hovering in
            isHovering = hovering
        }
        // CRITICAL: Use native AppKit double-click handler instead of .onTapGesture(count: 2)
        // SwiftUI's gesture system blocks the run loop on macOS, causing sheets to only
        // appear after app deactivation. This native handler fires immediately.
        // In selection mode, double-click toggles selection instead of editing
        // Task 13.2: For archived lists, double-click does nothing (read-only)
        .onDoubleClick {
            guard !isArchivedList else { return }  // No editing for archived lists
            if isInSelectionMode {
                onToggleSelection()
            } else {
                onEdit()
            }
        }
        // NOTE: Do NOT add .onTapGesture or .simultaneousGesture(TapGesture()) here!
        // Any tap gesture handler captures mouse-down events and blocks drag initiation.
        // Selection mode uses the checkbox button, double-click, or context menu instead.
        .contentShape(Rectangle())  // Required for hit testing on entire row area
        .listRowBackground(isInSelectionMode && isSelected ? Color.accentColor.opacity(0.1) : Color.clear)
        // MARK: - Accessibility (Task 11.2)
        // Combine child elements into a single accessible element for cleaner VoiceOver navigation
        .accessibilityElement(children: .combine)
        .accessibilityLabel(itemAccessibilityLabel)
        .accessibilityHint(archivedAccessibilityHint)
        .contextMenu {
            // Task 13.2: Archived lists have read-only context menu (only Quick Look if images exist)
            if isArchivedList {
                // Archived list item context menu - only Quick Look allowed
                if item.hasImages {
                    Button("Quick Look") {
                        onQuickLook()
                    }
                    .keyboardShortcut(.space, modifiers: [])
                }
                // No edit, toggle, or delete options for archived items
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
    }

    /// Accessibility hint based on list state
    private var archivedAccessibilityHint: String {
        if isArchivedList {
            return item.hasImages ? "Use Space to view images. This item is read-only." : "This item is read-only."
        } else if isInSelectionMode {
            return "Tap to toggle selection"
        } else {
            return "Double-tap to edit. Use actions menu for more options."
        }
    }
}

