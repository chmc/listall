import SwiftUI

/// Empty state view for when there are no lists
struct WatchEmptyStateView: View {
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "list.bullet")
                .font(.system(size: 40))
                .foregroundColor(.secondary)
                .accessibilityIdentifier("WatchEmptyState_Icon")

            Text(watchLocalizedString("No Lists", comment: "watchOS empty state title when there are no lists"))
                .font(.headline)
                .foregroundColor(.primary)
                .accessibilityIdentifier("WatchEmptyState_Title")

            Text(watchLocalizedString("Create lists on your iPhone to see them here", comment: "watchOS empty state message for lists"))
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
                .accessibilityIdentifier("WatchEmptyState_Message")
        }
        .padding()
        .accessibilityIdentifier("WatchEmptyStateView")
        .accessibilityLabel(watchLocalizedString("No lists available", comment: "watchOS accessibility label for empty lists state"))
        .accessibilityHint(watchLocalizedString("Create lists on your iPhone to see them here", comment: "watchOS empty state message for lists"))
    }
}

// MARK: - Preview
#Preview {
    WatchEmptyStateView()
}


