import XCTest

/// Simplified screenshot tests - no complex detection, just straightforward screenshot capture
@MainActor
final class ListAllUITests_Screenshots: XCTestCase {

    var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()

        // Setup Fastlane snapshot
        setupSnapshot(app)
    }

    /// Test: Capture welcome screen (empty state)
    func testScreenshots01_WelcomeScreen() throws {
        // CRITICAL: Terminate app first to force fresh launch with correct AppleLanguages
        // iOS caches .strings bundle on first launch, so we need to kill/relaunch for language change
        app.terminate()

        // Launch with empty state - SKIP_TEST_DATA prevents populating lists
        // CRITICAL: Use += to APPEND arguments, not = which would overwrite the language settings from setupSnapshot()
        app.launchArguments += ["UITEST_MODE", "UITEST_SCREENSHOT_MODE", "DISABLE_TOOLTIPS", "SKIP_TEST_DATA"]

        app.launch()

        // Wait for app to be ready
        sleep(2)

        // Take screenshot of empty state
        snapshot("01_Welcome")
    }

    /// Test: Capture main flow with data
    func testScreenshots02_MainFlow() throws {
        // CRITICAL: Terminate app first to force fresh launch with correct AppleLanguages
        // Without this, the app from test01 might still be running with stale state
        // This caused 30-minute hangs on iPad Finnish in CI
        app.terminate()

        // Launch with test data - without SKIP_TEST_DATA, hardcoded lists will be populated
        // CRITICAL: Use += to APPEND arguments, not = which would overwrite the language settings from setupSnapshot()
        app.launchArguments += ["UITEST_MODE", "UITEST_SCREENSHOT_MODE", "DISABLE_TOOLTIPS"]

        app.launch()

        // Wait for app to be ready
        sleep(2)

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
