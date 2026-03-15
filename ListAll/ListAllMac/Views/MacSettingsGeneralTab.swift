//
//  MacSettingsGeneralTab.swift
//  ListAllMac
//
//  General settings tab for macOS preferences.
//

import SwiftUI

struct MacSettingsGeneralTab: View {
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
                            .foregroundColor(Theme.Colors.primary)
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
                            .foregroundColor(Theme.Colors.primary)
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
        .padding(.horizontal, -20)
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
