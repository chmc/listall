import XCTest

// MARK: - MCP Command Models

/// Single action to execute in XCUITest
/// Used both for single-command mode (embedded in MCPCommand) and batch mode (in commands array)
struct MCPAction: Codable {
    let action: String
    let identifier: String?
    let label: String?
    let text: String?
    let direction: String?
    let timeout: TimeInterval?
    let clearFirst: Bool?
    let queryRole: String?
    let queryDepth: Int?
    let duration: TimeInterval?
}

/// Command structure for MCP -> XCUITest communication
/// Supports two modes:
/// - Single command (backward compatible): action fields at top level
/// - Batch mode: bundleId shared, multiple actions in commands array
struct MCPCommand: Codable {
    // Shared field for all actions
    let bundleId: String

    // Single-command mode fields (backward compatible)
    let action: String?
    let identifier: String?
    let label: String?
    let text: String?
    let direction: String?
    let timeout: TimeInterval?
    let clearFirst: Bool?
    let queryRole: String?
    let queryDepth: Int?
    let duration: TimeInterval?

    // Batch mode: array of actions to execute sequentially
    let commands: [MCPAction]?
}

/// Result structure for XCUITest -> MCP communication (single action)
struct MCPResult: Codable {
    let success: Bool
    let message: String
    let elements: [[String: String]]?
    let error: String?
    // Enhanced feedback fields
    let elementType: String?
    let elementFrame: String?
    let usedCoordinateFallback: Bool?
    let hint: String?

    init(
        success: Bool,
        message: String,
        elements: [[String: String]]? = nil,
        error: String? = nil,
        elementType: String? = nil,
        elementFrame: String? = nil,
        usedCoordinateFallback: Bool? = nil,
        hint: String? = nil
    ) {
        self.success = success
        self.message = message
        self.elements = elements
        self.error = error
        self.elementType = elementType
        self.elementFrame = elementFrame
        self.usedCoordinateFallback = usedCoordinateFallback
        self.hint = hint
    }
}

/// Result structure for batch command execution
/// Contains overall success status and individual results for each action
struct MCPBatchResult: Codable {
    let success: Bool
    let message: String
    let results: [MCPResult]
    let error: String?

    init(
        success: Bool,
        message: String,
        results: [MCPResult],
        error: String? = nil
    ) {
        self.success = success
        self.message = message
        self.results = results
        self.error = error
    }
}

// MARK: - MCP Command Runner

/// XCUITest class that reads commands from a file, executes them, and writes results.
/// This acts as a bridge between the MCP server and the iOS/watchOS simulator.
///
/// Usage:
/// 1. MCP server writes command JSON to /tmp/listall_mcp_command.json
/// 2. MCP server invokes `xcodebuild test-without-building -only-testing:ListAllMCPTests/MCPCommandRunner/testRunMCPCommand`
/// 3. This test reads the command, executes it, and writes result to /tmp/listall_mcp_result.json
/// 4. MCP server reads the result and returns to Claude
final class MCPCommandRunner: XCTestCase {

    // MARK: - Constants

    private static let commandPath = "/tmp/listall_mcp_command.json"
    private static let resultPath = "/tmp/listall_mcp_result.json"
    private static let defaultTimeout: TimeInterval = 10.0

    // MARK: - Setup

    override func setUpWithError() throws {
        try super.setUpWithError()
        // Stop immediately on failure for MCP commands
        continueAfterFailure = false
    }

    // MARK: - Main Test Entry Point

    /// Main entry point that reads command file, executes action, and writes result.
    /// This is invoked by the MCP server via xcodebuild.
    /// Supports both single-command (backward compatible) and batch mode.
    func testRunMCPCommand() throws {
        // Skip if no command file - this test is only meant to be invoked by MCP server
        try XCTSkipUnless(
            FileManager.default.fileExists(atPath: Self.commandPath),
            "No MCP command file present - this test is invoked by MCP server, not CI"
        )

        do {
            // Read command from file
            let command = try readCommand()

            // Check if this is a batch command
            if let actions = command.commands, !actions.isEmpty {
                // Batch mode: execute multiple actions and write batch result
                let batchResult = try executeBatchCommand(command, actions: actions)
                try writeBatchResult(batchResult)

                // If any action failed, fail the test for visibility
                if !batchResult.success {
                    XCTFail(batchResult.error ?? batchResult.message)
                }
            } else {
                // Single-command mode (backward compatible)
                var result: MCPResult

                do {
                    result = try executeCommand(command)
                } catch {
                    result = MCPResult(
                        success: false,
                        message: "Command execution failed",
                        elements: nil,
                        error: error.localizedDescription
                    )
                }

                try writeResult(result)

                if !result.success {
                    XCTFail(result.error ?? result.message)
                }
            }

        } catch {
            // Capture any setup/read errors and write to result
            let result = MCPResult(
                success: false,
                message: "Command execution failed",
                elements: nil,
                error: error.localizedDescription
            )

            do {
                try writeResult(result)
            } catch {
                XCTFail("Failed to write result: \(error)")
            }

            XCTFail(error.localizedDescription)
        }
    }

    // MARK: - Command Handling

    /// Read command from the command file
    private func readCommand() throws -> MCPCommand {
        let commandURL = URL(fileURLWithPath: Self.commandPath)

        guard FileManager.default.fileExists(atPath: Self.commandPath) else {
            throw MCPCommandError.commandFileNotFound(Self.commandPath)
        }

        let data = try Data(contentsOf: commandURL)
        let decoder = JSONDecoder()
        return try decoder.decode(MCPCommand.self, from: data)
    }

    /// Write result to the result file
    private func writeResult(_ result: MCPResult) throws {
        let resultURL = URL(fileURLWithPath: Self.resultPath)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted]
        let data = try encoder.encode(result)
        try data.write(to: resultURL, options: .atomic)
    }

    /// Write batch result to the result file
    private func writeBatchResult(_ result: MCPBatchResult) throws {
        let resultURL = URL(fileURLWithPath: Self.resultPath)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted]
        let data = try encoder.encode(result)
        try data.write(to: resultURL, options: .atomic)
    }

    /// Execute a command and return the result
    private func executeCommand(_ command: MCPCommand) throws -> MCPResult {
        // Get or launch the app
        let app = XCUIApplication(bundleIdentifier: command.bundleId)

        // Launch the app with UITEST_MODE if not running
        // This is needed because xcodebuild may run tests on a cloned simulator
        if app.state != .runningForeground {
            // Launch with test isolation arguments
            app.launchArguments = ["UITEST_MODE", "DISABLE_TOOLTIPS"]
            app.launch()

            // Wait for app to be in foreground
            let timeout = command.timeout ?? Self.defaultTimeout
            let appeared = app.wait(for: .runningForeground, timeout: timeout)
            if !appeared {
                throw MCPCommandError.appNotReady(command.bundleId, app.state.rawValue)
            }
        }

        // Execute the appropriate action
        guard let action = command.action else {
            throw MCPCommandError.missingParameter("action")
        }

        switch action {
        case "click":
            return try executeClick(app: app, command: command)
        case "type":
            return try executeType(app: app, command: command)
        case "swipe":
            return try executeSwipe(app: app, command: command)
        case "query":
            return try executeQuery(app: app, command: command)
        case "longPress":
            return try executeLongPress(app: app, command: command)
        default:
            throw MCPCommandError.unknownAction(action)
        }
    }

    // MARK: - Batch Command Execution

    /// Execute a batch of actions and return batch result
    /// The app is launched once and all actions are executed sequentially.
    /// If any action fails, subsequent actions still run but overall success is false.
    private func executeBatchCommand(_ command: MCPCommand, actions: [MCPAction]) throws -> MCPBatchResult {
        // Get or launch the app once for all actions
        let app = XCUIApplication(bundleIdentifier: command.bundleId)

        // Launch the app with UITEST_MODE if not running
        if app.state != .runningForeground {
            app.launchArguments = ["UITEST_MODE", "DISABLE_TOOLTIPS"]
            app.launch()

            // Wait for app to be in foreground
            let timeout = Self.defaultTimeout
            let appeared = app.wait(for: .runningForeground, timeout: timeout)
            if !appeared {
                throw MCPCommandError.appNotReady(command.bundleId, app.state.rawValue)
            }
        }

        // Execute each action and collect results
        var results: [MCPResult] = []
        var overallSuccess = true

        for (index, action) in actions.enumerated() {
            let result: MCPResult

            do {
                result = try executeAction(app: app, action: action)
            } catch {
                result = MCPResult(
                    success: false,
                    message: "Action \(index + 1) (\(action.action)) failed",
                    elements: nil,
                    error: error.localizedDescription
                )
            }

            results.append(result)

            if !result.success {
                overallSuccess = false
            }
        }

        // Build summary message
        let successCount = results.filter { $0.success }.count
        let message = "Executed \(actions.count) actions: \(successCount) succeeded, \(actions.count - successCount) failed"

        return MCPBatchResult(
            success: overallSuccess,
            message: message,
            results: results,
            error: overallSuccess ? nil : "One or more actions failed"
        )
    }

    /// Execute a single action from a batch
    private func executeAction(app: XCUIApplication, action: MCPAction) throws -> MCPResult {
        switch action.action {
        case "click":
            return try executeClickAction(app: app, action: action)
        case "type":
            return try executeTypeAction(app: app, action: action)
        case "swipe":
            return try executeSwipeAction(app: app, action: action)
        case "query":
            return try executeQueryAction(app: app, action: action)
        case "longPress":
            return try executeLongPressAction(app: app, action: action)
        default:
            throw MCPCommandError.unknownAction(action.action)
        }
    }

    // MARK: - Action Execution (for batch mode)

    /// Execute a click/tap action from batch
    private func executeClickAction(app: XCUIApplication, action: MCPAction) throws -> MCPResult {
        let element = try findElementForAction(in: app, action: action)
        let timeout = action.timeout ?? Self.defaultTimeout

        guard element.waitForExistence(timeout: timeout) else {
            throw MCPCommandError.elementNotFound(action.identifier ?? action.label ?? "unknown")
        }

        // Capture element info for feedback
        let elementType = String(describing: element.elementType)
        let frame = element.frame
        let frameStr = "x:\(Int(frame.origin.x)), y:\(Int(frame.origin.y)), w:\(Int(frame.width)), h:\(Int(frame.height))"

        // Wait for animation stabilization
        waitForElementStability(element, timeout: 0.5)

        var usedCoordinateFallback = false
        var hint: String? = nil

        if element.isHittable {
            element.tap()
        } else {
            usedCoordinateFallback = true
            let coordinate = element.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
            coordinate.tap()
            hint = "Element was not hittable, used coordinate-based tap."
        }

        Thread.sleep(forTimeInterval: 0.1)

        let targetDesc = action.identifier ?? action.label ?? "element"
        return MCPResult(
            success: true,
            message: "Successfully clicked '\(targetDesc)'",
            elements: nil,
            error: nil,
            elementType: elementType,
            elementFrame: frameStr,
            usedCoordinateFallback: usedCoordinateFallback,
            hint: hint
        )
    }

    /// Execute a type/text entry action from batch
    private func executeTypeAction(app: XCUIApplication, action: MCPAction) throws -> MCPResult {
        guard let text = action.text else {
            throw MCPCommandError.missingParameter("text")
        }

        let timeout = action.timeout ?? Self.defaultTimeout
        var targetElement: XCUIElement

        if action.identifier != nil || action.label != nil {
            targetElement = try findElementForAction(in: app, action: action)

            guard targetElement.waitForExistence(timeout: timeout) else {
                throw MCPCommandError.elementNotFound(action.identifier ?? action.label ?? "unknown")
            }

            targetElement.tap()
        } else {
            let textFields = app.textFields.allElementsBoundByIndex
            let textViews = app.textViews.allElementsBoundByIndex
            let searchFields = app.searchFields.allElementsBoundByIndex

            let allTextElements = textFields + textViews + searchFields

            guard let firstFocusable = allTextElements.first(where: { $0.exists && $0.isHittable }) else {
                throw MCPCommandError.noFocusableElement
            }

            targetElement = firstFocusable
            targetElement.tap()
        }

        if action.clearFirst == true {
            targetElement.tap()
            if let currentValue = targetElement.value as? String, !currentValue.isEmpty {
                targetElement.tap()
                targetElement.tap()
                targetElement.tap()
                targetElement.typeText(XCUIKeyboardKey.delete.rawValue)
            }
        }

        targetElement.typeText(text)

        let targetDesc = action.identifier ?? action.label ?? "focused element"
        return MCPResult(
            success: true,
            message: "Successfully typed '\(text)' into '\(targetDesc)'",
            elements: nil,
            error: nil
        )
    }

    /// Execute a swipe/scroll action from batch
    private func executeSwipeAction(app: XCUIApplication, action: MCPAction) throws -> MCPResult {
        guard let direction = action.direction else {
            throw MCPCommandError.missingParameter("direction")
        }

        let timeout = action.timeout ?? Self.defaultTimeout
        var targetElement: XCUIElement

        if action.identifier != nil || action.label != nil {
            targetElement = try findElementForAction(in: app, action: action)

            guard targetElement.waitForExistence(timeout: timeout) else {
                throw MCPCommandError.elementNotFound(action.identifier ?? action.label ?? "unknown")
            }
        } else {
            targetElement = app
        }

        switch direction {
        case "up":
            targetElement.swipeUp()
        case "down":
            targetElement.swipeDown()
        case "left":
            targetElement.swipeLeft()
        case "right":
            targetElement.swipeRight()
        default:
            throw MCPCommandError.invalidDirection(direction)
        }

        let targetDesc = action.identifier ?? action.label ?? "app window"
        return MCPResult(
            success: true,
            message: "Successfully swiped \(direction) on '\(targetDesc)'",
            elements: nil,
            error: nil
        )
    }

    /// Execute a query action from batch
    private func executeQueryAction(app: XCUIApplication, action: MCPAction) throws -> MCPResult {
        var elements: [[String: String]] = []
        let maxDepth = action.queryDepth ?? 3
        let roleFilter = action.queryRole

        collectElements(from: app, role: roleFilter, depth: maxDepth, elements: &elements)

        return MCPResult(
            success: true,
            message: "Found \(elements.count) elements",
            elements: elements,
            error: nil
        )
    }

    /// Find element for an MCPAction (batch mode)
    private func findElementForAction(in app: XCUIApplication, action: MCPAction) throws -> XCUIElement {
        // Search in sheets first
        if let element = findElementInSheetsForAction(app: app, action: action) {
            return element
        }

        // Search in navigation bars
        if let element = findElementInNavigationBarsForAction(app: app, action: action) {
            return element
        }

        // Search in alerts
        if let element = findElementInAlertsForAction(app: app, action: action) {
            return element
        }

        // Standard element search
        if let element = findElementStandardForAction(in: app, action: action) {
            return element
        }

        throw MCPCommandError.elementNotFound(action.identifier ?? action.label ?? "unknown")
    }

    private func findElementInSheetsForAction(app: XCUIApplication, action: MCPAction) -> XCUIElement? {
        let sheets = app.sheets
        guard sheets.count > 0 else { return nil }

        if let identifier = action.identifier, !identifier.isEmpty {
            let button = sheets.buttons[identifier]
            if button.exists { return button.firstMatch }

            let textField = sheets.textFields[identifier]
            if textField.exists { return textField.firstMatch }

            let any = sheets.descendants(matching: .any)[identifier]
            if any.exists { return any.firstMatch }
        }

        if let label = action.label, !label.isEmpty {
            let predicate = NSPredicate(format: "label CONTAINS[c] %@", label)

            let buttons = sheets.buttons.matching(predicate)
            if buttons.firstMatch.exists { return buttons.firstMatch }

            let staticTexts = sheets.staticTexts.matching(predicate)
            if staticTexts.firstMatch.exists { return staticTexts.firstMatch }
        }

        return nil
    }

    private func findElementInNavigationBarsForAction(app: XCUIApplication, action: MCPAction) -> XCUIElement? {
        let navBars = app.navigationBars
        guard navBars.count > 0 else { return nil }

        if let identifier = action.identifier, !identifier.isEmpty {
            let button = navBars.buttons[identifier]
            if button.exists { return button.firstMatch }
        }

        if let label = action.label, !label.isEmpty {
            let predicate = NSPredicate(format: "label CONTAINS[c] %@", label)

            let buttons = navBars.buttons.matching(predicate)
            if buttons.firstMatch.exists { return buttons.firstMatch }
        }

        return nil
    }

    private func findElementInAlertsForAction(app: XCUIApplication, action: MCPAction) -> XCUIElement? {
        let alerts = app.alerts
        guard alerts.count > 0 else { return nil }

        if let identifier = action.identifier, !identifier.isEmpty {
            let button = alerts.buttons[identifier]
            if button.exists { return button.firstMatch }
        }

        if let label = action.label, !label.isEmpty {
            let predicate = NSPredicate(format: "label CONTAINS[c] %@", label)

            let buttons = alerts.buttons.matching(predicate)
            if buttons.firstMatch.exists { return buttons.firstMatch }
        }

        return nil
    }

    private func findElementStandardForAction(in app: XCUIApplication, action: MCPAction) -> XCUIElement? {
        if let identifier = action.identifier, !identifier.isEmpty {
            let buttons = app.buttons[identifier]
            if buttons.exists { return buttons.firstMatch }

            let textFields = app.textFields[identifier]
            if textFields.exists { return textFields.firstMatch }

            let staticTexts = app.staticTexts[identifier]
            if staticTexts.exists { return staticTexts.firstMatch }

            let cells = app.cells[identifier]
            if cells.exists { return cells.firstMatch }

            let switches = app.switches[identifier]
            if switches.exists { return switches.firstMatch }

            let images = app.images[identifier]
            if images.exists { return images.firstMatch }

            let element = app.descendants(matching: .any)[identifier].firstMatch
            if element.exists {
                return element
            }
        }

        if let label = action.label, !label.isEmpty {
            let buttons = app.buttons.matching(NSPredicate(format: "label CONTAINS %@", label))
            if buttons.firstMatch.exists { return buttons.firstMatch }

            let staticTexts = app.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", label))
            if staticTexts.firstMatch.exists { return staticTexts.firstMatch }

            let textFields = app.textFields.matching(NSPredicate(format: "label CONTAINS %@", label))
            if textFields.firstMatch.exists { return textFields.firstMatch }

            let cells = app.cells.matching(NSPredicate(format: "label CONTAINS %@", label))
            if cells.firstMatch.exists { return cells.firstMatch }
        }

        return nil
    }

    // MARK: - Click Action

    /// Execute a click/tap action
    private func executeClick(app: XCUIApplication, command: MCPCommand) throws -> MCPResult {
        let element = try findElement(in: app, command: command)
        let timeout = command.timeout ?? Self.defaultTimeout

        guard element.waitForExistence(timeout: timeout) else {
            throw MCPCommandError.elementNotFound(command.identifier ?? command.label ?? "unknown")
        }

        // Capture element info for feedback
        let elementType = String(describing: element.elementType)
        let frame = element.frame
        let frameStr = "x:\(Int(frame.origin.x)), y:\(Int(frame.origin.y)), w:\(Int(frame.width)), h:\(Int(frame.height))"

        // Wait for animation stabilization (sheet spring ~350ms)
        waitForElementStability(element, timeout: 0.5)

        // Track if we used coordinate fallback
        var usedCoordinateFallback = false
        var hint: String? = nil

        // Try direct tap first, fallback to coordinate-based tap for overlay elements
        if element.isHittable {
            element.tap()
        } else {
            // Coordinate-based tap works for elements in sheets/overlays that may not be "hittable"
            // but are still visible and tappable at their center point
            usedCoordinateFallback = true
            let coordinate = element.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
            coordinate.tap()
            hint = "Element was not hittable, used coordinate-based tap. Recommend: listall_screenshot to verify state."
        }

        // Brief delay for SwiftUI event processing
        Thread.sleep(forTimeInterval: 0.1)

        let targetDesc = command.identifier ?? command.label ?? "element"
        return MCPResult(
            success: true,
            message: "Successfully clicked '\(targetDesc)'",
            elements: nil,
            error: nil,
            elementType: elementType,
            elementFrame: frameStr,
            usedCoordinateFallback: usedCoordinateFallback,
            hint: hint
        )
    }

    /// Wait until element frame stops changing (animation complete)
    private func waitForElementStability(_ element: XCUIElement, timeout: TimeInterval) {
        let startTime = Date()
        var lastFrame = element.frame
        var stableCount = 0

        while Date().timeIntervalSince(startTime) < timeout {
            Thread.sleep(forTimeInterval: 0.05)
            let currentFrame = element.frame

            if abs(currentFrame.origin.x - lastFrame.origin.x) < 1 &&
               abs(currentFrame.origin.y - lastFrame.origin.y) < 1 {
                stableCount += 1
                if stableCount >= 3 { return }
            } else {
                stableCount = 0
            }
            lastFrame = currentFrame
        }
    }

    // MARK: - Long Press Action

    /// Execute a long-press action (single-command mode)
    private func executeLongPress(app: XCUIApplication, command: MCPCommand) throws -> MCPResult {
        let element = try findElement(in: app, command: command)
        let timeout = command.timeout ?? Self.defaultTimeout

        guard element.waitForExistence(timeout: timeout) else {
            throw MCPCommandError.elementNotFound(command.identifier ?? command.label ?? "unknown")
        }

        let elementType = String(describing: element.elementType)
        let frame = element.frame
        let frameStr = "x:\(Int(frame.origin.x)), y:\(Int(frame.origin.y)), w:\(Int(frame.width)), h:\(Int(frame.height))"

        waitForElementStability(element, timeout: 0.5)

        let pressDuration = min(command.duration ?? 1.0, 10.0)

        var usedCoordinateFallback = false
        var hint: String? = nil

        if element.isHittable {
            element.press(forDuration: pressDuration)
        } else {
            usedCoordinateFallback = true
            let coordinate = element.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
            coordinate.press(forDuration: pressDuration)
            hint = "Element was not hittable, used coordinate-based long press."
        }

        Thread.sleep(forTimeInterval: 0.1)

        let targetDesc = command.identifier ?? command.label ?? "element"
        return MCPResult(
            success: true,
            message: "Successfully long-pressed '\(targetDesc)' for \(pressDuration)s",
            elements: nil,
            error: nil,
            elementType: elementType,
            elementFrame: frameStr,
            usedCoordinateFallback: usedCoordinateFallback,
            hint: hint
        )
    }

    /// Execute a long-press action from batch
    private func executeLongPressAction(app: XCUIApplication, action: MCPAction) throws -> MCPResult {
        let element = try findElementForAction(in: app, action: action)
        let timeout = action.timeout ?? Self.defaultTimeout

        guard element.waitForExistence(timeout: timeout) else {
            throw MCPCommandError.elementNotFound(action.identifier ?? action.label ?? "unknown")
        }

        let elementType = String(describing: element.elementType)
        let frame = element.frame
        let frameStr = "x:\(Int(frame.origin.x)), y:\(Int(frame.origin.y)), w:\(Int(frame.width)), h:\(Int(frame.height))"

        waitForElementStability(element, timeout: 0.5)

        let pressDuration = min(action.duration ?? 1.0, 10.0)

        var usedCoordinateFallback = false
        var hint: String? = nil

        if element.isHittable {
            element.press(forDuration: pressDuration)
        } else {
            usedCoordinateFallback = true
            let coordinate = element.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
            coordinate.press(forDuration: pressDuration)
            hint = "Element was not hittable, used coordinate-based long press."
        }

        Thread.sleep(forTimeInterval: 0.1)

        let targetDesc = action.identifier ?? action.label ?? "element"
        return MCPResult(
            success: true,
            message: "Successfully long-pressed '\(targetDesc)' for \(pressDuration)s",
            elements: nil,
            error: nil,
            elementType: elementType,
            elementFrame: frameStr,
            usedCoordinateFallback: usedCoordinateFallback,
            hint: hint
        )
    }

    // MARK: - Type Action

    /// Execute a type/text entry action
    private func executeType(app: XCUIApplication, command: MCPCommand) throws -> MCPResult {
        guard let text = command.text else {
            throw MCPCommandError.missingParameter("text")
        }

        let timeout = command.timeout ?? Self.defaultTimeout
        var targetElement: XCUIElement

        // If identifier/label provided, find and focus that element
        if command.identifier != nil || command.label != nil {
            targetElement = try findElement(in: app, command: command)

            guard targetElement.waitForExistence(timeout: timeout) else {
                throw MCPCommandError.elementNotFound(command.identifier ?? command.label ?? "unknown")
            }

            // Tap to focus
            targetElement.tap()
        } else {
            // Type into currently focused element - find first responder or first text field
            let textFields = app.textFields.allElementsBoundByIndex
            let textViews = app.textViews.allElementsBoundByIndex
            let searchFields = app.searchFields.allElementsBoundByIndex

            let allTextElements = textFields + textViews + searchFields

            guard let firstFocusable = allTextElements.first(where: { $0.exists && $0.isHittable }) else {
                throw MCPCommandError.noFocusableElement
            }

            targetElement = firstFocusable
            targetElement.tap()
        }

        // Clear existing text if requested
        if command.clearFirst == true {
            // Select all and delete
            targetElement.tap()
            if let currentValue = targetElement.value as? String, !currentValue.isEmpty {
                // Triple tap to select all
                targetElement.tap()
                targetElement.tap()
                targetElement.tap()
                targetElement.typeText(XCUIKeyboardKey.delete.rawValue)
            }
        }

        // Type the text
        targetElement.typeText(text)

        let targetDesc = command.identifier ?? command.label ?? "focused element"
        return MCPResult(
            success: true,
            message: "Successfully typed '\(text)' into '\(targetDesc)'",
            elements: nil,
            error: nil
        )
    }

    // MARK: - Swipe Action

    /// Execute a swipe/scroll action
    private func executeSwipe(app: XCUIApplication, command: MCPCommand) throws -> MCPResult {
        guard let direction = command.direction else {
            throw MCPCommandError.missingParameter("direction")
        }

        let timeout = command.timeout ?? Self.defaultTimeout
        var targetElement: XCUIElement

        // If identifier/label provided, swipe on that element
        if command.identifier != nil || command.label != nil {
            targetElement = try findElement(in: app, command: command)

            guard targetElement.waitForExistence(timeout: timeout) else {
                throw MCPCommandError.elementNotFound(command.identifier ?? command.label ?? "unknown")
            }
        } else {
            // Swipe on the app window
            targetElement = app
        }

        // Perform swipe
        switch direction {
        case "up":
            targetElement.swipeUp()
        case "down":
            targetElement.swipeDown()
        case "left":
            targetElement.swipeLeft()
        case "right":
            targetElement.swipeRight()
        default:
            throw MCPCommandError.invalidDirection(direction)
        }

        let targetDesc = command.identifier ?? command.label ?? "app window"
        return MCPResult(
            success: true,
            message: "Successfully swiped \(direction) on '\(targetDesc)'",
            elements: nil,
            error: nil
        )
    }

    // MARK: - Query Action

    /// Execute a query action to list UI elements
    private func executeQuery(app: XCUIApplication, command: MCPCommand) throws -> MCPResult {
        var elements: [[String: String]] = []
        let maxDepth = command.queryDepth ?? 3
        let roleFilter = command.queryRole

        // Collect elements from the app
        collectElements(from: app, role: roleFilter, depth: maxDepth, elements: &elements)

        return MCPResult(
            success: true,
            message: "Found \(elements.count) elements",
            elements: elements,
            error: nil
        )
    }

    /// Recursively collect elements from the hierarchy
    private func collectElements(
        from element: XCUIElement,
        role: String?,
        depth: Int,
        elements: inout [[String: String]]
    ) {
        guard depth > 0 else { return }

        // Get all children of various types
        let types: [XCUIElement.ElementType] = [
            .button, .staticText, .textField, .textView, .image,
            .cell, .table, .scrollView, .navigationBar, .toolbar,
            .switch, .slider, .stepper, .picker, .segmentedControl,
            .searchField, .secureTextField, .link, .tab, .tabBar,
            .sheet, .alert, .dialog
        ]

        for type in types {
            let children = element.descendants(matching: type)
            for i in 0..<children.count {
                let child = children.element(boundBy: i)
                guard child.exists else { continue }

                // Build element info
                var info: [String: String] = [:]
                info["type"] = String(describing: type)

                if let identifier = child.identifier as String?, !identifier.isEmpty {
                    info["identifier"] = identifier
                }

                if let label = child.label as String?, !label.isEmpty {
                    info["label"] = label
                }

                if let value = child.value as? String, !value.isEmpty {
                    info["value"] = value
                }

                info["isEnabled"] = child.isEnabled ? "true" : "false"
                info["isHittable"] = child.isHittable ? "true" : "false"

                // Filter by role if specified
                if let role = role {
                    if String(describing: type).lowercased().contains(role.lowercased()) ||
                       (info["identifier"]?.lowercased().contains(role.lowercased()) ?? false) {
                        elements.append(info)
                    }
                } else {
                    elements.append(info)
                }

                // Limit to prevent excessive output
                if elements.count >= 100 {
                    return
                }
            }
        }
    }

    // MARK: - Element Finding

    /// Find an element by identifier or label
    /// Searches sheets, alerts, and navigation bars first for better modal support
    private func findElement(in app: XCUIApplication, command: MCPCommand) throws -> XCUIElement {
        // PRIORITY 1: Search in sheets/modals first (iOS 18+ uses these for add forms)
        // This catches buttons like "Create", "Cancel", "Add" in modal presentations
        if let element = findElementInSheets(app: app, command: command) {
            return element
        }

        // PRIORITY 2: Search in navigation bars (for toolbar buttons in modals)
        if let element = findElementInNavigationBars(app: app, command: command) {
            return element
        }

        // PRIORITY 3: Search in alerts (for confirmation dialogs)
        if let element = findElementInAlerts(app: app, command: command) {
            return element
        }

        // PRIORITY 4: Standard element search (main app content)
        if let element = findElementStandard(in: app, command: command) {
            return element
        }

        throw MCPCommandError.elementNotFound(command.identifier ?? command.label ?? "unknown")
    }

    /// Search for element in sheet presentations
    private func findElementInSheets(app: XCUIApplication, command: MCPCommand) -> XCUIElement? {
        let sheets = app.sheets
        guard sheets.count > 0 else { return nil }

        // Search by identifier in sheets
        if let identifier = command.identifier, !identifier.isEmpty {
            let button = sheets.buttons[identifier]
            if button.exists { return button.firstMatch }

            let textField = sheets.textFields[identifier]
            if textField.exists { return textField.firstMatch }

            let any = sheets.descendants(matching: .any)[identifier]
            if any.exists { return any.firstMatch }
        }

        // Search by label in sheets
        if let label = command.label, !label.isEmpty {
            let predicate = NSPredicate(format: "label CONTAINS[c] %@", label)

            let buttons = sheets.buttons.matching(predicate)
            if buttons.firstMatch.exists { return buttons.firstMatch }

            let staticTexts = sheets.staticTexts.matching(predicate)
            if staticTexts.firstMatch.exists { return staticTexts.firstMatch }
        }

        return nil
    }

    /// Search for element in navigation bars (common for modal toolbar buttons)
    private func findElementInNavigationBars(app: XCUIApplication, command: MCPCommand) -> XCUIElement? {
        let navBars = app.navigationBars
        guard navBars.count > 0 else { return nil }

        // Search by identifier in navigation bars
        if let identifier = command.identifier, !identifier.isEmpty {
            let button = navBars.buttons[identifier]
            if button.exists { return button.firstMatch }
        }

        // Search by label in navigation bars (for "Cancel", "Create", "Done", "Save" etc.)
        if let label = command.label, !label.isEmpty {
            let predicate = NSPredicate(format: "label CONTAINS[c] %@", label)

            let buttons = navBars.buttons.matching(predicate)
            if buttons.firstMatch.exists { return buttons.firstMatch }
        }

        return nil
    }

    /// Search for element in alerts
    private func findElementInAlerts(app: XCUIApplication, command: MCPCommand) -> XCUIElement? {
        let alerts = app.alerts
        guard alerts.count > 0 else { return nil }

        // Search by identifier in alerts
        if let identifier = command.identifier, !identifier.isEmpty {
            let button = alerts.buttons[identifier]
            if button.exists { return button.firstMatch }
        }

        // Search by label in alerts
        if let label = command.label, !label.isEmpty {
            let predicate = NSPredicate(format: "label CONTAINS[c] %@", label)

            let buttons = alerts.buttons.matching(predicate)
            if buttons.firstMatch.exists { return buttons.firstMatch }
        }

        return nil
    }

    /// Standard element search (original logic)
    private func findElementStandard(in app: XCUIApplication, command: MCPCommand) -> XCUIElement? {
        // Try identifier first (preferred)
        if let identifier = command.identifier, !identifier.isEmpty {
            // Try specific element types with identifier first (more reliable)
            let buttons = app.buttons[identifier]
            if buttons.exists { return buttons.firstMatch }

            let textFields = app.textFields[identifier]
            if textFields.exists { return textFields.firstMatch }

            let staticTexts = app.staticTexts[identifier]
            if staticTexts.exists { return staticTexts.firstMatch }

            let cells = app.cells[identifier]
            if cells.exists { return cells.firstMatch }

            let switches = app.switches[identifier]
            if switches.exists { return switches.firstMatch }

            let images = app.images[identifier]
            if images.exists { return images.firstMatch }

            // Fallback to descendants with matching identifier
            let element = app.descendants(matching: .any)[identifier].firstMatch
            if element.exists {
                return element
            }
        }

        // Try label
        if let label = command.label, !label.isEmpty {
            // Search through common element types for matching label
            let buttons = app.buttons.matching(NSPredicate(format: "label CONTAINS %@", label))
            if buttons.firstMatch.exists { return buttons.firstMatch }

            let staticTexts = app.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", label))
            if staticTexts.firstMatch.exists { return staticTexts.firstMatch }

            let textFields = app.textFields.matching(NSPredicate(format: "label CONTAINS %@", label))
            if textFields.firstMatch.exists { return textFields.firstMatch }

            let cells = app.cells.matching(NSPredicate(format: "label CONTAINS %@", label))
            if cells.firstMatch.exists { return cells.firstMatch }
        }

        return nil
    }
}

// MARK: - Errors

/// Errors that can occur during MCP command execution
enum MCPCommandError: LocalizedError {
    case commandFileNotFound(String)
    case unknownAction(String)
    case missingParameter(String)
    case elementNotFound(String)
    case elementNotHittable(String)
    case appNotReady(String, UInt)
    case invalidDirection(String)
    case noFocusableElement

    var errorDescription: String? {
        switch self {
        case .commandFileNotFound(let path):
            return "Command file not found at: \(path)"
        case .unknownAction(let action):
            return "Unknown action: \(action). Supported: click, type, swipe, query, longPress"
        case .missingParameter(let param):
            return "Missing required parameter: \(param)"
        case .elementNotFound(let identifier):
            return "Element not found: \(identifier)"
        case .elementNotHittable(let identifier):
            return "Element is not hittable (may be off-screen or hidden): \(identifier)"
        case .appNotReady(let bundleId, let state):
            return "App '\(bundleId)' not ready. Current state: \(state)"
        case .invalidDirection(let direction):
            return "Invalid swipe direction: \(direction). Use: up, down, left, right"
        case .noFocusableElement:
            return "No focusable text element found in the app"
        }
    }
}
