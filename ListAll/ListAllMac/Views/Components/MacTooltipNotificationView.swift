//
//  MacTooltipNotificationView.swift
//  ListAllMac
//
//  Toast-style notification view for proactive feature tips.
//  Displays tips in the top-right corner with dismiss capability.
//  Part of Task 12.5: Add Proactive Feature Tips
//

import SwiftUI

/// Toast-style notification view for displaying proactive feature tips
/// Appears in top-right corner with slide-in animation
struct MacTooltipNotificationView: View {
    let tip: MacTooltipType
    let onDismiss: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            // Tip icon
            Image(systemName: tip.icon)
                .font(.title2)
                .foregroundColor(.accentColor)
                .accessibilityHidden(true)

            // Tip content
            VStack(alignment: .leading, spacing: 4) {
                Text(tip.title)
                    .font(.headline)
                    .foregroundColor(.primary)

                Text(tip.message)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
            }

            Spacer()

            // Dismiss button
            Button(action: onDismiss) {
                Image(systemName: "xmark.circle.fill")
                    .font(.title3)
                    .foregroundColor(.secondary)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Dismiss tip")
        }
        .padding()
        .background(.regularMaterial)
        .cornerRadius(10)
        .shadow(color: .black.opacity(0.15), radius: 5, x: 0, y: 2)
        .frame(maxWidth: 350)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Feature tip: \(tip.title). \(tip.message)")
        .accessibilityAddTraits(.isButton)
        .accessibilityHint("Double tap to dismiss")
        .accessibilityIdentifier("FeatureTipNotification")
    }
}

// MARK: - Preview

#if DEBUG
struct MacTooltipNotificationView_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: 20) {
            ForEach(MacTooltipType.allCases) { tip in
                MacTooltipNotificationView(tip: tip, onDismiss: {})
            }
        }
        .padding()
        .frame(width: 400)
    }
}
#endif
