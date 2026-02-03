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

    // Note: continueOnFailure is handled at batch level, not per-action
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

    // Batch mode: array of actions to execute sequentially
    let commands: [MCPAction]?

    // Batch mode: stop executing on first failure (default: true = continue on failure)
    // When false, batch execution stops at the first failed action
    let continueOnFailure: Bool?
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

// MARK: - MCP Command Runner for watchOS

/// XCUITest class that reads commands from a file, executes them, and writes results.
/// This acts as a bridge between the MCP server and the watchOS simulator.
///
/// Usage:
/// 1. MCP server writes command JSON to /tmp/listall_mcp_command.json
/// 2. MCP server invokes `xcodebuild test-without-building -only-testing:ListAllWatch Watch AppUITests/MCPCommandRunner/testRunMCPCommand`
/// 3. This test reads the command, executes it, and writes result to /tmp/listall_mcp_result.json
/// 4. MCP server reads the result and returns to Claude
///
/// watchOS-specific adaptations:
/// - No sheet search logic (watchOS has no sheets)
/// - Increased timeouts (watchOS simulator is slower)
/// - Simplified element types (no tabBar, segmentedControl, etc.)
/// - Coordinate-based tap fallback for small watch UI
final class MCPCommandRunner: XCTestCase {

    // MARK: - Constants (watchOS-adapted timeouts)

    // watchOS uses separate temp file paths to enable parallel iOS+watchOS testing
    // This avoids file conflicts when both platforms run XCUITest simultaneously
    private static let commandPath = "/tmp/listall_mcp_watch_command.json"
    private static let resultPath = "/tmp/listall_mcp_watch_result.json"

    // watchOS-specific: increased timeouts for slower simulator
    private static let defaultTimeout: TimeInterval = 15.0
    private static let appLaunchTimeout: TimeInterval = 45.0

    // MARK: - Action-Specific Stability Timeouts

    /// Returns the appropriate stability timeout for different action types.
    /// - Click: 0.5s - buttons typically don't animate much before tap
    /// - Type: 0.5s - text fields need stability for reliable input
    /// - Swipe: 1.0s - scroll animations need time to settle
    /// - Default: 0.5s - conservative default for unknown actions
    private func getStabilityTimeout(for action: String) -> TimeInterval {
        switch action {
        case "click": return 0.5
        case "type": return 0.5
        case "swipe": return 1.0
        default: return 0.5
        }
    }

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

            // Wait for app to be in foreground (watchOS needs longer timeout)
            let timeout = command.timeout ?? Self.appLaunchTimeout
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
        default:
            throw MCPCommandError.unknownAction(action)
        }
    }

    // MARK: - Batch Command Execution

    /// Execute a batch of actions and return batch result
    /// The app is launched once and all actions are executed sequentially.
    /// By default (continueOnFailure=true), all actions run even if some fail.
    /// Set continueOnFailure=false to stop at the first failure.
    /// watchOS-specific: uses longer timeouts for slower simulator
    private func executeBatchCommand(_ command: MCPCommand, actions: [MCPAction]) throws -> MCPBatchResult {
        // Get or launch the app once for all actions
        let app = XCUIApplication(bundleIdentifier: command.bundleId)

        // Launch the app with UITEST_MODE if not running
        if app.state != .runningForeground {
            app.launchArguments = ["UITEST_MODE", "DISABLE_TOOLTIPS"]
            app.launch()

            // Wait for app to be in foreground (watchOS needs longer timeout)
            let timeout = Self.appLaunchTimeout
            let appeared = app.wait(for: .runningForeground, timeout: timeout)
            if !appeared {
                throw MCPCommandError.appNotReady(command.bundleId, app.state.rawValue)
            }
        }

        // Determine failure behavior (default: continue on failure for backward compatibility)
        let shouldContinueOnFailure = command.continueOnFailure ?? true

        // Execute each action and collect results
        var results: [MCPResult] = []
        var overallSuccess = true
        var stoppedEarly = false

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

                // Stop early if continueOnFailure is false
                if !shouldContinueOnFailure {
                    stoppedEarly = true
                    break
                }
            }
        }

        // Build summary message
        let successCount = results.filter { $0.success }.count
        let executedCount = results.count
        var message = "Executed \(executedCount) of \(actions.count) actions: \(successCount) succeeded, \(executedCount - successCount) failed"
        if stoppedEarly {
            message += " (stopped on first failure)"
        }

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
        default:
            throw MCPCommandError.unknownAction(action.action)
        }
    }

    // MARK: - Action Execution (for batch mode)

    /// Execute a click/tap action from batch
    /// watchOS-specific: uses action-specific stability timeout
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

        // Wait for animation stabilization using action-specific timeout
        waitForElementStability(element, timeout: getStabilityTimeout(for: action.action))

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

        Thread.sleep(forTimeInterval: 0.15)

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
            // watchOS: no textViews, only textFields and searchFields
            let textFields = app.textFields.allElementsBoundByIndex
            let searchFields = app.searchFields.allElementsBoundByIndex

            let allTextElements = textFields + searchFields

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
    /// watchOS uses swipe extensively for navigation
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
            // Right swipe often goes "back" on watchOS
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
    /// watchOS-adapted: no sheet search (watchOS doesn't have sheets)
    private func findElementForAction(in app: XCUIApplication, action: MCPAction) throws -> XCUIElement {
        // Search in navigation bars first
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

    /// Standard element search for batch mode
    /// watchOS-optimized: search order prioritizes interactive elements (button, cell, switch)
    private func findElementStandardForAction(in app: XCUIApplication, action: MCPAction) -> XCUIElement? {
        if let identifier = action.identifier, !identifier.isEmpty {
            // Search order optimized for watchOS: buttons and cells are most common interactions
            let buttons = app.buttons[identifier]
            if buttons.exists { return buttons.firstMatch }

            let cells = app.cells[identifier]
            if cells.exists { return cells.firstMatch }

            let switches = app.switches[identifier]
            if switches.exists { return switches.firstMatch }

            let staticTexts = app.staticTexts[identifier]
            if staticTexts.exists { return staticTexts.firstMatch }

            let textFields = app.textFields[identifier]
            if textFields.exists { return textFields.firstMatch }

            let images = app.images[identifier]
            if images.exists { return images.firstMatch }

            let element = app.descendants(matching: .any)[identifier].firstMatch
            if element.exists {
                return element
            }
        }

        if let label = action.label, !label.isEmpty {
            // Search order optimized for watchOS: buttons and cells first
            let buttons = app.buttons.matching(NSPredicate(format: "label CONTAINS %@", label))
            if buttons.firstMatch.exists { return buttons.firstMatch }

            let cells = app.cells.matching(NSPredicate(format: "label CONTAINS %@", label))
            if cells.firstMatch.exists { return cells.firstMatch }

            let staticTexts = app.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", label))
            if staticTexts.firstMatch.exists { return staticTexts.firstMatch }

            let textFields = app.textFields.matching(NSPredicate(format: "label CONTAINS %@", label))
            if textFields.firstMatch.exists { return textFields.firstMatch }
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

        // Wait for animation stabilization using action-specific timeout
        waitForElementStability(element, timeout: getStabilityTimeout(for: "click"))

        // Track if we used coordinate fallback
        var usedCoordinateFallback = false
        var hint: String? = nil

        // Try direct tap first, fallback to coordinate-based tap
        // watchOS small UI makes coordinate-based taps especially useful
        if element.isHittable {
            element.tap()
        } else {
            // Coordinate-based tap works for elements that may not be "hittable"
            // but are still visible and tappable at their center point
            usedCoordinateFallback = true
            let coordinate = element.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
            coordinate.tap()
            hint = "Element was not hittable, used coordinate-based tap. Recommend: listall_screenshot to verify state."
        }

        // Brief delay for SwiftUI event processing
        Thread.sleep(forTimeInterval: 0.15)

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
            let searchFields = app.searchFields.allElementsBoundByIndex

            let allTextElements = textFields + searchFields

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
    /// watchOS uses swipe extensively for navigation (no Digital Crown support in XCUITest)
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
            // Right swipe often goes "back" on watchOS
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

    /// Collect elements from the UI hierarchy
    /// watchOS-adapted: simplified element types for watch UI
    ///
    /// TODO: The `depth` parameter currently has no effect because `descendants(matching:)`
    /// retrieves ALL descendants regardless of depth. XCUITest does not provide a built-in
    /// way to limit traversal depth. For watchOS this is acceptable since the UI typically
    /// has ~27 elements. If depth limiting becomes necessary, we would need to implement
    /// manual tree traversal using `children(matching:)` recursively, but this would be
    /// significantly slower due to multiple XCUITest queries.
    private func collectElements(
        from element: XCUIElement,
        role: String?,
        depth: Int,
        elements: inout [[String: String]]
    ) {
        guard depth > 0 else { return }

        // watchOS-specific element types (simplified from iOS)
        // Ordered by interaction frequency: buttons are most common for watchOS interactions
        let types: [XCUIElement.ElementType] = [
            .button, .cell, .switch, .staticText, .textField, .image,
            .table, .scrollView, .navigationBar,
            .slider, .picker,
            .searchField, .link, .alert
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

                // Limit to prevent excessive output (watchOS usually has fewer elements)
                if elements.count >= 50 {
                    return
                }
            }
        }
    }

    // MARK: - Element Finding

    /// Find an element by identifier or label
    /// watchOS-adapted: no sheet search (watchOS doesn't have sheets)
    private func findElement(in app: XCUIApplication, command: MCPCommand) throws -> XCUIElement {
        // PRIORITY 1: Search in navigation bars (for toolbar/back buttons)
        if let element = findElementInNavigationBars(app: app, command: command) {
            return element
        }

        // PRIORITY 2: Search in alerts (for confirmation dialogs)
        if let element = findElementInAlerts(app: app, command: command) {
            return element
        }

        // PRIORITY 3: Standard element search (main app content)
        if let element = findElementStandard(in: app, command: command) {
            return element
        }

        throw MCPCommandError.elementNotFound(command.identifier ?? command.label ?? "unknown")
    }

    /// Search for element in navigation bars
    private func findElementInNavigationBars(app: XCUIApplication, command: MCPCommand) -> XCUIElement? {
        let navBars = app.navigationBars
        guard navBars.count > 0 else { return nil }

        // Search by identifier in navigation bars
        if let identifier = command.identifier, !identifier.isEmpty {
            let button = navBars.buttons[identifier]
            if button.exists { return button.firstMatch }
        }

        // Search by label in navigation bars
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

    /// Standard element search
    /// watchOS-optimized: search order prioritizes interactive elements (button, cell, switch)
    /// since most watchOS interactions are taps on these element types
    private func findElementStandard(in app: XCUIApplication, command: MCPCommand) -> XCUIElement? {
        // Try identifier first (preferred)
        if let identifier = command.identifier, !identifier.isEmpty {
            // Search order optimized for watchOS: buttons and cells are most common interactions
            let buttons = app.buttons[identifier]
            if buttons.exists { return buttons.firstMatch }

            let cells = app.cells[identifier]
            if cells.exists { return cells.firstMatch }

            let switches = app.switches[identifier]
            if switches.exists { return switches.firstMatch }

            let staticTexts = app.staticTexts[identifier]
            if staticTexts.exists { return staticTexts.firstMatch }

            let textFields = app.textFields[identifier]
            if textFields.exists { return textFields.firstMatch }

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
            // Search order optimized for watchOS: buttons and cells first
            let buttons = app.buttons.matching(NSPredicate(format: "label CONTAINS %@", label))
            if buttons.firstMatch.exists { return buttons.firstMatch }

            let cells = app.cells.matching(NSPredicate(format: "label CONTAINS %@", label))
            if cells.firstMatch.exists { return cells.firstMatch }

            let staticTexts = app.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", label))
            if staticTexts.firstMatch.exists { return staticTexts.firstMatch }

            let textFields = app.textFields.matching(NSPredicate(format: "label CONTAINS %@", label))
            if textFields.firstMatch.exists { return textFields.firstMatch }
        }

        return nil
    }
}

// MARK: - Errors

/// Errors that can occur during MCP command execution on watchOS
/// These error messages provide watchOS-specific context and recovery guidance.
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
            return """
                watchOS command file not found at: \(path)

                This indicates the MCP server did not write the command file.
                Recovery: Run listall_diagnostics to check XCUITest runner status.
                """
        case .unknownAction(let action):
            return """
                Unknown watchOS action: \(action)

                Supported actions: click, type, swipe, query
                Note: watchOS has limited UI patterns compared to iOS.
                Use swipe for Digital Crown-like scrolling.
                """
        case .missingParameter(let param):
            return "Missing required parameter: \(param)"
        case .elementNotFound(let identifier):
            return """
                watchOS element not found: '\(identifier)'

                Recovery steps:
                1. Run listall_screenshot(udid: "booted") to see current UI state
                2. Run listall_query to discover available element identifiers
                3. Check if element is visible (watchOS has small screen, may need to scroll)

                Note: watchOS uses Digital Crown for scrolling. Use listall_swipe(direction: "up")
                or listall_swipe(direction: "down") to scroll the view.
                """
        case .elementNotHittable(let identifier):
            return """
                watchOS element not hittable: '\(identifier)'

                The element exists but cannot be tapped. Possible causes:
                1. Element is off-screen (use listall_swipe to scroll)
                2. Element is behind another view
                3. Element is disabled

                Recovery: Run listall_screenshot to verify element visibility.
                """
        case .appNotReady(let bundleId, let state):
            return """
                watchOS app '\(bundleId)' not ready (state: \(state))

                watchOS simulator is slower to launch apps than iOS.
                Recovery steps:
                1. Wait a few seconds and retry
                2. Run listall_screenshot to check simulator state
                3. If stuck: listall_shutdown_simulator(udid: "all") and restart

                Note: watchOS app launch can take 30-45 seconds on first run.
                """
        case .invalidDirection(let direction):
            return """
                Invalid swipe direction: '\(direction)'

                Valid directions: up, down, left, right

                watchOS swipe patterns:
                - up/down: Scroll content (like Digital Crown)
                - left: Often reveals delete/action buttons
                - right: Navigate back (dismiss current view)
                """
        case .noFocusableElement:
            return """
                No focusable text element found on watchOS

                Recovery steps:
                1. Run listall_query(role: "textField") to find text inputs
                2. watchOS has limited text input - check if current screen has text fields
                3. Use listall_screenshot to verify the UI state

                Note: Many watchOS screens use buttons/lists instead of text input.
                """
        }
    }
}
