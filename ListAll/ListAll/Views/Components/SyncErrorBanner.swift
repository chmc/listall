//
//  SyncErrorBanner.swift
//  ListAll
//
//  Banner shown when iCloud sync export failures are detected.
//

import SwiftUI

struct SyncErrorBanner: View {
    let onDismiss: () -> Void

    var body: some View {
        HStack(spacing: Theme.Spacing.md) {
            Image(systemName: "icloud.slash")
                .foregroundColor(.orange)
                .font(.title3)

            VStack(alignment: .leading, spacing: 2) {
                Text(String(localized: "iCloud Sync Error"))
                    .font(Theme.Typography.caption)
                    .foregroundColor(.secondary)

                Text(String(localized: "Your lists aren't syncing. Check iCloud in Settings."))
                    .font(Theme.Typography.body)
                    .fontWeight(.medium)
                    .lineLimit(2)
            }

            Spacer()

            Button(action: onDismiss) {
                Image(systemName: "xmark")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(Theme.Spacing.sm)
            }
            .accessibilityLabel("Dismiss")
        }
        .padding(Theme.Spacing.md)
        .background(
            RoundedRectangle(cornerRadius: Theme.CornerRadius.lg)
                .fill(Theme.Colors.background)
                .shadow(color: Theme.Shadow.largeColor, radius: Theme.Shadow.largeRadius,
                        x: Theme.Shadow.largeX, y: Theme.Shadow.largeY)
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel(String(localized: "Sync error: Your lists aren't syncing"))
    }
}
