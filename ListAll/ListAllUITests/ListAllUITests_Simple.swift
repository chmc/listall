import XCTest

/// Simplified screenshot tests - no complex detection, just straightforward screenshot capture
@MainActor
final class ListAllUITests_Screenshots: XCTestCase {

    var app: XCUIApplication!

    /// Timeout for app launch - iPad simulators in CI can be very slow
    /// Increased from 30s to 60s to handle iPad Pro in CI
    private let launchTimeout: TimeInterval = 60

    /// Timeout for UI elements to appear after launch
    private let elementTimeout: TimeInterval = 15

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()

        // Setup Fastlane snapshot
        setupSnapshot(app)
    }

    /// Launch app with retry logic to handle "Failed to terminate" errors on iPad simulators
    /// This is a known flaky issue where app.launch() internally fails to terminate the previous instance
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
                // Additional delay for UI to settle - iPad needs more time
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
        // Wait for any navigation bar, tab bar, or main content to appear
        // This is more reliable than fixed sleep
        let navBar = app.navigationBars.firstMatch
        let anyButton = app.buttons.firstMatch
        let anyCell = app.cells.firstMatch

        let startTime = Date()
        while Date().timeIntervalSince(startTime) < elementTimeout {
            if navBar.exists || anyButton.exists || anyCell.exists {
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

    /// Test: Capture welcome screen (empty state)
    func testScreenshots01_WelcomeScreen() throws {
        print("========================================")
        print("📱 Starting Welcome Screen Screenshot Test")
        print("========================================")

        // Launch with empty state - SKIP_TEST_DATA prevents populating lists
        guard launchAppWithRetry(arguments: ["UITEST_MODE", "UITEST_SCREENSHOT_MODE", "DISABLE_TOOLTIPS", "SKIP_TEST_DATA"]) else {
            XCTFail("App failed to launch for welcome screen screenshot")
            return
        }

        // Wait for UI to be ready (dynamic wait instead of fixed sleep)
        _ = waitForUIReady()

        // Take screenshot of empty state
        print("📸 Capturing welcome screen screenshot")
        snapshot("01_Welcome")
        print("✅ Welcome screen screenshot captured")
        print("========================================")
    }

    /// Test: Capture main flow with data
    func testScreenshots02_MainFlow() throws {
        print("========================================")
        print("📱 Starting Main Flow Screenshot Test")
        print("========================================")

        // Launch with test data - without SKIP_TEST_DATA, hardcoded lists will be populated
        guard launchAppWithRetry(arguments: ["UITEST_MODE", "UITEST_SCREENSHOT_MODE", "DISABLE_TOOLTIPS"]) else {
            XCTFail("App failed to launch for main flow screenshot")
            return
        }

        // Wait for UI to be ready (dynamic wait instead of fixed sleep)
        _ = waitForUIReady()

        // Additional wait for data to load into list
        // Look for any cell which indicates data is loaded
        let anyCell = app.cells.firstMatch
        if anyCell.waitForExistence(timeout: elementTimeout) {
            print("✅ Data loaded - found list cells")
        } else {
            print("⚠️ No cells found, but proceeding with screenshot")
        }

        // Screenshot: Main screen with hardcoded test lists
        print("📸 Capturing main screen screenshot")
        snapshot("02_MainScreen")
        print("✅ Main screen screenshot captured")
        print("========================================")
    }
}
