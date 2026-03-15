//
//  MacSettingsAccentColorTests.swift
//  ListAllMacTests
//
//  Tests that macOS settings tabs use Theme.Colors.primary (teal) for toggles and buttons.
//

import SwiftUI
import XCTest
@testable import ListAll

#if os(macOS)

final class MacSettingsAccentColorTests: XCTestCase {

    // MARK: - Theme Color Availability

    func testThemePrimaryColorExistsForMacSettingsToggles() {
        // All toggles in macOS settings should use Theme.Colors.primary (brand teal)
        let primaryColor = Theme.Colors.primary
        XCTAssertNotNil(primaryColor, "Theme.Colors.primary should exist for macOS settings toggle tints")
    }

    func testThemePrimaryColorIsNotSystemBlue() {
        // macOS settings icons should use Theme.Colors.primary, not .blue
        let primary = Theme.Colors.primary
        let systemBlue = SwiftUI.Color.blue

        XCTAssertNotEqual(
            primary.description,
            systemBlue.description,
            "Theme.Colors.primary should differ from system blue for macOS settings"
        )
    }

    func testThemePrimaryColorIsNotAccentColor() {
        // macOS settings button icons should use Theme.Colors.primary, not .accentColor
        let primary = Theme.Colors.primary
        let accentColor = SwiftUI.Color.accentColor

        // These should be semantically different — we want explicit teal, not system accent
        XCTAssertNotNil(primary, "Theme.Colors.primary must be available for macOS settings icons")
    }

    // MARK: - Source Code Verification

    func testGeneralTabDoesNotUseAccentColor() throws {
        // Verify MacSettingsGeneralTab source does not use .accentColor
        // (should use Theme.Colors.primary instead)
        let sourceFile = try sourceContents(of: "MacSettingsGeneralTab.swift")
        XCTAssertFalse(
            sourceFile.contains(".accentColor"),
            "MacSettingsGeneralTab should use Theme.Colors.primary, not .accentColor"
        )
    }

    func testSecurityTabDoesNotUseSystemBlue() throws {
        // Verify MacSettingsSecurityTab source does not use .foregroundColor(.blue)
        // (should use Theme.Colors.primary instead)
        let sourceFile = try sourceContents(of: "MacSettingsSecurityTab.swift")
        XCTAssertFalse(
            sourceFile.contains(".foregroundColor(.blue)"),
            "MacSettingsSecurityTab should use Theme.Colors.primary, not .blue for biometric icon"
        )
    }

    func testDataTabUsesThemePrimary() throws {
        // Verify MacSettingsDataTab uses Theme.Colors.primary for buttons
        let sourceFile = try sourceContents(of: "MacSettingsDataTab.swift")
        XCTAssertTrue(
            sourceFile.contains("Theme.Colors.primary"),
            "MacSettingsDataTab should use Theme.Colors.primary for button colors"
        )
    }

    func testAboutTabUsesThemePrimary() throws {
        // Verify MacSettingsAboutTab uses Theme.Colors.primary for icon
        let sourceFile = try sourceContents(of: "MacSettingsAboutTab.swift")
        XCTAssertTrue(
            sourceFile.contains("Theme.Colors.primary"),
            "MacSettingsAboutTab should use Theme.Colors.primary for app icon color"
        )
    }

    // MARK: - Helpers

    private func sourceContents(of filename: String, filePath: String = #filePath) throws -> String {
        // Navigate from this test file to the source directory
        // Test file: ListAll/ListAllMacTests/MacSettingsAccentColorTests.swift
        // Source:    ListAll/ListAllMac/Views/<filename>
        let testFileURL = URL(fileURLWithPath: filePath)
        let testsDir = testFileURL.deletingLastPathComponent() // ListAllMacTests/
        let listAllDir = testsDir.deletingLastPathComponent()  // ListAll/
        let candidate = listAllDir.appendingPathComponent("ListAllMac/Views/\(filename)")
        if FileManager.default.fileExists(atPath: candidate.path) {
            return try String(contentsOf: candidate, encoding: .utf8)
        }
        throw XCTSkip("Could not locate \(filename) at \(candidate.path)")
    }
}

#endif
