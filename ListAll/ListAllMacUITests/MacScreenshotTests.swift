//
//  MacScreenshotTests.swift
//  ListAllMacUITests
//
//  Created by Claude Code on 8.12.2025.
//
//  macOS screenshot tests for LOCAL screenshot generation.
//  Screenshots are captured at 2880x1800 (Retina) resolution.
//  Output: ~/Library/Caches/tools.fastlane/screenshots/Mac-*.png
//
//  Usage:
//    xcodebuild test -project ListAll.xcodeproj -scheme ListAllMac \
//      -destination 'platform=macOS' -only-testing:ListAllMacUITests/MacScreenshotTests
//

import XCTest

/// Screenshot tests for macOS App Store submission
/// Captures screenshots at 2880x1800 (Retina) resolution for App Store submission
/// Screenshots are saved to Fastlane cache directory and organized by locale
@MainActor
final class MacScreenshotTests: XCTestCase {

    var app: XCUIApplication!

    /// Timeout for app launch
    private let launchTimeout: TimeInterval = 60

    /// Timeout for UI elements to appear after launch
    private let elementTimeout: TimeInterval = 15

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()

        // Setup Fastlane snapshot
        // This configures locale detection and screenshot directory setup
        setupSnapshot(app)
    }

    /// Launch app with retry logic to handle "Failed to terminate" errors
    /// Note: maxRetries=2 gives 2×60s=120s budget, leaving 180s for test execution within 300s timeout
    private func launchAppWithRetry(arguments: [String], maxRetries: Int = 2) -> Bool {
        for attempt in 1...maxRetries {
            // Brief pause before retry attempts to let system settle
            if attempt > 1 {
                print("⏳ Waiting 5 seconds before retry attempt \(attempt)...")
                sleep(5)
                // Recreate app instance for retry
                app = XCUIApplication()
                setupSnapshot(app)
            }

            // Add launch arguments (must be done each attempt since app may be recreated)
            app.launchArguments += arguments

            print("🚀 Launch attempt \(attempt)/\(maxRetries) with timeout \(launchTimeout)s...")

            // Temporarily allow failures during launch attempt
            let previousContinueAfterFailure = continueAfterFailure
            continueAfterFailure = true

            app.launch()

            // Check if launch succeeded
            let launched = app.wait(for: .runningForeground, timeout: launchTimeout)

            // Restore failure behavior
            continueAfterFailure = previousContinueAfterFailure

            if launched {
                print("✅ App launched successfully on attempt \(attempt)")
                // Additional delay for UI to settle
                sleep(2)
                return true
            }

            // Log retry attempt (visible in test logs)
            print("⚠️ App launch attempt \(attempt)/\(maxRetries) failed, retrying...")
        }

        XCTFail("App failed to launch after \(maxRetries) attempts")
        return false
    }

    /// Wait for a stable UI state by checking for any visible element
    /// Returns true if UI appears ready, false if timeout
    private func waitForUIReady() -> Bool {
        // Wait for any window, button, or table to appear
        // This is more reliable than fixed sleep
        let anyWindow = app.windows.firstMatch
        let anyButton = app.buttons.firstMatch
        let anyTable = app.tables.firstMatch

        let startTime = Date()
        while Date().timeIntervalSince(startTime) < elementTimeout {
            if anyWindow.exists || anyButton.exists || anyTable.exists {
                print("✅ UI ready - found interactive elements")
                // Small additional settle time
                sleep(1)
                return true
            }
            // Poll every 0.5 seconds
            Thread.sleep(forTimeInterval: 0.5)
        }

        print("⚠️ UI ready check timed out, proceeding anyway")
        return false
    }

    /// Resize window to specific dimensions for screenshot consistency
    /// - Parameters:
    ///   - width: Target width in points
    ///   - height: Target height in points
    private func resizeWindow(width: CGFloat, height: CGFloat) {
        let window = app.windows.firstMatch
        guard window.exists else {
            print("⚠️ Window not found, cannot resize")
            return
        }

        // Note: XCUIElement doesn't directly support resizing on macOS
        // The window size is determined by the content and app layout
        // For screenshot consistency, we'll rely on the app's default window size
        print("📐 Window frame: \(window.frame)")
    }

    // MARK: - Screenshot Tests

    /// Test: Capture main window with sidebar showing lists and detail view with items
    /// This is the primary screenshot showing the app's main interface
    func testScreenshot01_MainWindow() throws {
        print("========================================")
        print("💻 Starting Main Window Screenshot Test")
        print("========================================")

        // Launch with test data - without SKIP_TEST_DATA, deterministic lists will be populated
        guard launchAppWithRetry(arguments: ["UITEST_MODE", "UITEST_SCREENSHOT_MODE", "DISABLE_ANIMATIONS"]) else {
            XCTFail("App failed to launch for main window screenshot")
            return
        }

        // Wait for UI to be ready
        _ = waitForUIReady()

        // Wait for lists to load - look for any table row
        let listTable = app.tables.firstMatch
        if listTable.waitForExistence(timeout: elementTimeout) {
            print("✅ Lists loaded - found list table")

            // Wait for table rows to appear
            sleep(1)

            // Click on first list to show detail view
            let firstRow = listTable.tableRows.firstMatch
            if firstRow.waitForExistence(timeout: elementTimeout) {
                print("✅ Found first list, clicking to show detail")
                firstRow.click()
                sleep(1)
            }
        } else {
            print("⚠️ No list table found, but proceeding with screenshot")
        }

        // Take screenshot of main window with sidebar and detail view
        print("📸 Capturing main window screenshot")
        snapshot("01_MainWindow")
        print("✅ Main window screenshot captured")
        print("========================================")
    }

    /// Test: Capture list detail view with multiple items (completed and active)
    /// Shows the list management interface with items
    func testScreenshot02_ListDetailView() throws {
        print("========================================")
        print("💻 Starting List Detail View Screenshot Test")
        print("========================================")

        // Launch with test data
        guard launchAppWithRetry(arguments: ["UITEST_MODE", "UITEST_SCREENSHOT_MODE", "DISABLE_ANIMATIONS"]) else {
            XCTFail("App failed to launch for list detail screenshot")
            return
        }

        // Wait for UI to be ready
        _ = waitForUIReady()

        // Navigate to a list with items
        let listTable = app.tables.firstMatch
        if listTable.waitForExistence(timeout: elementTimeout) {
            // Click on second list (should have more items for better screenshot)
            let rows = listTable.tableRows
            if rows.count > 1 {
                let secondRow = rows.element(boundBy: 1)
                if secondRow.waitForExistence(timeout: elementTimeout) {
                    print("✅ Found second list, clicking to show detail")
                    secondRow.click()
                    sleep(1)
                }
            } else if rows.count > 0 {
                // Fall back to first row if only one list exists
                let firstRow = rows.firstMatch
                if firstRow.waitForExistence(timeout: elementTimeout) {
                    print("✅ Found first list, clicking to show detail")
                    firstRow.click()
                    sleep(1)
                }
            }
        }

        // Take screenshot showing list detail with items
        print("📸 Capturing list detail view screenshot")
        snapshot("02_ListDetailView")
        print("✅ List detail view screenshot captured")
        print("========================================")
    }

    /// Test: Capture item editing sheet/modal
    /// Shows the item creation/editing interface
    func testScreenshot03_ItemEditSheet() throws {
        print("========================================")
        print("💻 Starting Item Edit Sheet Screenshot Test")
        print("========================================")

        // Launch with test data
        guard launchAppWithRetry(arguments: ["UITEST_MODE", "UITEST_SCREENSHOT_MODE", "DISABLE_ANIMATIONS"]) else {
            XCTFail("App failed to launch for item edit screenshot")
            return
        }

        // Wait for UI to be ready
        _ = waitForUIReady()

        // Navigate to a list
        let listTable = app.tables.firstMatch
        if listTable.waitForExistence(timeout: elementTimeout) {
            let firstRow = listTable.tableRows.firstMatch
            if firstRow.waitForExistence(timeout: elementTimeout) {
                print("✅ Found first list, clicking to show detail")
                firstRow.click()
                sleep(1)
            }
        }

        // Look for "Add Item" button or similar to open edit sheet
        // Try multiple possible identifiers
        let addItemButton = app.buttons["Add Item"].firstMatch
        let plusButton = app.buttons["+"].firstMatch

        if addItemButton.waitForExistence(timeout: elementTimeout) {
            print("✅ Found 'Add Item' button, clicking to show edit sheet")
            addItemButton.click()
            sleep(1)
        } else if plusButton.waitForExistence(timeout: elementTimeout) {
            print("✅ Found '+' button, clicking to show edit sheet")
            plusButton.click()
            sleep(1)
        } else {
            print("⚠️ Could not find add item button, trying to click on existing item")
            // Try clicking on an existing item to open edit sheet
            let itemTable = app.tables.matching(identifier: "itemTable").firstMatch
            if itemTable.exists {
                let firstItem = itemTable.tableRows.firstMatch
                if firstItem.waitForExistence(timeout: elementTimeout) {
                    print("✅ Clicking on first item to show edit sheet")
                    firstItem.click()
                    sleep(1)
                }
            }
        }

        // Take screenshot showing item edit sheet
        print("📸 Capturing item edit sheet screenshot")
        snapshot("03_ItemEditSheet")
        print("✅ Item edit sheet screenshot captured")
        print("========================================")
    }

    /// Test: Capture settings window with tabs
    /// Shows the app preferences/settings interface
    func testScreenshot04_SettingsWindow() throws {
        print("========================================")
        print("💻 Starting Settings Window Screenshot Test")
        print("========================================")

        // Launch with test data
        guard launchAppWithRetry(arguments: ["UITEST_MODE", "UITEST_SCREENSHOT_MODE", "DISABLE_ANIMATIONS"]) else {
            XCTFail("App failed to launch for settings screenshot")
            return
        }

        // Wait for UI to be ready
        _ = waitForUIReady()

        // Open Settings window using keyboard shortcut (Cmd+,)
        print("⌨️ Opening Settings with Cmd+,")
        app.typeKey(",", modifierFlags: .command)
        sleep(1)

        // Wait for settings window to appear
        let settingsWindow = app.windows["Settings"]
        if settingsWindow.waitForExistence(timeout: elementTimeout) {
            print("✅ Settings window opened")
        } else {
            print("⚠️ Settings window not found by identifier, checking for any dialog")
            // Try to find any sheet or dialog that appeared
            sleep(1)
        }

        // Take screenshot showing settings window
        print("📸 Capturing settings window screenshot")
        snapshot("04_SettingsWindow")
        print("✅ Settings window screenshot captured")
        print("========================================")
    }
}

// MARK: - Screenshot Output Information
//
// Screenshots are captured using XCUIScreen.main.screenshot() which captures
// the entire main display at native Retina resolution.
//
// Output location (managed by MacSnapshotHelper.swift):
//   ~/Library/Containers/io.github.chmc.ListAllMacUITests.xctrunner/Data/Library/Caches/tools.fastlane/screenshots/Mac-*.png
//
// Filenames follow App Store convention:
//   - Mac-01_MainWindow.png
//   - Mac-02_ListDetailView.png
//   - Mac-03_ItemEditSheet.png
//   - Mac-04_SettingsWindow.png
//
// IMPORTANT - Aspect Ratio:
//   XCUIScreen.main.screenshot() captures the ENTIRE DISPLAY, so the screenshot
//   aspect ratio depends on your display's aspect ratio:
//   - 16:10 displays (e.g., 2880x1800): ✅ Perfect for App Store
//   - 16:9 displays (e.g., 3840x2160): ⚠️ Requires cropping to 16:10
//   - 21:9 ultrawide (e.g., 3840x1600): ⚠️ Requires cropping to 16:10
//
//   Recommended: Generate screenshots on a 16:10 Retina Mac for best results.
//
// Locale organization:
//   The MacSnapshotHelper reads locale from Fastlane cache directory
//   (language.txt and locale.txt) to organize screenshots by locale.
//
// For local screenshot generation:
//   1. Run tests via xcodebuild or Fastlane
//   2. Screenshots saved to cache directory
//   3. Verify aspect ratio: sips -g pixelWidth -g pixelHeight screenshot.png
//   4. Crop if needed: magick screenshot.png -gravity center -crop 2880x1800+0+0 +repage output.png
//   5. Post-process to move screenshots to fastlane/screenshots/mac/[locale]/
//
// App Store requirements:
//   - Minimum 3 screenshots per locale
//   - Maximum 10 screenshots per locale
//   - 16:10 aspect ratio (e.g., 2880x1800, 2560x1600, 1440x900)
//   - PNG format
//
// See documentation/macos-screenshot-generation.md for detailed guide.
