//
//  AppHidingScriptGenerator.swift
//  ListAllMac
//
//  Created as part of MACOS_PLAN.md Phase 1: App Hiding
//  Generates AppleScript to hide/quit background apps for clean screenshots
//

import Foundation

/// Generates AppleScript commands to hide or quit background applications
/// for clean screenshot capture on macOS.
///
/// Key design decisions:
/// - Uses native AppleScript case comparison (NOT shell tr command)
/// - Excludes test infrastructure (xctest, xctrunner, etc.)
/// - Excludes system-essential apps (Finder, Dock, SystemUIServer)
/// - Includes error handling to continue on individual app failures
///
/// Note: Not marked as Sendable or MainActor to avoid Swift concurrency inference issues
/// that cause crashes during test cleanup on background threads
final class AppHidingScriptGenerator {

    // MARK: - System Apps Always Excluded

    /// Apps that should never be quit (system-essential)
    private let systemApps = [
        "Finder", "finder",
        "Dock", "dock",
        "SystemUIServer", "systemuiserver",
        "Terminal", "terminal"
    ]

    /// Development tools to exclude (pattern matched)
    private let devToolPatterns = [
        "Xcode", "xcode",
        "xctest", "XCTest",
        "xctrunner", "XCTRunner",
        "xcodebuild",
        "Simulator"
    ]

    /// The app being tested
    private let testAppNames = [
        "ListAll", "ListAllMac", "listall"
    ]

    // MARK: - Script Generation

    /// Generate AppleScript to hide/quit background apps
    /// - Parameter excludedApps: Additional apps to exclude from hiding
    /// - Returns: Valid AppleScript string
    func generateHideScript(excludedApps: [String]) -> String {
        // Build the complete exclusion list
        let allExcludedApps = (systemApps + excludedApps)
            .map { "\"\($0)\"" }
            .joined(separator: ", ")

        return """
        tell application "System Events"
            set appList to name of every process whose background only is false
            repeat with appName in appList
                set shouldSkip to false

                -- System essentials (AppleScript "is in" is case-insensitive)
                if appName is in {\(allExcludedApps)} then
                    set shouldSkip to true
                end if

                -- Development tools (pattern matching for both cases)
                if appName contains "Xcode" or appName contains "xcode" then set shouldSkip to true
                if appName contains "xctest" or appName contains "XCTest" then set shouldSkip to true
                if appName contains "xctrunner" or appName contains "XCTRunner" then set shouldSkip to true
                if appName contains "xcodebuild" then set shouldSkip to true
                if appName contains "Simulator" then set shouldSkip to true

                -- App being tested
                if appName is "ListAll" or appName contains "ListAllMac" or appName contains "listall" then set shouldSkip to true

                if shouldSkip is false then
                    try
                        tell process appName to quit
                    on error errMsg
                        log "Could not quit " & appName & ": " & errMsg
                    end try
                end if
            end repeat
        end tell
        """
    }

    /// Generate AppleScript to hide (not quit) background apps
    /// - Parameter excludedApps: Additional apps to exclude from hiding
    /// - Returns: Valid AppleScript string
    func generateHideOnlyScript(excludedApps: [String]) -> String {
        let allExcludedApps = (systemApps + excludedApps)
            .map { "\"\($0)\"" }
            .joined(separator: ", ")

        return """
        tell application "System Events"
            set appList to name of every process whose background only is false
            repeat with appName in appList
                set shouldSkip to false

                -- System essentials
                if appName is in {\(allExcludedApps)} then
                    set shouldSkip to true
                end if

                -- Development tools
                if appName contains "Xcode" or appName contains "xcode" then set shouldSkip to true
                if appName contains "xctest" or appName contains "XCTest" then set shouldSkip to true
                if appName contains "xctrunner" or appName contains "XCTRunner" then set shouldSkip to true
                if appName contains "xcodebuild" then set shouldSkip to true
                if appName contains "Simulator" then set shouldSkip to true

                -- App being tested
                if appName is "ListAll" or appName contains "ListAllMac" or appName contains "listall" then set shouldSkip to true

                if shouldSkip is false then
                    try
                        set visible of process appName to false
                    on error errMsg
                        log "Could not hide " & appName & ": " & errMsg
                    end try
                end if
            end repeat
        end tell
        """
    }

    /// Validate that the script doesn't use inefficient patterns
    /// - Parameter script: AppleScript to validate
    /// - Returns: Array of validation errors (empty if valid)
    func validateScript(_ script: String) -> [String] {
        var errors: [String] = []

        // Check for shell-based case conversion (inefficient)
        if script.contains("tr '[:upper:]' '[:lower:]'") {
            errors.append("Script uses tr for case conversion - should use native AppleScript")
        }

        // Check for do shell script (generally inefficient for simple ops)
        if script.contains("do shell script") {
            errors.append("Script uses shell subprocess - consider native AppleScript")
        }

        // Check for proper error handling
        if !script.contains("on error") || !script.contains("try") {
            errors.append("Script missing error handling")
        }

        return errors
    }

    /// Explicit deinit to prevent Swift concurrency automatic deallocation issues
    deinit {
        // Explicitly do nothing - prevents Swift runtime from auto-generating
        // actor-isolated deallocation that crashes during XCTest cleanup
    }
}
