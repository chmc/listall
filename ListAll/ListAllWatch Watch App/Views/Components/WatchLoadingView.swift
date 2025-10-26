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
            }
            
            Text(message)
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding()
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
            
            Text(watchLocalizedString("Syncing...", comment: "watchOS sync indicator message"))
                .font(.caption2)
                .foregroundColor(.secondary)
        }
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
            
            Text(watchLocalizedString("Error", comment: "watchOS error title"))
                .font(.headline)
                .foregroundColor(.primary)
            
            Text(message)
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            
            Button(watchLocalizedString("Retry", comment: "watchOS retry button text")) {
                WatchHapticManager.shared.playRefresh()
                onRetry()
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
        }
        .padding()
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
        print("Retry tapped")
    }
}
