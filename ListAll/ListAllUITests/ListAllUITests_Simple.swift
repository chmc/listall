import XCTest

/// Simplified screenshot tests - no complex detection, just straightforward screenshot capture
@MainActor
final class ListAllUITests_Screenshots: XCTestCase {

    var app: XCUIApplication!

    /// Timeout for app launch - iPad simulators in CI can be very slow
    /// Increased from 30s to 60s to handle iPad Pro in CI
    private let launchTimeout: TimeInterval = 60

    /// Timeout for UI elements to appear after launch
    /// iPad simulators need significantly more time, especially with locale switching
    private let elementTimeout: TimeInterval = 30

    /// Whether running on iPad (used for navigation adjustments)
    private var isIPad: Bool {
        UIDevice.current.userInterfaceIdiom == .pad
    }

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
        let uiReady = waitForUIReady()

        // iPad welcome screen may not have the elements waitForUIReady() checks for
        // (no cells in empty state, navigation structure differs from iPhone)
        // Add explicit wait for iPad to ensure UI renders before screenshot
        if !uiReady {
            print("⏳ UI ready check returned false - adding fallback wait for iPad rendering...")
            sleep(5)
        }

        // Verify app window is actually rendered by checking window existence
        let window = app.windows.firstMatch
        if !window.waitForExistence(timeout: 10) {
            print("⚠️ Warning: Window not detected, but proceeding with screenshot")
        } else {
            print("✅ App window confirmed visible")
        }

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

        // CRITICAL: Wait for data to load into list - MUST find cells before taking screenshot
        // iPad + Finnish locale combination is particularly slow due to locale switching overhead
        // Without this check, we get black screenshots
        let anyCell = app.cells.firstMatch

        // First attempt with standard timeout
        if anyCell.waitForExistence(timeout: elementTimeout) {
            print("✅ Data loaded - found list cells")
        } else {
            // iPad may need extra time - wait longer and check again
            print("⚠️ No cells found on first attempt, waiting additional time for iPad/locale...")
            sleep(5)

            if anyCell.waitForExistence(timeout: elementTimeout) {
                print("✅ Data loaded on retry - found list cells")
            } else {
                // Final check - if still no cells, fail the test rather than capture black screenshot
                print("❌ CRITICAL: No cells found after extended wait - UI did not render")
                print("❌ This would result in a black/empty screenshot")
                XCTFail("List cells not found - data did not load in time. Screenshot would be black.")
                return
            }
        }

        // On iPad: select first list to show sidebar + content two-column layout
        // Without this, iPad screenshot shows sidebar + "Select a List" placeholder
        if isIPad {
            let firstCell = app.cells.firstMatch
            if firstCell.exists {
                print("📱 iPad: Tapping first list to show two-column layout")
                firstCell.tap()

                // Wait for detail column to load (look for items or AddItemButton)
                let addButton = app.buttons["AddItemButton"]
                let addButtonToolbar = app.buttons["AddItemToolbarButton"]
                if addButton.waitForExistence(timeout: elementTimeout) {
                    print("✅ iPad: Detail column loaded with list items")
                } else if addButtonToolbar.waitForExistence(timeout: elementTimeout) {
                    print("✅ iPad: Detail column loaded with list items (toolbar button)")
                } else {
                    print("⚠️ iPad: Detail column slow to load, adding settle time")
                    sleep(3)
                }
            }
        }

        // Screenshot: Main screen with hardcoded test lists
        print("📸 Capturing main screen screenshot")
        snapshot("02_MainScreen")
        print("✅ Main screen screenshot captured")
        print("========================================")
    }

    // MARK: - Navigation Helpers

    /// Launch app with test data, wait for list cells to load, and navigate to the first list (Grocery Shopping)
    /// Returns true if navigation succeeded
    private func launchAndNavigateToGroceryList() -> Bool {
        guard launchAppWithRetry(arguments: ["UITEST_MODE", "UITEST_SCREENSHOT_MODE", "DISABLE_TOOLTIPS"]) else {
            XCTFail("App failed to launch")
            return false
        }

        _ = waitForUIReady()

        // Wait for list cells to appear
        let firstCell = app.cells.firstMatch
        if firstCell.waitForExistence(timeout: elementTimeout) {
            print("✅ Data loaded - found list cells")
        } else {
            print("⚠️ No cells found on first attempt, waiting additional time for iPad/locale...")
            sleep(5)
            if firstCell.waitForExistence(timeout: elementTimeout) {
                print("✅ Data loaded on retry - found list cells")
            } else {
                XCTFail("List cells not found - data did not load in time.")
                return false
            }
        }

        // Tap the first list cell (Grocery Shopping / Ruokaostokset - orderNumber 0)
        print("👆 Tapping first list cell to navigate to grocery items")
        firstCell.tap()

        // Wait for items view to load - use the AddItemButton identifier (locale-independent)
        let addButton = app.buttons["AddItemButton"]
        let addButtonToolbar = app.buttons["AddItemToolbarButton"]
        if addButton.waitForExistence(timeout: elementTimeout) {
            if UIDevice.current.userInterfaceIdiom == .pad {
                print("📱 iPad: Sidebar + detail layout - list selected in sidebar, items shown in detail column")
            }
            print("✅ Navigated to grocery list items view (found AddItemButton)")
            sleep(1) // settle time
            return true
        } else if addButtonToolbar.waitForExistence(timeout: elementTimeout) {
            print("✅ Navigated to grocery list items view (found AddItemToolbarButton - iPad)")
            sleep(1) // settle time
            return true
        }

        // Fallback: check for known item text (English or Finnish)
        let milkEN = app.staticTexts["Milk"]
        let milkFI = app.staticTexts["Maito"]
        if milkEN.waitForExistence(timeout: 5) || milkFI.waitForExistence(timeout: 3) {
            print("✅ Navigated to grocery list items view (found item text)")
            sleep(1) // settle time
        } else {
            // Last fallback: the navigation may have worked but items are slow to render
            print("⚠️ Items view elements not detected, proceeding with extended wait")
            sleep(5)
        }

        // Confirm toolbar is fully rendered before returning
        let sortFilterButton = app.buttons["SortFilterButton"]
        if !sortFilterButton.waitForExistence(timeout: 5) {
            print("⚠️ SortFilterButton not yet visible, waiting for toolbar...")
            sleep(2)
            if !sortFilterButton.waitForExistence(timeout: 5) {
                print("⚠️ Toolbar not ready even after extended wait")
            }
        } else {
            print("✅ Toolbar ready (SortFilterButton visible)")
        }

        return true
    }

    /// Test: Capture grocery items list (iPhone only — iPad shows this in 02 via split view)
    func testScreenshots03_GroceryItems() throws {
        try XCTSkipIf(isIPad, "iPad two-column layout already shows items in screenshot 02")

        guard launchAndNavigateToGroceryList() else {
            XCTFail("Failed to navigate to grocery list")
            return
        }

        snapshot("03_GroceryItems")
    }

    /// Test: Capture sort/filter organization sheet on grocery list
    func testScreenshots04_SortFilter() throws {
        print("========================================")
        print("📱 Starting Sort/Filter Screenshot Test")
        print("========================================")

        guard launchAndNavigateToGroceryList() else {
            XCTFail("Failed to navigate to grocery list")
            return
        }

        // Tap the sort/filter button to open the Organization sheet
        let sortFilterButton = app.buttons["SortFilterButton"]
        guard sortFilterButton.waitForExistence(timeout: elementTimeout) else {
            XCTFail("SortFilterButton not found")
            return
        }

        let doneButton = app.buttons["OrganizationDoneButton"]
        var sheetAppeared = false

        // Retry up to 3 times — button action uses `= true` (not toggle), so re-tap is safe
        for attempt in 1...3 {
            print("👆 Tapping sort/filter button (attempt \(attempt))")
            if sortFilterButton.isHittable {
                sortFilterButton.tap()
            } else {
                print("⚠️ Button exists but not hittable, waiting...")
                sleep(2)
                sortFilterButton.tap()
            }

            if doneButton.waitForExistence(timeout: 10) {
                print("✅ Organization sheet appeared")
                sheetAppeared = true
                break
            }
            print("⚠️ Sheet not detected after attempt \(attempt), retrying...")
            sleep(1)
        }

        guard sheetAppeared else {
            XCTFail("Organization sheet did not appear after 3 attempts")
            return
        }

        print("📸 Capturing sort/filter screenshot")
        snapshot(isIPad ? "03_SortFilter" : "04_SortFilter")
        print("✅ Sort/filter screenshot captured")
        print("========================================")
    }

    /// Test: Capture add new item sheet on grocery list
    func testScreenshots05_AddItem() throws {
        print("========================================")
        print("📱 Starting Add Item Screenshot Test")
        print("========================================")

        guard launchAndNavigateToGroceryList() else {
            XCTFail("Failed to navigate to grocery list")
            return
        }

        // Tap the floating add item button - primary: identifier (locale-independent)
        let addButtonByID = app.buttons["AddItemButton"]
        let addButtonToolbar = app.buttons["AddItemToolbarButton"]  // iPad toolbar
        let addButtonEN = app.buttons["Add new item"]
        let addButtonFI = app.buttons["Lisää uusi tuote"]
        var addButtonFound = false

        if addButtonByID.waitForExistence(timeout: elementTimeout) {
            print("👆 Tapping add item button (by identifier)")
            addButtonByID.tap()
            addButtonFound = true
        } else if addButtonToolbar.waitForExistence(timeout: elementTimeout) {
            print("👆 Tapping add item button (iPad toolbar)")
            addButtonToolbar.tap()
            addButtonFound = true
        } else if addButtonEN.waitForExistence(timeout: 5) {
            print("👆 Tapping add item button (EN label fallback)")
            addButtonEN.tap()
            addButtonFound = true
        } else if addButtonFI.waitForExistence(timeout: 3) {
            print("👆 Tapping add item button (FI label fallback)")
            addButtonFI.tap()
            addButtonFound = true
        }

        if !addButtonFound {
            // Diagnostic output: dump button hierarchy
            let allButtons = app.buttons.allElementsBoundByAccessibilityElement
            print("❌ Add item button not found. Button count: \(allButtons.count)")
            for (index, button) in allButtons.enumerated() where index < 10 {
                print("  Button[\(index)]: identifier='\(button.identifier)', label='\(button.label)'")
            }
            XCTFail("Add item button not found in either locale")
            return
        }

        // Wait for the item edit sheet to appear
        // Try both English and Finnish placeholder text
        let titleFieldEN = app.textFields["Enter item name"]
        let titleFieldFI = app.textFields["Syötä tuotteen nimi"]
        var titleField: XCUIElement?

        if titleFieldEN.waitForExistence(timeout: elementTimeout) {
            titleField = titleFieldEN
            print("✅ Add item sheet appeared (EN)")
        } else if titleFieldFI.waitForExistence(timeout: 5) {
            titleField = titleFieldFI
            print("✅ Add item sheet appeared (FI)")
        } else {
            print("⚠️ Title field not found by placeholder, waiting for sheet...")
            sleep(3)
        }

        // Determine locale and type appropriate item name
        let isFinnish = titleField == titleFieldFI
        let itemName = isFinnish ? "Avokado" : "Avocado"

        print("🌐 Locale: \(isFinnish ? "Finnish" : "English"), typing '\(itemName)'")
        if let field = titleField {
            field.tap()
            field.typeText(itemName)
        } else {
            // Fallback: type into whatever field is focused
            app.typeText(itemName)
        }

        // Brief settle time for text to render
        sleep(1)

        print("📸 Capturing add item screenshot")
        snapshot(isIPad ? "04_AddItem" : "05_AddItem")
        print("✅ Add item screenshot captured")
        print("========================================")
    }
}
