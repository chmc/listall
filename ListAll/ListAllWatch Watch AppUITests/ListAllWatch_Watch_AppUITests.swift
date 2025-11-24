//
//  ListAllWatch_Watch_AppUITests.swift
//  ListAllWatch Watch AppUITests
//
//  Created by Aleksi Sutela on 19.10.2025.
//

import XCTest

final class ListAllWatch_Watch_AppUITests: XCTestCase {

    override func setUpWithError() throws {
        // Put setup code here. This method is called before the invocation of each test method in the class.

        // In UI tests it is usually best to stop immediately when a failure occurs.
        continueAfterFailure = false

        // In UI tests it's important to set the initial state - such as interface orientation - required for your tests before they run. The setUp method is a good place to do this.
    }

    override func tearDownWithError() throws {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }

    @MainActor
    func testWatchScreenshots() throws {
        // UI tests must launch the application that they test.
        let app = XCUIApplication()

        // Setup snapshot for Fastlane screenshot automation
        setupSnapshot(app)

        // Enable UI test mode with deterministic data
        app.launchArguments.append("UITEST_MODE")
        app.launchEnvironment["UITEST_SEED"] = "1"

        // Launch the app
        app.launch()

        // Wait for app to be ready - use proper wait instead of fixed sleep
        let launched = app.wait(for: .runningForeground, timeout: 30)
        XCTAssertTrue(launched, "Watch app failed to launch within 30 seconds")

        // Additional wait for initial data to load
        sleep(3)

        // Screenshot 1: Lists Home (REQUIRED)
        print("📸 Capturing Screenshot 1: Lists Home")
        snapshot("01_Watch_Lists_Home")
        print("✅ Screenshot 1 captured")

        // Navigate to first list by tapping the first cell
        let firstCell = app.cells.element(boundBy: 0)
        guard firstCell.waitForExistence(timeout: 10) else {
            XCTFail("❌ First list cell not found - cannot capture list detail screenshots")
            return
        }

        print("👉 Tapping first list cell")
        firstCell.tap()

        // Wait until detail view is visible by looking for the filter button ("All"/"Kaikki")
        let filterButton = app.buttons.matching(NSPredicate(format: "label CONTAINS[c] 'All' OR label CONTAINS[c] 'Kaikki'")).element
        _ = filterButton.waitForExistence(timeout: 10)
        sleep(1)

        // Screenshot 2: List Detail (REQUIRED)
        print("📸 Capturing Screenshot 2: List Detail")
        snapshot("02_Watch_List_Detail")
        print("✅ Screenshot 2 captured")

        // Interact with an item (toggle completion)
        let firstItem = app.buttons.matching(NSPredicate(format: "label CONTAINS[c] 'Milk' OR label CONTAINS[c] 'Maito'")).element
        guard firstItem.waitForExistence(timeout: 10) else {
            XCTFail("❌ First item (Milk/Maito) not found - cannot capture item toggled screenshot")
            return
        }

        print("📸 Preparing Screenshot 3: Item interaction")
        firstItem.tap()
        sleep(1)

        // Screenshot 3: Item Toggled (REQUIRED)
        print("📸 Capturing Screenshot 3: Item Toggled")
        snapshot("03_Watch_Item_Toggled")
        print("✅ Screenshot 3 captured")

        // Go back to lists view: try nav bar back button, else swipe right
        let backButton = app.navigationBars.buttons.element(boundBy: 0)
        if backButton.exists {
            print("⬅️ Tapping back button")
            backButton.tap()
        } else {
            print("⬅️ Back button not found, attempting swipe right")
            app.swipeRight()
        }
        sleep(2)

        // Navigate to second list by index
        let secondCell = app.cells.element(boundBy: 1)
        guard secondCell.waitForExistence(timeout: 10) else {
            XCTFail("❌ Second list cell not found - cannot capture second list screenshots")
            return
        }

        print("👉 Tapping second list cell")
        secondCell.tap()
        sleep(2)

        // Screenshot 4: Different list with different content (REQUIRED)
        print("📸 Capturing Screenshot 4: Second List")
        snapshot("04_Watch_Second_List")
        print("✅ Screenshot 4 captured")

        // Test filter functionality
        let filterButton2 = app.buttons.matching(NSPredicate(format: "label CONTAINS[c] 'All' OR label CONTAINS[c] 'Kaikki'")).element
        guard filterButton2.waitForExistence(timeout: 10) else {
            XCTFail("❌ Filter button not found - cannot capture filter menu screenshot")
            return
        }

        filterButton2.tap()
        sleep(1)

        // Screenshot 5: Filter Menu (REQUIRED)
        print("📸 Capturing Screenshot 5: Filter Menu")
        snapshot("05_Watch_Filter_Menu")
        print("✅ Screenshot 5 captured")

        print("✅ All 5 Watch screenshots captured successfully!")
    }

    @MainActor
    func testLaunchPerformance() throws {
        if #available(macOS 10.15, iOS 13.0, tvOS 13.0, watchOS 7.0, *) {
            // This measures how long it takes to launch your application.
            measure(metrics: [XCTApplicationLaunchMetric()]) {
                XCUIApplication().launch()
            }
        }
    }
}
