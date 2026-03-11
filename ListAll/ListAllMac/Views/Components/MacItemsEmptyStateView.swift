//
//  MacItemsEmptyStateView.swift
//  ListAllMac
//
//  Empty state views for items list on macOS.
//

import SwiftUI
import AppKit

// MARK: - Items Empty State View

/// Empty state view for items list with usage tips.
/// macOS equivalent of iOS ItemsEmptyStateView.
struct MacItemsEmptyStateView: View {
    let hasItems: Bool
    let isArchived: Bool
    let onAddItem: () -> Void

    init(hasItems: Bool, isArchived: Bool = false, onAddItem: @escaping () -> Void) {
        self.hasItems = hasItems
        self.isArchived = isArchived
        self.onAddItem = onAddItem
    }

    var body: some View {
        VStack(spacing: 20) {
            if hasItems {
                // All items crossed out - celebration state
                if isArchived {
                    archivedCelebrationState
                } else {
                    celebrationState
                }
            } else if isArchived {
                // Archived list with no items - read-only state
                archivedEmptyState
            } else {
                // No items yet - helpful state
                helpfulState
            }
        }
        .padding(.horizontal, 32)
    }

    @ViewBuilder
    private var archivedEmptyState: some View {
        VStack(spacing: 20) {
            Image(systemName: "archivebox")
                .font(.system(size: 48))
                .foregroundColor(.secondary)
                .accessibilityHidden(true)

            Text(String(localized: "Empty Archived List"))
                .font(.title2)

            Text(String(localized: "This archived list has no items. Restore it to add items."))
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
    }

    @ViewBuilder
    private var archivedCelebrationState: some View {
        VStack(spacing: 20) {
            celebrationIcon
                .accessibilityHidden(true)

            Text(String(localized: "All Done!"))
                .font(.title)
                .fontWeight(.bold)

            Text(String(localized: "All items in this archived list were completed."))
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
    }

    @ViewBuilder
    private var celebrationState: some View {
        VStack(spacing: 20) {
            celebrationIcon
                .accessibilityHidden(true)

            Text(String(localized: "All Done!"))
                .font(.title)
                .fontWeight(.bold)

            Text(String(localized: "You've completed all items in this list."))
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)

            // Tips
            VStack(alignment: .leading, spacing: 8) {
                Text(String(localized: "What's next?"))
                    .font(.headline)
                    .padding(.top, 8)

                MacTipRow(icon: "eye", text: String(localized: "Toggle the eye icon to see completed items"))
                MacTipRow(icon: "plus.circle", text: String(localized: "Add more items to continue"))
                MacTipRow(icon: "arrow.left", text: String(localized: "Go back to view your other lists"))
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color(NSColor.controlBackgroundColor))
            )
        }
    }

    @ViewBuilder
    private var helpfulState: some View {
        VStack(spacing: 20) {
            Image(systemName: "list.bullet.rectangle")
                .font(.system(size: 48))
                .foregroundColor(.secondary)
                .accessibilityHidden(true)

            Text(String(localized: "No Items Yet"))
                .font(.title2)

            Text(String(localized: "Start adding items to your list"))
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)

            // Add item button
            Button(action: onAddItem) {
                HStack {
                    Image(systemName: Constants.UI.addIcon)
                    Text(String(localized: "Add Your First Item"))
                }
                .font(.headline)
            }
            .buttonStyle(.borderedProminent)

            // Usage tips
            VStack(alignment: .leading, spacing: 8) {
                Text(String(localized: "Quick Tips"))
                    .font(.headline)
                    .padding(.top, 8)

                MacTipRow(icon: "hand.tap", text: String(localized: "Click an item to mark it complete"))
                MacTipRow(icon: "pencil", text: String(localized: "Double-click to edit details"))
                MacTipRow(icon: "photo", text: String(localized: "Add photos, quantities, and descriptions"))
                MacTipRow(icon: "wand.and.stars", text: String(localized: "Get smart suggestions as you type"))
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color(NSColor.controlBackgroundColor))
            )
        }
    }

    /// Shared celebration icon used by both active and archived celebration states.
    private var celebrationIcon: some View {
        ZStack {
            Circle()
                .fill(LinearGradient(
                    colors: [Theme.Colors.completedGreen.opacity(0.2), Theme.Colors.completedGreen.opacity(0.1)],
                    startPoint: .topLeading, endPoint: .bottomTrailing
                ))
                .shadow(color: Theme.Colors.completedGreen.opacity(0.2), radius: 12)
                .frame(width: 80, height: 80)

            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 48))
                .foregroundColor(Theme.Colors.completedGreen)
        }
    }
}

// MARK: - Tip Row

/// Tip row component for empty state views.
struct MacTipRow: View {
    let icon: String
    let text: String

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 12))
                .foregroundColor(Theme.Colors.primary)
                .frame(width: 20)
                .accessibilityHidden(true)

            Text(text)
                .font(.callout)
                .foregroundColor(.secondary)

            Spacer()
        }
        .accessibilityElement(children: .combine)
    }
}

// MARK: - Previews

#Preview("Items Empty State - No Items") {
    MacItemsEmptyStateView(hasItems: false, isArchived: false, onAddItem: { })
        .frame(width: 500, height: 400)
}

#Preview("Items Empty State - All Complete") {
    MacItemsEmptyStateView(hasItems: true, isArchived: false, onAddItem: { })
        .frame(width: 500, height: 400)
}

#Preview("Items Empty State - Archived Empty") {
    MacItemsEmptyStateView(hasItems: false, isArchived: true, onAddItem: { })
        .frame(width: 500, height: 400)
}

#Preview("Items Empty State - Archived All Complete") {
    MacItemsEmptyStateView(hasItems: true, isArchived: true, onAddItem: { })
        .frame(width: 500, height: 400)
}
