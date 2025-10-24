//
//  WatchEmptyStateView.swift
//  ListAllWatch Watch App
//
//  Created by AI Assistant on 20.10.2025.
//

import SwiftUI

/// Empty state view for when there are no lists
struct WatchEmptyStateView: View {
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "list.bullet")
                .font(.system(size: 40))
                .foregroundColor(.secondary)
            
            Text("No Lists")
                .font(.headline)
                .foregroundColor(.primary)
            
            Text("Create lists on your iPhone to see them here")
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
        }
        .padding()
        .accessibilityLabel("No lists available")
        .accessibilityHint("Create lists on your iPhone to see them here")
    }
}

// MARK: - Preview
#Preview {
    WatchEmptyStateView()
}


