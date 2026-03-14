//
//  MacSettingsSyncTab.swift
//  ListAllMac
//
//  Sync settings tab for macOS preferences.
//

import SwiftUI

struct MacSettingsSyncTab: View {
    var body: some View {
        Form {
            Section {
                HStack {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                        .accessibilityHidden(true)
                    Text("iCloud Sync: Enabled")
                        .fontWeight(.medium)
                }
                .accessibilityElement(children: .combine)
                .accessibilityLabel("iCloud Sync is enabled")

                Text("Your lists automatically sync across all your Apple devices signed into the same iCloud account.")
                    .font(.caption)
                    .foregroundColor(.secondary)

                Text("Sync is built into the app and works automatically in the background.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            } header: {
                Text("iCloud")
                    .accessibilityAddTraits(.isHeader)
            }
        }
        .formStyle(.grouped)
        .padding(.horizontal, -20)
    }
}
