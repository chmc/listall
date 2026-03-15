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
    let totalItems: Int
    let onAddItem: () -> Void

    init(hasItems: Bool, isArchived: Bool = false, totalItems: Int = 0, onAddItem: @escaping () -> Void) {
        self.hasItems = hasItems
        self.isArchived = isArchived
        self.totalItems = totalItems
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

            if totalItems > 0 {
                Text("\(totalItems)/\(totalItems) \(String(localized: "items completed"))")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            } else {
                Text(String(localized: "You've completed all items in this list."))
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
    }

    @ViewBuilder
    private var helpfulState: some View {
        VStack(spacing: 20) {
            // Icon in circle matching mockup
            ZStack {
                Circle()
                    .fill(Theme.Colors.primary.opacity(0.1))
                    .frame(width: 80, height: 80)

                Image(systemName: "square")
                    .font(.system(size: 32))
                    .foregroundColor(.secondary.opacity(0.4))
            }
            .accessibilityHidden(true)

            Text(String(localized: "No Items Yet"))
                .font(.title2)
                .fontWeight(.bold)

            Text(String(localized: "Start adding items to your list"))
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)

            // Add item button - teal
            Button(action: onAddItem) {
                Text(String(localized: "Add First Item"))
                    .font(.headline)
            }
            .buttonStyle(.borderedProminent)
            .tint(Theme.Colors.primary)

            // Usage tips - simple bullet text matching mockup
            VStack(alignment: .leading, spacing: 8) {
                Text(String(localized: "QUICK TIPS"))
                    .font(.system(size: 9, weight: .semibold))
                    .tracking(1.2)
                    .foregroundColor(.secondary.opacity(0.5))
                    .textCase(.uppercase)
                    .padding(.bottom, 2)

                MacSimpleTipRow(text: String(localized: "Tap + to add items quickly"))
                MacSimpleTipRow(text: String(localized: "Drag to reorder items"))
                MacSimpleTipRow(text: String(localized: "Swipe left to delete"))
            }
            .frame(maxWidth: .infinity, alignment: .leading)
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

// MARK: - Simple Tip Row

/// Simple bullet-point tip row for empty state views (no icon).
struct MacSimpleTipRow: View {
    let text: String

    var body: some View {
        HStack(spacing: 8) {
            Text("\u{2022}")
                .font(.callout)
                .foregroundColor(.secondary.opacity(0.5))

            Text(text)
                .font(.callout)
                .foregroundColor(.secondary)

            Spacer()
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
    MacItemsEmptyStateView(hasItems: true, totalItems: 6, onAddItem: { })
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
