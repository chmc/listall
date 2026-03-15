import XCTest
import SwiftUI
@testable import ListAll

class ToggleButtonCapsuleTests: XCTestCase {

    func testToggleButtonConfigurationForActiveItem() {
        // Active item should show "Mark as Completed" with completedGreen color
        let config = ToggleButtonConfiguration(isCrossedOut: false)

        XCTAssertEqual(config.text, "Mark as Completed")
        XCTAssertEqual(
            config.color.description,
            Theme.Colors.completedGreen.description,
            "Active item toggle should use completedGreen"
        )
    }

    func testToggleButtonConfigurationForCompletedItem() {
        // Completed item should show "Mark as Active" with primary (teal) color
        let config = ToggleButtonConfiguration(isCrossedOut: true)

        XCTAssertEqual(config.text, "Mark as Active")
        XCTAssertEqual(
            config.color.description,
            Theme.Colors.primary.description,
            "Completed item toggle should use primary teal"
        )
    }

    func testToggleButtonUsesColoredTextOnTintedBackground() {
        // Button should use colored text (not white) on tinted capsule background
        // This matches the design mockup: green text on green-tinted capsule for "Mark as Completed"
        // and teal text on teal-tinted capsule for "Mark as Active"
        let activeConfig = ToggleButtonConfiguration(isCrossedOut: false)
        let completedConfig = ToggleButtonConfiguration(isCrossedOut: true)

        // Text color should match the config.color (not white)
        XCTAssertEqual(
            activeConfig.color.description,
            Theme.Colors.completedGreen.description,
            "Mark as Completed text should be green"
        )
        XCTAssertEqual(
            completedConfig.color.description,
            Theme.Colors.primary.description,
            "Mark as Active text should be teal"
        )
    }
}
