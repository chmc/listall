//
//  AppHidingLogicTests.swift
//  ListAllMacTests
//
//  Created as part of MACOS_PLAN.md Phase 1: App Hiding Unit Tests
//  TDD Cycle 1: RED phase - These tests should FAIL initially
//

import XCTest
@testable import ListAll

/// Unit tests for AppleScript generation logic for hiding background apps
/// These tests verify the script generator produces valid, efficient AppleScript
final class AppHidingLogicTests: XCTestCase {

    var generator: AppHidingScriptGenerator!

    override func setUp() {
        super.setUp()
        generator = AppHidingScriptGenerator()
    }

    override func tearDown() {
        generator = nil
        super.tearDown()
    }

    // MARK: - Test 1-5: Basic Script Structure

    /// Test 1: Script produces valid AppleScript syntax
    func test_generateHideScript_producesValidSyntax() {
        let script = generator.generateHideScript(excludedApps: ["Finder", "Dock"])

        XCTAssertTrue(script.contains("tell application \"System Events\""),
                      "Script must start with System Events tell block")
        XCTAssertFalse(script.contains("\\\""),
                       "Should not have escaped quotes - use proper AppleScript quoting")
    }

    /// Test 2: Script does NOT use tr shell calls for case conversion (CRITICAL)
    func test_generateHideScript_doesNotUseShellForCaseConversion() {
        let script = generator.generateHideScript(excludedApps: [])

        // CRITICAL: Must NOT spawn shell for case conversion - inefficient!
        XCTAssertFalse(script.contains("tr '[:upper:]' '[:lower:]'"),
            "Should use AppleScript native comparison, not tr shell command")
        XCTAssertFalse(script.contains("do shell script"),
            "Should not spawn shell processes for string operations")
    }

    /// Test 3: Script excludes test infrastructure processes
    func test_generateHideScript_excludesTestProcesses() {
        let script = generator.generateHideScript(excludedApps: [])

        // Must exclude test runners and infrastructure
        let hasXctest = script.lowercased().contains("xctest")
        let hasXctrunner = script.lowercased().contains("xctrunner")
        let hasListAll = script.lowercased().contains("listall")

        XCTAssertTrue(hasXctest, "Must exclude xctest process")
        XCTAssertTrue(hasXctrunner, "Must exclude xctrunner process")
        XCTAssertTrue(hasListAll, "Must exclude ListAll app being tested")
    }

    /// Test 4: Script includes error handling
    func test_generateHideScript_hasErrorHandling() {
        let script = generator.generateHideScript(excludedApps: [])

        XCTAssertTrue(script.contains("on error"),
                      "Must have error handling for app quit failures")
        XCTAssertTrue(script.contains("try"),
                      "Must use try blocks for safe app interactions")
    }

    /// Test 5: Script excludes provided apps
    func test_generateHideScript_excludesProvidedApps() {
        let script = generator.generateHideScript(excludedApps: ["Safari", "Chrome"])

        XCTAssertTrue(script.contains("Safari"),
                      "Must include Safari in exclusion list")
        XCTAssertTrue(script.contains("Chrome"),
                      "Must include Chrome in exclusion list")
    }

    // MARK: - Test 6-10: System App Exclusions

    /// Test 6: Script always excludes Finder
    func test_generateHideScript_alwaysExcludesFinder() {
        let script = generator.generateHideScript(excludedApps: [])

        XCTAssertTrue(script.contains("Finder") || script.contains("finder"),
                      "Must always exclude Finder")
    }

    /// Test 7: Script always excludes Dock
    func test_generateHideScript_alwaysExcludesDock() {
        let script = generator.generateHideScript(excludedApps: [])

        XCTAssertTrue(script.contains("Dock") || script.contains("dock"),
                      "Must always exclude Dock")
    }

    /// Test 8: Script always excludes SystemUIServer
    func test_generateHideScript_alwaysExcludesSystemUIServer() {
        let script = generator.generateHideScript(excludedApps: [])

        let hasSystemUI = script.contains("SystemUIServer") || script.contains("systemuiserver")
        XCTAssertTrue(hasSystemUI, "Must always exclude SystemUIServer")
    }

    /// Test 9: Script excludes Xcode development tools
    func test_generateHideScript_excludesXcodeTools() {
        let script = generator.generateHideScript(excludedApps: [])

        // Should exclude Xcode and related tools via pattern matching
        let hasXcode = script.contains("Xcode") || script.contains("xcode")
        let hasXcodebuild = script.contains("xcodebuild")
        let hasSimulator = script.contains("Simulator")

        XCTAssertTrue(hasXcode, "Must exclude Xcode")
        XCTAssertTrue(hasXcodebuild, "Must exclude xcodebuild")
        XCTAssertTrue(hasSimulator, "Must exclude Simulator")
    }

    /// Test 10: Script uses case-insensitive comparison
    func test_generateHideScript_usesCaseInsensitiveComparison() {
        let script = generator.generateHideScript(excludedApps: [])

        // AppleScript "is in" list comparison is case-insensitive
        // OR uses pattern matching with both cases
        let hasCaseHandling = script.contains("is in") ||
                              (script.contains("Finder") && script.contains("finder")) ||
                              script.contains("contains")

        XCTAssertTrue(hasCaseHandling,
                      "Must handle case-insensitive app name matching")
    }

    // MARK: - Test 11-15: Script Logic

    /// Test 11: Script only hides foreground apps (not background-only)
    func test_generateHideScript_onlyTargetsForegroundApps() {
        let script = generator.generateHideScript(excludedApps: [])

        XCTAssertTrue(script.contains("background only is false"),
                      "Should only target apps with background only = false")
    }

    /// Test 12: Script iterates over all processes
    func test_generateHideScript_iteratesOverProcesses() {
        let script = generator.generateHideScript(excludedApps: [])

        XCTAssertTrue(script.contains("repeat with"),
                      "Should iterate over processes")
        XCTAssertTrue(script.contains("every process"),
                      "Should get list of all processes")
    }

    /// Test 13: Script uses shouldSkip pattern for clarity
    func test_generateHideScript_usesShouldSkipPattern() {
        let script = generator.generateHideScript(excludedApps: [])

        XCTAssertTrue(script.contains("shouldSkip") || script.contains("should skip"),
                      "Should use shouldSkip flag for clear logic")
    }

    /// Test 14: Script quits non-excluded apps
    func test_generateHideScript_quitsNonExcludedApps() {
        let script = generator.generateHideScript(excludedApps: [])

        XCTAssertTrue(script.contains("quit"),
                      "Should quit non-excluded apps")
    }

    /// Test 15: Script logs errors but continues on failure
    func test_generateHideScript_logsErrorsButContinues() {
        let script = generator.generateHideScript(excludedApps: [])

        // Should log errors (using AppleScript's log command)
        XCTAssertTrue(script.contains("log") || script.contains("on error"),
                      "Should log errors for debugging")
        // Error handling block should exist
        XCTAssertTrue(script.contains("end try"),
                      "Should have proper try/end try structure")
    }
}
