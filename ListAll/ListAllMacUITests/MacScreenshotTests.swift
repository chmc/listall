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
import AppKit

/// Screenshot tests for macOS App Store submission
/// Captures screenshots at 2880x1800 (Retina) resolution for App Store submission
/// Screenshots are saved to Fastlane cache directory and organized by locale
@MainActor
final class MacScreenshotTests: XCTestCase {

    var app: XCUIApplication!
    var orchestrator: ScreenshotOrchestrator!

    /// Timeout for app launch
    private let launchTimeout: TimeInterval = 60

    /// Timeout for UI elements to appear after launch
    private let elementTimeout: TimeInterval = 15

    override func setUpWithError() throws {
        continueAfterFailure = false

        // CRITICAL: On macOS, give the system time to stabilize between test runs
        // This is especially important when running multiple locales in sequence
        // Without this delay, authorization can be lost between locale changes
        print("⏳ Waiting 3 seconds for system to stabilize before test setup...")
        sleep(3)

        // On macOS, explicitly set the bundle identifier to ensure correct app launches
        // This helps XCUITest find the right app more reliably
        // CRITICAL: Use XCUIApplication() default initializer to maintain authorization
        // across test runs. Bundle identifier is resolved automatically.
        app = XCUIApplication()

        // macOS UI tests need more time due to app activation and window management
        // Default is 60 seconds, which is too short for macOS screenshot tests
        executionTimeAllowance = 300  // 5 minutes per test

        // Setup Fastlane snapshot
        // This configures locale detection and screenshot directory setup
        setupSnapshot(app)

        // Initialize ScreenshotOrchestrator with real implementations
        let scriptExecutor = RealAppleScriptExecutor()
        let captureStrategy = WindowCaptureStrategy()
        let validator = ScreenshotValidator()
        let workspace = RealWorkspace()
        let screenshotCapture = RealScreenshotCapture()

        orchestrator = ScreenshotOrchestrator(
            scriptExecutor: scriptExecutor,
            captureStrategy: captureStrategy,
            validator: validator,
            workspace: workspace,
            screenshotCapture: screenshotCapture
        )

        // Drain run loop at start of each test to ensure clean state
        // This helps prevent "Run loop nesting count is negative" errors
        drainRunLoop()
    }

    /// Launch app with retry logic to handle "Failed to terminate" errors
    /// Note: maxRetries=2 gives 2×60s=120s budget, leaving 180s for test execution within 300s timeout
    private func launchAppWithRetry(arguments: [String], maxRetries: Int = 2) -> Bool {
        // CRITICAL: Preserve existing launch arguments set by MacSnapshotHelper
        // MacSnapshotHelper.setupSnapshot() sets -AppleLanguages for localization
        // We need to append our test arguments, not replace them!
        let baseArguments = app.launchArguments

        for attempt in 1...maxRetries {
            // Brief pause before retry attempts to let system settle
            if attempt > 1 {
                print("⏳ Waiting 5 seconds before retry attempt \(attempt)...")
                sleep(5)
                // DO NOT recreate app instance - this causes authorization loss on macOS
                // The app instance from setUpWithError() maintains authorization across launches
            }

            // Set launch arguments: preserve MacSnapshotHelper args + test-specific args
            app.launchArguments = baseArguments + arguments

            print("🚀 Launch attempt \(attempt)/\(maxRetries)...")

            // On macOS, app.launch() may time out and throw if app doesn't reach foreground
            // We need to catch this and check if app is actually running in background
            let previousContinueAfterFailure = continueAfterFailure
            continueAfterFailure = true

            // Store XCTest expectation failure flag
            var launchDidTimeout = false

            // NOTE: XCTest errors are recorded via test failure API, not Swift exceptions
            // So we can't catch them with try-catch. Instead, we let launch() fail
            // and then check the app state to see if it's actually running.

            // Launch app - this may time out waiting for foreground on macOS
            app.launch()

            // If we reach here, launch() either succeeded or failed but didn't halt execution
            // Check if the "failure" was just that app is in background
            sleep(2)

            let appState = app.state
            print("📊 App state after launch: \(appState.rawValue) (2=notRunning, 3=runningBackground, 4=runningForeground)")

            // Consider both foreground and background as successful launch
            let isRunning = (appState == .runningForeground || appState == .runningBackground)

            continueAfterFailure = previousContinueAfterFailure

            if isRunning {
                // App launched successfully (even if XCTest reported a "failure")
                print("✅ App is running on attempt \(attempt), state: \(appState.rawValue)")

                // Try to activate to foreground if in background
                if appState == .runningBackground {
                    print("⚡ App in background, activating to foreground...")
                    app.activate()
                    sleep(2)
                    print("📊 App state after activate(): \(app.state.rawValue)")
                }

                // Additional delay for UI to settle
                sleep(1)
                return true
            } else {
                print("⚠️ App not running after launch (state: \(appState.rawValue)) on attempt \(attempt)")
            }

            // Log retry attempt
            print("⚠️ App launch attempt \(attempt)/\(maxRetries) failed, retrying...")
        }

        XCTFail("App failed to launch after \(maxRetries) attempts")
        return false
    }

    /// Force window to be visible and positioned on-screen using AppleScript
    /// This is critical because XCUIApplication.activate() doesn't guarantee window visibility
    /// NOTE: AppleScript requires additional permissions which may trigger dialogs
    private func forceWindowOnScreen() {
        print("📍 Forcing window to be visible and on-screen...")

        // STRATEGY: Use aggressive AppleScript approach to ensure window is truly frontmost
        // XCUIApplication.activate() alone is insufficient for screenshot tests

        // Use AppleScript to FORCE window to be frontmost and visible
        // This is more reliable than XCUIApplication for ensuring window is on top
        let script = """
        tell application "System Events"
            tell process "ListAll"
                -- First, make sure the app is frontmost (THIS IS CRITICAL)
                set frontmost to true

                -- Wait a moment for frontmost to take effect
                delay 0.5

                -- If there are windows, make sure they're visible and on-screen
                if (count of windows) > 0 then
                    tell window 1
                        -- Ensure window is not minimized
                        if value of attribute "AXMinimized" is true then
                            set value of attribute "AXMinimized" to false
                        end if

                        -- Get current position and size
                        set windowPosition to position
                        set windowSize to size

                        -- If window is off-screen (negative or very large position), move it on-screen
                        set posX to item 1 of windowPosition
                        set posY to item 2 of windowPosition

                        -- Move to center-ish position if off-screen
                        if posX < 0 or posX > 2000 or posY < 0 or posY > 1500 then
                            set position to {100, 100}
                        end if

                        -- CRITICAL: Ensure window size is reasonable
                        -- macOS may launch test app with tiny window
                        set currentWidth to item 1 of windowSize
                        set currentHeight to item 2 of windowSize

                        if currentWidth < 800 or currentHeight < 600 then
                            set size to {1200, 800}
                        end if
                    end tell

                    -- Force window 1 to be key window (accepts keyboard input)
                    -- This is stronger than just frontmost
                    perform action "AXRaise" of window 1
                end if
            end tell
        end tell

        -- Also activate the app to bring to front
        tell application "ListAll"
            activate
        end tell

        -- Wait for window to fully render
        delay 1
        """

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
        process.arguments = ["-e", script]

        do {
            try process.run()
            process.waitUntilExit()

            if process.terminationStatus == 0 {
                print("  ✓ Window positioned on-screen via AppleScript")
            } else {
                print("  ⚠️ AppleScript returned non-zero status: \(process.terminationStatus)")
            }
        } catch {
            print("  ⚠️ AppleScript execution failed: \(error)")
            print("  💡 Continuing anyway - window may still be usable")
        }

        // Give window MORE time to reposition and render
        sleep(2)
    }

    /// Prepare app window for clean screenshots
    /// NOTE: Desktop should already be cleared by shell script before tests run
    /// This function ensures ListAll window is visible, on-screen, and frontmost
    private func prepareWindowForScreenshot() {
        print("🖥️ Preparing window for screenshot...")

        // CRITICAL: Hide all other apps to ensure ListAll is the ONLY visible window
        // This prevents other apps from appearing in the screenshot
        // Try orchestrator first, fall back to hideAllOtherApps() if it fails
        do {
            try orchestrator.hideBackgroundApps()
            print("  ✓ Background apps hidden via orchestrator")
        } catch {
            print("  ⚠️ Orchestrator failed: \(error), using fallback hideAllOtherApps()")
            hideAllOtherApps()
        }

        // STEP 1: Activate via NSWorkspace with force flag
        if let listAllApp = NSWorkspace.shared.runningApplications.first(where: {
            $0.bundleIdentifier == "io.github.chmc.ListAllMac"
        }) {
            listAllApp.activate(options: [.activateIgnoringOtherApps])
            print("  ✓ Activated ListAll via NSWorkspace")
        }

        // STEP 2: Use XCUIApplication's activate
        app.activate()

        // STEP 3: Wait for window by checking for actual content elements
        // Don't use app.windows.count - it doesn't work reliably with SwiftUI on macOS
        // Instead, wait for content elements which proves the window exists
        let sidebar = app.outlines["ListsSidebar"]
        if sidebar.waitForExistence(timeout: 10) {
            print("✅ Window verified - found sidebar content")

            // STEP 4: Verify content is populated
            verifyContentReady(sidebar: sidebar)

            // Give a moment for window to settle after activation
            sleep(1)
        } else {
            // Try AppleScript fallback to position window
            print("⚠️ Sidebar not found, trying AppleScript fallback...")
            forceWindowOnScreen()

            // Give UI time to update after AppleScript
            sleep(2)

            // Check for any button as evidence of window
            let anyButton = app.buttons.firstMatch
            if anyButton.waitForExistence(timeout: 5) {
                print("✅ Window appears ready (found buttons)")
            } else {
                print("⚠️ WARNING: Could not verify window - screenshots may have issues")
            }
        }

        // Drain run loop to ensure clean state before screenshot
        drainRunLoop()
    }

    /// Verify that content is ready for screenshots
    /// - Parameter sidebar: The sidebar outline element
    private func verifyContentReady(sidebar: XCUIElement) {
        print("🔍 Verifying content is ready for screenshot...")

        // Check that sidebar has rows (lists)
        let rows = sidebar.outlineRows
        if rows.count > 0 {
            print("  ✓ Sidebar has \(rows.count) lists")
        } else {
            print("  ⚠️ WARNING: Sidebar has no lists - test data may not be loaded")
        }

        // Check for visible buttons
        let buttons = app.buttons
        if buttons.count > 0 {
            print("  ✓ Found \(buttons.count) buttons")
        } else {
            print("  ⚠️ WARNING: No buttons found")
        }

        // Overall content ready status
        let hasContent = rows.count > 0 && buttons.count > 0
        if hasContent {
            print("  ✅ Content verification PASSED - ready for screenshot")
        } else {
            print("  ⚠️ Content verification FAILED - screenshot may be incomplete")
        }
    }

    /// Hide all other running applications to ensure only ListAll is visible
    /// This is critical for clean screenshots that only show the test app
    private func hideAllOtherApps() {
        print("👻 Hiding all other applications...")

        let workspace = NSWorkspace.shared
        let listAllBundleId = "io.github.chmc.ListAllMac"

        // Get all running apps except ListAll and system apps
        let runningApps = workspace.runningApplications.filter { app in
            // Keep ListAll and system apps visible
            guard app.bundleIdentifier != listAllBundleId else { return false }
            guard app.bundleIdentifier != "com.apple.finder" else { return false }
            guard app.bundleIdentifier != "com.apple.dock" else { return false }
            guard app.activationPolicy == .regular else { return false }

            return true
        }

        print("  ℹ️ Found \(runningApps.count) apps to hide")

        // Hide each app
        for app in runningApps {
            if let bundleId = app.bundleIdentifier {
                print("  👻 Hiding \(bundleId)")
                app.hide()
            }
        }

        // Give apps time to hide
        sleep(1)

        print("  ✓ All other apps hidden")
    }

    /// Drain the run loop to ensure clean state between operations
    /// This helps prevent "Run loop nesting count is negative" errors
    /// by allowing pending run loop operations to complete
    private func drainRunLoop() {
        // Process any pending run loop events
        // Use multiple short iterations to ensure all pending work is processed
        for _ in 0..<5 {
            RunLoop.current.run(until: Date(timeIntervalSinceNow: 0.05))
        }
    }

    /// Wait for a stable UI state by checking for actual content elements
    /// Uses waitForExistence() which properly handles NSHostingView layer timing
    /// Returns true if UI appears ready, false if timeout
    private func waitForUIReady() -> Bool {
        // CRITICAL: On macOS with SwiftUI, NSHostingView creates a hidden accessibility layer
        // We must use waitForExistence() which synchronously polls the hierarchy
        // rather than checking .exists which returns immediately

        // Wait for the sidebar outline (the main content element) to exist
        // This proves the window AND the SwiftUI view hierarchy are ready
        let sidebar = app.outlines["ListsSidebar"]
        if sidebar.waitForExistence(timeout: elementTimeout) {
            print("✅ UI ready - found sidebar outline")
            sleep(1)  // Small additional settle time for animation completion
            return true
        }

        // Fallback: Wait for ANY outline (in case accessibility ID is different)
        let anyOutline = app.outlines.firstMatch
        if anyOutline.waitForExistence(timeout: 5) {
            print("✅ UI ready - found an outline element")
            sleep(1)
            return true
        }

        // Last resort: Wait for any button (toolbar buttons appear early)
        let anyButton = app.buttons.firstMatch
        if anyButton.waitForExistence(timeout: 5) {
            print("✅ UI ready - found a button element")
            sleep(1)
            return true
        }

        print("⚠️ UI ready check timed out, proceeding anyway")
        return false
    }

    /// Resize window to specific dimensions for screenshot consistency
    /// - Parameters:
    ///   - width: Target width in points
    ///   - height: Target height in points
    private func resizeWindow(width: CGFloat, height: CGFloat) {
        // NOTE: On macOS SwiftUI, window.exists returns false due to accessibility bug
        // but we can still get window frame. Don't guard on exists.
        let window = app.windows.firstMatch

        // Note: XCUIElement doesn't directly support resizing on macOS
        // The window size is determined by the content and app layout
        // For screenshot consistency, we'll rely on the app's default window size
        print("📐 Window frame: \(window.frame)")
    }

    // MARK: - Prerequisites Verification

    /// P2 BLOCKING PREREQUISITE: Verify window capture works before any other tests
    /// This test MUST pass before proceeding with TDD implementation.
    /// If it fails, pivot to Dedicated macOS User approach (see MACOS_PLAN.md Section 9.8)
    ///
    /// Success criteria:
    /// - Screenshot width > 800 pixels
    /// - Screenshot height > 600 pixels
    /// - At least window OR fullscreen capture must work
    func testA_P2_WindowCaptureVerification() throws {
        print("========================================")
        print("🔍 P2 BLOCKING: Window Capture Verification")
        print("========================================")

        // Launch app with test mode
        guard launchAppWithRetry(arguments: ["UITEST_MODE"]) else {
            XCTFail("❌ P2 FAILED: App failed to launch")
            return
        }

        // Wait for UI to stabilize
        print("⏳ Waiting for UI to stabilize...")
        sleep(3)

        // Activate app to ensure it's frontmost
        app.activate()
        sleep(2)

        // Get main window reference
        let mainWindow = app.windows.firstMatch
        let windowAccessible = mainWindow.exists || mainWindow.isHittable

        print("📊 Window accessibility check: exists=\(mainWindow.exists), isHittable=\(mainWindow.isHittable)")

        // Capture screenshot using adaptive strategy (same as MacSnapshotHelper)
        let image: NSImage
        var captureMethod: String

        if windowAccessible {
            // Window is accessible - capture window only (preferred)
            print("📸 Capturing window screenshot...")
            app.activate()
            sleep(1)
            let screenshot = mainWindow.screenshot()
            image = screenshot.image
            captureMethod = "window"
        } else {
            // Window not accessible (SwiftUI accessibility bug) - use fullscreen fallback
            print("⚠️ Window not accessible (SwiftUI bug), using fullscreen fallback...")
            app.activate()
            sleep(1)
            let screenshot = XCUIScreen.main.screenshot()
            image = screenshot.image
            captureMethod = "fullscreen"
        }

        let imageSize = image.size
        print("📊 Screenshot captured via \(captureMethod): \(imageSize.width) x \(imageSize.height)")

        // CRITICAL ASSERTIONS: If these fail, pivot to dedicated macOS user approach
        // NOTE: Using >= instead of > because 800px width is valid for App Store (2x Retina = 800px minimum)
        XCTAssertGreaterThanOrEqual(
            imageSize.width, 800,
            "❌ P2 FAILED: Screenshot width (\(imageSize.width)) must be >=800. " +
            "Pivot to Dedicated macOS User approach (see MACOS_PLAN.md Section 9.8)"
        )
        XCTAssertGreaterThanOrEqual(
            imageSize.height, 600,
            "❌ P2 FAILED: Screenshot height (\(imageSize.height)) must be >=600. " +
            "Pivot to Dedicated macOS User approach (see MACOS_PLAN.md Section 9.8)"
        )

        // Additional validation: Check that screenshot is not mostly blank
        // A valid screenshot should have reasonable file size (> 1KB per 1000 pixels)
        if let pngData = image.pngRepresentation() {
            let expectedMinBytes = Int(imageSize.width * imageSize.height) / 1000
            let actualBytes = pngData.count
            print("📊 Screenshot file size: \(actualBytes) bytes (min expected: \(expectedMinBytes) bytes)")

            if actualBytes < expectedMinBytes {
                print("⚠️ WARNING: Screenshot may be blank or corrupt (small file size)")
            }
        }

        print("✅ P2 PASSED: Window capture verification successful!")
        print("   Capture method: \(captureMethod)")
        print("   Screenshot size: \(imageSize.width) x \(imageSize.height)")
        if captureMethod == "fullscreen" {
            print("   ⚠️ NOTE: Using fullscreen fallback due to SwiftUI accessibility bug")
            print("   This is expected - MacSnapshotHelper handles this automatically")
        }
        print("   Proceed to Phase 0: Test Infrastructure")
        print("========================================")
    }

    // MARK: - Screenshot Tests

    /// Test: Capture main window with sidebar showing lists and detail view with items
    /// This is the primary screenshot showing the app's main interface
    func testScreenshot01_MainWindow() throws {
        print("========================================")
        print("💻 Starting Main Window Screenshot Test")
        print("========================================")

        // Launch with test data
        // NOTE: We still pass UITEST_MODE to populate test data, but NSApp.setActivationPolicy(.regular) should be called by AppDelegate
        guard launchAppWithRetry(arguments: ["UITEST_MODE"]) else {
            XCTFail("App failed to launch for main window screenshot")
            return
        }

        // Wait for UI to be ready
        _ = waitForUIReady()

        // DEBUG: Print the full accessibility tree to understand what XCUITest sees
        print("=== DEBUG: Full element hierarchy ===")
        print("App exists: \(app.exists)")
        print("App state: \(app.state.rawValue)")
        print("App windows count: \(app.windows.allElementsBoundByIndex.count)")
        print("App menuBars count: \(app.menuBars.allElementsBoundByIndex.count)")
        print("App menuBarItems count: \(app.menuBarItems.allElementsBoundByIndex.count)")
        if app.menuBarItems.count > 0 {
            for i in 0..<min(5, app.menuBarItems.allElementsBoundByIndex.count) {
                let item = app.menuBarItems.element(boundBy: i)
                print("  Menu bar item \(i): '\(item.title)' exists=\(item.exists)")
            }
        }
        print("App buttons count: \(app.buttons.allElementsBoundByIndex.count)")
        print("App staticTexts count: \(app.staticTexts.allElementsBoundByIndex.count)")
        print("App outlines count: \(app.outlines.allElementsBoundByIndex.count)")
        if app.buttons.count > 0 {
            print("First button identifier: \(app.buttons.firstMatch.identifier)")
        }
        print("=== END DEBUG ===")

        // CRITICAL FIX: Prepare window BEFORE any UI interactions
        // The window must be visible and frontmost before we can interact with UI elements
        prepareWindowForScreenshot()

        // Wait for lists to load - look for sidebar using accessibility identifier
        // On macOS, SwiftUI List with .sidebar style is exposed as an outline, not a table
        // CRITICAL: SwiftUI WindowGroup doesn't expose windows to accessibility hierarchy
        // BUT mainWindow.screenshot() STILL WORKS - we verify window exists by checking for content elements
        let mainWindow = app.windows.firstMatch
        // NOTE: Don't use mainWindow.waitForExistence() - it returns false due to SwiftUI accessibility bug
        // The window IS there - we verify via content elements below
        print("📊 Main window reference obtained (screenshot() will work even if exists is false)")

        print("📊 Querying sidebar...")
        // Try from app root first (more reliable), then from window
        let sidebarFromApp = app.outlines["ListsSidebar"]
        let sidebarFromWindow = mainWindow.outlines["ListsSidebar"]

        var sidebarToUse: XCUIElement?

        if sidebarFromApp.waitForExistence(timeout: elementTimeout) {
            print("✅ Lists loaded - found sidebar outline from app root")
            sidebarToUse = sidebarFromApp
        } else if sidebarFromWindow.waitForExistence(timeout: 5) {
            print("✅ Lists loaded - found sidebar outline from window")
            sidebarToUse = sidebarFromWindow
        } else {
            print("⚠️ Sidebar outline not found, trying to find ANY outline...")
            // Debug: List all outlines
            let allOutlines = mainWindow.outlines
            print("📊 Found \(allOutlines.count) outlines in window")
            for i in 0..<min(5, allOutlines.count) {
                let outline = allOutlines.element(boundBy: i)
                if outline.exists {
                    print("  Outline \(i): identifier='\(outline.identifier)'")
                    sidebarToUse = outline
                    break
                }
            }
        }

        if let sidebar = sidebarToUse {
            // Wait for outline rows to appear
            sleep(1)

            // Click on first list to show detail view
            // Look for the first outline row (which represents a list in the sidebar)
            let firstRow = sidebar.outlineRows.firstMatch
            if firstRow.waitForExistence(timeout: elementTimeout) {
                print("✅ Found first list in sidebar, attempting click...")
                // CRITICAL: On macOS Tahoe, elements may be "not hittable" even when visible
                // Try click, but continue even if it fails - we still want the screenshot
                if firstRow.isHittable {
                    firstRow.click()
                    sleep(1)
                } else {
                    print("⚠️ OutlineRow exists but not hittable - trying coordinate click")
                    // Try clicking at element's center coordinates as fallback
                    let coordinate = firstRow.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
                    coordinate.tap()
                    sleep(1)
                }
            } else {
                print("⚠️ No outline rows found in sidebar, trying alternative...")
                // Try clicking on first cell descendant
                let firstCell = sidebar.cells.firstMatch
                if firstCell.waitForExistence(timeout: 3) {
                    print("✅ Found first cell in sidebar, clicking")
                    if firstCell.isHittable {
                        firstCell.click()
                    } else {
                        let coordinate = firstCell.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
                        coordinate.tap()
                    }
                    sleep(1)
                }
            }
        } else {
            print("⚠️ Could not find sidebar outline, trying to find list by name")
            // Fallback: Try finding by static text (list name)
            // Test data should create "Grocery Shopping" as first list
            let firstListCell = mainWindow.staticTexts["Grocery Shopping"].firstMatch
            if firstListCell.waitForExistence(timeout: elementTimeout) {
                print("✅ Found first list by name, clicking")
                if firstListCell.isHittable {
                    firstListCell.click()
                } else {
                    let coordinate = firstListCell.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
                    coordinate.tap()
                }
                sleep(1)
            } else {
                print("⚠️ Could not find any lists, proceeding with screenshot anyway")
            }
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

        // CRITICAL FIX: Prepare window BEFORE any UI interactions
        // The window must be visible and frontmost before we can interact with UI elements
        prepareWindowForScreenshot()

        // Navigate to a list with items
        let sidebar = app.outlines["ListsSidebar"]
        if sidebar.waitForExistence(timeout: elementTimeout) {
            // Click on second list (should have more items for better screenshot)
            let rows = sidebar.outlineRows
            if rows.count > 1 {
                let secondRow = rows.element(boundBy: 1)
                if secondRow.waitForExistence(timeout: elementTimeout) {
                    print("✅ Found second list in sidebar, attempting click...")
                    // CRITICAL: On macOS Tahoe, elements may be "not hittable" even when visible
                    if secondRow.isHittable {
                        secondRow.click()
                    } else {
                        print("⚠️ OutlineRow exists but not hittable - trying coordinate click")
                        let coordinate = secondRow.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
                        coordinate.tap()
                    }
                    sleep(1)
                }
            } else if rows.count > 0 {
                // Fall back to first row if only one list exists
                let firstRow = rows.firstMatch
                if firstRow.waitForExistence(timeout: elementTimeout) {
                    print("✅ Found first list in sidebar, attempting click...")
                    if firstRow.isHittable {
                        firstRow.click()
                    } else {
                        let coordinate = firstRow.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
                        coordinate.tap()
                    }
                    sleep(1)
                }
            }
        } else {
            // Fallback: Try finding second list by name
            let secondListCell = app.staticTexts["Weekend Projects"].firstMatch
            if secondListCell.waitForExistence(timeout: elementTimeout) {
                print("✅ Found second list by name, clicking")
                if secondListCell.isHittable {
                    secondListCell.click()
                } else {
                    let coordinate = secondListCell.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
                    coordinate.tap()
                }
                sleep(1)
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

        // CRITICAL FIX: Prepare window BEFORE any UI interactions
        // The window must be visible and frontmost before we can interact with UI elements
        prepareWindowForScreenshot()

        // CRITICAL: Ensure sidebar is visible before trying to navigate
        // The sidebar may be hidden due to previous app state or window size
        let sidebar = app.outlines["ListsSidebar"]
        if !sidebar.waitForExistence(timeout: 3) {
            print("⚠️ Sidebar not visible, toggling with keyboard shortcut (Cmd+Option+S)")
            // Toggle sidebar visibility using View > Toggle Sidebar menu (Cmd+Option+S)
            app.typeKey("s", modifierFlags: [.command, .option])
            sleep(1)
        }

        // Navigate to a list - use multiple strategies for macOS Tahoe compatibility
        if sidebar.waitForExistence(timeout: elementTimeout) {
            let firstRow = sidebar.outlineRows.firstMatch
            if firstRow.waitForExistence(timeout: elementTimeout) {
                print("✅ Found first list in sidebar, attempting to select...")

                // Strategy 1: Try double-click (more reliable for selection)
                if firstRow.isHittable {
                    print("  → Trying double-click on hittable row")
                    firstRow.doubleClick()
                    sleep(1)
                } else {
                    print("⚠️ OutlineRow exists but not hittable - trying coordinate double-tap")
                    let coordinate = firstRow.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
                    coordinate.doubleTap()
                    sleep(1)
                }

                // Strategy 2: If double-click didn't work, try keyboard navigation
                let addButton = app.buttons["AddItemButton"].firstMatch
                if !addButton.waitForExistence(timeout: 2) {
                    print("  → Double-click didn't select, trying keyboard navigation")
                    // Click sidebar first to focus it
                    sidebar.click()
                    usleep(500_000)  // 0.5 seconds
                    // Press Down arrow to select first item, then Enter to confirm
                    app.typeKey(.downArrow, modifierFlags: [])
                    usleep(300_000)  // 0.3 seconds
                    app.typeKey(.return, modifierFlags: [])
                    sleep(1)
                }
            }
        }

        // Fallback: Try finding list by partial name (sidebar truncates text)
        let addItemButtonCheck = app.buttons["AddItemButton"].firstMatch
        if !addItemButtonCheck.waitForExistence(timeout: 2) {
            print("⚠️ List not selected yet, trying to find list by partial text")
            // Look for text starting with "Grocery"
            let groceryText = app.staticTexts.matching(NSPredicate(format: "label BEGINSWITH 'Grocery'")).firstMatch
            if groceryText.waitForExistence(timeout: 3) {
                print("✅ Found text starting with 'Grocery', double-clicking")
                groceryText.doubleTap()
                sleep(1)
            }
        }

        // Verify list selection succeeded by checking if Add Item button is visible
        // The Add Item button only appears when a list is selected
        let addItemButton = app.buttons["AddItemButton"].firstMatch

        if addItemButton.waitForExistence(timeout: 5) {
            print("✅ List selection succeeded - found 'AddItemButton', clicking to show edit sheet")
            if addItemButton.isHittable {
                addItemButton.click()
            } else {
                print("⚠️ AddItemButton not hittable - trying coordinate click")
                let coordinate = addItemButton.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
                coordinate.tap()
            }
            // Wait for sheet to appear and animate
            sleep(2)
        } else {
            print("⚠️ AddItemButton not found after first selection attempt")

            // Try using predicate to find truncated list text
            let groceryListText = app.staticTexts.matching(NSPredicate(format: "label BEGINSWITH 'Grocery'")).firstMatch
            if groceryListText.waitForExistence(timeout: 3) {
                print("✅ Found list text starting with 'Grocery', double-tapping to select")
                groceryListText.doubleTap()
                sleep(2)

                // Try AddItemButton again after selecting
                if addItemButton.waitForExistence(timeout: 3) {
                    print("✅ Now found AddItemButton after list selection, clicking")
                    addItemButton.doubleTap()
                    sleep(2)
                }
            }

            // Final fallback: Try clicking on existing item in list
            if !addItemButton.exists {
                print("⚠️ Still no AddItemButton, trying to click on existing item in detail view")
                // Try clicking on an existing item to open edit sheet
                // The items list has identifier "ItemsList" (see MacMainView line 826)
                let itemsList = app.tables["ItemsList"]
                if itemsList.waitForExistence(timeout: elementTimeout) {
                    let firstItem = itemsList.tableRows.firstMatch
                    if firstItem.waitForExistence(timeout: elementTimeout) {
                        print("✅ Clicking on first item to show edit sheet")
                        if firstItem.isHittable {
                            firstItem.click()
                        } else {
                            let coordinate = firstItem.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
                            coordinate.tap()
                        }
                        sleep(2)
                    } else {
                        print("⚠️ No items found in list")
                    }
                } else {
                    print("⚠️ Could not find ItemsList table")
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

        // CRITICAL FIX: Prepare window BEFORE any UI interactions
        // The window must be visible and frontmost before we can interact with UI elements
        prepareWindowForScreenshot()

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
// Screenshots are captured using mainWindow.screenshot() which captures
// the app window at native Retina resolution. The app is activated
// immediately before capture to ensure it's frontmost.
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
// IMPORTANT - Screenshot Capture:
//   mainWindow.screenshot() captures the SCREEN REGION where the window exists.
//   On macOS, if other apps cover that region, they appear in the screenshot.
//   The MacSnapshotHelper activates the app IMMEDIATELY before capture to ensure
//   the ListAll window is frontmost. The screenshot size depends on window size.
//
//   For App Store, screenshots are post-processed to 2880x1800 (16:10) via
//   Fastlane's screenshots_macos_normalize lane.
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
