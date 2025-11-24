import XCTest

/// Simplified screenshot tests - no complex detection, just straightforward screenshot capture
@MainActor
final class ListAllUITests_Screenshots: XCTestCase {

    var app: XCUIApplication!

    /// Timeout for app launch - iPad in CI can be slow
    private let launchTimeout: TimeInterval = 30

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()

        // Setup Fastlane snapshot
        setupSnapshot(app)
    }

    /// Launch app with retry logic to handle "Failed to terminate" errors on iPad simulators
    /// This is a known flaky issue where app.launch() internally fails to terminate the previous instance
    private func launchAppWithRetry(arguments: [String], maxRetries: Int = 3) -> Bool {
        for attempt in 1...maxRetries {
            // Brief pause before retry attempts to let system settle
            if attempt > 1 {
                sleep(2)
                // Recreate app instance for retry
                app = XCUIApplication()
                setupSnapshot(app)
            }

            // Add launch arguments (must be done each attempt since app may be recreated)
            app.launchArguments += arguments

            // Temporarily allow failures during launch attempt
            let previousContinueAfterFailure = continueAfterFailure
            continueAfterFailure = true

            app.launch()

            // Check if launch succeeded
            let launched = app.wait(for: .runningForeground, timeout: launchTimeout)

            // Restore failure behavior
            continueAfterFailure = previousContinueAfterFailure

            if launched {
                // Additional small delay for UI to settle
                sleep(1)
                return true
            }

            // Log retry attempt (visible in test logs)
            print("⚠️ App launch attempt \(attempt)/\(maxRetries) failed, retrying...")
        }

        XCTFail("App failed to launch after \(maxRetries) attempts")
        return false
    }

    /// Test: Capture welcome screen (empty state)
    func testScreenshots01_WelcomeScreen() throws {
        // Launch with empty state - SKIP_TEST_DATA prevents populating lists
        guard launchAppWithRetry(arguments: ["UITEST_MODE", "UITEST_SCREENSHOT_MODE", "DISABLE_TOOLTIPS", "SKIP_TEST_DATA"]) else {
            XCTFail("App failed to launch for welcome screen screenshot")
            return
        }

        // Wait for UI to be ready
        sleep(2)

        // Take screenshot of empty state
        print("📸 Capturing welcome screen screenshot")
        snapshot("01_Welcome")
        print("✅ Welcome screen screenshot captured")
    }

    /// Test: Capture main flow with data
    func testScreenshots02_MainFlow() throws {
        // Launch with test data - without SKIP_TEST_DATA, hardcoded lists will be populated
        guard launchAppWithRetry(arguments: ["UITEST_MODE", "UITEST_SCREENSHOT_MODE", "DISABLE_TOOLTIPS"]) else {
            XCTFail("App failed to launch for main flow screenshot")
            return
        }

        // Wait for UI to be ready and data to load
        sleep(2)

        // Screenshot: Main screen with hardcoded test lists
        print("📸 Capturing main screen screenshot")
        snapshot("02_MainScreen")
        print("✅ Main screen screenshot captured")
    }
}
