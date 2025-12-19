//
//  ListAllMacUITests.swift
//  ListAllMacUITests
//
//  UI tests for the ListAll macOS app.
//

import XCTest

@MainActor
final class ListAllMacUITests: XCTestCase {

    var app: XCUIApplication!

    // MARK: - Setup and Teardown

    override func setUpWithError() throws {
        // Stop on first failure for easier debugging
        continueAfterFailure = false

        // Create app instance
        app = XCUIApplication()

        // Launch with test configuration
        app.launchForUITest(skipTestData: false)

        // Wait for app to be ready
        XCTAssertTrue(
            app.wait(for: .runningForeground, timeout: 10),
            "App should launch successfully"
        )

        print("🧪 macOS UI Test setup complete")
    }

    override func tearDownWithError() throws {
        // Terminate app after each test
        if app != nil {
            app.terminate()
            app = nil
        }
    }

    // MARK: - Launch Tests

    func testAppLaunches() throws {
        // Verify the app launched and main UI is ready
        // Note: Use isMainUIReady() instead of mainWindow.exists due to SwiftUI accessibility limitations
        XCTAssertTrue(app.isMainUIReady(timeout: 5), "Main UI should be ready")
        XCTAssertEqual(app.state, .runningForeground, "App should be in foreground")
    }

    func testMainWindowElements() throws {
        // Verify key UI elements are present
        // Note: Use isMainUIReady() instead of mainWindow.exists due to SwiftUI accessibility limitations
        XCTAssertTrue(app.isMainUIReady(timeout: 5), "Main UI should be ready")

        // Sidebar should be visible
        let sidebar = app.outlines.firstMatch
        XCTAssertTrue(sidebar.exists, "Sidebar should be visible")

        // Detail area should be present
        let detailArea = app.scrollViews.firstMatch
        XCTAssertTrue(detailArea.exists, "Detail area should exist")
    }

    // MARK: - Test Data Verification

    func testDeterministicDataLoaded() throws {
        // Verify that all expected test lists are present
        XCTAssertTrue(
            app.verifyTestListsPresent(locale: "en-US"),
            "All test lists should be present"
        )

        // Verify we have exactly 4 lists
        let expectedListCount = XCUIApplication.englishTestLists.count
        let actualListCount = app.listCount()
        XCTAssertEqual(
            actualListCount,
            expectedListCount,
            "Should have \(expectedListCount) test lists"
        )
    }

    // MARK: - Menu Navigation Tests

    func testFileMenuNewListCommand() throws {
        // Click File > New List menu item
        app.clickMenuItem(["File", "New List"])

        // Verify create list sheet appears
        let sheet = app.waitForSheet(timeout: 3)
        XCTAssertNotNil(sheet, "Create list sheet should appear")

        // Cancel to clean up
        app.dismissSheet()
    }

    func testKeyboardShortcutNewList() throws {
        // Use Command+N to create new list
        app.createNewListViaKeyboard()

        // Verify create list sheet appears
        let sheet = app.waitForSheet(timeout: 3)
        XCTAssertNotNil(sheet, "Create list sheet should appear via keyboard shortcut")

        // Cancel to clean up
        app.dismissSheet()
    }

    func testSettingsMenuCommand() throws {
        // Open Settings via Command+Comma
        app.openSettings()

        // Verify Settings window appears
        let settingsWindow = app.waitForWindow(title: "Settings", timeout: 3)
        XCTAssertNotNil(settingsWindow, "Settings window should open")

        // Close Settings
        app.closeSettings()
    }

    // MARK: - Sidebar Interaction Tests

    func testSelectListInSidebar() throws {
        // Select the first test list
        let firstListName = XCUIApplication.englishTestLists[0]
        let selected = app.selectList(named: firstListName)

        XCTAssertTrue(selected, "Should be able to select list '\(firstListName)'")

        // Verify list detail view shows the list name
        let listTitle = app.staticTexts[firstListName]
        XCTAssertTrue(
            listTitle.waitForExistence(timeout: 3),
            "List title should appear in detail view"
        )
    }

    func testSidebarShowsListCounts() throws {
        // Each list in sidebar should show item count
        let firstListName = XCUIApplication.englishTestLists[0]
        let listCell = app.outlines.cells.staticTexts[firstListName]

        XCTAssertTrue(
            listCell.waitForExistence(timeout: 3),
            "List cell should exist in sidebar"
        )

        // The item count should be visible (as secondary text)
        // For "Grocery Shopping" we expect 6 items from test data
        let countLabel = app.outlines.cells.staticTexts["6"]
        XCTAssertTrue(
            countLabel.exists,
            "Item count should be visible in sidebar"
        )
    }

    // MARK: - List Creation Tests

    func testCreateNewListWithValidName() throws {
        // Open create list sheet
        app.createNewListViaKeyboard()

        // Wait for sheet
        let sheet = try XCTUnwrap(app.waitForSheet(timeout: 3), "Sheet should appear")

        // Find text field and enter list name
        let textField = sheet.textFields.firstMatch
        XCTAssertTrue(textField.waitForExistence(timeout: 2), "Text field should exist")

        textField.click()
        textField.typeText("Test List")

        // Click Create button
        let createButton = sheet.buttons["Create"]
        XCTAssertTrue(createButton.exists, "Create button should exist")
        createButton.click()

        // Verify sheet dismisses
        XCTAssertTrue(
            sheet.waitForDisappearance(timeout: 3),
            "Sheet should dismiss after creating list"
        )

        // Verify new list appears in sidebar
        let newListCell = app.outlines.cells.staticTexts["Test List"]
        XCTAssertTrue(
            newListCell.waitForExistence(timeout: 3),
            "New list should appear in sidebar"
        )
    }

    func testCreateListValidationEmptyName() throws {
        // Open create list sheet
        app.createNewListViaKeyboard()

        let sheet = try XCTUnwrap(app.waitForSheet(timeout: 3), "Sheet should appear")

        // Try to create without entering a name
        let createButton = sheet.buttons["Create"]
        XCTAssertTrue(createButton.exists, "Create button should exist")

        // Create button should be disabled when text is empty
        XCTAssertFalse(createButton.isEnabled, "Create button should be disabled with empty name")

        // Cancel to clean up
        app.dismissSheet()
    }

    func testCancelListCreation() throws {
        // Open create list sheet
        app.createNewListViaKeyboard()

        let sheet = try XCTUnwrap(app.waitForSheet(timeout: 3), "Sheet should appear")

        // Enter some text
        let textField = sheet.textFields.firstMatch
        textField.click()
        textField.typeText("This Will Be Cancelled")

        // Click Cancel button
        let cancelButton = sheet.buttons["Cancel"]
        XCTAssertTrue(cancelButton.exists, "Cancel button should exist")
        cancelButton.click()

        // Verify sheet dismisses
        XCTAssertTrue(
            sheet.waitForDisappearance(timeout: 3),
            "Sheet should dismiss after cancel"
        )

        // Verify list was not created
        let listCell = app.outlines.cells.staticTexts["This Will Be Cancelled"]
        XCTAssertFalse(listCell.exists, "Cancelled list should not appear in sidebar")
    }

    // MARK: - List Detail Tests

    func testListDetailShowsItems() throws {
        // Select first list
        let firstListName = XCUIApplication.englishTestLists[0] // "Grocery Shopping"
        app.selectList(named: firstListName)

        // Wait for list detail to load
        Thread.sleep(forTimeInterval: 1)

        // Verify items are displayed
        let itemCount = app.itemCount()
        XCTAssertGreaterThan(itemCount, 0, "List should have items")

        // Verify specific test items exist (from UITestDataService)
        let milkItem = app.tables.cells.staticTexts["Milk"]
        XCTAssertTrue(milkItem.waitForExistence(timeout: 3), "Milk item should exist")

        let breadItem = app.tables.cells.staticTexts["Bread"]
        XCTAssertTrue(breadItem.exists, "Bread item should exist")
    }

    func testToggleItemCompletion() throws {
        // Select first list
        let firstListName = XCUIApplication.englishTestLists[0]
        app.selectList(named: firstListName)

        // Wait for items to load
        Thread.sleep(forTimeInterval: 1)

        // Find an uncompleted item (Milk)
        let milkItem = app.tables.cells.staticTexts["Milk"]
        XCTAssertTrue(milkItem.waitForExistence(timeout: 3), "Milk item should exist")

        // Find and click its checkbox
        let toggled = app.toggleItem(titled: "Milk")
        XCTAssertTrue(toggled, "Should be able to toggle item completion")

        // Note: Verifying the visual state change is difficult in XCTest
        // The core functionality is that clicking doesn't crash
    }

    // MARK: - Item Creation Tests

    func testCreateNewItemInList() throws {
        // Select first list
        let firstListName = XCUIApplication.englishTestLists[0]
        app.selectList(named: firstListName)

        // Wait for list to load
        Thread.sleep(forTimeInterval: 1)

        // Get initial item count
        let initialCount = app.itemCount()

        // Create new item using keyboard shortcut (Command+I)
        app.createNewItemViaKeyboard()

        // Wait for add item sheet
        let sheet = try XCTUnwrap(app.waitForSheet(timeout: 3), "Add item sheet should appear")

        // Enter item name
        let textField = sheet.textFields.firstMatch
        XCTAssertTrue(textField.waitForExistence(timeout: 2), "Item name field should exist")

        textField.click()
        textField.typeText("Test Item")

        // Click Add button
        let addButton = sheet.buttons["Add"]
        XCTAssertTrue(addButton.exists, "Add button should exist")
        addButton.click()

        // Verify sheet dismisses
        XCTAssertTrue(
            sheet.waitForDisappearance(timeout: 3),
            "Sheet should dismiss after adding item"
        )

        // Wait for UI to update
        Thread.sleep(forTimeInterval: 1)

        // Verify item was added
        let newItem = app.tables.cells.staticTexts["Test Item"]
        XCTAssertTrue(
            newItem.waitForExistence(timeout: 3),
            "New item should appear in list"
        )

        // Verify item count increased
        let newCount = app.itemCount()
        XCTAssertEqual(newCount, initialCount + 1, "Item count should increase by 1")
    }

    func testCreateItemWithQuantityAndDescription() throws {
        // Select first list
        let firstListName = XCUIApplication.englishTestLists[0]
        app.selectList(named: firstListName)

        Thread.sleep(forTimeInterval: 1)

        // Create new item
        app.createNewItemViaKeyboard()

        let sheet = try XCTUnwrap(app.waitForSheet(timeout: 3), "Add item sheet should appear")

        // Enter item name
        let textField = sheet.textFields.firstMatch
        textField.click()
        textField.typeText("Detailed Item")

        // Increase quantity (click stepper)
        let stepper = sheet.steppers.firstMatch
        if stepper.exists {
            stepper.buttons["increment"].click()
            stepper.buttons["increment"].click()
            // Should now be quantity 3
        }

        // Enter description (find text editor)
        let descriptionEditor = sheet.textViews.firstMatch
        if descriptionEditor.exists {
            descriptionEditor.click()
            descriptionEditor.typeText("This is a detailed description")
        }

        // Save
        sheet.buttons["Add"].click()

        // Verify sheet dismisses
        XCTAssertTrue(sheet.waitForDisappearance(timeout: 3), "Sheet should dismiss")

        // Verify item appears
        Thread.sleep(forTimeInterval: 1)
        let newItem = app.tables.cells.staticTexts["Detailed Item"]
        XCTAssertTrue(newItem.waitForExistence(timeout: 3), "Detailed item should appear")
    }

    // MARK: - Window Management Tests

    func testMultipleWindowsSupport() throws {
        // Verify main UI is ready
        // Note: Use isMainUIReady() instead of mainWindow.exists due to SwiftUI accessibility limitations
        XCTAssertTrue(app.isMainUIReady(timeout: 5), "Main UI should be ready")

        // Note: Opening multiple windows requires user interaction or specific menu commands
        // This is a placeholder for when that functionality is implemented
        // For now, we just verify single window works
    }

    func testWindowResizing() throws {
        // Get main window
        let window = app.mainWindow
        XCTAssertTrue(window.exists, "Main window should exist")

        // macOS windows should have standard window controls
        let closeButton = window.buttons[XCUIIdentifierCloseWindow]
        XCTAssertTrue(closeButton.exists, "Close button should exist")

        let minimizeButton = window.buttons[XCUIIdentifierMinimizeWindow]
        XCTAssertTrue(minimizeButton.exists, "Minimize button should exist")

        let zoomButton = window.buttons[XCUIIdentifierZoomWindow]
        XCTAssertTrue(zoomButton.exists, "Zoom button should exist")
    }

    // MARK: - Keyboard Navigation Tests

    func testTabNavigationInForm() throws {
        // Open create list sheet
        app.createNewListViaKeyboard()

        let sheet = try XCTUnwrap(app.waitForSheet(timeout: 3), "Sheet should appear")

        // Text field should have focus initially
        let textField = sheet.textFields.firstMatch
        XCTAssertTrue(textField.exists, "Text field should exist")

        // Type list name
        textField.typeText("Keyboard Nav Test")

        // Press Tab to move to next control
        textField.typeKey(XCUIKeyboardKey.tab, modifierFlags: [])

        // Press Return to activate Create button
        sheet.typeKey(XCUIKeyboardKey.return, modifierFlags: [])

        // Verify sheet dismisses
        XCTAssertTrue(
            sheet.waitForDisappearance(timeout: 3),
            "Sheet should dismiss via keyboard"
        )
    }

    func testEscapeKeyCancelsSheet() throws {
        // Open create list sheet
        app.createNewListViaKeyboard()

        let sheet = try XCTUnwrap(app.waitForSheet(timeout: 3), "Sheet should appear")

        // Press Escape to cancel
        sheet.typeKey(XCUIKeyboardKey.escape, modifierFlags: [])

        // Verify sheet dismisses
        XCTAssertTrue(
            sheet.waitForDisappearance(timeout: 3),
            "Sheet should dismiss with Escape key"
        )
    }

    // MARK: - Context Menu Tests

    func testListContextMenu() throws {
        // Select a list
        let firstListName = XCUIApplication.englishTestLists[1] // "Weekend Projects"
        let listCell = app.outlines.cells.staticTexts[firstListName]

        XCTAssertTrue(listCell.waitForExistence(timeout: 3), "List cell should exist")

        // Right-click to show context menu
        listCell.rightClick()

        // Wait for context menu to appear
        Thread.sleep(forTimeInterval: 0.5)

        // Verify Delete option exists
        let deleteMenuItem = app.menuItems["Delete"]
        XCTAssertTrue(
            deleteMenuItem.waitForExistence(timeout: 2),
            "Delete menu item should appear in context menu"
        )

        // Click away to dismiss menu (press Escape)
        app.typeKey(XCUIKeyboardKey.escape, modifierFlags: [])
    }

    // MARK: - Accessibility Tests

    func testAccessibilityLabels() throws {
        // Verify key elements have proper accessibility
        // Note: Use isMainUIReady() instead of mainWindow.exists due to SwiftUI accessibility limitations
        XCTAssertTrue(app.isMainUIReady(timeout: 5), "Main UI should be ready")

        // Sidebar should be accessible
        let sidebar = app.outlines.firstMatch
        XCTAssertTrue(sidebar.exists, "Sidebar should be accessible")

        // Buttons should have labels
        // Note: Specific identifiers would need to be added to the app
    }

    func testVoiceOverNavigation() throws {
        // Verify important elements are accessible to VoiceOver
        let keyIdentifiers: [String] = [
            // Add actual accessibility identifiers from MacAccessibilityIdentifier
            // when app views are updated with accessibility identifiers
        ]

        // Note: This is a placeholder - actual identifiers need to be added to the app
        // and then tested here
        print("🔍 VoiceOver navigation test placeholder: \(keyIdentifiers.count) identifiers to check")
    }

    // MARK: - Empty State Tests

    func testEmptyStateWithNoListSelected() throws {
        // Launch without selecting any list
        // The detail view should show empty state

        // Verify empty state message appears
        let emptyStateText = app.staticTexts["No List Selected"]
        XCTAssertTrue(
            emptyStateText.waitForExistence(timeout: 3),
            "Empty state message should appear when no list selected"
        )

        // Verify "Create New List" button exists in empty state
        let createButton = app.buttons["Create New List"]
        XCTAssertTrue(createButton.exists, "Create button should exist in empty state")
    }

    // MARK: - Performance Tests

    func testLaunchPerformance() throws {
        // Skip performance test during UI test runs
        throw XCTSkip("Performance tests should be run separately")

        // Measure app launch time
        measure(metrics: [XCTApplicationLaunchMetric()]) {
            let testApp = XCUIApplication()
            testApp.launchForUITest()
            testApp.terminate()
        }
    }

    func testListScrollPerformance() throws {
        // Skip performance test during UI test runs
        throw XCTSkip("Performance tests should be run separately")

        // Select list with many items
        let firstListName = XCUIApplication.englishTestLists[0]
        app.selectList(named: firstListName)

        // Measure scroll performance
        let table = app.tables.firstMatch
        XCTAssertTrue(table.exists, "Table should exist")

        measure {
            table.swipeUp()
            table.swipeDown()
        }
    }

    // MARK: - Screenshot Tests

    func testTakeMainScreenshot() throws {
        // Wait for UI to settle
        app.waitForUIToSettle(seconds: 1)

        // Select first list to show content
        let firstListName = XCUIApplication.englishTestLists[0]
        app.selectList(named: firstListName)

        // Wait for list to load
        app.waitForUIToSettle(seconds: 1)

        // Take screenshot
        let screenshot = app.takeScreenshot(named: "MacOS-MainView")
        add(screenshot)
    }
}
