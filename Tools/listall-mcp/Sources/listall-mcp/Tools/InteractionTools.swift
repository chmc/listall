import Foundation
import MCP
import ApplicationServices

// MARK: - Interaction Tools

/// Namespace for interaction tool definitions and handlers.
/// Supports both macOS (via Accessibility API) and iOS/watchOS simulators (via XCUITest Bridge).
enum InteractionTools {
    // MARK: - Constants

    /// Default path to the ListAll Xcode project
    private static let defaultProjectPath = "/Users/aleksi/source/listall/ListAll/ListAll.xcodeproj"

    // MARK: - Tool Definitions

    /// Tool definition for listall_click
    static var clickTool: Tool {
        Tool(
            name: "listall_click",
            description: """
                Click (tap) a UI element by accessibility identifier or label.

                For macOS: Requires Accessibility permission. Uses the Accessibility API.
                For simulators: Uses XCUITest bridge (slower, ~5-10 seconds per action).

                Use listall_query first to discover available elements.
                Specify either identifier (preferred) or label to find the element.
                """,
            inputSchema: .object([
                "type": .string("object"),
                "properties": .object([
                    "app_name": .object([
                        "type": .string("string"),
                        "description": .string("For macOS: The name of the application (e.g., 'ListAllMac')")
                    ]),
                    "bundle_id": .object([
                        "type": .string("string"),
                        "description": .string("The bundle identifier (e.g., 'io.github.chmc.ListAllMac' for macOS or 'io.github.chmc.ListAll' for iOS)")
                    ]),
                    "simulator_udid": .object([
                        "type": .string("string"),
                        "description": .string("For simulators: The UDID of the simulator (use 'booted' for any booted simulator)")
                    ]),
                    "identifier": .object([
                        "type": .string("string"),
                        "description": .string("The accessibility identifier of the element to click")
                    ]),
                    "label": .object([
                        "type": .string("string"),
                        "description": .string("Alternative: The accessibility label/title of the element to click")
                    ]),
                    "role": .object([
                        "type": .string("string"),
                        "description": .string("Optional (macOS only): Filter by element role (e.g., 'AXButton', 'AXMenuItem')")
                    ])
                ]),
                "required": .array([])
            ])
        )
    }

    /// Tool definition for listall_type
    static var typeTool: Tool {
        Tool(
            name: "listall_type",
            description: """
                Enter text into a UI element.

                For macOS: Requires Accessibility permission. Uses the Accessibility API.
                For simulators: Uses XCUITest bridge (slower, ~5-10 seconds per action).

                Can type into the currently focused element or a specific element identified by accessibility ID/label.
                """,
            inputSchema: .object([
                "type": .string("object"),
                "properties": .object([
                    "app_name": .object([
                        "type": .string("string"),
                        "description": .string("For macOS: The name of the application (e.g., 'ListAllMac')")
                    ]),
                    "bundle_id": .object([
                        "type": .string("string"),
                        "description": .string("The bundle identifier (e.g., 'io.github.chmc.ListAllMac' for macOS or 'io.github.chmc.ListAll' for iOS)")
                    ]),
                    "simulator_udid": .object([
                        "type": .string("string"),
                        "description": .string("For simulators: The UDID of the simulator (use 'booted' for any booted simulator)")
                    ]),
                    "text": .object([
                        "type": .string("string"),
                        "description": .string("The text to type/enter")
                    ]),
                    "identifier": .object([
                        "type": .string("string"),
                        "description": .string("Optional: Accessibility identifier of target element (omit to type into focused element)")
                    ]),
                    "label": .object([
                        "type": .string("string"),
                        "description": .string("Optional: Accessibility label of target element")
                    ]),
                    "clear_first": .object([
                        "type": .string("boolean"),
                        "description": .string("Optional: Clear existing text before typing (default: false)")
                    ])
                ]),
                "required": .array([.string("text")])
            ])
        )
    }

    /// Tool definition for listall_swipe
    static var swipeTool: Tool {
        Tool(
            name: "listall_swipe",
            description: """
                Perform a scroll/swipe gesture on a UI element.

                For macOS: Requires Accessibility permission. Uses scroll events.
                For simulators: Uses XCUITest bridge swipe actions (slower, ~5-10 seconds per action).

                Use this for scrolling lists, tables, or scrollable views.
                """,
            inputSchema: .object([
                "type": .string("object"),
                "properties": .object([
                    "app_name": .object([
                        "type": .string("string"),
                        "description": .string("For macOS: The name of the application (e.g., 'ListAllMac')")
                    ]),
                    "bundle_id": .object([
                        "type": .string("string"),
                        "description": .string("The bundle identifier (e.g., 'io.github.chmc.ListAllMac' for macOS or 'io.github.chmc.ListAll' for iOS)")
                    ]),
                    "simulator_udid": .object([
                        "type": .string("string"),
                        "description": .string("For simulators: The UDID of the simulator (use 'booted' for any booted simulator)")
                    ]),
                    "direction": .object([
                        "type": .string("string"),
                        "description": .string("Scroll direction: 'up', 'down', 'left', or 'right'"),
                        "enum": .array([.string("up"), .string("down"), .string("left"), .string("right")])
                    ]),
                    "amount": .object([
                        "type": .string("number"),
                        "description": .string("macOS only: Scroll amount in pixels (default: 100)")
                    ]),
                    "identifier": .object([
                        "type": .string("string"),
                        "description": .string("Optional: Accessibility identifier of the scrollable element")
                    ]),
                    "label": .object([
                        "type": .string("string"),
                        "description": .string("Optional: Accessibility label of the scrollable element")
                    ])
                ]),
                "required": .array([.string("direction")])
            ])
        )
    }

    /// Tool definition for listall_query
    static var queryTool: Tool {
        Tool(
            name: "listall_query",
            description: """
                Query UI elements to discover accessibility IDs, labels, and structure.

                For macOS: Requires Accessibility permission. Uses the Accessibility API.
                For simulators: Uses XCUITest bridge (slower, ~5-15 seconds).

                Use this to find element identifiers for click/type/swipe operations.
                Returns UI elements with their properties (role, identifier, title, value).
                """,
            inputSchema: .object([
                "type": .string("object"),
                "properties": .object([
                    "app_name": .object([
                        "type": .string("string"),
                        "description": .string("For macOS: The name of the application (e.g., 'ListAllMac')")
                    ]),
                    "bundle_id": .object([
                        "type": .string("string"),
                        "description": .string("The bundle identifier (e.g., 'io.github.chmc.ListAllMac' for macOS or 'io.github.chmc.ListAll' for iOS)")
                    ]),
                    "simulator_udid": .object([
                        "type": .string("string"),
                        "description": .string("For simulators: The UDID of the simulator (use 'booted' for any booted simulator)")
                    ]),
                    "role": .object([
                        "type": .string("string"),
                        "description": .string("Optional: Filter results by element role/type (e.g., 'button', 'textField')")
                    ]),
                    "depth": .object([
                        "type": .string("integer"),
                        "description": .string("Maximum depth to traverse (default: 5, max: 10)")
                    ]),
                    "format": .object([
                        "type": .string("string"),
                        "description": .string("macOS only: Output format 'tree' (hierarchical) or 'flat' (list)"),
                        "enum": .array([.string("tree"), .string("flat")])
                    ]),
                    "max_elements": .object([
                        "type": .string("integer"),
                        "description": .string("Optional: Maximum number of elements to return (default: unlimited for tree, 100 for flat)")
                    ]),
                    "include_geometry": .object([
                        "type": .string("boolean"),
                        "description": .string("Optional: Include position/size in results (default: true)")
                    ]),
                    "compact": .object([
                        "type": .string("boolean"),
                        "description": .string("Compact mode: no geometry, compact JSON, reduced depth to 3 (default: false). Use this to reduce token usage.")
                    ])
                ]),
                "required": .array([])
            ])
        )
    }

    /// Tool definition for listall_batch
    static var batchTool: Tool {
        Tool(
            name: "listall_batch",
            description: """
                Execute multiple UI actions in a single operation (simulator only).

                This is more efficient than calling individual tools when you need to perform
                multiple actions in sequence. Each action in the batch is executed sequentially.

                Use this when you need to: click button A, then type text, then click button B.
                Performance: ~10-12s for 3 actions vs ~24s for 3 separate calls.

                Note: query action is not supported in batch (use separate listall_query call).
                """,
            inputSchema: .object([
                "type": .string("object"),
                "properties": .object([
                    "simulator_udid": .object([
                        "type": .string("string"),
                        "description": .string("The UDID of the simulator (use 'booted' for any booted simulator)")
                    ]),
                    "bundle_id": .object([
                        "type": .string("string"),
                        "description": .string("Bundle identifier of the target app")
                    ]),
                    "actions": .object([
                        "type": .string("array"),
                        "description": .string("Array of actions to execute sequentially"),
                        "items": .object([
                            "type": .string("object"),
                            "properties": .object([
                                "action": .object([
                                    "type": .string("string"),
                                    "enum": .array([.string("click"), .string("type"), .string("swipe")]),
                                    "description": .string("Action type: click, type, or swipe")
                                ]),
                                "identifier": .object([
                                    "type": .string("string"),
                                    "description": .string("Accessibility identifier of target element")
                                ]),
                                "label": .object([
                                    "type": .string("string"),
                                    "description": .string("Accessibility label of target element")
                                ]),
                                "text": .object([
                                    "type": .string("string"),
                                    "description": .string("Text to type (for type action)")
                                ]),
                                "direction": .object([
                                    "type": .string("string"),
                                    "description": .string("Swipe direction: up, down, left, right (for swipe action)")
                                ]),
                                "clear_first": .object([
                                    "type": .string("boolean"),
                                    "description": .string("Clear text before typing (for type action)")
                                ])
                            ]),
                            "required": .array([.string("action")])
                        ])
                    ])
                ]),
                "required": .array([.string("simulator_udid"), .string("bundle_id"), .string("actions")])
            ])
        )
    }

    // MARK: - Tool Collection

    /// All interaction tools
    static var allTools: [Tool] {
        [
            clickTool,
            typeTool,
            swipeTool,
            queryTool,
            batchTool
        ]
    }

    /// Check if a tool name is an interaction tool
    static func isInteractionTool(_ name: String) -> Bool {
        allTools.contains { $0.name == name }
    }

    // MARK: - Tool Handlers

    /// Route a tool call to the appropriate handler
    static func handleToolCall(name: String, arguments: [String: Value]?) async throws -> CallTool.Result {
        // Extract simulator_udid to determine if this is a simulator or macOS request
        let simulatorUDID = arguments?["simulator_udid"].flatMap { value -> String? in
            if case .string(let str) = value { return str }
            return nil
        }

        // If simulator_udid is provided, use XCUITest bridge
        if let udid = simulatorUDID {
            // Batch tool is simulator-only (macOS uses Accessibility API which is already fast)
            if name == "listall_batch" {
                guard let bundleId = arguments?["bundle_id"].flatMap({ value -> String? in
                    if case .string(let str) = value { return str }
                    return nil
                }) else {
                    throw MCPError.invalidParams("bundle_id is required for batch operations")
                }
                return try await handleSimulatorBatch(udid: udid, bundleId: bundleId, arguments: arguments)
            }
            return try await handleSimulatorToolCall(name: name, udid: udid, arguments: arguments)
        }

        // Batch tool is not supported for macOS (Accessibility API is already fast)
        if name == "listall_batch" {
            throw MCPError.invalidParams("listall_batch is only supported for simulators. For macOS, use individual tools (listall_click, listall_type, listall_swipe) which are already fast via Accessibility API.")
        }

        // Otherwise, use macOS Accessibility API
        // Check accessibility permission first
        guard AccessibilityService.hasAccessibilityPermission() else {
            log("Accessibility permission not granted")
            throw MCPError.internalError(PermissionError.accessibilityDenied)
        }

        switch name {
        case "listall_click":
            return try await handleMacOSClick(arguments: arguments)
        case "listall_type":
            return try await handleMacOSType(arguments: arguments)
        case "listall_swipe":
            return try await handleMacOSSwipe(arguments: arguments)
        case "listall_query":
            return try await handleMacOSQuery(arguments: arguments)
        default:
            throw MCPError.invalidParams("Unknown interaction tool: \(name)")
        }
    }

    // MARK: - Simulator Tool Handlers

    /// Handle simulator tool calls via XCUITest bridge
    private static func handleSimulatorToolCall(name: String, udid: String, arguments: [String: Value]?) async throws -> CallTool.Result {
        // Log device type for debugging (watchOS now supported!)
        let deviceType = try await XCUITestBridge.getDeviceType(for: udid)
        log("\(name) called for \(deviceType) simulator: \(udid)")

        guard let bundleId = arguments?["bundle_id"].flatMap({ value -> String? in
            if case .string(let str) = value { return str }
            return nil
        }) else {
            throw MCPError.invalidParams("bundle_id is required for simulator interactions")
        }

        switch name {
        case "listall_click":
            return try await handleSimulatorClick(udid: udid, bundleId: bundleId, arguments: arguments)
        case "listall_type":
            return try await handleSimulatorType(udid: udid, bundleId: bundleId, arguments: arguments)
        case "listall_swipe":
            return try await handleSimulatorSwipe(udid: udid, bundleId: bundleId, arguments: arguments)
        case "listall_query":
            return try await handleSimulatorQuery(udid: udid, bundleId: bundleId, arguments: arguments)
        default:
            throw MCPError.invalidParams("Unknown interaction tool: \(name)")
        }
    }

    /// Handle simulator click via XCUITest
    private static func handleSimulatorClick(udid: String, bundleId: String, arguments: [String: Value]?) async throws -> CallTool.Result {
        let identifier = arguments?["identifier"].flatMap { value -> String? in
            if case .string(let str) = value { return str }
            return nil
        }

        let label = arguments?["label"].flatMap { value -> String? in
            if case .string(let str) = value { return str }
            return nil
        }

        guard identifier != nil || label != nil else {
            throw MCPError.invalidParams("Either identifier or label must be provided")
        }

        let result = try await XCUITestBridge.click(
            simulatorUDID: udid,
            bundleId: bundleId,
            identifier: identifier,
            label: label,
            projectPath: defaultProjectPath
        )

        if result.success {
            // Build enhanced feedback message
            var message = result.message

            // Add element details if available
            if let elementType = result.elementType {
                message += "\n  Element type: \(elementType)"
            }
            if let frame = result.elementFrame {
                message += "\n  Position: \(frame)"
            }
            if let usedFallback = result.usedCoordinateFallback, usedFallback {
                message += "\n  Note: Used coordinate-based tap (element was not directly hittable)"
            }
            if let hint = result.hint {
                message += "\n  Hint: \(hint)"
            }

            return CallTool.Result(content: [.text(message)])
        } else {
            throw MCPError.internalError(result.error ?? result.message)
        }
    }

    /// Handle simulator type via XCUITest
    private static func handleSimulatorType(udid: String, bundleId: String, arguments: [String: Value]?) async throws -> CallTool.Result {
        guard let text = arguments?["text"].flatMap({ value -> String? in
            if case .string(let str) = value { return str }
            return nil
        }) else {
            throw MCPError.invalidParams("Missing required parameter: text")
        }

        let identifier = arguments?["identifier"].flatMap { value -> String? in
            if case .string(let str) = value { return str }
            return nil
        }

        let label = arguments?["label"].flatMap { value -> String? in
            if case .string(let str) = value { return str }
            return nil
        }

        let clearFirst = arguments?["clear_first"].flatMap { value -> Bool? in
            if case .bool(let b) = value { return b }
            return nil
        } ?? false

        let result = try await XCUITestBridge.type(
            simulatorUDID: udid,
            bundleId: bundleId,
            text: text,
            identifier: identifier,
            label: label,
            clearFirst: clearFirst,
            projectPath: defaultProjectPath
        )

        if result.success {
            return CallTool.Result(content: [.text(result.message)])
        } else {
            throw MCPError.internalError(result.error ?? result.message)
        }
    }

    /// Handle simulator swipe via XCUITest
    private static func handleSimulatorSwipe(udid: String, bundleId: String, arguments: [String: Value]?) async throws -> CallTool.Result {
        guard let direction = arguments?["direction"].flatMap({ value -> String? in
            if case .string(let str) = value { return str }
            return nil
        }) else {
            throw MCPError.invalidParams("Missing required parameter: direction")
        }

        let identifier = arguments?["identifier"].flatMap { value -> String? in
            if case .string(let str) = value { return str }
            return nil
        }

        let label = arguments?["label"].flatMap { value -> String? in
            if case .string(let str) = value { return str }
            return nil
        }

        let result = try await XCUITestBridge.swipe(
            simulatorUDID: udid,
            bundleId: bundleId,
            direction: direction,
            identifier: identifier,
            label: label,
            projectPath: defaultProjectPath
        )

        if result.success {
            return CallTool.Result(content: [.text(result.message)])
        } else {
            throw MCPError.internalError(result.error ?? result.message)
        }
    }

    /// Handle simulator query via XCUITest
    private static func handleSimulatorQuery(udid: String, bundleId: String, arguments: [String: Value]?) async throws -> CallTool.Result {
        let role = arguments?["role"].flatMap { value -> String? in
            if case .string(let str) = value { return str }
            return nil
        }

        let depth = arguments?["depth"].flatMap { value -> Int? in
            if case .int(let n) = value { return n }
            if case .double(let n) = value { return Int(n) }
            return nil
        } ?? 3

        let result = try await XCUITestBridge.query(
            simulatorUDID: udid,
            bundleId: bundleId,
            role: role,
            depth: depth,
            projectPath: defaultProjectPath
        )

        if result.success {
            // Format elements as JSON
            var output = result.message

            if let elements = result.elements, !elements.isEmpty {
                let jsonData = try JSONSerialization.data(withJSONObject: elements, options: [.prettyPrinted, .sortedKeys])
                if let jsonString = String(data: jsonData, encoding: .utf8) {
                    output += "\n\nElements:\n\(jsonString)"
                }
            }

            return CallTool.Result(content: [.text(output)])
        } else {
            throw MCPError.internalError(result.error ?? result.message)
        }
    }

    /// Handle simulator batch execution via XCUITest
    private static func handleSimulatorBatch(udid: String, bundleId: String, arguments: [String: Value]?) async throws -> CallTool.Result {
        // Parse actions array from arguments
        guard let actionsValue = arguments?["actions"] else {
            throw MCPError.invalidParams("Missing required parameter: actions")
        }

        guard case .array(let actionsArray) = actionsValue else {
            throw MCPError.invalidParams("actions must be an array")
        }

        if actionsArray.isEmpty {
            return CallTool.Result(content: [.text("No actions to execute")])
        }

        // Convert Value array to XCUITestBridge.Action array
        var actions: [XCUITestBridge.Action] = []

        for (index, actionValue) in actionsArray.enumerated() {
            guard case .object(let actionDict) = actionValue else {
                throw MCPError.invalidParams("Action at index \(index) must be an object")
            }

            // Extract action type (required)
            guard let actionTypeValue = actionDict["action"],
                  case .string(let actionType) = actionTypeValue else {
                throw MCPError.invalidParams("Action at index \(index) missing required 'action' field")
            }

            // Validate action type
            guard ["click", "type", "swipe"].contains(actionType) else {
                throw MCPError.invalidParams("Action at index \(index) has invalid action type '\(actionType)'. Must be click, type, or swipe.")
            }

            // Extract optional fields
            let identifier = actionDict["identifier"].flatMap { value -> String? in
                if case .string(let str) = value { return str }
                return nil
            }

            let label = actionDict["label"].flatMap { value -> String? in
                if case .string(let str) = value { return str }
                return nil
            }

            let text = actionDict["text"].flatMap { value -> String? in
                if case .string(let str) = value { return str }
                return nil
            }

            let direction = actionDict["direction"].flatMap { value -> String? in
                if case .string(let str) = value { return str }
                return nil
            }

            let clearFirst = actionDict["clear_first"].flatMap { value -> Bool? in
                if case .bool(let b) = value { return b }
                return nil
            }

            // Validate action-specific required fields
            switch actionType {
            case "click":
                guard identifier != nil || label != nil else {
                    throw MCPError.invalidParams("Click action at index \(index) requires either 'identifier' or 'label'")
                }
            case "type":
                guard text != nil else {
                    throw MCPError.invalidParams("Type action at index \(index) requires 'text' field")
                }
            case "swipe":
                guard direction != nil else {
                    throw MCPError.invalidParams("Swipe action at index \(index) requires 'direction' field")
                }
                guard ["up", "down", "left", "right"].contains(direction!) else {
                    throw MCPError.invalidParams("Swipe action at index \(index) has invalid direction '\(direction!)'. Must be up, down, left, or right.")
                }
            default:
                break
            }

            let action = XCUITestBridge.Action(
                action: actionType,
                identifier: identifier,
                label: label,
                text: text,
                direction: direction,
                timeout: 10,
                clearFirst: clearFirst,
                queryRole: nil,
                queryDepth: nil
            )
            actions.append(action)
        }

        log("listall_batch: Executing \(actions.count) actions on simulator \(udid)")

        // Execute batch via XCUITestBridge
        let result = try await XCUITestBridge.executeBatch(
            actions: actions,
            simulatorUDID: udid,
            bundleId: bundleId,
            projectPath: defaultProjectPath
        )

        // Format results
        var output = "Batch execution \(result.success ? "completed" : "failed"): \(result.message)\n"
        output += "Actions: \(actions.count), Results: \(result.results.count)\n\n"

        for (index, actionResult) in result.results.enumerated() {
            let action = actions[index]
            let status = actionResult.success ? "SUCCESS" : "FAILED"
            output += "[\(index + 1)] \(action.action.uppercased()) - \(status)\n"
            output += "    \(actionResult.message)\n"

            if let error = actionResult.error {
                output += "    Error: \(error)\n"
            }
            if let elementType = actionResult.elementType {
                output += "    Element type: \(elementType)\n"
            }
            if let hint = actionResult.hint {
                output += "    Hint: \(hint)\n"
            }
        }

        if result.success {
            return CallTool.Result(content: [.text(output)])
        } else {
            throw MCPError.internalError(output)
        }
    }

    // MARK: - macOS Click Handler

    /// Handle listall_click tool call for macOS
    static func handleMacOSClick(arguments: [String: Value]?) async throws -> CallTool.Result {
        log("listall_click called (macOS)")

        let appName = arguments?["app_name"].flatMap { value -> String? in
            if case .string(let str) = value { return str }
            return nil
        }

        let bundleId = arguments?["bundle_id"].flatMap { value -> String? in
            if case .string(let str) = value { return str }
            return nil
        }

        let identifier = arguments?["identifier"].flatMap { value -> String? in
            if case .string(let str) = value { return str }
            return nil
        }

        let label = arguments?["label"].flatMap { value -> String? in
            if case .string(let str) = value { return str }
            return nil
        }

        let role = arguments?["role"].flatMap { value -> String? in
            if case .string(let str) = value { return str }
            return nil
        }

        // Validate inputs
        guard appName != nil || bundleId != nil else {
            throw MCPError.invalidParams("Either app_name or bundle_id must be provided")
        }

        guard identifier != nil || label != nil else {
            throw MCPError.invalidParams("Either identifier or label must be provided to find the element")
        }

        // Get application element
        guard let appElement = AccessibilityService.getApplicationElement(bundleId: bundleId, appName: appName) else {
            let appIdentifier = bundleId ?? appName ?? "unknown"
            throw MCPError.internalError("Application '\(appIdentifier)' not found or not running")
        }

        log("Found application, searching for element...")

        // Find the target element
        guard let element = AccessibilityService.findElement(
            in: appElement,
            identifier: identifier,
            label: label,
            role: role
        ) else {
            let searchDesc = identifier ?? label ?? "unknown"
            throw MCPError.internalError("Element '\(searchDesc)' not found in application")
        }

        log("Found element, performing click...")

        // Activate app before clicking - the click may fall back to CGEvent-based mouse events
        // which are delivered to the frontmost app
        do {
            try await AccessibilityService.ensureAppActivated(bundleId: bundleId, appName: appName)
        } catch {
            throw MCPError.internalError("Failed to activate app: \(error.localizedDescription)")
        }

        // Perform click
        do {
            try AccessibilityService.click(element)
        } catch {
            throw MCPError.internalError("Failed to click element: \(error.localizedDescription)")
        }

        let targetDesc = identifier ?? label ?? "element"
        log("Click successful on '\(targetDesc)'")

        return CallTool.Result(content: [
            .text("Successfully clicked '\(targetDesc)'. The action has been performed.")
        ])
    }

    // MARK: - macOS Type Handler

    /// Handle listall_type tool call for macOS
    static func handleMacOSType(arguments: [String: Value]?) async throws -> CallTool.Result {
        log("listall_type called (macOS)")

        let appName = arguments?["app_name"].flatMap { value -> String? in
            if case .string(let str) = value { return str }
            return nil
        }

        let bundleId = arguments?["bundle_id"].flatMap { value -> String? in
            if case .string(let str) = value { return str }
            return nil
        }

        guard let text = arguments?["text"].flatMap({ value -> String? in
            if case .string(let str) = value { return str }
            return nil
        }) else {
            throw MCPError.invalidParams("Missing required parameter: text")
        }

        let identifier = arguments?["identifier"].flatMap { value -> String? in
            if case .string(let str) = value { return str }
            return nil
        }

        let label = arguments?["label"].flatMap { value -> String? in
            if case .string(let str) = value { return str }
            return nil
        }

        let clearFirst = arguments?["clear_first"].flatMap { value -> Bool? in
            if case .bool(let b) = value { return b }
            return nil
        } ?? false

        // Validate inputs
        guard appName != nil || bundleId != nil else {
            throw MCPError.invalidParams("Either app_name or bundle_id must be provided")
        }

        // Get application element
        guard let appElement = AccessibilityService.getApplicationElement(bundleId: bundleId, appName: appName) else {
            let appIdentifier = bundleId ?? appName ?? "unknown"
            throw MCPError.internalError("Application '\(appIdentifier)' not found or not running")
        }

        log("Found application...")

        // If identifier or label provided, find and type into specific element
        if identifier != nil || label != nil {
            guard let element = AccessibilityService.findElement(
                in: appElement,
                identifier: identifier,
                label: label,
                role: nil
            ) else {
                let searchDesc = identifier ?? label ?? "unknown"
                throw MCPError.internalError("Element '\(searchDesc)' not found in application")
            }

            log("Found element, setting text...")

            // Clear first if requested
            if clearFirst {
                do {
                    try AccessibilityService.typeText("", into: element)
                } catch {
                    log("Warning: Could not clear text: \(error)")
                }
            }

            // Set text value
            do {
                try AccessibilityService.typeText(text, into: element)
            } catch {
                throw MCPError.internalError("Failed to type text: \(error.localizedDescription)")
            }

            let targetDesc = identifier ?? label ?? "element"
            log("Text entered into '\(targetDesc)'")

            return CallTool.Result(content: [
                .text("Successfully entered text into '\(targetDesc)'. Text: '\(text)'")
            ])
        } else {
            // Type into focused element using key events
            // CGEvents go to the system event queue and are delivered to the frontmost app,
            // so we must activate the target app first
            log("Activating app before typing with key events...")

            do {
                try await AccessibilityService.ensureAppActivated(bundleId: bundleId, appName: appName)
            } catch {
                throw MCPError.internalError("Failed to activate app: \(error.localizedDescription)")
            }

            log("Typing into focused element using key events...")

            do {
                try AccessibilityService.typeText(text)
            } catch {
                throw MCPError.internalError("Failed to type text: \(error.localizedDescription)")
            }

            log("Text typed using key events")

            return CallTool.Result(content: [
                .text("Successfully typed '\(text)' into focused element using keyboard events.")
            ])
        }
    }

    // MARK: - macOS Swipe Handler

    /// Handle listall_swipe tool call for macOS
    static func handleMacOSSwipe(arguments: [String: Value]?) async throws -> CallTool.Result {
        log("listall_swipe called (macOS)")

        let appName = arguments?["app_name"].flatMap { value -> String? in
            if case .string(let str) = value { return str }
            return nil
        }

        let bundleId = arguments?["bundle_id"].flatMap { value -> String? in
            if case .string(let str) = value { return str }
            return nil
        }

        guard let directionStr = arguments?["direction"].flatMap({ value -> String? in
            if case .string(let str) = value { return str }
            return nil
        }) else {
            throw MCPError.invalidParams("Missing required parameter: direction")
        }

        let amount = arguments?["amount"].flatMap { value -> Double? in
            if case .double(let n) = value { return n }
            if case .int(let n) = value { return Double(n) }
            return nil
        } ?? 100.0

        let identifier = arguments?["identifier"].flatMap { value -> String? in
            if case .string(let str) = value { return str }
            return nil
        }

        let label = arguments?["label"].flatMap { value -> String? in
            if case .string(let str) = value { return str }
            return nil
        }

        // Validate inputs
        guard appName != nil || bundleId != nil else {
            throw MCPError.invalidParams("Either app_name or bundle_id must be provided")
        }

        // Parse direction
        let scrollDirection: ScrollDirection
        var scrollAmount: CGFloat

        switch directionStr {
        case "up":
            scrollDirection = .vertical
            scrollAmount = CGFloat(amount)  // Positive scrolls content up (wheel down)
        case "down":
            scrollDirection = .vertical
            scrollAmount = CGFloat(-amount)  // Negative scrolls content down (wheel up)
        case "left":
            scrollDirection = .horizontal
            scrollAmount = CGFloat(amount)
        case "right":
            scrollDirection = .horizontal
            scrollAmount = CGFloat(-amount)
        default:
            throw MCPError.invalidParams("Invalid direction: '\(directionStr)'. Must be 'up', 'down', 'left', or 'right'")
        }

        // Get application element
        guard let appElement = AccessibilityService.getApplicationElement(bundleId: bundleId, appName: appName) else {
            let appIdentifier = bundleId ?? appName ?? "unknown"
            throw MCPError.internalError("Application '\(appIdentifier)' not found or not running")
        }

        log("Found application...")

        // Find scrollable element if identifier/label provided, otherwise use first window
        let scrollElement: AXUIElement

        if identifier != nil || label != nil {
            guard let element = AccessibilityService.findElement(
                in: appElement,
                identifier: identifier,
                label: label,
                role: nil
            ) else {
                let searchDesc = identifier ?? label ?? "unknown"
                throw MCPError.internalError("Element '\(searchDesc)' not found in application")
            }
            scrollElement = element
        } else {
            // Get first window
            var windowsRef: CFTypeRef?
            AXUIElementCopyAttributeValue(appElement, kAXWindowsAttribute as CFString, &windowsRef)
            guard let windows = windowsRef as? [AXUIElement], let firstWindow = windows.first else {
                throw MCPError.internalError("No windows found in application")
            }
            scrollElement = firstWindow
        }

        log("Performing scroll: \(directionStr), amount: \(amount)")

        // Activate app before scrolling - scroll events use CGEvents which go to frontmost app
        do {
            try await AccessibilityService.ensureAppActivated(bundleId: bundleId, appName: appName)
        } catch {
            throw MCPError.internalError("Failed to activate app: \(error.localizedDescription)")
        }

        // Perform scroll
        do {
            try AccessibilityService.scroll(in: scrollElement, direction: scrollDirection, amount: scrollAmount)
        } catch {
            throw MCPError.internalError("Failed to scroll: \(error.localizedDescription)")
        }

        let targetDesc = identifier ?? label ?? "window"
        log("Scroll successful on '\(targetDesc)'")

        return CallTool.Result(content: [
            .text("Successfully scrolled \(directionStr) by \(Int(amount)) pixels on '\(targetDesc)'.")
        ])
    }

    // MARK: - macOS Query Handler

    /// Handle listall_query tool call for macOS
    static func handleMacOSQuery(arguments: [String: Value]?) async throws -> CallTool.Result {
        log("listall_query called (macOS)")

        let appName = arguments?["app_name"].flatMap { value -> String? in
            if case .string(let str) = value { return str }
            return nil
        }

        let bundleId = arguments?["bundle_id"].flatMap { value -> String? in
            if case .string(let str) = value { return str }
            return nil
        }

        let role = arguments?["role"].flatMap { value -> String? in
            if case .string(let str) = value { return str }
            return nil
        }

        let depth = arguments?["depth"].flatMap { value -> Int? in
            if case .int(let n) = value { return n }
            if case .double(let n) = value { return Int(n) }
            return nil
        } ?? 5

        let format = arguments?["format"].flatMap { value -> String? in
            if case .string(let str) = value { return str }
            return nil
        } ?? "tree"

        let maxElements = arguments?["max_elements"].flatMap { value -> Int? in
            if case .int(let n) = value { return n }
            if case .double(let n) = value { return Int(n) }
            return nil
        }

        let includeGeometry = arguments?["include_geometry"].flatMap { value -> Bool? in
            if case .bool(let b) = value { return b }
            return nil
        } ?? true

        let compact = arguments?["compact"].flatMap { value -> Bool? in
            if case .bool(let b) = value { return b }
            return nil
        } ?? false

        // Validate inputs
        guard appName != nil || bundleId != nil else {
            throw MCPError.invalidParams("Either app_name or bundle_id must be provided")
        }

        // Apply compact mode overrides: no geometry, reduced depth (3)
        let effectiveIncludeGeometry = compact ? false : includeGeometry
        let effectiveDepth = compact ? min(depth, 3) : depth

        // Clamp depth
        let clampedDepth = min(max(effectiveDepth, 1), 10)

        // Get application element
        guard let appElement = AccessibilityService.getApplicationElement(bundleId: bundleId, appName: appName) else {
            let appIdentifier = bundleId ?? appName ?? "unknown"
            throw MCPError.internalError("Application '\(appIdentifier)' not found or not running")
        }

        log("Found application, querying UI elements...")

        let result: Any

        if format == "flat" {
            // Return flat list of elements
            let effectiveMax = maxElements ?? 100
            let elements = AccessibilityService.findAllElements(
                in: appElement,
                role: role,
                maxResults: effectiveMax,
                includeGeometry: effectiveIncludeGeometry
            )
            result = elements
            log("Found \(elements.count) elements")
        } else {
            // Return hierarchical tree
            let tree = AccessibilityService.getElementTree(
                from: appElement,
                depth: clampedDepth,
                maxElements: maxElements,
                includeGeometry: effectiveIncludeGeometry
            )
            result = tree
            log("Built element tree")
        }

        // Convert to JSON - use compact format (no prettyPrinted) when compact mode
        let jsonOptions: JSONSerialization.WritingOptions = compact ? [.sortedKeys] : [.prettyPrinted, .sortedKeys]
        let jsonData = try JSONSerialization.data(withJSONObject: result, options: jsonOptions)
        let jsonString = String(data: jsonData, encoding: .utf8) ?? "{}"

        let appIdentifier = bundleId ?? appName ?? "unknown"
        let modeInfo = compact ? ", compact: true" : ""

        return CallTool.Result(content: [
            .text("UI Elements for '\(appIdentifier)' (format: \(format), depth: \(clampedDepth)\(modeInfo)):\n\n\(jsonString)")
        ])
    }
}
