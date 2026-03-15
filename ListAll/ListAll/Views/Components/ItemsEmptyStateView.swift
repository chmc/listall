import SwiftUI

/// Empty state view for items list
struct ItemsEmptyStateView: View {
    let hasItems: Bool
    let totalCount: Int
    let completedCount: Int
    let onAddItem: () -> Void

    init(hasItems: Bool, totalCount: Int = 0, completedCount: Int = 0, onAddItem: @escaping () -> Void) {
        self.hasItems = hasItems
        self.totalCount = totalCount
        self.completedCount = completedCount
        self.onAddItem = onAddItem
    }

    var body: some View {
        VStack(spacing: Theme.Spacing.lg) {
            if hasItems {
                celebrationState
            } else {
                helpfulState
            }
        }
        .padding(.horizontal, Theme.Spacing.xl)
    }

    private var celebrationState: some View {
        VStack(spacing: Theme.Spacing.lg) {
            // Green checkmark circle with glow
            ZStack {
                Circle()
                    .fill(LinearGradient(
                        colors: [Theme.Colors.completedGreen.opacity(0.2), Theme.Colors.completedGreen.opacity(0.1)],
                        startPoint: .topLeading, endPoint: .bottomTrailing
                    ))
                    .shadow(color: Theme.Colors.completedGreen.opacity(0.2), radius: 12)
                    .frame(width: 100, height: 100)

                Image(systemName: "checkmark")
                    .font(.system(size: 44, weight: .bold))
                    .foregroundColor(.white)
            }

            Text(String(localized: "All Done!"))
                .font(Theme.Typography.largeTitle)
                .fontWeight(.bold)

            Text(String(localized: "Every item has been checked off."))
                .font(Theme.Typography.body)
                .foregroundColor(Theme.Colors.secondary)
                .multilineTextAlignment(.center)

            if totalCount > 0 {
                Text(String(localized: "\(completedCount)/\(totalCount) items completed"))
                    .font(Theme.Typography.callout)
                    .foregroundColor(Theme.Colors.secondary)
            }
        }
    }

    private var helpfulState: some View {
        VStack(spacing: Theme.Spacing.lg) {
            // Plus icon in rounded square
            Image(systemName: "plus.square")
                .font(.system(size: 48, weight: .light))
                .foregroundColor(.secondary.opacity(0.4))

            Text(String(localized: "No Items Yet"))
                .font(Theme.Typography.title)
                .fontWeight(.bold)

            Text(String(localized: "Add your first item to get started."))
                .font(Theme.Typography.body)
                .foregroundColor(Theme.Colors.secondary)
                .multilineTextAlignment(.center)

            Button(action: onAddItem) {
                Text(String(localized: "Add First Item"))
                    .font(Theme.Typography.headline)
                    .foregroundColor(.white)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                    .background(Theme.Colors.brandGradient)
                    .cornerRadius(Theme.CornerRadius.md)
            }
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
    ItemsEmptyStateView(hasItems: true, totalCount: 6, completedCount: 6, onAddItem: { })
}
