import SwiftUI

/// Custom pull-to-refresh component for watchOS with dynamic text and animated refresh icon
struct WatchPullToRefreshView<Content: View>: View {
    let content: Content
    let onRefresh: () async -> Void
    
    @State private var isPulling = false
    @State private var isRefreshing = false
    @State private var pullOffset: CGFloat = 0
    @State private var refreshRotation: Double = 0
    
    private let pullThreshold: CGFloat = 60
    private let maxPullOffset: CGFloat = 100
    
    init(@ViewBuilder content: () -> Content, onRefresh: @escaping () async -> Void) {
        self.content = content()
        self.onRefresh = onRefresh
    }
    
    var body: some View {
        ZStack(alignment: .top) {
            // Main content
            content
                .offset(y: isRefreshing ? 0 : max(0, pullOffset))
                .animation(.easeOut(duration: 0.3), value: isRefreshing)
            
            // Pull-to-refresh indicator
            if isPulling || isRefreshing {
                VStack(spacing: 8) {
                    if isRefreshing {
                        // Animated refresh icon
                        Image(systemName: "arrow.clockwise")
                            .font(.title2)
                            .foregroundColor(.blue)
                            .rotationEffect(.degrees(refreshRotation))
                            .animation(
                                .linear(duration: 1.0).repeatForever(autoreverses: false),
                                value: refreshRotation
                            )
                            .onAppear {
                                refreshRotation = 360
                            }
                    } else {
                        // Pull down text
                        HStack(spacing: 4) {
                            Image(systemName: "arrow.down")
                                .font(.caption)
                                .foregroundColor(.blue)
                            Text(watchLocalizedString("Pull down to refresh", comment: "watchOS pull-to-refresh instruction text"))
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.top, 8)
                .opacity(isRefreshing ? 1.0 : min(1.0, pullOffset / pullThreshold))
                .animation(.easeInOut(duration: 0.2), value: isRefreshing)
                .animation(.easeInOut(duration: 0.2), value: pullOffset)
            }
            
            // Invisible pull-to-refresh area at the top
            VStack {
                Rectangle()
                    .fill(Color.clear)
                    .frame(height: 20)
                    .contentShape(Rectangle())
                    .gesture(
                        DragGesture(minimumDistance: 0)
                            .onChanged { value in
                                let translation = value.translation.height
                                
                                // Only respond to downward pulls when not refreshing
                                if translation > 0 && !isRefreshing {
                                    pullOffset = min(translation, maxPullOffset)
                                    isPulling = true
                                }
                            }
                            .onEnded { value in
                                let translation = value.translation.height
                                
                                if translation > pullThreshold && !isRefreshing {
                                    // Trigger refresh
                                    isRefreshing = true
                                    isPulling = false
                                    
                                    Task {
                                        await onRefresh()
                                        
                                        // Reset states after refresh
                                        await MainActor.run {
                                            withAnimation(.easeOut(duration: 0.3)) {
                                                isRefreshing = false
                                                pullOffset = 0
                                                refreshRotation = 0
                                            }
                                        }
                                    }
                                } else {
                                    // Reset if not enough pull
                                    withAnimation(.easeOut(duration: 0.3)) {
                                        isPulling = false
                                        pullOffset = 0
                                    }
                                }
                            }
                    )
                
                Spacer()
            }
        }
    }
}

// MARK: - Preview
#Preview {
    WatchPullToRefreshView {
        ScrollView {
            LazyVStack {
                ForEach(0..<10) { index in
                    Text("Item \(index + 1)")
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(Color.blue.opacity(0.1))
                        .cornerRadius(8)
                        .padding(.horizontal)
                }
            }
        }
    } onRefresh: {
        // Simulate refresh
        try? await Task.sleep(nanoseconds: 2_000_000_000) // 2 seconds
    }
}
