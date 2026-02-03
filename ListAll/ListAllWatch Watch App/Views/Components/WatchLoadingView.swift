import SwiftUI

/// Loading view component for watchOS
struct WatchLoadingView: View {
    let message: String
    let showProgress: Bool
    
    init(message: String = watchLocalizedString("Loading...", comment: "watchOS generic loading message"), showProgress: Bool = true) {
        self.message = message
        self.showProgress = showProgress
    }
    
    var body: some View {
        VStack(spacing: 12) {
            if showProgress {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: .blue))
                    .scaleEffect(1.2)
                    .accessibilityIdentifier("WatchLoadingView_Indicator")
            }

            Text(message)
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .accessibilityIdentifier("WatchLoadingView_Message")
        }
        .padding()
        .accessibilityIdentifier("WatchLoadingView")
        .loadingAnimation()
    }
}

/// Sync loading view with pulsing animation
struct WatchSyncLoadingView: View {
    @State private var isPulsing = false

    var body: some View {
        VStack(spacing: 8) {
            HStack(spacing: 4) {
                Circle()
                    .fill(Color.blue)
                    .frame(width: 6, height: 6)
                    .scaleEffect(isPulsing ? 1.2 : 0.8)
                    .animation(.easeInOut(duration: 0.6).repeatForever(autoreverses: true), value: isPulsing)

                Circle()
                    .fill(Color.blue)
                    .frame(width: 6, height: 6)
                    .scaleEffect(isPulsing ? 0.8 : 1.2)
                    .animation(.easeInOut(duration: 0.6).repeatForever(autoreverses: true).delay(0.2), value: isPulsing)

                Circle()
                    .fill(Color.blue)
                    .frame(width: 6, height: 6)
                    .scaleEffect(isPulsing ? 1.2 : 0.8)
                    .animation(.easeInOut(duration: 0.6).repeatForever(autoreverses: true).delay(0.4), value: isPulsing)
            }
            .accessibilityIdentifier("WatchSyncLoadingView_Dots")

            Text(watchLocalizedString("Syncing...", comment: "watchOS sync indicator message"))
                .font(.caption2)
                .foregroundColor(.secondary)
                .accessibilityIdentifier("WatchSyncLoadingView_Message")
        }
        .accessibilityIdentifier("WatchSyncLoadingView")
        .onAppear {
            isPulsing = true
        }
    }
}

/// Error state view with retry button
struct WatchErrorView: View {
    let message: String
    let onRetry: () -> Void

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 30))
                .foregroundColor(.orange)
                .accessibilityIdentifier("WatchErrorView_Icon")

            Text(watchLocalizedString("Error", comment: "watchOS error title"))
                .font(.headline)
                .foregroundColor(.primary)
                .accessibilityIdentifier("WatchErrorView_Title")

            Text(message)
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
                .accessibilityIdentifier("WatchErrorView_Message")

            Button(watchLocalizedString("Retry", comment: "watchOS retry button text")) {
                WatchHapticManager.shared.playRefresh()
                onRetry()
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
            .accessibilityIdentifier("WatchErrorView_RetryButton")
        }
        .padding()
        .accessibilityIdentifier("WatchErrorView")
        .errorAnimation()
    }
}

// MARK: - Preview
#Preview("Loading") {
    WatchLoadingView()
}

#Preview("Sync Loading") {
    WatchSyncLoadingView()
}

#Preview("Error") {
    WatchErrorView(message: "Failed to load lists") {
        // Retry action
    }
}
