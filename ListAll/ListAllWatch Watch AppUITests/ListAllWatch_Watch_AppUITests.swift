//
//  ListAllWatch_Watch_AppUITests.swift
//  ListAllWatch Watch AppUITests
//
//  Created by Aleksi Sutela on 19.10.2025.
//

import XCTest

final class ListAllWatch_Watch_AppUITests: XCTestCase {

    var app: XCUIApplication!

    override func setUpWithError() throws {
        // Put setup code here. This method is called before the invocation of each test method in the class.

        // In UI tests it is usually best to stop immediately when a failure occurs.
        continueAfterFailure = false

        // In UI tests it's important to set the initial state - such as interface orientation - required for your tests before they run. The setUp method is a good place to do this.
    }

    override func tearDownWithError() throws {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
        app = nil
    }

    /// Launch the Watch app with retry logic for improved reliability
    /// - Parameter maxRetries: Maximum number of launch attempts (default: 2)
    /// - Returns: True if launch succeeded
    /// - Throws: XCTSkip if all launch attempts fail
    @MainActor
    private func launchAppWithRetry(maxRetries: Int = 2) throws -> Bool {
        print("========================================")
        print("⌚️ Starting Watch app launch with retry logic")
        print("🔄 Max attempts: \(maxRetries)")
        print("⏱️  Started at: \(Date())")
        print("========================================")

        for attempt in 1...maxRetries {
            if attempt > 1 {
                print("⏳ Waiting 5 seconds before retry attempt \(attempt)...")
                sleep(5)

                // Recreate app instance for retry
                app = XCUIApplication()
                setupSnapshot(app)
                app.launchArguments.append("UITEST_MODE")
                app.launchEnvironment["UITEST_SEED"] = "1"
            }

            print("🚀 Launch attempt \(attempt)/\(maxRetries)...")
            app.launch()

            if app.wait(for: .runningForeground, timeout: 30) {
                print("✅ Watch app launched successfully on attempt \(attempt)")

                // Wait for first cell to appear as confirmation that UI is ready
                let firstCell = app.cells.firstMatch
                if firstCell.waitForExistence(timeout: 15) {
                    print("✅ UI is ready - first cell appeared")
                    return true
                } else {
                    print("⚠️  App launched but UI not ready on attempt \(attempt)")
                    continue
                }
            }

            print("⚠️  Watch app launch attempt \(attempt)/\(maxRetries) failed")
        }

        throw XCTSkip("Watch app failed to launch after \(maxRetries) attempts")
    }

    /// Wait for an element to appear with detailed diagnostic logging
    /// - Parameters:
    ///   - element: The UI element to wait for
    ///   - timeout: Maximum time to wait in seconds
    ///   - description: Human-readable description for logging
    /// - Returns: True if element appeared within timeout
    @MainActor
    private func waitForElement(_ element: XCUIElement, timeout: TimeInterval = 10, description: String) -> Bool {
        print("⏳ Waiting for: \(description) (timeout: \(timeout)s)")
        let existed = element.waitForExistence(timeout: timeout)
        if existed {
            print("✅ Found: \(description)")
        } else {
            print("❌ Not found: \(description) after \(timeout)s")
        }
        return existed
    }

    @MainActor
    func testWatchScreenshots() throws {
        print("========================================")
        print("⌚️ Starting Watch Screenshot Test")
        print("⏱️  Test started at: \(Date())")
        print("========================================")

        // UI tests must launch the application that they test.
        app = XCUIApplication()

        // Setup snapshot for Fastlane screenshot automation
        setupSnapshot(app)

        // Enable UI test mode with deterministic data
        app.launchArguments.append("UITEST_MODE")
        app.launchEnvironment["UITEST_SEED"] = "1"

        // Launch the app with retry logic
        do {
            _ = try launchAppWithRetry(maxRetries: 2)
        } catch {
            XCTFail("Failed to launch Watch app: \(error.localizedDescription)")
            return
        }

        // Screenshot 1: Lists Home (REQUIRED)
        print("========================================")
        print("📸 Phase 1: Capturing Lists Home")
        print("========================================")
        snapshot("01_Watch_Lists_Home")
        print("✅ Screenshot 1 captured successfully")

        // Navigate to first list by tapping the first cell
        print("========================================")
        print("📸 Phase 2: Navigating to First List")
        print("========================================")

        let firstCell = app.cells.element(boundBy: 0)
        guard waitForElement(firstCell, timeout: 10, description: "First list cell") else {
            XCTFail("❌ First list cell not found - cannot capture list detail screenshots")
            return
        }

        print("👉 Tapping first list cell")
        firstCell.tap()

        // Wait until detail view is visible by looking for the filter button ("All"/"Kaikki")
        let filterButton = app.buttons.matching(NSPredicate(format: "label CONTAINS[c] 'All' OR label CONTAINS[c] 'Kaikki'")).element
        guard waitForElement(filterButton, timeout: 10, description: "Filter button (All/Kaikki)") else {
            XCTFail("❌ Filter button not found - list detail view may not have loaded")
            return
        }

        // Screenshot 2: List Detail (REQUIRED)
        print("📸 Capturing Screenshot 2: List Detail")
        snapshot("02_Watch_List_Detail")
        print("✅ Screenshot 2 captured successfully")

        // Interact with an item (toggle completion)
        print("========================================")
        print("📸 Phase 3: Item Interaction")
        print("========================================")

        let firstItem = app.buttons.matching(NSPredicate(format: "label CONTAINS[c] 'Milk' OR label CONTAINS[c] 'Maito'")).element
        guard waitForElement(firstItem, timeout: 10, description: "First item (Milk/Maito)") else {
            XCTFail("❌ First item (Milk/Maito) not found - cannot capture item toggled screenshot")
            return
        }

        print("👉 Toggling item completion state")
        firstItem.tap()

        // Wait for the item's visual state to update (checkmark appearance)
        // The item button should still exist but with updated state
        let itemStillExists = firstItem.waitForExistence(timeout: 5)
        if !itemStillExists {
            print("⚠️  Item disappeared after tap - unexpected behavior")
        }

        // Screenshot 3: Item Toggled (REQUIRED)
        print("📸 Capturing Screenshot 3: Item Toggled")
        snapshot("03_Watch_Item_Toggled")
        print("✅ Screenshot 3 captured successfully")

        // Go back to lists view: try nav bar back button, else swipe right
        print("========================================")
        print("📸 Phase 4: Navigating to Second List")
        print("========================================")

        let backButton = app.navigationBars.buttons.element(boundBy: 0)
        if backButton.exists {
            print("⬅️ Tapping back button to return to lists")
            backButton.tap()
        } else {
            print("⬅️ Back button not found, attempting swipe right gesture")
            app.swipeRight()
        }

        // Wait for lists view to appear by checking for second cell
        let secondCell = app.cells.element(boundBy: 1)
        guard waitForElement(secondCell, timeout: 10, description: "Second list cell") else {
            XCTFail("❌ Second list cell not found - may not have navigated back to lists view")
            return
        }

        print("👉 Tapping second list cell")
        secondCell.tap()

        // Wait for second list detail view to load
        let secondListFilterButton = app.buttons.matching(NSPredicate(format: "label CONTAINS[c] 'All' OR label CONTAINS[c] 'Kaikki'")).element
        guard waitForElement(secondListFilterButton, timeout: 10, description: "Second list filter button") else {
            XCTFail("❌ Second list detail view not loaded")
            return
        }

        // Screenshot 4: Different list with different content (REQUIRED)
        print("📸 Capturing Screenshot 4: Second List")
        snapshot("04_Watch_Second_List")
        print("✅ Screenshot 4 captured successfully")

        // Test filter functionality
        print("========================================")
        print("📸 Phase 5: Filter Menu")
        print("========================================")

        let filterButton2 = app.buttons.matching(NSPredicate(format: "label CONTAINS[c] 'All' OR label CONTAINS[c] 'Kaikki'")).element
        guard waitForElement(filterButton2, timeout: 10, description: "Filter button for menu") else {
            XCTFail("❌ Filter button not found - cannot capture filter menu screenshot")
            return
        }

        print("👉 Tapping filter button to open menu")
        filterButton2.tap()

        // Wait for filter menu to appear - look for "Active" or "Aktiiviset" option
        let filterMenuOption = app.buttons.matching(NSPredicate(format: "label CONTAINS[c] 'Active' OR label CONTAINS[c] 'Aktiiviset'")).element
        guard waitForElement(filterMenuOption, timeout: 10, description: "Filter menu option (Active/Aktiiviset)") else {
            XCTFail("❌ Filter menu did not appear")
            return
        }

        // Screenshot 5: Filter Menu (REQUIRED)
        print("📸 Capturing Screenshot 5: Filter Menu")
        snapshot("05_Watch_Filter_Menu")
        print("✅ Screenshot 5 captured successfully")

        print("========================================")
        print("✅ All 5 Watch screenshots captured successfully!")
        print("⏱️  Test completed at: \(Date())")
        print("========================================")
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
