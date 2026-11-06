import SwiftUI

/// Empty state view for when there are no lists
struct WatchEmptyStateView: View {
    /// Asks the iPhone for its lists
    let onSync: () async -> Void

    @State private var isSyncing = false

    var body: some View {
        // Scrolls with the Digital Crown so the message and button fit on small watches
        ScrollView {
            content
        }
    }

    private var content: some View {
        VStack(spacing: 12) {
            Image(systemName: "list.bullet")
                .font(.system(size: 40))
                .foregroundColor(.secondary)
                .accessibilityIdentifier("WatchEmptyState_Icon")

            Text(watchLocalizedString("No Lists", comment: "watchOS empty state title when there are no lists"))
                .font(.headline)
                .foregroundColor(.primary)
                .accessibilityIdentifier("WatchEmptyState_Title")

            Text(watchLocalizedString("Lists from your iPhone appear here", comment: "watchOS empty state message for lists"))
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal)
                .accessibilityIdentifier("WatchEmptyState_Message")

            Button {
                Task {
                    isSyncing = true
                    await onSync()
                    isSyncing = false
                }
            } label: {
                Label(watchLocalizedString("Sync with iPhone", comment: "watchOS empty state button that asks the iPhone for its lists"),
                      systemImage: "arrow.triangle.2.circlepath")
            }
            .disabled(isSyncing)
            .accessibilityIdentifier("WatchEmptyState_SyncButton")
        }
        .padding()
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("WatchEmptyStateView")
    }
}

// MARK: - Preview
#Preview {
    WatchEmptyStateView(onSync: {})
}
