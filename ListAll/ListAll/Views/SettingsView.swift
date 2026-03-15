import SwiftUI

struct SettingsView: View {
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @State private var showingExportSheet = false
    @State private var showingImportSheet = false
    @State private var showingResetTooltipsAlert = false
    @State private var showingAllTips = false
    @State private var showingLanguageRestartAlert = false
    @AppStorage(Constants.UserDefaultsKeys.addButtonPosition) private var addButtonPositionRaw: String = Constants.AddButtonPosition.right.rawValue
    @AppStorage(Constants.UserDefaultsKeys.requiresBiometricAuth) private var requiresBiometricAuth = false
    @AppStorage(Constants.UserDefaultsKeys.authTimeoutDuration) private var authTimeoutDurationRaw: Int = Constants.AuthTimeoutDuration.immediate.rawValue
    @AppStorage("defaultListSortOrder") private var defaultSortOrder = "orderNumber"  // Task 15.7
    @StateObject private var biometricService = BiometricAuthService.shared
    @StateObject private var hapticManager = HapticManager.shared
    @StateObject private var tooltipManager = TooltipManager.shared
    @StateObject private var localizationManager = LocalizationManager.shared
    
    private var addButtonPosition: Binding<Constants.AddButtonPosition> {
        Binding(
            get: { Constants.AddButtonPosition(rawValue: addButtonPositionRaw) ?? .right },
            set: { addButtonPositionRaw = $0.rawValue }
        )
    }
    
    private var authTimeoutDuration: Binding<Constants.AuthTimeoutDuration> {
        Binding(
            get: { Constants.AuthTimeoutDuration(rawValue: authTimeoutDurationRaw) ?? .immediate },
            set: { authTimeoutDurationRaw = $0.rawValue }
        )
    }
    
    private var biometricType: BiometricType {
        biometricService.biometricType()
    }
    
    // MARK: - App Version Helper
    private var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "-"
    }
    /// Whether this view is embedded in a NavigationSplitView detail column (iPad)
    /// When true, skip the NavigationView wrapper since navigation context is already provided
    private var isEmbeddedInSplitView: Bool {
        horizontalSizeClass == .regular
    }

    var body: some View {
        settingsContent
            .sheet(isPresented: $showingExportSheet) {
                ExportView()
            }
            .sheet(isPresented: $showingImportSheet) {
                ImportView()
            }
            .sheet(isPresented: $showingAllTips) {
                AllFeatureTipsView()
            }
            .alert("Reset All Tips", isPresented: $showingResetTooltipsAlert) {
                Button("Cancel", role: .cancel) { }
                Button("Reset", role: .destructive) {
                    tooltipManager.resetAllTooltips()
                }
            } message: {
                Text("This will show all feature tips again as if you're using the app for the first time. Tips will appear when you use different features.")
            }
            .alert("Language Changed", isPresented: $showingLanguageRestartAlert) {
                Button("OK", role: .cancel) { }
            } message: {
                Text("The language has been changed. Some changes will take effect immediately, but you may need to restart the app for all text to update.")
            }
    }

    @ViewBuilder
    private var settingsContent: some View {
        if isEmbeddedInSplitView {
            // iPad: No NavigationView wrapper — detail column provides navigation context
            settingsList
                .navigationTitle("Settings")
                .navigationBarTitleDisplayMode(.large)
        } else {
            // iPhone: Wrap in NavigationView for sheet presentation
            NavigationView {
                settingsList
                    .navigationTitle("Settings")
                    .navigationBarTitleDisplayMode(.large)
            }
        }
    }

    private var settingsList: some View {
        SwiftUI.List {
            Section(header: Text("Language"), footer: Text("Change the app language. You may need to restart the app for all changes to take effect.")) {
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
                    .pickerStyle(.navigationLink)
                }
                
                Section(header: Text("Display"), footer: Text("Haptic feedback provides tactile responses for app interactions")) {
                    Picker("Add item button position", selection: addButtonPosition) {
                        ForEach(Constants.AddButtonPosition.allCases) { position in
                            Text(position.displayName).tag(position)
                        }
                    }

                    // Task 15.7: Default sort order picker
                    Picker("Default Sort Order", selection: $defaultSortOrder) {
                        Text("Manual").tag("orderNumber")
                        Text("Name").tag("name")
                        Text("Date Created").tag("createdAt")
                        Text("Date Modified").tag("modifiedAt")
                    }
                    .accessibilityLabel("Default sort order for lists")

                    Toggle(isOn: $hapticManager.isEnabled) {
                        HStack {
                            Image(systemName: "waveform")
                                .foregroundColor(.purple)
                            Text("Haptic Feedback")
                        }
                    }
                    .tint(Theme.Colors.primary)
                }
                
                Section(header: Text("Help & Tips"), footer: helpFooterText) {
                    HStack {
                        Image(systemName: "lightbulb.fill")
                            .foregroundColor(.yellow)
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Feature Tips")
                                .font(.body)
                            Text("\(tooltipManager.shownTooltipCount()) of \(tooltipManager.totalTooltipCount()) tips viewed")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                    }
                    
                    Button(action: {
                        showingAllTips = true
                    }) {
                        HStack {
                            Image(systemName: "list.bullet")
                                .foregroundColor(Theme.Colors.primary)
                            Text("View All Feature Tips")
                                .foregroundColor(.primary)
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    .hoverEffect(.highlight)  // Task 16.16: iPad trackpad hover effect

                    Button(action: {
                        showingResetTooltipsAlert = true
                    }) {
                        HStack {
                            Image(systemName: "arrow.counterclockwise")
                                .foregroundColor(Theme.Colors.primary)
                            Text("Show All Tips Again")
                                .foregroundColor(.primary)
                        }
                    }
                    .hoverEffect(.highlight)  // Task 16.16: iPad trackpad hover effect
                }
                
                Section(header: Text("Security"), footer: securityFooterText) {
                    if biometricType != .none {
                        Toggle(isOn: $requiresBiometricAuth) {
                            HStack {
                                Image(systemName: biometricType.iconName)
                                    .foregroundColor(Theme.Colors.primary)
                                Text("Require \(biometricType.displayName)")
                            }
                        }
                        .tint(Theme.Colors.primary)

                        // Show timeout setting only when biometric auth is enabled
                        if requiresBiometricAuth {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Require Authentication")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                
                                Picker("Timeout Duration", selection: authTimeoutDuration) {
                                    ForEach(Constants.AuthTimeoutDuration.allCases) { duration in
                                        VStack(alignment: .leading) {
                                            Text(duration.displayName)
                                                .font(.body)
                                            Text(duration.description)
                                                .font(.caption)
                                                .foregroundColor(.secondary)
                                        }
                                        .tag(duration)
                                    }
                                }
                                .pickerStyle(.navigationLink)
                            }
                        }
                    } else {
                        HStack {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundColor(.orange)
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Biometric authentication not available")
                                    .font(.subheadline)
                                Text("Enable Face ID or Touch ID in Settings")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                }
                
                Section("Data") {
                    Button("Export Data") {
                        showingExportSheet = true
                    }
                    .foregroundColor(Theme.Colors.primary)
                    .hoverEffect(.highlight)  // Task 16.16: iPad trackpad hover effect

                    Button("Import Data") {
                        showingImportSheet = true
                    }
                    .foregroundColor(Theme.Colors.primary)
                    .hoverEffect(.highlight)  // Task 16.16: iPad trackpad hover effect
                }
                
                Section("About") {
                    // App header with icon
                    HStack(spacing: 12) {
                        Image(systemName: "list.bullet.clipboard")
                            .font(.system(size: 40))
                            .foregroundColor(Theme.Colors.primary)

                        VStack(alignment: .leading, spacing: 2) {
                            Text(Constants.App.name)
                                .font(.headline)
                            Text("Version \(appVersion)")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(.vertical, 4)

                    // Creator and copyright
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Created by \(Constants.Creator.name)")
                            .font(.subheadline)
                        Text(Constants.Creator.copyrightNotice)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

                    // Links
                    Link(destination: URL(string: Constants.Creator.websiteURL)!) {
                        HStack {
                            Image(systemName: "globe")
                                .foregroundColor(Theme.Colors.primary)
                            Text("Visit Website")
                                .foregroundColor(.primary)
                            Spacer()
                            Image(systemName: "arrow.up.right")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }

                    Link(destination: URL(string: Constants.Creator.githubURL)!) {
                        HStack {
                            Image(systemName: "chevron.left.forwardslash.chevron.right")
                                .foregroundColor(Theme.Colors.primary)
                            Text("View Source Code")
                                .foregroundColor(.primary)
                            Spacer()
                            Image(systemName: "arrow.up.right")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
        }
    }

    private var helpFooterText: Text {
        return Text(String(localized: "Feature tips help you discover app functionality. Reset to see all tips again."))
    }
    
    private var securityFooterText: Text {
        if biometricType != .none && requiresBiometricAuth {
            let timeoutDesc = authTimeoutDuration.wrappedValue.displayName.lowercased()
            let localizedString = String(format: String(localized: "Authentication will be required %@ when returning to the app. You can use %@ or your device passcode."), timeoutDesc, biometricType.displayName)
            return Text(localizedString)
        } else if biometricType != .none {
            return Text("When enabled, you'll need to authenticate with \(biometricType.displayName) or passcode to unlock the app.")
        } else {
            return Text("Biometric authentication is not set up on this device.")
        }
    }
}

#Preview {
    SettingsView()
}
