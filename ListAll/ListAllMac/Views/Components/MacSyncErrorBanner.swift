//
//  MacSyncErrorBanner.swift
//  ListAllMac
//
//  Banner shown when iCloud sync export failures are detected.
//

import SwiftUI

struct MacSyncErrorBanner: View {
    let onDismiss: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "icloud.slash")
                .foregroundColor(.orange)
                .font(.title2)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 2) {
                Text(String(localized: "iCloud Sync Error"))
                    .font(.caption)
                    .foregroundColor(.secondary)

                Text(String(localized: "Your lists aren't syncing. Check iCloud in System Settings."))
                    .font(.body)
                    .fontWeight(.medium)
                    .lineLimit(2)
            }

            Spacer()

            Button(action: onDismiss) {
                Image(systemName: "xmark")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(6)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Dismiss")
        }
        .padding(12)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .shadow(color: Color.black.opacity(0.15), radius: 4, x: 0, y: 2)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(String(localized: "Sync error: Your lists aren't syncing"))
    }
}
