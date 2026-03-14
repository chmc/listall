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
        case security
        case sync
        case data
        case about
    }

    @State private var selectedTab: SettingsTab = .general

    var body: some View {
        TabView(selection: $selectedTab) {
            MacSettingsGeneralTab()
                .tabItem {
                    Label("General", systemImage: "gear")
                }
                .tag(SettingsTab.general)

            MacSettingsSecurityTab()
                .tabItem {
                    Label("Security", systemImage: "lock.shield")
                }
                .tag(SettingsTab.security)

            MacSettingsSyncTab()
                .tabItem {
                    Label("Sync", systemImage: "arrow.triangle.2.circlepath")
                }
                .tag(SettingsTab.sync)

            MacSettingsDataTab()
                .tabItem {
                    Label("Data", systemImage: "externaldrive")
                }
                .tag(SettingsTab.data)

            MacSettingsAboutTab()
                .tabItem {
                    Label("About", systemImage: "info.circle")
                }
                .tag(SettingsTab.about)
        }
        .frame(minWidth: 500, idealWidth: 550, minHeight: 480, idealHeight: 500)
    }
}

#Preview {
    MacSettingsView()
        .environmentObject(DataManager.shared)
}
