//
//  MacAllFeatureTipsView.swift
//  ListAllMac
//
//  Displays all feature tips with their viewed status.
//

import SwiftUI

/// View displaying all feature tips available in the app
struct MacAllFeatureTipsView: View {
    @StateObject private var tooltipManager = MacTooltipManager.shared
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Feature Tips")
                    .font(.headline)
                    .accessibilityAddTraits(.isHeader)

                Spacer()

                Text("\(tooltipManager.shownTooltipCount())/\(tooltipManager.totalTooltipCount()) viewed")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .accessibilityLabel("\(tooltipManager.shownTooltipCount()) of \(tooltipManager.totalTooltipCount()) tips viewed")
            }
            .padding()
            .background(Color(NSColor.windowBackgroundColor))

            Divider()

            // Tips List
            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(MacTooltipType.allCases) { tip in
                        MacFeatureTipRow(tip: tip, isViewed: tooltipManager.hasShown(tip))
                        Divider()
                    }
                }
            }

            Divider()

            // Footer
            HStack {
                Text("Tips help you discover features. Reset to see them again.")
                    .font(.caption)
                    .foregroundColor(.secondary)

                Spacer()

                Button("Done") {
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
            }
            .padding()
            .background(Color(NSColor.windowBackgroundColor))
        }
        .frame(width: 450, height: 400)
    }
}

/// A single row displaying a feature tip
private struct MacFeatureTipRow: View {
    let tip: MacTooltipType
    let isViewed: Bool

    var body: some View {
        HStack(spacing: 12) {
            // Status indicator
            Image(systemName: isViewed ? "checkmark.circle.fill" : "circle")
                .foregroundColor(isViewed ? .green : .secondary)
                .font(.title3)
                .accessibilityHidden(true)

            // Icon
            Image(systemName: tip.icon)
                .foregroundColor(.accentColor)
                .font(.title2)
                .frame(width: 28)
                .accessibilityHidden(true)

            // Content
            VStack(alignment: .leading, spacing: 4) {
                Text(tip.title)
                    .font(.body)
                    .fontWeight(.medium)

                Text(tip.message)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
            }

            Spacer()
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(tip.title). \(tip.message). \(isViewed ? "Viewed" : "Not viewed")")
    }
}

#Preview {
    MacAllFeatureTipsView()
}
