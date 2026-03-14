//
//  MacSettingsAboutTab.swift
//  ListAllMac
//
//  About settings tab for macOS preferences.
//

import SwiftUI

struct MacSettingsAboutTab: View {
    private var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
    }

    private var buildNumber: String {
        Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
    }

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "list.bullet.clipboard")
                .font(.system(size: 64))
                .foregroundColor(Theme.Colors.primary)
                .accessibilityHidden(true)

            Text("ListAll")
                .font(.title)
                .fontWeight(.bold)
                .accessibilityAddTraits(.isHeader)

            Text("Version \(appVersion) (\(buildNumber))")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .accessibilityLabel("Version \(appVersion), build \(buildNumber)")

            Divider()

            Text("A simple, elegant list management app for iOS, watchOS, and macOS.")
                .font(.body)
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)

            VStack(spacing: 4) {
                Text("Created by \(Constants.Creator.name)")
                    .font(.body)
                Text(Constants.Creator.copyrightNotice)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()

            HStack(spacing: 16) {
                Link("Visit Website", destination: URL(string: Constants.Creator.websiteURL)!)
                    .font(.caption)
                    .accessibilityHint("Opens ListAll website in browser")

                Link("View Source Code", destination: URL(string: Constants.Creator.githubURL)!)
                    .font(.caption)
                    .accessibilityHint("Opens GitHub repository in browser")
            }
        }
        .padding()
    }
}
