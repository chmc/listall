import Foundation
import MCP
@preconcurrency import ScreenCaptureKit
import CoreGraphics
import AppKit

// MARK: - macOS Tools

/// Namespace for macOS-specific tool definitions and handlers
enum MacOSTools {
    // MARK: - Tool Definitions

    /// Tool definition for listall_launch (macOS variant)
    static var launchMacOSTool: Tool {
        Tool(
            name: "listall_launch_macos",
            description: """
                Launch a macOS application by name or bundle identifier.
                Uses 'open -a AppName' or 'open -b BundleID' to launch the app.
                For ListAllMac, use app_name: 'ListAll' or bundle_id: 'io.github.chmc.ListAll'.
                Use launch_args to pass arguments like 'UITEST_MODE' to populate test data.
                Returns success message or error if app cannot be launched.
                """,
            inputSchema: .object([
                "type": .string("object"),
                "properties": .object([
                    "app_name": .object([
                        "type": .string("string"),
                        "description": .string("The name of the application to launch (e.g., 'ListAll', 'Safari')")
                    ]),
                    "bundle_id": .object([
                        "type": .string("string"),
                        "description": .string("Alternative: The bundle identifier of the app (e.g., 'io.github.chmc.ListAll')")
                    ]),
                    "launch_args": .object([
                        "type": .string("array"),
                        "items": .object(["type": .string("string")]),
                        "description": .string("Optional: Launch arguments to pass to the app (e.g., ['UITEST_MODE', 'DISABLE_TOOLTIPS'])")
                    ])
                ]),
                "required": .array([])
            ])
        )
    }

    /// Tool definition for listall_screenshot (macOS variant)
    static var screenshotMacOSTool: Tool {
        Tool(
            name: "listall_screenshot_macos",
            description: """
                Take a screenshot of a macOS application window and return it as base64-encoded PNG.
                Uses ScreenCaptureKit to capture the window. Requires Screen Recording permission.
                Specify either app_name or bundle_id to identify which app window to capture.
                For ListAllMac, use app_name: 'ListAll' or bundle_id: 'io.github.chmc.ListAll'.
                Screenshots are saved to .listall-mcp/YYMMDD-HHMMSS-{context}/ for history.
                Returns the screenshot as an embedded image that Claude can see and analyze.
                """,
            inputSchema: .object([
                "type": .string("object"),
                "properties": .object([
                    "app_name": .object([
                        "type": .string("string"),
                        "description": .string("The name of the application to screenshot (e.g., 'ListAll')")
                    ]),
                    "bundle_id": .object([
                        "type": .string("string"),
                        "description": .string("Alternative: The bundle identifier of the app (e.g., 'io.github.chmc.ListAll')")
                    ]),
                    "window_title": .object([
                        "type": .string("string"),
                        "description": .string("Optional: Specific window title to capture if app has multiple windows")
                    ]),
                    "context": .object([
                        "type": .string("string"),
                        "description": .string("Optional context for screenshot folder name (e.g., 'button-component', 'before-fix')")
                    ])
                ]),
                "required": .array([])
            ])
        )
    }

    /// Tool definition for checking macOS permissions
    static var checkPermissionsTool: Tool {
        Tool(
            name: "listall_check_macos_permissions",
            description: """
                Check if required macOS permissions are granted for the MCP server.
                Checks Screen Recording permission (for screenshots) and Accessibility permission (for interactions).
                Returns status and instructions for granting missing permissions.
                """,
            inputSchema: .object([
                "type": .string("object"),
                "properties": .object([:]),
                "required": .array([])
            ])
        )
    }

    /// Tool definition for quitting macOS applications
    static var quitMacOSTool: Tool {
        Tool(
            name: "listall_quit_macos",
            description: """
                Quit a running macOS application.
                Uses AppleScript to gracefully quit the app.
                For ListAll, use app_name: 'ListAll' or bundle_id: 'io.github.chmc.ListAll'.
                """,
            inputSchema: .object([
                "type": .string("object"),
                "properties": .object([
                    "app_name": .object([
                        "type": .string("string"),
                        "description": .string("The name of the application to quit (e.g., 'ListAll')")
                    ]),
                    "bundle_id": .object([
                        "type": .string("string"),
                        "description": .string("Alternative: The bundle identifier (e.g., 'io.github.chmc.ListAll')")
                    ])
                ]),
                "required": .array([])
            ])
        )
    }

    /// Tool definition for hiding macOS applications
    static var hideMacOSTool: Tool {
        Tool(
            name: "listall_hide_macos",
            description: """
                Hide a running macOS application (move to background without quitting).
                App must be running - returns error if not running.
                App remains in memory and can be re-shown by calling listall_launch_macos.
                For ListAll, use app_name: 'ListAll' or bundle_id: 'io.github.chmc.ListAll'.
                """,
            inputSchema: .object([
                "type": .string("object"),
                "properties": .object([
                    "app_name": .object([
                        "type": .string("string"),
                        "description": .string("The name of the application to hide (e.g., 'ListAll')")
                    ]),
                    "bundle_id": .object([
                        "type": .string("string"),
                        "description": .string("Alternative: The bundle identifier (e.g., 'io.github.chmc.ListAll')")
                    ])
                ]),
                "required": .array([])
            ])
        )
    }

    // MARK: - Tool Collection

    /// All macOS tools
    static var allTools: [Tool] {
        [
            launchMacOSTool,
            screenshotMacOSTool,
            quitMacOSTool,
            hideMacOSTool,
            checkPermissionsTool
        ]
    }

    /// Check if a tool name is a macOS tool
    static func isMacOSTool(_ name: String) -> Bool {
        allTools.contains { $0.name == name }
    }

    // MARK: - Tool Handlers

    /// Route a tool call to the appropriate handler
    static func handleToolCall(name: String, arguments: [String: Value]?) async throws -> CallTool.Result {
        switch name {
        case "listall_launch_macos":
            return try await handleLaunchMacOS(arguments: arguments)
        case "listall_screenshot_macos":
            // Screenshot is @MainActor-isolated for ScreenCaptureKit
            return try await handleScreenshotMacOS(arguments: arguments)
        case "listall_quit_macos":
            return try await handleQuitMacOS(arguments: arguments)
        case "listall_hide_macos":
            return try await handleHideMacOS(arguments: arguments)
        case "listall_check_macos_permissions":
            return try await handleCheckPermissions(arguments: arguments)
        default:
            throw MCPError.invalidParams("Unknown macOS tool: \(name)")
        }
    }

    // MARK: - Launch Handler

    /// Handle listall_launch_macos tool call
    static func handleLaunchMacOS(arguments: [String: Value]?) async throws -> CallTool.Result {
        log("listall_launch_macos called")

        var appName = arguments?["app_name"].flatMap { value -> String? in
            if case .string(let str) = value { return str }
            return nil
        }

        var bundleId = arguments?["bundle_id"].flatMap { value -> String? in
            if case .string(let str) = value { return str }
            return nil
        }

        // Extract launch_args
        var launchArgs: [String] = []
        if let arguments = arguments, case .array(let argsArray) = arguments["launch_args"] {
            for arg in argsArray {
                if case .string(let str) = arg {
                    // Security: alphanumeric + underscore only, non-empty
                    let allowedChars = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "_"))
                    if !str.isEmpty && str.unicodeScalars.allSatisfy({ allowedChars.contains($0) }) {
                        launchArgs.append(str)
                    } else {
                        log("Skipping invalid launch argument: \(str)")
                    }
                }
            }
        }

        // Validate that at least one identifier is provided
        guard appName != nil || bundleId != nil else {
            throw MCPError.invalidParams("Either app_name or bundle_id must be provided")
        }

        // Normalize ListAll variants (ListAllMac -> ListAll)
        appName = normalizeListAllAppName(appName)
        bundleId = normalizeListAllBundleID(bundleId)

        // Validate bundle ID if provided
        if let bundleId = bundleId {
            try validateBundleID(bundleId)
        }

        // Validate app name if provided (basic security check)
        if let appName = appName {
            try validateAppName(appName)
        }

        // Build the open command arguments
        var openArgs: [String] = []

        // Add background flag if requested (launches without focusing)
        if launchArgs.contains("BACKGROUND") {
            openArgs.append("-g")
            log("Background mode enabled (app will not be focused)")
        }

        if let bundleId = bundleId {
            openArgs.append("-b")
            openArgs.append(bundleId)
            log("Launching app by bundle ID: \(bundleId)")
        } else if let appName = appName {
            openArgs.append("-a")
            openArgs.append(appName)
            log("Launching app by name: \(appName)")
        }

        // Append launch arguments if provided
        if !launchArgs.isEmpty {
            openArgs.append("--args")
            openArgs.append(contentsOf: launchArgs)
            log("With launch arguments: \(launchArgs)")
        }

        // If UITEST_MODE is in launch args, quit the app first to ensure fresh launch with new args
        // (If app is already running, macOS brings existing instance to foreground without applying new args)
        if launchArgs.contains("UITEST_MODE") {
            let targetApp = appName ?? "ListAll"
            log("UITEST_MODE requested, quitting '\(targetApp)' to ensure fresh launch...")
            let quitScript = "tell application \"\(targetApp)\" to quit"
            _ = try? await ShellCommand.execute("/usr/bin/osascript", arguments: ["-e", quitScript])
            // Brief sleep to ensure app fully terminates before relaunch
            try? await Task.sleep(nanoseconds: 500_000_000)  // 0.5 seconds
        }

        // Execute the open command
        var result = try await ShellCommand.execute("/usr/bin/open", arguments: openArgs)

        // If standard launch fails for ListAll, search DerivedData
        if result.exitCode != 0 && (appName == "ListAll" || bundleId == "io.github.chmc.ListAll") {
            log("Standard launch failed, searching DerivedData for ListAll.app")
            if let appPath = await findListAllMacAppPath() {
                log("Found ListAll.app at: \(appPath)")
                // Build fallback arguments including background flag and launch args
                var fallbackArgs: [String] = []
                if launchArgs.contains("BACKGROUND") {
                    fallbackArgs.append("-g")
                }
                fallbackArgs.append(appPath)
                if !launchArgs.isEmpty {
                    fallbackArgs.append("--args")
                    fallbackArgs.append(contentsOf: launchArgs)
                }
                result = try await ShellCommand.execute("/usr/bin/open", arguments: fallbackArgs)
            }
        }

        if result.exitCode == 0 {
            let identifier = bundleId ?? appName ?? "unknown"
            let argsNote = launchArgs.isEmpty ? "" : " with args: \(launchArgs.joined(separator: ", "))"
            log("App launched successfully: \(identifier)\(argsNote)")

            // Build response message
            var message = "Successfully launched \(identifier)."
            if !launchArgs.isEmpty {
                message += " Launch arguments: \(launchArgs.joined(separator: ", "))."
                if launchArgs.contains("UITEST_MODE") {
                    message += " (App was quit first to ensure fresh launch with UITEST_MODE.)"
                }
            }
            if launchArgs.contains("BACKGROUND") {
                message += " App is running in background (not focused)."
            } else {
                message += " The app should now be visible."
            }

            return CallTool.Result(content: [
                .text(message)
            ])
        } else {
            log("Failed to launch app: \(result.stderr)")

            // Provide helpful error messages
            if result.stderr.contains("Unable to find application") {
                let identifier = bundleId ?? appName ?? "unknown"
                throw MCPError.internalError("Application not found: '\(identifier)'. Make sure the app is installed or built.")
            }

            throw MCPError.internalError("Failed to launch app: \(result.stderr)")
        }
    }

    // MARK: - App Path Discovery

    /// Find ListAll macOS app in DerivedData locations
    private static func findListAllMacAppPath() async -> String? {
        let fm = FileManager.default

        // 1. Check project's local DerivedData (relative to MCP server location)
        // MCP server is at Tools/listall-mcp, project DerivedData is at ListAll/DerivedData
        let mcpDir = fm.currentDirectoryPath
        let projectRoot = ((mcpDir as NSString).deletingLastPathComponent as NSString).deletingLastPathComponent
        let localDerivedData = (projectRoot as NSString).appendingPathComponent("ListAll/DerivedData/Build/Products/Debug/ListAll.app")
        if fm.fileExists(atPath: localDerivedData) {
            return localDerivedData
        }

        // 2. Check global DerivedData
        let globalDerivedData = "\(NSHomeDirectory())/Library/Developer/Xcode/DerivedData"
        if let contents = try? fm.contentsOfDirectory(atPath: globalDerivedData) {
            for item in contents where item.hasPrefix("ListAll-") {
                let appPath = "\(globalDerivedData)/\(item)/Build/Products/Debug/ListAll.app"
                // Verify it's a macOS app (has Contents/MacOS structure)
                let execPath = "\(appPath)/Contents/MacOS/ListAll"
                if fm.fileExists(atPath: execPath) {
                    return appPath
                }
            }
        }

        // 3. Check well-known project location (hardcoded fallback)
        let knownPath = "\(NSHomeDirectory())/source/listall/ListAll/DerivedData/Build/Products/Debug/ListAll.app"
        if fm.fileExists(atPath: knownPath) {
            return knownPath
        }

        return nil
    }

    // MARK: - Screenshot Handler

    /// Handle listall_screenshot_macos tool call
    /// Uses CGWindowListCopyWindowInfo + screencapture command for reliable CLI operation
    static func handleScreenshotMacOS(arguments: [String: Value]?) async throws -> CallTool.Result {
        log("listall_screenshot_macos called")

        var appName = arguments?["app_name"].flatMap { value -> String? in
            if case .string(let str) = value { return str }
            return nil
        }

        var bundleId = arguments?["bundle_id"].flatMap { value -> String? in
            if case .string(let str) = value { return str }
            return nil
        }

        let windowTitle = arguments?["window_title"].flatMap { value -> String? in
            if case .string(let str) = value { return str }
            return nil
        }

        let context = arguments?["context"].flatMap { value -> String? in
            if case .string(let str) = value { return str }
            return nil
        }

        // Validate that at least one identifier is provided
        guard appName != nil || bundleId != nil else {
            throw MCPError.invalidParams("Either app_name or bundle_id must be provided")
        }

        // Normalize ListAll variants (ListAllMac -> ListAll)
        appName = normalizeListAllAppName(appName)
        bundleId = normalizeListAllBundleID(bundleId)

        // Validate bundle ID if provided
        if let bundleId = bundleId {
            try validateBundleID(bundleId)
        }

        // Validate app name if provided
        if let appName = appName {
            try validateAppName(appName)
        }

        log("Finding window for app: \(bundleId ?? appName ?? "unknown")")

        // Use CGWindowListCopyWindowInfo to find windows (works reliably in CLI context)
        guard let windowList = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID) as? [[String: Any]] else {
            throw MCPError.internalError("Failed to get window list")
        }

        // Find windows matching the app
        // Store layer to sort by (higher layers = sheets/modals on top)
        var matchingWindows: [(windowId: CGWindowID, name: String, ownerName: String, bounds: CGRect, layer: Int)] = []

        for windowInfo in windowList {
            guard let windowId = windowInfo[kCGWindowNumber as String] as? CGWindowID,
                  let ownerName = windowInfo[kCGWindowOwnerName as String] as? String,
                  let boundsDict = windowInfo[kCGWindowBounds as String] as? [String: Any],
                  let layer = windowInfo[kCGWindowLayer as String] as? Int else {
                continue
            }

            // Accept layer 0 (normal windows) and positive layers (sheets/modals)
            // Negative layers are typically system-level windows (dock, menu bar)
            guard layer >= 0 else {
                continue
            }

            let windowName = windowInfo[kCGWindowName as String] as? String ?? ""
            let ownerPID = windowInfo[kCGWindowOwnerPID as String] as? Int32

            // Match by app name or bundle ID
            var matches = false
            if let appName = appName {
                matches = ownerName == appName
            }
            if let bundleId = bundleId, let pid = ownerPID {
                // Get bundle ID from PID
                if let app = NSRunningApplication(processIdentifier: pid) {
                    matches = app.bundleIdentifier == bundleId
                }
            }

            if matches {
                let bounds = CGRect(
                    x: boundsDict["X"] as? CGFloat ?? 0,
                    y: boundsDict["Y"] as? CGFloat ?? 0,
                    width: boundsDict["Width"] as? CGFloat ?? 0,
                    height: boundsDict["Height"] as? CGFloat ?? 0
                )
                // Skip tiny windows (likely auxiliary)
                if bounds.width > 50 && bounds.height > 50 {
                    matchingWindows.append((windowId, windowName, ownerName, bounds, layer))
                }
            }
        }

        // Sort by layer descending - highest layer (sheets/modals) first
        matchingWindows.sort { $0.layer > $1.layer }

        guard !matchingWindows.isEmpty else {
            let identifier = bundleId ?? appName ?? "unknown"
            log("No windows found for: \(identifier)")

            // List available apps for debugging
            let availableApps = Set(windowList.compactMap { $0[kCGWindowOwnerName as String] as? String })
            log("Available applications: \(availableApps)")

            throw MCPError.internalError(
                "Application '\(identifier)' not found or has no visible windows. " +
                "Available apps: \(availableApps.joined(separator: ", "))"
            )
        }

        // Select window (by title if specified, otherwise first window which is highest layer)
        let targetWindow: (windowId: CGWindowID, name: String, ownerName: String, bounds: CGRect, layer: Int)
        if let windowTitle = windowTitle {
            guard let window = matchingWindows.first(where: { $0.name.contains(windowTitle) }) else {
                let availableTitles = matchingWindows.map { $0.name }
                log("Window with title '\(windowTitle)' not found. Available: \(availableTitles)")
                throw MCPError.internalError(
                    "Window with title containing '\(windowTitle)' not found. " +
                    "Available windows: \(availableTitles.joined(separator: ", "))"
                )
            }
            targetWindow = window
        } else {
            // First window is highest layer (sheet/modal if present, otherwise main window)
            targetWindow = matchingWindows[0]
        }

        let windowTypeDesc = targetWindow.layer > 0 ? "sheet/modal (layer \(targetWindow.layer))" : "main window"
        log("Capturing window ID \(targetWindow.windowId): '\(targetWindow.name)' (\(Int(targetWindow.bounds.width))x\(Int(targetWindow.bounds.height))) - \(windowTypeDesc)")

        // Use screencapture command to capture the specific window
        // -l flag captures window by ID, -x suppresses sound, -o excludes shadow
        let tempFile = FileManager.default.temporaryDirectory
            .appendingPathComponent("listall_screenshot_\(UUID().uuidString).png")

        var result = try await ShellCommand.execute(
            "/usr/sbin/screencapture",
            arguments: ["-l", "\(targetWindow.windowId)", "-x", "-o", tempFile.path]
        )

        // If window ID capture fails (common with sheets/modals), fall back to bounds-based capture
        if result.exitCode != 0 || !FileManager.default.fileExists(atPath: tempFile.path) ||
           (FileManager.default.contents(atPath: tempFile.path)?.isEmpty ?? true) {
            log("Window ID capture failed, falling back to bounds-based capture")

            // Try capturing by screen region (bounds) instead
            // -R flag captures a specific rectangle: x,y,width,height
            let bounds = targetWindow.bounds
            let rectArg = "\(Int(bounds.origin.x)),\(Int(bounds.origin.y)),\(Int(bounds.width)),\(Int(bounds.height))"

            result = try await ShellCommand.execute(
                "/usr/sbin/screencapture",
                arguments: ["-R", rectArg, "-x", "-o", tempFile.path]
            )
        }

        guard result.exitCode == 0 else {
            log("screencapture failed: \(result.stderr)")
            throw MCPError.internalError("Failed to capture screenshot: \(result.stderr)")
        }

        // Read the captured image
        guard let rawPngData = FileManager.default.contents(atPath: tempFile.path) else {
            throw MCPError.internalError("Failed to read screenshot file")
        }

        // Clean up temp file
        try? FileManager.default.removeItem(at: tempFile)

        // Resize image if needed to stay under Claude API limits (2000px)
        let pngData = ScreenshotStorage.resizeImageIfNeeded(rawPngData)

        // Save screenshot to project folder (DO NOT delete - history is valuable)
        let savedPath = try ScreenshotStorage.saveScreenshot(
            imageData: pngData,
            context: context,
            platform: "macos"
        )

        let base64Image = pngData.base64EncodedString()

        log("Screenshot captured successfully (\(pngData.count) bytes), saved to: \(savedPath)")

        return CallTool.Result(content: [
            .text("Screenshot saved to: \(savedPath)"),
            .image(data: base64Image, mimeType: "image/png", metadata: nil)
        ])
    }

    // MARK: - Permission Check Handler

    /// Handle listall_check_macos_permissions tool call
    static func handleCheckPermissions(arguments: [String: Value]?) async throws -> CallTool.Result {
        log("listall_check_macos_permissions called")

        let status = await PermissionService.getPermissionStatus()

        // Format status as readable output
        var output = "macOS Permission Status:\n\n"

        if let screenRecording = status["screen_recording"] as? [String: Any] {
            let granted = screenRecording["granted"] as? Bool ?? false
            let description = screenRecording["description"] as? String ?? ""
            let requiredFor = screenRecording["required_for"] as? [String] ?? []

            output += "Screen Recording: \(granted ? "GRANTED" : "NOT GRANTED")\n"
            output += "  \(description)\n"
            output += "  Required for: \(requiredFor.joined(separator: ", "))\n"
        }

        output += "\n"

        if let accessibility = status["accessibility"] as? [String: Any] {
            let granted = accessibility["granted"] as? Bool ?? false
            let description = accessibility["description"] as? String ?? ""
            let requiredFor = accessibility["required_for"] as? [String] ?? []

            output += "Accessibility: \(granted ? "GRANTED" : "NOT GRANTED")\n"
            output += "  \(description)\n"
            output += "  Required for: \(requiredFor.joined(separator: ", "))\n"
        }

        output += "\n"

        // Add instructions if any permission is missing
        let screenRecordingGranted = (status["screen_recording"] as? [String: Any])?["granted"] as? Bool ?? false
        let accessibilityGranted = (status["accessibility"] as? [String: Any])?["granted"] as? Bool ?? false

        if !screenRecordingGranted || !accessibilityGranted {
            output += "Instructions to grant missing permissions:\n\n"

            if !screenRecordingGranted {
                output += """
                SCREEN RECORDING:
                1. Open System Settings
                2. Go to Privacy & Security > Screen Recording
                3. Click the '+' button to add Terminal (or the app running the MCP server)
                4. Restart Terminal after granting permission

                """
            }

            if !accessibilityGranted {
                output += """
                ACCESSIBILITY:
                1. Open System Settings
                2. Go to Privacy & Security > Accessibility
                3. Click the '+' button to add Terminal (or the app running the MCP server)
                4. Make sure the checkbox is enabled
                5. Restart Terminal after granting permission
                """
            }
        } else {
            output += "All required permissions are granted."
        }

        log("Permission check completed")

        return CallTool.Result(content: [.text(output)])
    }

    // MARK: - Quit Handler

    /// Handle listall_quit_macos tool call
    static func handleQuitMacOS(arguments: [String: Value]?) async throws -> CallTool.Result {
        log("listall_quit_macos called")

        var appName = arguments?["app_name"].flatMap { value -> String? in
            if case .string(let str) = value { return str }
            return nil
        }

        var bundleId = arguments?["bundle_id"].flatMap { value -> String? in
            if case .string(let str) = value { return str }
            return nil
        }

        guard appName != nil || bundleId != nil else {
            throw MCPError.invalidParams("Either app_name or bundle_id must be provided")
        }

        // CRITICAL: Validate inputs BEFORE any use (prevents AppleScript injection)
        if let name = appName {
            try validateAppName(name)
        }
        if let id = bundleId {
            try validateBundleID(id)
        }

        // Apply normalization to match launch behavior
        appName = normalizeListAllAppName(appName)
        bundleId = normalizeListAllBundleID(bundleId)

        // Use consistent identifier for messages (matches other tools' pattern)
        let identifier = bundleId ?? appName ?? "unknown"

        log("Quitting macOS app: \(identifier)")

        // Build AppleScript - inputs are validated, safe to interpolate
        let quitScript: String
        if let bundleId = bundleId {
            quitScript = "tell application id \"\(bundleId)\" to quit"
        } else if let appName = appName {
            quitScript = "tell application \"\(appName)\" to quit"
        } else {
            throw MCPError.invalidParams("No valid app identifier")
        }

        let result = try await ShellCommand.execute("/usr/bin/osascript", arguments: ["-e", quitScript])

        if result.exitCode == 0 {
            return CallTool.Result(content: [.text("Successfully quit '\(identifier)'.")])
        } else {
            // App might not be running - not an error
            if result.stderr.contains("not running") {
                return CallTool.Result(content: [.text("App '\(identifier)' was not running.")])
            }
            throw MCPError.internalError("Failed to quit app: \(result.stderr)")
        }
    }

    // MARK: - Hide Handler

    /// Handle listall_hide_macos tool call
    static func handleHideMacOS(arguments: [String: Value]?) async throws -> CallTool.Result {
        log("listall_hide_macos called")

        var appName = arguments?["app_name"].flatMap { value -> String? in
            if case .string(let str) = value { return str }
            return nil
        }

        var bundleId = arguments?["bundle_id"].flatMap { value -> String? in
            if case .string(let str) = value { return str }
            return nil
        }

        guard appName != nil || bundleId != nil else {
            throw MCPError.invalidParams("Either app_name or bundle_id must be provided")
        }

        // CRITICAL: Validate inputs BEFORE any use (prevents AppleScript injection)
        if let name = appName {
            try validateAppName(name)
        }
        if let id = bundleId {
            try validateBundleID(id)
        }

        // Apply normalization to match launch behavior
        appName = normalizeListAllAppName(appName)
        bundleId = normalizeListAllBundleID(bundleId)

        // Use consistent identifier for messages
        let identifier = bundleId ?? appName ?? "unknown"

        log("Hiding macOS app: \(identifier)")

        // PREFER: Use NSRunningApplication (no Automation permission needed)
        if let bid = bundleId {
            if let app = NSRunningApplication.runningApplications(withBundleIdentifier: bid).first {
                let success = app.hide()
                if success {
                    log("Successfully hid app using NSRunningApplication")
                    return CallTool.Result(content: [.text("Successfully hid '\(identifier)'.")])
                }
                // Fall through to AppleScript if hide() fails
                log("NSRunningApplication.hide() returned false, trying AppleScript")
            } else {
                // App not running
                log("App '\(identifier)' is not running (NSRunningApplication check)")
                return CallTool.Result(content: [.text("App '\(identifier)' is not running. Nothing to hide.")])
            }
        }

        // FALLBACK: AppleScript (requires Automation permission)
        // First check if app is running (AppleScript `set visible to false` LAUNCHES the app if not running!)
        let targetApp = appName ?? bundleId!
        let checkScript = "application \"\(targetApp)\" is running"
        let checkResult = try await ShellCommand.execute("/usr/bin/osascript", arguments: ["-e", checkScript])

        if checkResult.stdout.trimmingCharacters(in: .whitespacesAndNewlines) != "true" {
            log("App '\(identifier)' is not running (AppleScript check)")
            return CallTool.Result(content: [.text("App '\(identifier)' is not running. Nothing to hide.")])
        }

        // App is running, safe to hide
        let hideScript = "tell application \"\(targetApp)\" to set visible to false"
        let result = try await ShellCommand.execute("/usr/bin/osascript", arguments: ["-e", hideScript])

        if result.exitCode == 0 {
            log("Successfully hid app using AppleScript")
            return CallTool.Result(content: [.text("Successfully hid '\(identifier)'.")])
        } else {
            throw MCPError.internalError("Failed to hide app: \(result.stderr)")
        }
    }
}

// MARK: - Input Validation

/// Validate app name format (basic security check)
/// Valid format: alphanumeric with spaces, hyphens, and underscores
func validateAppName(_ appName: String) throws {
    // Check for basic format
    let allowedCharacters = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: " -_"))
    guard appName.unicodeScalars.allSatisfy({ allowedCharacters.contains($0) }) else {
        throw MCPError.invalidParams("Invalid app name format: '\(appName)'. App name can only contain letters, numbers, spaces, hyphens, and underscores.")
    }

    // Check minimum length
    guard appName.count >= 1 && appName.count <= 255 else {
        throw MCPError.invalidParams("Invalid app name length: '\(appName)'. App name must be 1-255 characters.")
    }
}

// MARK: - ListAll App Name Normalization

/// Normalize ListAll app name variants to the canonical name
/// The macOS app is named "ListAll" (not "ListAllMac")
func normalizeListAllAppName(_ appName: String?) -> String? {
    guard let name = appName else { return nil }

    // Map common variants to the canonical name
    switch name.lowercased() {
    case "listallmac", "listall mac", "listall-mac":
        log("Normalized app name '\(name)' to 'ListAll'")
        return "ListAll"
    default:
        return name
    }
}

/// Normalize ListAll bundle ID variants to the canonical ID
/// The macOS app uses "io.github.chmc.ListAll" (same as iOS)
func normalizeListAllBundleID(_ bundleId: String?) -> String? {
    guard let id = bundleId else { return nil }

    // Map common variants to the canonical bundle ID
    switch id.lowercased() {
    case "io.github.chmc.listallmac":
        log("Normalized bundle ID '\(id)' to 'io.github.chmc.ListAll'")
        return "io.github.chmc.ListAll"
    default:
        return id
    }
}
