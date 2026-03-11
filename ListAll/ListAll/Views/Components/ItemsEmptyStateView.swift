import SwiftUI

/// Empty state view for items list with usage tips
struct ItemsEmptyStateView: View {
    let hasItems: Bool
    let onAddItem: () -> Void

    var body: some View {
        VStack(spacing: Theme.Spacing.lg) {
            if hasItems {
                // All items crossed out - celebration state
                celebrationState
            } else {
                // No items yet - helpful state
                helpfulState
            }
        }
        .padding(.horizontal, Theme.Spacing.xl)
    }

    private var celebrationState: some View {
        VStack(spacing: Theme.Spacing.lg) {
            // Celebration icon
            ZStack {
                Circle()
                    .fill(LinearGradient(
                        colors: [Theme.Colors.completedGreen.opacity(0.2), Theme.Colors.completedGreen.opacity(0.1)],
                        startPoint: .topLeading, endPoint: .bottomTrailing
                    ))
                    .shadow(color: Theme.Colors.completedGreen.opacity(0.2), radius: 12)
                    .frame(width: 100, height: 100)

                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 60))
                    .foregroundColor(Theme.Colors.completedGreen)
            }

            Text(String(localized: "All Done! 🎉"))
                .font(Theme.Typography.largeTitle)
                .fontWeight(.bold)

            Text(String(localized: "You've completed all items in this list."))
                .font(Theme.Typography.body)
                .foregroundColor(Theme.Colors.secondary)
                .multilineTextAlignment(.center)

            VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                Text(String(localized: "What's next?"))
                    .font(Theme.Typography.headline)
                    .padding(.top, Theme.Spacing.md)

                TipRow(icon: "eye", text: "Toggle the eye icon to see completed items")
                TipRow(icon: "plus.circle", text: "Add more items to continue")
                TipRow(icon: "arrow.left", text: "Go back to view your other lists")
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(Theme.Spacing.md)
            .background(
                RoundedRectangle(cornerRadius: Theme.CornerRadius.md)
                    .fill(Color(UIColor.secondarySystemGroupedBackground))
            )
        }
    }

    private var helpfulState: some View {
        VStack(spacing: Theme.Spacing.lg) {
            Image(systemName: "list.bullet.rectangle")
                .font(.system(size: 60))
                .foregroundColor(Theme.Colors.secondary)

            Text(String(localized: "No Items Yet"))
                .font(Theme.Typography.title)

            Text(String(localized: "Start adding items to your list"))
                .font(Theme.Typography.body)
                .foregroundColor(Theme.Colors.secondary)
                .multilineTextAlignment(.center)

            // Add item button
            Button(action: onAddItem) {
                HStack {
                    Image(systemName: Constants.UI.addIcon)
                    Text(String(localized: "Add Your First Item"))
                }
                .font(Theme.Typography.headline)
                .foregroundColor(.white)
                .padding()
                .background(Theme.Colors.brandGradient)
                .cornerRadius(Theme.CornerRadius.md)
            }

            // Usage tips
            VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                Text("💡 Quick Tips")
                    .font(Theme.Typography.headline)
                    .padding(.top, Theme.Spacing.md)

                TipRow(icon: "hand.tap", text: "Tap an item to mark it complete")
                TipRow(icon: "arrow.right.circle", text: "Tap the arrow to edit details")
                TipRow(icon: "photo", text: "Add photos, quantities, and descriptions")
                TipRow(icon: "wand.and.stars", text: "Get smart suggestions as you type")
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(Theme.Spacing.md)
            .background(
                RoundedRectangle(cornerRadius: Theme.CornerRadius.md)
                    .fill(Color(UIColor.secondarySystemGroupedBackground))
            )
        }
    }
}

/// Tip row component
struct TipRow: View {
    let icon: String
    let text: String

    var body: some View {
        HStack(spacing: Theme.Spacing.sm) {
            Image(systemName: icon)
                .font(.system(size: 14))
                .foregroundColor(Theme.Colors.primary)
                .frame(width: 24)

            Text(text)
                .font(Theme.Typography.body)
                .foregroundColor(Theme.Colors.secondary)

            Spacer()
        }
    }
}

#Preview("Items Empty State - No Items") {
    ItemsEmptyStateView(hasItems: false, onAddItem: { })
}

#Preview("Items Empty State - All Complete") {
    ItemsEmptyStateView(hasItems: true, onAddItem: { })
}
