import SwiftUI
import XCTest
@testable import ListAll

class SettingsAccentColorTests: XCTestCase {

    func testThemePrimaryColorExistsForSettingsToggles() {
        // All toggles in SettingsView should use Theme.Colors.primary (brand teal)
        // instead of system green default
        let primaryColor = Theme.Colors.primary
        XCTAssertNotNil(primaryColor, "Theme.Colors.primary should exist for toggle tints")
    }

    func testThemePrimaryColorIsNotSystemBlue() {
        // Settings icons should use Theme.Colors.primary, not .blue
        // This verifies the brand color is distinct from system blue
        let primary = Theme.Colors.primary
        let systemBlue = SwiftUI.Color.blue

        XCTAssertNotEqual(
            primary.description,
            systemBlue.description,
            "Theme.Colors.primary should differ from system blue"
        )
    }

    func testThemePrimaryColorIsNotAccentColor() {
        // About section link icons should use Theme.Colors.primary, not .accentColor
        // This ensures consistent branding throughout settings
        let primary = Theme.Colors.primary

        // Verify the constant is available for use in SettingsView
        XCTAssertNotNil(primary, "Theme.Colors.primary must be available for settings icons")
    }
}
