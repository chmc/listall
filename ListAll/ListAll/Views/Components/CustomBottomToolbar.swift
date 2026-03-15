import SwiftUI

// MARK: - Custom Bottom Toolbar Component
struct CustomBottomToolbar: View {
    let onListsTap: () -> Void
    let onSettingsTap: () -> Void

    var body: some View {
        HStack(spacing: 0) {
            // Lists Button (Active/Selected)
            Button(action: onListsTap) {
                VStack(spacing: 4) {
                    Image(systemName: Constants.UI.listIcon)
                        .font(.system(size: 24))
                        .foregroundColor(.accentColor)
                    Text(String(localized: "Lists"))
                        .font(.system(size: 10))
                        .foregroundColor(.accentColor)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
            }
            .hoverEffect(.highlight)  // Task 16.16: iPad trackpad hover effect
            .accessibilityLabel(String(localized: "Lists"))

            // Settings Button
            Button(action: onSettingsTap) {
                VStack(spacing: 4) {
                    Image(systemName: Constants.UI.settingsIcon)
                        .font(.system(size: 24))
                        .foregroundColor(.gray)
                    Text(String(localized: "Settings"))
                        .font(.system(size: 10))
                        .foregroundColor(.gray)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
            }
            .hoverEffect(.highlight)  // Task 16.16: iPad trackpad hover effect
            .accessibilityLabel(String(localized: "Settings"))
            .accessibilityIdentifier("SettingsButton")
        }
        .frame(height: 50)
        .padding(.bottom, 8)
    }
}
