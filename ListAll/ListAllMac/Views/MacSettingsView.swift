//
//  MacSettingsView.swift
//  ListAllMac
//
//  Settings view for macOS preferences.
//

import SwiftUI

/// macOS Settings view displayed via Preferences menu (Cmd+,)
struct MacSettingsView: View {
    @EnvironmentObject var dataManager: DataManager

    // Settings tabs
    private enum SettingsTab: Hashable {
        case general
        case sync
        case data
        case about
    }

    @State private var selectedTab: SettingsTab = .general

    var body: some View {
        TabView(selection: $selectedTab) {
            GeneralSettingsTab()
                .tabItem {
                    Label("General", systemImage: "gear")
                }
                .tag(SettingsTab.general)

            SyncSettingsTab()
                .tabItem {
                    Label("Sync", systemImage: "arrow.triangle.2.circlepath")
                }
                .tag(SettingsTab.sync)

            DataSettingsTab()
                .tabItem {
                    Label("Data", systemImage: "externaldrive")
                }
                .tag(SettingsTab.data)

            AboutSettingsTab()
                .tabItem {
                    Label("About", systemImage: "info.circle")
                }
                .tag(SettingsTab.about)
        }
        .frame(width: 450, height: 300)
        .padding()
    }
}

// MARK: - General Settings Tab

private struct GeneralSettingsTab: View {
    @AppStorage("defaultListSortOrder") private var defaultSortOrder = "orderNumber"

    var body: some View {
        Form {
            Section {
                Picker("Default Sort Order", selection: $defaultSortOrder) {
                    Text("Manual").tag("orderNumber")
                    Text("Name").tag("name")
                    Text("Date Created").tag("createdAt")
                    Text("Date Modified").tag("modifiedAt")
                }
                .pickerStyle(.menu)
                .accessibilityLabel("Default sort order")
            } header: {
                Text("Lists")
                    .accessibilityAddTraits(.isHeader)
            }
        }
        .formStyle(.grouped)
    }
}

// MARK: - Sync Settings Tab

private struct SyncSettingsTab: View {
    @AppStorage("iCloudSyncEnabled") private var iCloudSyncEnabled = true

    var body: some View {
        Form {
            Section {
                Toggle("Enable iCloud Sync", isOn: $iCloudSyncEnabled)
                    .accessibilityHint("When enabled, syncs lists across your devices")

                Text("Sync your lists across all your Apple devices using iCloud.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            } header: {
                Text("iCloud")
                    .accessibilityAddTraits(.isHeader)
            }
        }
        .formStyle(.grouped)
    }
}

// MARK: - Data Settings Tab

private struct DataSettingsTab: View {
    var body: some View {
        Form {
            Section {
                Button("Export Data...") {
                    // TODO: Implement export in Task 3.5
                    NotificationCenter.default.post(
                        name: NSNotification.Name("ExportData"),
                        object: nil
                    )
                }
                .accessibilityHint("Opens export options")

                Button("Import Data...") {
                    // TODO: Implement import in Task 3.6
                    NotificationCenter.default.post(
                        name: NSNotification.Name("ImportData"),
                        object: nil
                    )
                }
                .accessibilityHint("Opens file picker to import data")
            } header: {
                Text("Import / Export")
                    .accessibilityAddTraits(.isHeader)
            }
        }
        .formStyle(.grouped)
    }
}

// MARK: - About Settings Tab

private struct AboutSettingsTab: View {
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
                .foregroundColor(.accentColor)
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

            Spacer()

            Link("Visit Website", destination: URL(string: "https://github.com/chmc/listall")!)
                .font(.caption)
                .accessibilityHint("Opens GitHub page in browser")
        }
        .padding()
    }
}

#Preview {
    MacSettingsView()
        .environmentObject(DataManager.shared)
}
