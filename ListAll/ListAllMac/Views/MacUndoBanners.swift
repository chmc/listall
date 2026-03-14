//
//  MacUndoBanners.swift
//  ListAllMac
//
//  Undo banners for completed, deleted, and bulk-deleted items.
//

import SwiftUI

// MARK: - Undo Complete Banner (macOS)

/// macOS-styled undo banner for completed items.
/// Shows a green checkmark, item name, and undo/dismiss buttons.
/// Uses material background for modern macOS appearance.
struct MacUndoBanner: View {
    let itemName: String
    let onUndo: () -> Void
    let onDismiss: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundColor(.green)
                .font(.title2)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 2) {
                Text("Completed")
                    .font(.caption)
                    .foregroundColor(.secondary)

                Text(itemName)
                    .font(.body)
                    .fontWeight(.medium)
                    .lineLimit(1)
            }

            Spacer()

            Button(action: onUndo) {
                Text("Undo")
                    .font(.headline)
                    .foregroundColor(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 6)
                    .background(Color.accentColor)
                    .cornerRadius(6)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Undo completion")
            .accessibilityHint("Marks item as active again")

            Button(action: onDismiss) {
                Image(systemName: "xmark")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(6)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Dismiss")
            .accessibilityHint("Hides this notification")
        }
        .padding(12)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .shadow(color: Color.black.opacity(0.15), radius: 4, x: 0, y: 2)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Completed \(itemName)")
        .accessibilityHint("Use undo button to mark as active")
    }
}

// MARK: - Undo Delete Banner (macOS)

/// macOS-styled undo banner for deleted items.
/// Shows a red trash icon, item name, and undo/dismiss buttons.
struct MacDeleteUndoBanner: View {
    let itemName: String
    let onUndo: () -> Void
    let onDismiss: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "trash.circle.fill")
                .foregroundColor(.red)
                .font(.title2)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 2) {
                Text("Deleted")
                    .font(.caption)
                    .foregroundColor(.secondary)

                Text(itemName)
                    .font(.body)
                    .fontWeight(.medium)
                    .lineLimit(1)
            }

            Spacer()

            Button(action: onUndo) {
                Text("Undo")
                    .font(.headline)
                    .foregroundColor(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 6)
                    .background(Color.red)
                    .cornerRadius(6)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Undo deletion")
            .accessibilityHint("Restores the deleted item")

            Button(action: onDismiss) {
                Image(systemName: "xmark")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(6)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Dismiss")
            .accessibilityHint("Hides this notification")
        }
        .padding(12)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .shadow(color: Color.black.opacity(0.15), radius: 4, x: 0, y: 2)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Deleted \(itemName)")
        .accessibilityHint("Use undo button to restore item")
    }
}

// MARK: - Bulk Delete Undo Banner (macOS) - Task 12.8

/// macOS-styled undo banner for bulk deleted items.
/// Shows a red trash icon, item count, and undo/dismiss buttons.
struct MacBulkDeleteUndoBanner: View {
    let itemCount: Int
    let onUndo: () -> Void
    let onDismiss: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "trash.circle.fill")
                .foregroundColor(.red)
                .font(.title2)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 2) {
                Text("Deleted")
                    .font(.caption)
                    .foregroundColor(.secondary)

                Text("\(itemCount) items")
                    .font(.body)
                    .fontWeight(.medium)
            }

            Spacer()

            Button(action: onUndo) {
                Text("Undo")
                    .font(.headline)
                    .foregroundColor(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 6)
                    .background(Color.red)
                    .cornerRadius(6)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Undo deletion")
            .accessibilityHint("Restores all \(itemCount) deleted items")
            .accessibilityIdentifier("BulkDeleteUndoButton")

            Button(action: onDismiss) {
                Image(systemName: "xmark")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(6)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Dismiss")
            .accessibilityHint("Hides this notification")
        }
        .padding(12)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .shadow(color: Color.black.opacity(0.15), radius: 4, x: 0, y: 2)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Deleted \(itemCount) items")
        .accessibilityHint("Use undo button to restore all items")
        .accessibilityIdentifier("BulkDeleteUndoBanner")
    }
}
