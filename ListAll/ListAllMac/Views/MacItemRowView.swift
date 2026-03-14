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

    @State var isHovering = false
    @Environment(\.colorScheme) var colorScheme

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
            if !isInSelectionMode {
                if isArchivedList {
                    checkboxView()
                        .opacity(0.6)
                        .accessibilityLabel("\(item.title), \(item.isCrossedOut ? "completed" : "active"), read-only")
                } else {
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

            quantityBadge()

            // Hover actions (hidden in selection mode)
            if isHovering && !isInSelectionMode {
                hoverActions
            }
        }
        .padding(.vertical, 11)
        .padding(.horizontal, 14)
        .background(rowBackground)
        .overlay { rowBorderOverlay }
        .opacity(item.isCrossedOut ? 0.5 : 1.0)
        .onHover { hovering in
            isHovering = hovering
        }
        .onDoubleClick {
            guard !isArchivedList else { return }
            if isInSelectionMode {
                onToggleSelection()
            } else {
                onEdit()
            }
        }
        .contentShape(Rectangle())
        .listRowBackground(isInSelectionMode && isSelected ? Color.accentColor.opacity(0.1) : Color.clear)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(itemAccessibilityLabel)
        .accessibilityHint(archivedAccessibilityHint)
        .contextMenu { itemContextMenu }
    }
}
