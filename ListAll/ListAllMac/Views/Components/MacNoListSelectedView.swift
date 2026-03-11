//
//  MacNoListSelectedView.swift
//  ListAllMac
//
//  Simple empty state shown when no list is selected in the sidebar.
//

import SwiftUI

// MARK: - No List Selected Empty State

/// Simple empty state shown when no list is selected in the sidebar.
/// Used as a placeholder in the detail view.
struct MacNoListSelectedView: View {
    let onCreateList: () -> Void

    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "list.bullet.clipboard")
                .font(.system(size: 64))
                .foregroundColor(.secondary)
                .accessibilityHidden(true)

            Text("No List Selected")
                .font(.title2)
                .foregroundColor(.secondary)
                .accessibilityAddTraits(.isHeader)

            Text("Select a list from the sidebar or create a new one.")
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)

            Button("Create New List") {
                onCreateList()
            }
            .buttonStyle(.borderedProminent)
            .accessibilityHint("Opens sheet to create new list")
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

#Preview("No List Selected") {
    MacNoListSelectedView(onCreateList: { })
        .frame(width: 600, height: 400)
}
