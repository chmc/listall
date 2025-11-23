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

    /// Wait for app to be fully launched and in foreground
    /// This prevents timeouts on slow iPad simulators in CI
    private func waitForAppReady() -> Bool {
        // Wait for app to be in running foreground state
        let launched = app.wait(for: .runningForeground, timeout: launchTimeout)
        if !launched {
            XCTFail("App failed to launch within \(launchTimeout) seconds")
            return false
        }

        // Additional small delay for UI to settle
        sleep(1)
        return true
    }

    /// Safely terminate the app, ignoring any termination failures
    /// This prevents "Failed to terminate" errors from failing the test on iPad
    private func safeTerminate() {
        // Check if app is running before attempting to terminate
        if app.state != .notRunning {
            app.terminate()
            // Wait briefly for termination to complete
            _ = app.wait(for: .notRunning, timeout: 5)
        }
    }

    /// Test: Capture welcome screen (empty state)
    func testScreenshots01_WelcomeScreen() throws {
        // CRITICAL: Terminate app first to force fresh launch with correct AppleLanguages
        // iOS caches .strings bundle on first launch, so we need to kill/relaunch for language change
        // Use safe termination to avoid "Failed to terminate" errors on iPad
        safeTerminate()

        // Launch with empty state - SKIP_TEST_DATA prevents populating lists
        // CRITICAL: Use += to APPEND arguments, not = which would overwrite the language settings from setupSnapshot()
        app.launchArguments += ["UITEST_MODE", "UITEST_SCREENSHOT_MODE", "DISABLE_TOOLTIPS", "SKIP_TEST_DATA"]

        app.launch()

        // Wait for app to be ready with proper timeout
        guard waitForAppReady() else { return }

        // Take screenshot of empty state
        snapshot("01_Welcome")
    }

    /// Test: Capture main flow with data
    func testScreenshots02_MainFlow() throws {
        // CRITICAL: Terminate app first to force fresh launch with correct AppleLanguages
        // Without this, the app from test01 might still be running with stale state
        // Use safe termination to avoid "Failed to terminate" errors on iPad
        safeTerminate()

        // Launch with test data - without SKIP_TEST_DATA, hardcoded lists will be populated
        // CRITICAL: Use += to APPEND arguments, not = which would overwrite the language settings from setupSnapshot()
        app.launchArguments += ["UITEST_MODE", "UITEST_SCREENSHOT_MODE", "DISABLE_TOOLTIPS"]

        app.launch()

        // Wait for app to be ready with proper timeout
        guard waitForAppReady() else { return }

        // Screenshot: Main screen with hardcoded test lists
        snapshot("02_MainScreen")

        // Navigate and take more screenshots as needed
        // Example: tap first list, wait, screenshot
        // let firstList = app.collectionViews.cells.firstMatch
        // if firstList.exists {
        //     firstList.tap()
        //     sleep(1)
        //     snapshot("03_ListDetail")
        // }
    }
}
