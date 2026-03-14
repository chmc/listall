//
//  MacSettingsSecurityTab.swift
//  ListAllMac
//
//  Security settings tab for macOS preferences.
//

import SwiftUI

struct MacSettingsSecurityTab: View {
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
                    .tint(Theme.Colors.primary)
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
        .padding(.horizontal, -20)
    }
}
