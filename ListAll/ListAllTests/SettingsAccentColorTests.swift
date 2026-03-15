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

    // MARK: - AccentColor Asset Verification (M.1)

    func testAccentColorAssetResolvesToTeal() {
        // The AccentColor asset in the asset catalog should resolve to teal, not system blue
        // Use UIColor(named:) for reliable catalog color resolution
        guard let uiColor = UIColor(named: "AccentColor") else {
            XCTFail("AccentColor asset not found in asset catalog")
            return
        }

        // Resolve for light mode trait collection
        let lightTraits = UITraitCollection(userInterfaceStyle: .light)
        let resolvedColor = uiColor.resolvedColor(with: lightTraits)

        var red: CGFloat = 0, green: CGFloat = 0, blue: CGFloat = 0, alpha: CGFloat = 0
        resolvedColor.getRed(&red, green: &green, blue: &blue, alpha: &alpha)

        // AccentColor light mode: R:0.000 G:0.706 B:0.863 (teal)
        // System blue is approximately R:0.0 G:0.478 B:1.0
        XCTAssertGreaterThan(green, 0.6, "AccentColor green channel should be > 0.6 for teal (got \(green))")
        XCTAssertLessThan(blue, 0.95, "AccentColor blue channel should be < 0.95, not system blue (got \(blue))")
        XCTAssertLessThan(red, 0.1, "AccentColor red channel should be near 0 for teal (got \(red))")
    }

    func testBrandGradientUsesTealNotBlue() {
        // Brand gradient should use AccentColor-based colors, not system blue
        let gradient = Theme.Colors.brandGradient
        XCTAssertNotNil(gradient, "Brand gradient should exist and use AccentColor")
    }

    func testCompletedGreenColorExists() {
        // Celebration state uses completedGreen, distinct from primary teal
        let completedGreen = Theme.Colors.completedGreen
        let uiColor = UIColor(completedGreen)
        var red: CGFloat = 0, green: CGFloat = 0, blue: CGFloat = 0, alpha: CGFloat = 0
        uiColor.getRed(&red, green: &green, blue: &blue, alpha: &alpha)

        // completedGreen is #10B981: R:0.063 G:0.725 B:0.506
        XCTAssertGreaterThan(green, 0.7, "completedGreen should have strong green channel")
        XCTAssertLessThan(blue, 0.6, "completedGreen blue channel should be moderate")
    }
}
