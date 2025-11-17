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
        // Launch with empty state
        app.launchArguments = ["UITEST_MODE", "UITEST_SCREENSHOT_MODE"]
        app.launchEnvironment["UITEST_SEED"] = "0"  // Empty state
        app.launch()

        // Wait for app to be ready
        sleep(2)

        // Take screenshot
        snapshot("01_Welcome")
    }

    /// Test: Capture main flow with data
    func testScreenshots02_MainFlow() throws {
        // Launch with test data
        app.launchArguments = ["UITEST_MODE", "UITEST_SCREENSHOT_MODE"]
        app.launchEnvironment["UITEST_SEED"] = "1"  // With test data
        app.launch()

        // Wait for app to be ready
        sleep(2)

        // Screenshot 1: Main screen with lists
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
