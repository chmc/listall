//
//  MacSettingsView.swift
//  ListAllMac
//
//  Settings view for macOS preferences.
//

import SwiftUI
import UniformTypeIdentifiers

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
            GeneralSettingsTab()
                .tabItem {
                    Label("General", systemImage: "gear")
                }
                .tag(SettingsTab.general)

            SecuritySettingsTab()
                .tabItem {
                    Label("Security", systemImage: "lock.shield")
                }
                .tag(SettingsTab.security)

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
        .frame(minWidth: 500, idealWidth: 550, minHeight: 350, idealHeight: 400)
        .padding()
    }
}

// MARK: - General Settings Tab

private struct GeneralSettingsTab: View {
    @AppStorage("defaultListSortOrder") private var defaultSortOrder = "orderNumber"
    @StateObject private var localizationManager = LocalizationManager.shared
    @StateObject private var tooltipManager = MacTooltipManager.shared
    @State private var showingLanguageRestartAlert = false
    @State private var showingAllTips = false
    @State private var showingResetTooltipsAlert = false

    var body: some View {
        Form {
            Section {
                Picker("App Language", selection: Binding(
                    get: { localizationManager.currentLanguage },
                    set: { newLanguage in
                        localizationManager.setLanguage(newLanguage)
                        showingLanguageRestartAlert = true
                    }
                )) {
                    ForEach(LocalizationManager.AppLanguage.allCases) { language in
                        HStack {
                            Text(language.flagEmoji)
                            Text(language.nativeDisplayName)
                        }
                        .tag(language)
                    }
                }
                .pickerStyle(.menu)
                .accessibilityLabel("App language")

                Text("Change the app language. You may need to restart the app for all changes to take effect.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            } header: {
                Text("Language")
                    .accessibilityAddTraits(.isHeader)
            }

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

            Section {
                HStack {
                    Image(systemName: "lightbulb.fill")
                        .foregroundColor(.yellow)
                        .accessibilityHidden(true)
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Feature Tips")
                            .font(.body)
                        Text("\(tooltipManager.shownTooltipCount()) of \(tooltipManager.totalTooltipCount()) tips viewed")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                }
                .accessibilityElement(children: .combine)
                .accessibilityLabel("Feature Tips. \(tooltipManager.shownTooltipCount()) of \(tooltipManager.totalTooltipCount()) tips viewed")

                Button(action: { showingAllTips = true }) {
                    HStack {
                        Image(systemName: "list.bullet")
                            .foregroundColor(.accentColor)
                            .accessibilityHidden(true)
                        Text("View All Feature Tips")
                        Spacer()
                        Image(systemName: "chevron.right")
                            .foregroundColor(.secondary)
                            .font(.caption)
                            .accessibilityHidden(true)
                    }
                }
                .buttonStyle(.plain)
                .accessibilityHint("Opens a list of all feature tips")

                Button(action: { showingResetTooltipsAlert = true }) {
                    HStack {
                        Image(systemName: "arrow.counterclockwise")
                            .foregroundColor(.accentColor)
                            .accessibilityHidden(true)
                        Text("Show All Tips Again")
                    }
                }
                .buttonStyle(.plain)
                .accessibilityHint("Resets all tips so they can be shown again")
            } header: {
                Text("Help & Tips")
                    .accessibilityAddTraits(.isHeader)
            }
        }
        .formStyle(.grouped)
        .alert("Language Changed", isPresented: $showingLanguageRestartAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text("The language has been changed. Some changes will take effect immediately, but you may need to restart the app for all text to update.")
        }
        .alert("Reset All Tips", isPresented: $showingResetTooltipsAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Reset", role: .destructive) {
                tooltipManager.resetAllTooltips()
            }
        } message: {
            Text("This will reset all feature tips. Tips will appear again when you use different features.")
        }
        .sheet(isPresented: $showingAllTips) {
            MacAllFeatureTipsView()
        }
    }
}

// MARK: - Security Settings Tab

private struct SecuritySettingsTab: View {
    @StateObject private var biometricService = MacBiometricAuthService.shared
    @AppStorage(Constants.UserDefaultsKeys.requiresBiometricAuth) private var requiresBiometricAuth = false
    @AppStorage(Constants.UserDefaultsKeys.authTimeoutDuration) private var authTimeoutDurationRaw: Int = Constants.AuthTimeoutDuration.immediate.rawValue

    private var authTimeoutDuration: Binding<Constants.AuthTimeoutDuration> {
        Binding(
            get: { Constants.AuthTimeoutDuration(rawValue: authTimeoutDurationRaw) ?? .immediate },
            set: { authTimeoutDurationRaw = $0.rawValue }
        )
    }

    private var biometricType: MacBiometricType {
        biometricService.biometricType()
    }

    var body: some View {
        Form {
            Section {
                if biometricType != .none {
                    Toggle(isOn: $requiresBiometricAuth) {
                        HStack {
                            Image(systemName: biometricType.iconName)
                                .foregroundColor(.blue)
                            Text("Require \(biometricType.displayName)")
                        }
                    }
                    .accessibilityHint("When enabled, requires \(biometricType.displayName) to unlock the app")

                    if requiresBiometricAuth {
                        Picker("Require Authentication", selection: authTimeoutDuration) {
                            ForEach(Constants.AuthTimeoutDuration.allCases) { duration in
                                Text(duration.displayName)
                                    .tag(duration)
                            }
                        }
                        .pickerStyle(.menu)
                        .accessibilityLabel("Authentication timeout duration")

                        Text(authTimeoutDuration.wrappedValue.description)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                } else {
                    HStack {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(.orange)
                            .accessibilityHidden(true)
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Touch ID not available")
                                .font(.body)
                            Text("Enable Touch ID in System Settings to use app security features.")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel("Touch ID is not available. Enable Touch ID in System Settings to use app security features.")
                }
            } header: {
                Text("Authentication")
                    .accessibilityAddTraits(.isHeader)
            }
        }
        .formStyle(.grouped)
    }
}

// MARK: - Sync Settings Tab

private struct SyncSettingsTab: View {
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
    }
}

// MARK: - Data Settings Tab

private struct DataSettingsTab: View {
    @StateObject private var importViewModel = ImportViewModel()
    @State private var showingFilePicker = false

    var body: some View {
        Form {
            Section {
                Button("Export Data...") {
                    NotificationCenter.default.post(
                        name: NSNotification.Name("ExportData"),
                        object: nil
                    )
                }
                .accessibilityHint("Opens export options")

                Button("Import Data...") {
                    showingFilePicker = true
                }
                .accessibilityHint("Opens file picker to import data")
                .disabled(importViewModel.isImporting)
            } header: {
                Text("Import / Export")
                    .accessibilityAddTraits(.isHeader)
            }

            // Import Progress Section
            if importViewModel.isImporting {
                Section {
                    if let progress = importViewModel.importProgress {
                        MacImportProgressView(progress: progress)
                    } else {
                        MacImportProgressSimpleView()
                    }
                }
            }

            // Status Messages
            if let errorMessage = importViewModel.errorMessage {
                Section {
                    HStack(alignment: .top, spacing: 8) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(.red)
                            .accessibilityHidden(true)
                        Text(errorMessage)
                            .font(.caption)
                            .foregroundColor(.red)
                    }
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel("Error: \(errorMessage)")
                }
            }

            if let successMessage = importViewModel.successMessage {
                Section {
                    HStack(alignment: .top, spacing: 8) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                            .accessibilityHidden(true)
                        Text(successMessage)
                            .font(.caption)
                            .foregroundColor(.green)
                    }
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel("Success: \(successMessage)")
                }
            }
        }
        .formStyle(.grouped)
        .fileImporter(
            isPresented: $showingFilePicker,
            allowedContentTypes: [.json],
            allowsMultipleSelection: false
        ) { result in
            handleFileImportResult(result)
        }
        .onChange(of: importViewModel.showPreview) { showPreview in
            if showPreview, let preview = importViewModel.importPreview {
                presentImportPreview(preview)
            }
        }
    }

    // MARK: - Private Methods

    private func handleFileImportResult(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            if let url = urls.first {
                importViewModel.showPreviewForFile(url)
            }
        case .failure(let error):
            importViewModel.errorMessage = "Failed to select file: \(error.localizedDescription)"
        }
    }

    private func presentImportPreview(_ preview: ImportPreview) {
        // Use native sheet presenter for reliable presentation
        let previewSheet = MacImportPreviewSheet(
            preview: preview,
            viewModel: importViewModel,
            onDismiss: {
                MacNativeSheetPresenter.shared.dismissSheet()
            }
        )

        MacNativeSheetPresenter.shared.presentSheet(
            previewSheet,
            onCancel: {
                MacNativeSheetPresenter.shared.dismissSheet()
                importViewModel.cancelPreview()
            }
        )
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

#Preview {
    MacSettingsView()
        .environmentObject(DataManager.shared)
}
