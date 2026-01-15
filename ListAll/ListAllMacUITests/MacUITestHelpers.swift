//
//  MacUITestHelpers.swift
//  ListAllMacUITests
//
//  UI test helpers for macOS app testing.
//  Provides extensions and utilities for common macOS interactions.
//

import XCTest

// MARK: - Base Test Class with Appearance Management

/// Base class for macOS UI tests that manages system appearance settings.
/// Saves the user's appearance setting at the START of the test suite and restores it at the END.
/// Subclass this instead of XCTestCase for automatic appearance management.
///
/// **Implementation Note**: The `class func setUp()` and `class func tearDown()` methods run
/// once per test class (not once per test suite). However, `SystemSettingsManager` uses static
/// guards (`hasSaved`, `hasRestored`) to ensure save/restore only happens ONCE across all test
/// classes, effectively providing suite-level semantics.
///
/// **Important**: Tests must NOT be parallelized (`parallelizable = false` in test plan) for
/// this mechanism to work correctly.
@MainActor
class MacUITestCase: XCTestCase {

    /// Called once before the first test in the class runs.
    /// Saves the current system appearance setting.
    /// Note: Static guards in SystemSettingsManager ensure this only executes once per suite.
    override class func setUp() {
        super.setUp()
        SystemSettingsManager.saveSystemAppearance()
    }

    /// Called once after the last test in the class finishes.
    /// Restores the previously saved system appearance setting.
    /// Note: Static guards in SystemSettingsManager ensure this only executes once per suite.
    override class func tearDown() {
        SystemSettingsManager.restoreSystemAppearance()
        super.tearDown()
    }
}

// MARK: - Accessibility Identifiers

/// Centralized accessibility identifiers used in macOS views.
/// These should match the identifiers set in the app's SwiftUI views.
enum MacAccessibilityIdentifier {
    // Sidebar
    static let addListButton = "AddListButton"
    static let sidebarToggleArchived = "ToggleArchivedButton"

    // List Creation/Editing
    static let createListSheet = "CreateListSheet"
    static let editListSheet = "EditListSheet"
    static let listNameTextField = "ListNameTextField"
    static let saveButton = "SaveButton"
    static let cancelButton = "CancelButton"

    // List Detail
    static let addItemButton = "AddItemButton"
    static let editListButton = "EditListButton"

    // Item Creation/Editing
    static let addItemSheet = "AddItemSheet"
    static let editItemSheet = "EditItemSheet"
    static let itemNameTextField = "ItemNameTextField"
    static let itemQuantityStepper = "ItemQuantityStepper"
    static let itemDescriptionEditor = "ItemDescriptionEditor"

    // Settings
    static let settingsWindow = "SettingsWindow"
    static let iCloudSyncToggle = "iCloudSyncToggle"

    // Empty States
    static let emptyStateView = "EmptyStateView"
    static let createFirstListButton = "CreateFirstListButton"
}

// MARK: - XCUIApplication Extension

extension XCUIApplication {

    // MARK: - Launch Configuration

    /// Launch the app in UI test mode with deterministic test data.
    /// - Parameters:
    ///   - skipTestData: If true, launches without test data (for empty state testing)
    ///   - locale: The locale to use for testing (default: en-US)
    func launchForUITest(skipTestData: Bool = false, locale: String = "en-US") {
        // Clear launch arguments and environment
        launchArguments.removeAll()
        launchEnvironment.removeAll()

        // Enable UI test mode
        launchArguments.append("UITEST_MODE")

        // Configure test data
        if skipTestData {
            launchArguments.append("SKIP_TEST_DATA")
        } else {
            launchEnvironment["UITEST_SEED"] = "1"
        }

        // Force light mode for consistent screenshots
        launchArguments.append("FORCE_LIGHT_MODE")

        // Disable animations for faster, more reliable tests
        launchArguments.append("DISABLE_ANIMATIONS")

        // Set locale
        launchEnvironment["LANG"] = locale

        print("🧪 Launching macOS app for UI test")
        print("   - Skip test data: \(skipTestData)")
        print("   - Locale: \(locale)")

        launch()
    }

    // MARK: - Menu Navigation

    /// Access the main menu bar.
    var mainMenuBar: XCUIElement {
        return menuBars.element(boundBy: 0)
    }

    /// Open a menu by name.
    /// - Parameter menuName: The name of the menu (e.g., "File", "Edit", "View")
    /// - Returns: The menu element
    @discardableResult
    func openMenu(_ menuName: String) -> XCUIElement {
        let menu = mainMenuBar.menuBarItems[menuName]
        if !menu.exists {
            XCTFail("Menu '\(menuName)' not found")
        }
        menu.click()
        return menu
    }

    /// Click a menu item by path (e.g., "File" > "New List").
    /// - Parameters:
    ///   - path: Array of menu names from top to bottom
    func clickMenuItem(_ path: [String]) {
        guard !path.isEmpty else {
            XCTFail("Menu path is empty")
            return
        }

        // Click the top-level menu
        openMenu(path[0])

        // Navigate through submenus
        var currentMenu = mainMenuBar.menuBarItems[path[0]]
        for menuItem in path.dropFirst() {
            let item = currentMenu.menuItems[menuItem]
            if !item.waitForExistence(timeout: 2) {
                XCTFail("Menu item '\(menuItem)' not found in path \(path)")
                return
            }
            item.click()
            currentMenu = item
        }
    }

    /// Invoke a keyboard shortcut.
    /// - Parameters:
    ///   - key: The key to press
    ///   - modifiers: Modifier keys (Command, Option, Control, Shift)
    func performKeyboardShortcut(key: String, modifiers: XCUIElement.KeyModifierFlags) {
        // Type the key with modifiers
        typeKey(key, modifierFlags: modifiers)
    }

    // MARK: - Window Management

    /// Get the main window of the app.
    ///
    /// **IMPORTANT**: Due to SwiftUI WindowGroup accessibility limitations on macOS,
    /// `mainWindow.exists` will return `false` even when the window is visible.
    /// This is a known SwiftUI/XCUITest issue - see documentation/macos-swiftui-window-accessibility-fix.md
    ///
    /// **DO NOT USE** `.exists` or `.waitForExistence()` on this element.
    /// Instead, check for content elements (e.g., `app.outlines.firstMatch.exists`).
    ///
    /// This element CAN be used for:
    /// - `.screenshot()` - captures window successfully
    /// - Accessing child elements via queries
    var mainWindow: XCUIElement {
        return windows.element(boundBy: 0)
    }

    /// Check if the main UI is ready by verifying content elements exist.
    ///
    /// This is the recommended way to verify window readiness on macOS with SwiftUI,
    /// since `mainWindow.exists` returns false due to accessibility limitations.
    ///
    /// - Parameter timeout: How long to wait for UI (default: 5 seconds)
    /// - Returns: True if main UI content is ready
    func isMainUIReady(timeout: TimeInterval = 5) -> Bool {
        // Check for sidebar (the main content element that proves window is ready)
        let sidebar = outlines.firstMatch
        return sidebar.waitForExistence(timeout: timeout)
    }

    /// Wait for a window with a specific title to appear.
    /// - Parameters:
    ///   - title: The window title
    ///   - timeout: How long to wait (default: 5 seconds)
    /// - Returns: The window element if found, nil otherwise
    func waitForWindow(title: String, timeout: TimeInterval = 5) -> XCUIElement? {
        let window = windows[title]
        return window.waitForExistence(timeout: timeout) ? window : nil
    }

    /// Wait for a sheet (modal dialog) to appear.
    /// - Parameters:
    ///   - timeout: How long to wait (default: 5 seconds)
    /// - Returns: The sheet element if found, nil otherwise
    func waitForSheet(timeout: TimeInterval = 5) -> XCUIElement? {
        let sheet = sheets.firstMatch
        return sheet.waitForExistence(timeout: timeout) ? sheet : nil
    }

    /// Dismiss the current sheet by pressing Escape.
    func dismissSheet() {
        performKeyboardShortcut(key: XCUIKeyboardKey.escape.rawValue, modifiers: [])
    }

    /// Close the main window.
    func closeMainWindow() {
        performKeyboardShortcut(key: "w", modifiers: .command)
    }

    /// Open a new window.
    func openNewWindow() {
        performKeyboardShortcut(key: "n", modifiers: [.command, .shift])
    }

    // MARK: - Settings Window

    /// Open the Settings window using Command+Comma shortcut.
    func openSettings() {
        performKeyboardShortcut(key: ",", modifiers: .command)
    }

    /// Close the Settings window.
    func closeSettings() {
        if let settingsWindow = waitForWindow(title: "Settings", timeout: 2) {
            // Click the close button on the settings window
            settingsWindow.buttons[XCUIIdentifierCloseWindow].click()
        }
    }

    // MARK: - List Operations

    /// Create a new list using Command+N shortcut.
    func createNewListViaKeyboard() {
        performKeyboardShortcut(key: "n", modifiers: .command)
    }

    /// Select a list in the sidebar by name.
    /// - Parameter listName: The name of the list to select
    /// - Returns: True if the list was found and selected, false otherwise
    @discardableResult
    func selectList(named listName: String) -> Bool {
        let listCell = outlines.cells.staticTexts[listName]
        if listCell.waitForExistence(timeout: 5) {
            listCell.click()
            return true
        }
        return false
    }

    /// Get the count of lists in the sidebar.
    /// - Returns: The number of visible lists
    func listCount() -> Int {
        // Lists are shown as outline items in the sidebar
        return outlines.cells.count
    }

    // MARK: - Item Operations

    /// Create a new item in the current list using Command+I shortcut.
    func createNewItemViaKeyboard() {
        performKeyboardShortcut(key: "i", modifiers: .command)
    }

    /// Toggle an item's completion state by clicking its checkbox.
    /// - Parameter itemTitle: The title of the item
    /// - Returns: True if the item was found and toggled, false otherwise
    @discardableResult
    func toggleItem(titled itemTitle: String) -> Bool {
        // Find the item row
        let itemRow = tables.cells.staticTexts[itemTitle]
        if itemRow.waitForExistence(timeout: 3) {
            // Find the checkbox button in the same row
            let checkbox = itemRow.buttons.firstMatch
            if checkbox.exists {
                checkbox.click()
                return true
            }
        }
        return false
    }

    /// Get the count of items in the current list.
    /// - Returns: The number of visible items
    func itemCount() -> Int {
        return tables.cells.count
    }
}

// MARK: - Wait Helpers

extension XCUIElement {

    /// Wait for this element to appear and be hittable.
    /// - Parameter timeout: How long to wait (default: 5 seconds)
    /// - Returns: True if element is ready for interaction, false otherwise
    func waitForHittable(timeout: TimeInterval = 5) -> Bool {
        let predicate = NSPredicate(format: "exists == true AND hittable == true")
        let expectation = XCTNSPredicateExpectation(predicate: predicate, object: self)
        let result = XCTWaiter().wait(for: [expectation], timeout: timeout)
        return result == .completed
    }

    /// Wait for this element to disappear.
    /// - Parameter timeout: How long to wait (default: 5 seconds)
    /// - Returns: True if element disappeared, false if still present
    func waitForDisappearance(timeout: TimeInterval = 5) -> Bool {
        let predicate = NSPredicate(format: "exists == false")
        let expectation = XCTNSPredicateExpectation(predicate: predicate, object: self)
        let result = XCTWaiter().wait(for: [expectation], timeout: timeout)
        return result == .completed
    }

    /// Safely click this element if it exists and is hittable.
    /// - Returns: True if clicked successfully, false otherwise
    @discardableResult
    func clickIfExists() -> Bool {
        guard waitForHittable(timeout: 2) else {
            return false
        }
        click()
        return true
    }

    /// Clear text from a text field and type new text.
    /// - Parameter text: The text to type
    func clearAndType(_ text: String) {
        // Select all text
        click()
        performKeyboardShortcut(key: "a", modifiers: .command)
        // Type new text (replaces selection)
        typeText(text)
    }

    /// Helper to perform keyboard shortcut on an element.
    private func performKeyboardShortcut(key: String, modifiers: XCUIElement.KeyModifierFlags) {
        typeKey(key, modifierFlags: modifiers)
    }
}

// MARK: - Accessibility Testing Helpers

extension XCUIApplication {

    /// Verify that an element has proper accessibility labels.
    /// - Parameters:
    ///   - element: The element to check
    ///   - expectedLabel: The expected label
    ///   - file: The file where the check is called (for better error reporting)
    ///   - line: The line where the check is called (for better error reporting)
    func verifyAccessibilityLabel(
        for element: XCUIElement,
        expectedLabel: String,
        file: StaticString = #file,
        line: UInt = #line
    ) {
        XCTAssertTrue(element.exists, "Element should exist", file: file, line: line)
        XCTAssertEqual(
            element.label,
            expectedLabel,
            "Element should have correct accessibility label",
            file: file,
            line: line
        )
    }

    /// Verify that buttons have appropriate help text (tooltips).
    /// - Parameters:
    ///   - button: The button to check
    ///   - expectedHelp: The expected help text
    ///   - file: The file where the check is called
    ///   - line: The line where the check is called
    func verifyButtonHelp(
        for button: XCUIElement,
        expectedHelp: String,
        file: StaticString = #file,
        line: UInt = #line
    ) {
        XCTAssertTrue(button.exists, "Button should exist", file: file, line: line)
        // Note: XCTest doesn't expose tooltip text directly on macOS
        // This is a placeholder for when/if that functionality is available
        // For now, we can only verify the button exists
    }

    /// Verify VoiceOver can navigate to all important elements.
    /// - Parameter elementIdentifiers: Array of accessibility identifiers to check
    /// - Returns: Array of identifiers that were not found
    func verifyVoiceOverNavigation(elementIdentifiers: [String]) -> [String] {
        var missingIdentifiers: [String] = []

        for identifier in elementIdentifiers {
            let element = descendants(matching: .any).matching(identifier: identifier).firstMatch
            if !element.exists {
                missingIdentifiers.append(identifier)
                print("⚠️ VoiceOver: Element with identifier '\(identifier)' not found")
            }
        }

        return missingIdentifiers
    }
}

// MARK: - Test Data Helpers

extension XCUIApplication {

    /// Expected test lists in English locale (matches UITestDataService).
    static let englishTestLists = [
        "Grocery Shopping",
        "Weekend Projects",
        "Books to Read",
        "Travel Packing"
    ]

    /// Expected test lists in Finnish locale (matches UITestDataService).
    static let finnishTestLists = [
        "Ruokaostokset",
        "Viikonlopun projektit",
        "Luettavat kirjat",
        "Matkapakkaus"
    ]

    /// Get the expected test list names for the current locale.
    /// - Parameter locale: The locale code (e.g., "en-US", "fi")
    /// - Returns: Array of expected list names
    static func expectedTestLists(for locale: String) -> [String] {
        if locale.hasPrefix("fi") {
            return finnishTestLists
        } else {
            return englishTestLists
        }
    }

    /// Verify that all expected test lists are present.
    /// - Parameter locale: The locale to check against
    /// - Returns: True if all lists are present, false otherwise
    func verifyTestListsPresent(locale: String = "en-US") -> Bool {
        let expectedLists = XCUIApplication.expectedTestLists(for: locale)

        for listName in expectedLists {
            let listElement = outlines.cells.staticTexts[listName]
            if !listElement.waitForExistence(timeout: 5) {
                print("⚠️ Expected test list '\(listName)' not found")
                return false
            }
        }

        print("✅ All \(expectedLists.count) test lists present")
        return true
    }
}

// MARK: - Screenshot Helpers

extension XCUIApplication {

    /// Take a screenshot with a descriptive name.
    /// - Parameter name: The name for the screenshot
    /// - Returns: The screenshot attachment
    @discardableResult
    func takeScreenshot(named name: String) -> XCTAttachment {
        let screenshot = windows.firstMatch.screenshot()
        let attachment = XCTAttachment(screenshot: screenshot)
        attachment.name = name
        attachment.lifetime = .keepAlways
        return attachment
    }

    /// Wait briefly to allow UI to settle before taking a screenshot.
    /// - Parameter seconds: How long to wait (default: 0.5)
    func waitForUIToSettle(seconds: TimeInterval = 0.5) {
        Thread.sleep(forTimeInterval: seconds)
    }
}

// MARK: - Debug Helpers

extension XCUIApplication {

    /// Print the element hierarchy for debugging.
    /// - Parameter element: The root element (defaults to app's main window)
    func debugElementHierarchy(from element: XCUIElement? = nil) {
        let root = element ?? windows.firstMatch
        print("📋 Element Hierarchy:")
        print(root.debugDescription)
    }

    /// Log all visible elements of a specific type.
    /// - Parameter elementType: The type of elements to log
    func debugElements(ofType elementType: XCUIElement.ElementType) {
        let elements = descendants(matching: elementType)
        print("📋 Found \(elements.count) elements of type \(elementType):")
        for i in 0..<elements.count {
            let element = elements.element(boundBy: i)
            print("  [\(i)] label: '\(element.label)', identifier: '\(element.identifier)'")
        }
    }
}
