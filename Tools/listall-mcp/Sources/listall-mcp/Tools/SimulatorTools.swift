import Foundation
import MCP

// MARK: - Shell Execution Helper

/// Errors that can occur during shell command execution
enum ShellCommandError: LocalizedError {
    case timeout(seconds: TimeInterval, command: String)

    var errorDescription: String? {
        switch self {
        case .timeout(let seconds, let command):
            return """
                Command timed out after \(Int(seconds)) seconds.
                Command: \(command)
                The simulator may be unresponsive. Recovery steps:
                1. Run listall_screenshot to check simulator state
                2. Run listall_shutdown_simulator(udid: "all") to stop simulators
                3. Run listall_boot_simulator to restart
                4. Retry the operation
                """
        }
    }
}

/// Thread-safe state for process execution with timeout
private final class ProcessExecutionState: @unchecked Sendable {
    private let lock = NSLock()
    private var _didResume = false
    private var _timeoutWork: DispatchWorkItem?

    var didResume: Bool {
        lock.lock()
        defer { lock.unlock() }
        return _didResume
    }

    func setResumed() -> Bool {
        lock.lock()
        defer { lock.unlock() }
        if _didResume { return false }
        _didResume = true
        return true
    }

    func setTimeoutWork(_ work: DispatchWorkItem) {
        lock.lock()
        defer { lock.unlock() }
        _timeoutWork = work
    }

    func cancelTimeoutWork() {
        lock.lock()
        defer { lock.unlock() }
        _timeoutWork?.cancel()
    }
}

/// Shell command execution utilities
enum ShellCommand {
    /// Default timeout for XCUITest operations (allows for first-run compile time)
    static let defaultXCUITestTimeout: TimeInterval = 90.0

    /// Default timeout for simctl operations
    static let defaultSimctlTimeout: TimeInterval = 30.0

    /// Execute a shell command with timeout and return the output
    /// - Parameters:
    ///   - command: The command to execute
    ///   - arguments: Command arguments
    ///   - timeout: Timeout in seconds (default: 120)
    /// - Returns: Tuple of (stdout, stderr, exit code)
    static func execute(
        _ command: String,
        arguments: [String] = [],
        timeout: TimeInterval = 120.0
    ) async throws -> (stdout: String, stderr: String, exitCode: Int32) {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: command)
        process.arguments = arguments
        process.environment = ProcessInfo.processInfo.environment

        let stdoutPipe = Pipe()
        let stderrPipe = Pipe()
        process.standardOutput = stdoutPipe
        process.standardError = stderrPipe

        let state = ProcessExecutionState()
        let commandStr = ([command] + arguments).joined(separator: " ")

        return try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { continuation in

                // Timeout watchdog
                let timeoutWork = DispatchWorkItem { [state] in
                    guard state.setResumed() else { return }

                    if process.isRunning {
                        log("ShellCommand: Timeout after \(timeout)s, terminating process...")
                        process.terminate()  // SIGTERM first

                        // Wait briefly, then force kill if still running
                        Thread.sleep(forTimeInterval: 2.0)
                        if process.isRunning {
                            log("ShellCommand: Process still running, sending SIGKILL...")
                            kill(process.processIdentifier, SIGKILL)
                        }
                        // CRITICAL: Reap zombie process
                        process.waitUntilExit()
                    }

                    continuation.resume(throwing: ShellCommandError.timeout(seconds: timeout, command: commandStr))
                }
                state.setTimeoutWork(timeoutWork)

                process.terminationHandler = { [state] terminatedProcess in
                    state.cancelTimeoutWork()
                    guard state.setResumed() else { return }

                    let stdoutData = stdoutPipe.fileHandleForReading.readDataToEndOfFile()
                    let stderrData = stderrPipe.fileHandleForReading.readDataToEndOfFile()

                    let stdout = String(data: stdoutData, encoding: .utf8) ?? ""
                    let stderr = String(data: stderrData, encoding: .utf8) ?? ""

                    continuation.resume(returning: (stdout, stderr, terminatedProcess.terminationStatus))
                }

                DispatchQueue.global().asyncAfter(deadline: .now() + timeout, execute: timeoutWork)

                do {
                    try process.run()
                } catch {
                    state.cancelTimeoutWork()
                    guard state.setResumed() else { return }
                    continuation.resume(throwing: error)
                }
            }
        } onCancel: {
            if process.isRunning {
                log("ShellCommand: Task cancelled, terminating process...")
                process.terminate()
            }
        }
    }

    /// Execute xcrun with simctl subcommand
    static func simctl(_ arguments: [String]) async throws -> (stdout: String, stderr: String, exitCode: Int32) {
        try await execute("/usr/bin/xcrun", arguments: ["simctl"] + arguments, timeout: defaultSimctlTimeout)
    }
}

// MARK: - Input Validation

/// Validate simulator UDID format to prevent command injection
/// Valid formats: "all", "booted", or UUID (8-4-4-4-12 hex format)
func validateUDID(_ udid: String) throws {
    // Special keywords
    if udid == "all" || udid == "booted" {
        return
    }

    // UUID format validation
    guard UUID(uuidString: udid) != nil else {
        throw MCPError.invalidParams("Invalid UDID format: '\(udid)'. Must be 'all', 'booted', or a valid UUID.")
    }
}

/// Validate bundle ID format
/// Valid format: reverse domain notation (e.g., "com.example.app")
func validateBundleID(_ bundleID: String) throws {
    // Must contain at least one dot
    guard bundleID.contains(".") else {
        throw MCPError.invalidParams("Invalid bundle ID format: '\(bundleID)'. Must be in reverse domain notation (e.g., 'com.example.app').")
    }

    // No spaces allowed
    guard !bundleID.contains(" ") else {
        throw MCPError.invalidParams("Invalid bundle ID format: '\(bundleID)'. Bundle ID cannot contain spaces.")
    }
}

// MARK: - Simulator Device Models

/// Represents a simulator device from simctl list output
struct SimulatorDevice: Codable {
    let dataPath: String?
    let dataPathSize: Int?
    let logPath: String?
    let udid: String
    let isAvailable: Bool
    let deviceTypeIdentifier: String?
    let state: String
    let name: String
    let lastBootedAt: String?

    /// Determine device type from device type identifier
    var deviceType: String {
        guard let identifier = deviceTypeIdentifier else { return "Unknown" }
        if identifier.contains("iPhone") { return "iPhone" }
        if identifier.contains("iPad") { return "iPad" }
        if identifier.contains("Watch") { return "Apple Watch" }
        if identifier.contains("TV") { return "Apple TV" }
        if identifier.contains("Vision") { return "Apple Vision" }
        return "Unknown"
    }
}

/// Response from simctl list devices -j
struct SimctlDevicesResponse: Codable {
    let devices: [String: [SimulatorDevice]]
}

/// Simplified device info for MCP response
struct DeviceInfo: Codable {
    let name: String
    let udid: String
    let state: String
    let deviceType: String
    let runtime: String
    let isAvailable: Bool
}

// MARK: - Simulator Tools

/// Namespace for simulator tool definitions and handlers
enum SimulatorTools {
    // MARK: - Tool Definitions

    /// Tool definition for listall_list_simulators
    static var listSimulatorsTool: Tool {
        Tool(
            name: "listall_list_simulators",
            description: """
                List all available iOS, iPadOS, and watchOS simulators.
                Returns structured JSON with device info including name, UDID, state (Booted/Shutdown), and device type.
                Use this to find simulator UDIDs for other simulator commands.
                """,
            inputSchema: .object([
                "type": .string("object"),
                "properties": .object([
                    "device_type": .object([
                        "type": .string("string"),
                        "description": .string("Filter by device type: 'iPhone', 'iPad', 'Watch', or 'all' (default: 'all')"),
                        "enum": .array([.string("iPhone"), .string("iPad"), .string("Watch"), .string("all")])
                    ]),
                    "state": .object([
                        "type": .string("string"),
                        "description": .string("Filter by state: 'Booted', 'Shutdown', or 'all' (default: 'all')"),
                        "enum": .array([.string("Booted"), .string("Shutdown"), .string("all")])
                    ])
                ]),
                "required": .array([])
            ])
        )
    }

    /// Tool definition for listall_boot_simulator
    static var bootSimulatorTool: Tool {
        Tool(
            name: "listall_boot_simulator",
            description: """
                Boot a simulator by UDID. The simulator will start in the background.
                Use listall_list_simulators first to get available UDIDs.
                Returns success message or error if simulator cannot be booted.
                """,
            inputSchema: .object([
                "type": .string("object"),
                "properties": .object([
                    "udid": .object([
                        "type": .string("string"),
                        "description": .string("The UDID of the simulator to boot (get from listall_list_simulators)")
                    ])
                ]),
                "required": .array([.string("udid")])
            ])
        )
    }

    /// Tool definition for listall_shutdown_simulator
    static var shutdownSimulatorTool: Tool {
        Tool(
            name: "listall_shutdown_simulator",
            description: """
                Shutdown a running simulator by UDID, or shutdown all simulators.
                Use 'all' as UDID to shutdown all running simulators.
                """,
            inputSchema: .object([
                "type": .string("object"),
                "properties": .object([
                    "udid": .object([
                        "type": .string("string"),
                        "description": .string("The UDID of the simulator to shutdown, or 'all' to shutdown all simulators")
                    ])
                ]),
                "required": .array([.string("udid")])
            ])
        )
    }

    /// Tool definition for listall_launch
    static var launchTool: Tool {
        Tool(
            name: "listall_launch",
            description: """
                Launch an app in a simulator. Optionally installs the app first if app_path is provided.
                The simulator must be booted first (use listall_boot_simulator).
                For ListAll app, the bundle_id is 'io.github.chmc.ListAll'.
                Use launch_args to pass arguments like 'UITEST_MODE' to populate test data.
                """,
            inputSchema: .object([
                "type": .string("object"),
                "properties": .object([
                    "udid": .object([
                        "type": .string("string"),
                        "description": .string("The UDID of the simulator (use 'booted' for any booted simulator)")
                    ]),
                    "bundle_id": .object([
                        "type": .string("string"),
                        "description": .string("The bundle identifier of the app to launch (e.g., 'io.github.chmc.ListAll')")
                    ]),
                    "app_path": .object([
                        "type": .string("string"),
                        "description": .string("Optional: Path to the .app bundle to install before launching")
                    ]),
                    "launch_args": .object([
                        "type": .string("array"),
                        "items": .object(["type": .string("string")]),
                        "description": .string("Optional: Launch arguments to pass to the app (e.g., ['UITEST_MODE', 'DISABLE_TOOLTIPS'])")
                    ])
                ]),
                "required": .array([.string("udid"), .string("bundle_id")])
            ])
        )
    }

    /// Tool definition for listall_screenshot
    static var screenshotTool: Tool {
        Tool(
            name: "listall_screenshot",
            description: """
                Take a screenshot of a simulator and return it as base64-encoded PNG.
                The simulator must be booted first.
                Screenshots are saved to .listall-mcp/YYMMDD-HHMMSS-{context}/ for history.
                Returns the screenshot as an embedded image that Claude can see and analyze.
                """,
            inputSchema: .object([
                "type": .string("object"),
                "properties": .object([
                    "udid": .object([
                        "type": .string("string"),
                        "description": .string("The UDID of the simulator (use 'booted' for any booted simulator)")
                    ]),
                    "context": .object([
                        "type": .string("string"),
                        "description": .string("Optional context for screenshot folder name (e.g., 'button-component', 'before-fix')")
                    ])
                ]),
                "required": .array([.string("udid")])
            ])
        )
    }

    // MARK: - Tool Collection

    /// All simulator tools
    static var allTools: [Tool] {
        [
            listSimulatorsTool,
            bootSimulatorTool,
            shutdownSimulatorTool,
            launchTool,
            screenshotTool
        ]
    }

    /// Check if a tool name is a simulator tool
    static func isSimulatorTool(_ name: String) -> Bool {
        allTools.contains { $0.name == name }
    }

    // MARK: - Tool Handlers

    /// Route a tool call to the appropriate handler
    static func handleToolCall(name: String, arguments: [String: Value]?) async throws -> CallTool.Result {
        switch name {
        case "listall_list_simulators":
            return try await handleListSimulators(arguments: arguments)
        case "listall_boot_simulator":
            return try await handleBootSimulator(arguments: arguments)
        case "listall_shutdown_simulator":
            return try await handleShutdownSimulator(arguments: arguments)
        case "listall_launch":
            return try await handleLaunch(arguments: arguments)
        case "listall_screenshot":
            return try await handleScreenshot(arguments: arguments)
        default:
            throw MCPError.invalidParams("Unknown simulator tool: \(name)")
        }
    }

    /// Handle listall_list_simulators tool call
    static func handleListSimulators(arguments: [String: Value]?) async throws -> CallTool.Result {
        log("listall_list_simulators called")

        let deviceTypeFilter = arguments?["device_type"].flatMap { value -> String? in
            if case .string(let str) = value { return str }
            return nil
        } ?? "all"

        let stateFilter = arguments?["state"].flatMap { value -> String? in
            if case .string(let str) = value { return str }
            return nil
        } ?? "all"

        log("Filters - deviceType: \(deviceTypeFilter), state: \(stateFilter)")

        // Execute simctl list devices -j
        let result = try await ShellCommand.simctl(["list", "devices", "-j"])

        guard result.exitCode == 0 else {
            log("simctl list devices failed: \(result.stderr)")
            throw MCPError.internalError("Failed to list simulators: \(result.stderr)")
        }

        // Parse JSON response
        guard let jsonData = result.stdout.data(using: .utf8) else {
            throw MCPError.internalError("Failed to parse simctl output as UTF-8")
        }

        let decoder = JSONDecoder()
        let response = try decoder.decode(SimctlDevicesResponse.self, from: jsonData)

        // Transform to simplified device list
        var devices: [DeviceInfo] = []

        for (runtime, deviceList) in response.devices {
            // Extract runtime name from key like "com.apple.CoreSimulator.SimRuntime.iOS-18-2"
            let runtimeName = runtime
                .replacingOccurrences(of: "com.apple.CoreSimulator.SimRuntime.", with: "")
                .replacingOccurrences(of: "-", with: ".")

            for device in deviceList where device.isAvailable {
                // Apply device type filter
                if deviceTypeFilter != "all" {
                    let matchesFilter: Bool
                    switch deviceTypeFilter {
                    case "iPhone": matchesFilter = device.deviceType == "iPhone"
                    case "iPad": matchesFilter = device.deviceType == "iPad"
                    case "Watch": matchesFilter = device.deviceType == "Apple Watch"
                    default: matchesFilter = true
                    }
                    if !matchesFilter { continue }
                }

                // Apply state filter
                if stateFilter != "all" && device.state != stateFilter {
                    continue
                }

                devices.append(DeviceInfo(
                    name: device.name,
                    udid: device.udid,
                    state: device.state,
                    deviceType: device.deviceType,
                    runtime: runtimeName,
                    isAvailable: device.isAvailable
                ))
            }
        }

        // Sort by device type, then by name
        devices.sort { ($0.deviceType, $0.name) < ($1.deviceType, $1.name) }

        log("Found \(devices.count) simulators matching filters")

        // Format as JSON for response
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let jsonOutput = try encoder.encode(devices)
        let jsonString = String(data: jsonOutput, encoding: .utf8) ?? "[]"

        return CallTool.Result(content: [
            .text("Found \(devices.count) simulators:\n\n\(jsonString)")
        ])
    }

    /// Handle listall_boot_simulator tool call
    static func handleBootSimulator(arguments: [String: Value]?) async throws -> CallTool.Result {
        log("listall_boot_simulator called")

        guard let args = arguments,
              case .string(let udid) = args["udid"] else {
            throw MCPError.invalidParams("Missing required parameter: udid")
        }

        // Validate UDID format (security: prevent command injection)
        try validateUDID(udid)

        log("Booting simulator: \(udid)")

        let result = try await ShellCommand.simctl(["boot", udid])

        if result.exitCode == 0 {
            log("Simulator booted successfully")
            return CallTool.Result(content: [
                .text("Simulator \(udid) booted successfully. It may take a few seconds to fully start.")
            ])
        } else if result.stderr.contains("Unable to boot device in current state: Booted") {
            log("Simulator already booted")
            return CallTool.Result(content: [
                .text("Simulator \(udid) is already booted.")
            ])
        } else {
            log("Failed to boot simulator: \(result.stderr)")
            throw MCPError.internalError("Failed to boot simulator: \(result.stderr)")
        }
    }

    /// Handle listall_shutdown_simulator tool call
    static func handleShutdownSimulator(arguments: [String: Value]?) async throws -> CallTool.Result {
        log("listall_shutdown_simulator called")

        guard let args = arguments,
              case .string(let udid) = args["udid"] else {
            throw MCPError.invalidParams("Missing required parameter: udid")
        }

        // Validate UDID format (security: prevent command injection)
        try validateUDID(udid)

        log("Shutting down simulator: \(udid)")

        let result = try await ShellCommand.simctl(["shutdown", udid])

        if result.exitCode == 0 {
            log("Simulator shutdown successfully")
            let message = udid == "all"
                ? "All simulators have been shut down."
                : "Simulator \(udid) shut down successfully."
            return CallTool.Result(content: [.text(message)])
        } else if result.stderr.contains("Unable to shutdown device in current state: Shutdown") {
            log("Simulator already shutdown")
            return CallTool.Result(content: [
                .text("Simulator \(udid) is already shut down.")
            ])
        } else {
            log("Failed to shutdown simulator: \(result.stderr)")
            throw MCPError.internalError("Failed to shutdown simulator: \(result.stderr)")
        }
    }

    /// Handle listall_launch tool call
    static func handleLaunch(arguments: [String: Value]?) async throws -> CallTool.Result {
        log("listall_launch called")

        guard let args = arguments,
              case .string(let udid) = args["udid"],
              case .string(let bundleId) = args["bundle_id"] else {
            throw MCPError.invalidParams("Missing required parameters: udid and bundle_id")
        }

        // Validate inputs (security: prevent command injection)
        try validateUDID(udid)
        try validateBundleID(bundleId)

        // Optional app_path for installation
        let appPath = args["app_path"].flatMap { value -> String? in
            if case .string(let str) = value { return str }
            return nil
        }

        // Optional launch arguments
        var launchArgs: [String] = []
        if case .array(let argsArray) = args["launch_args"] {
            for arg in argsArray {
                if case .string(let str) = arg {
                    // Validate launch argument (alphanumeric and underscore only)
                    let allowedChars = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "_"))
                    if str.unicodeScalars.allSatisfy({ allowedChars.contains($0) }) {
                        launchArgs.append(str)
                    } else {
                        log("Skipping invalid launch argument: \(str)")
                    }
                }
            }
        }

        log("Launching app \(bundleId) on simulator \(udid)")
        if !launchArgs.isEmpty {
            log("With launch arguments: \(launchArgs)")
        }

        // Install app if path provided
        if let path = appPath {
            log("Installing app from: \(path)")
            let installResult = try await ShellCommand.simctl(["install", udid, path])
            if installResult.exitCode != 0 {
                log("Failed to install app: \(installResult.stderr)")
                throw MCPError.internalError("Failed to install app: \(installResult.stderr)")
            }
            log("App installed successfully")
        }

        // Always terminate first to ensure fresh UITEST_MODE initialization
        // This handles the case where app is already running and wouldn't reinitialize test data
        log("Terminating any existing instance of \(bundleId)...")
        _ = try? await ShellCommand.simctl(["terminate", udid, bundleId])

        // Brief delay for cleanup
        try? await Task.sleep(nanoseconds: 200_000_000) // 200ms

        // Launch the app with optional arguments
        var launchCommand = ["launch", udid, bundleId]
        launchCommand.append(contentsOf: launchArgs)

        let launchResult = try await ShellCommand.simctl(launchCommand)

        if launchResult.exitCode == 0 {
            log("App launched successfully")
            var message = "App \(bundleId) launched successfully on simulator."
            if appPath != nil {
                message = "App installed and launched successfully on simulator."
            }
            if !launchArgs.isEmpty {
                message += " Launch args: \(launchArgs.joined(separator: ", "))"
            }
            return CallTool.Result(content: [.text(message)])
        } else {
            log("Failed to launch app: \(launchResult.stderr)")
            throw MCPError.internalError("Failed to launch app: \(launchResult.stderr)")
        }
    }

    /// Handle listall_screenshot tool call
    static func handleScreenshot(arguments: [String: Value]?) async throws -> CallTool.Result {
        log("listall_screenshot called")

        guard let args = arguments,
              case .string(let udid) = args["udid"] else {
            throw MCPError.invalidParams("Missing required parameter: udid")
        }

        // Validate UDID format (security: prevent command injection)
        try validateUDID(udid)

        // Extract optional context
        let context = args["context"].flatMap { value -> String? in
            if case .string(let str) = value { return str }
            return nil
        }

        log("Taking screenshot of simulator: \(udid)")

        // Create temp file for screenshot capture
        let tempDir = FileManager.default.temporaryDirectory
        let tempPath = tempDir.appendingPathComponent("listall_screenshot_\(UUID().uuidString).png")

        defer {
            // Clean up temp file
            try? FileManager.default.removeItem(at: tempPath)
        }

        // Take screenshot
        let result = try await ShellCommand.simctl(["io", udid, "screenshot", tempPath.path])

        guard result.exitCode == 0 else {
            log("Failed to take screenshot: \(result.stderr)")

            // Provide helpful error messages
            if result.stderr.contains("No devices are booted") {
                throw MCPError.internalError("No simulators are booted. Use listall_boot_simulator first to boot a simulator.")
            }
            throw MCPError.internalError("Failed to take screenshot: \(result.stderr)")
        }

        // Read screenshot data
        guard let rawImageData = FileManager.default.contents(atPath: tempPath.path) else {
            throw MCPError.internalError("Failed to read screenshot file")
        }

        // Resize image if needed to stay under Claude API limits (2000px)
        let imageData = ScreenshotStorage.resizeImageIfNeeded(rawImageData)

        // Determine platform from UDID (get device info)
        var platform = "iphone"  // Default to iPhone (not generic "ios")

        // Resolve "booted" to actual UDID first
        var resolvedUdid = udid
        if udid == "booted" {
            let bootedResult = try? await ShellCommand.simctl(["list", "devices", "booted", "-j"])
            if let stdout = bootedResult?.stdout,
               let jsonData = stdout.data(using: .utf8),
               let json = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any],
               let devices = json["devices"] as? [String: [[String: Any]]] {
                // Get first booted device UDID
                for (_, deviceList) in devices {
                    if let firstDevice = deviceList.first,
                       let deviceUdid = firstDevice["udid"] as? String {
                        resolvedUdid = deviceUdid
                        break
                    }
                }
            }
        }

        // Now determine platform from resolved UDID
        let listResult = try? await ShellCommand.simctl(["list", "devices", "-j"])
        if let stdout = listResult?.stdout,
           let jsonData = stdout.data(using: .utf8),
           let json = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any],
           let devices = json["devices"] as? [String: [[String: Any]]] {
            // Find which runtime contains this UDID
            for (runtime, deviceList) in devices {
                if let device = deviceList.first(where: { ($0["udid"] as? String) == resolvedUdid }) {
                    if runtime.contains("watchOS") {
                        platform = "watch"
                    } else if runtime.contains("tvOS") {
                        platform = "tvos"
                    } else if runtime.contains("iOS") {
                        // Differentiate iPhone vs iPad by device name
                        if let deviceName = device["name"] as? String,
                           deviceName.lowercased().contains("ipad") {
                            platform = "ipad"
                        }
                        // else: stays "iphone" (default)
                    }
                    break
                }
            }
        }

        // Save screenshot to project folder (DO NOT delete - history is valuable)
        let savedPath = try ScreenshotStorage.saveScreenshot(
            imageData: imageData,
            context: context,
            platform: platform
        )

        let base64Image = imageData.base64EncodedString()

        log("Screenshot taken successfully (\(imageData.count) bytes), saved to: \(savedPath)")

        return CallTool.Result(content: [
            .text("Screenshot saved to: \(savedPath)"),
            .image(data: base64Image, mimeType: "image/png", metadata: nil)
        ])
    }
}
