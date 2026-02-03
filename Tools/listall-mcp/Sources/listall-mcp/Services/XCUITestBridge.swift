import Foundation

// MARK: - XCUITest Bridge

/// Service that bridges MCP server commands to XCUITest execution via xcodebuild.
///
/// Architecture:
/// 1. MCP server writes command JSON to /tmp/listall_mcp_command.json
/// 2. This bridge invokes xcodebuild test-without-building for MCPCommandRunner
/// 3. XCUITest reads command, executes action, writes result to /tmp/listall_mcp_result.json
/// 4. This bridge reads the result and returns to MCP server
///
/// Concurrency:
/// - Uses serial execution queue to prevent race conditions on shared temp files
/// - Each command waits for previous commands to complete before executing
///
/// Performance: ~5-15 seconds per interaction (acceptable for verification loop)
/// watchOS Performance: ~10-30 seconds per interaction (slower simulator)
enum XCUITestBridge {
    // MARK: - Simulator Platform

    /// Platform types for simulators
    enum SimulatorPlatform {
        case iOS
        case watchOS
        case unknown

        /// xcodebuild destination platform string
        var destination: String {
            switch self {
            case .iOS, .unknown: return "iOS Simulator"
            case .watchOS: return "watchOS Simulator"
            }
        }

        /// xctestrun file platform pattern
        var xctestrunPattern: String {
            switch self {
            case .iOS, .unknown: return "iphonesimulator"
            case .watchOS: return "watchsimulator"
            }
        }

        /// Test target path for MCPCommandRunner
        var testTarget: String {
            switch self {
            case .iOS, .unknown: return "ListAllUITests/MCPCommandRunner/testRunMCPCommand"
            case .watchOS: return "ListAllWatch Watch AppUITests/MCPCommandRunner/testRunMCPCommand"
            }
        }

        /// Scheme name for building
        var schemeName: String {
            switch self {
            case .iOS, .unknown: return "ListAll"
            case .watchOS: return "ListAllWatch Watch App"
            }
        }
    }

    // MARK: - Constants

    private static let commandPath = "/tmp/listall_mcp_command.json"
    private static let resultPath = "/tmp/listall_mcp_result.json"
    private static let xcodebuildPath = "/usr/bin/xcodebuild"
    private static let xcrunPath = "/usr/bin/xcrun"

    /// Serial queue for XCUITest command execution
    /// Prevents race conditions on shared temp files without IPC protocol changes
    private static let executionQueue = DispatchQueue(label: "io.listall.xcuitest.bridge")

    // MARK: - Command Models

    /// Command to send to XCUITest
    struct Command: Encodable {
        let action: String
        let identifier: String?
        let label: String?
        let text: String?
        let direction: String?
        let bundleId: String
        let timeout: TimeInterval?
        let clearFirst: Bool?
        let queryRole: String?
        let queryDepth: Int?
    }

    /// Result from XCUITest
    struct Result: Decodable {
        let success: Bool
        let message: String
        let elements: [[String: String]]?
        let error: String?
        // Enhanced feedback fields
        let elementType: String?
        let elementFrame: String?
        let usedCoordinateFallback: Bool?
        let hint: String?
    }

    // MARK: - Public API

    /// Execute a click action on a simulator
    /// - Parameters:
    ///   - simulatorUDID: UDID of the target simulator
    ///   - bundleId: Bundle ID of the target app
    ///   - identifier: Accessibility identifier of the element
    ///   - label: Optional label to find element by
    ///   - projectPath: Path to the Xcode project
    /// - Returns: Result from XCUITest
    static func click(
        simulatorUDID: String,
        bundleId: String,
        identifier: String?,
        label: String?,
        projectPath: String
    ) async throws -> Result {
        let command = Command(
            action: "click",
            identifier: identifier,
            label: label,
            text: nil,
            direction: nil,
            bundleId: bundleId,
            timeout: 10,
            clearFirst: nil,
            queryRole: nil,
            queryDepth: nil
        )
        return try await executeCommand(command, simulatorUDID: simulatorUDID, projectPath: projectPath)
    }

    /// Execute a type action on a simulator
    /// - Parameters:
    ///   - simulatorUDID: UDID of the target simulator
    ///   - bundleId: Bundle ID of the target app
    ///   - text: Text to type
    ///   - identifier: Optional accessibility identifier of the element
    ///   - label: Optional label to find element by
    ///   - clearFirst: Whether to clear existing text first
    ///   - projectPath: Path to the Xcode project
    /// - Returns: Result from XCUITest
    static func type(
        simulatorUDID: String,
        bundleId: String,
        text: String,
        identifier: String?,
        label: String?,
        clearFirst: Bool,
        projectPath: String
    ) async throws -> Result {
        let command = Command(
            action: "type",
            identifier: identifier,
            label: label,
            text: text,
            direction: nil,
            bundleId: bundleId,
            timeout: 10,
            clearFirst: clearFirst,
            queryRole: nil,
            queryDepth: nil
        )
        return try await executeCommand(command, simulatorUDID: simulatorUDID, projectPath: projectPath)
    }

    /// Execute a swipe action on a simulator
    /// - Parameters:
    ///   - simulatorUDID: UDID of the target simulator
    ///   - bundleId: Bundle ID of the target app
    ///   - direction: Swipe direction (up, down, left, right)
    ///   - identifier: Optional accessibility identifier of the element
    ///   - label: Optional label to find element by
    ///   - projectPath: Path to the Xcode project
    /// - Returns: Result from XCUITest
    static func swipe(
        simulatorUDID: String,
        bundleId: String,
        direction: String,
        identifier: String?,
        label: String?,
        projectPath: String
    ) async throws -> Result {
        let command = Command(
            action: "swipe",
            identifier: identifier,
            label: label,
            text: nil,
            direction: direction,
            bundleId: bundleId,
            timeout: 10,
            clearFirst: nil,
            queryRole: nil,
            queryDepth: nil
        )
        return try await executeCommand(command, simulatorUDID: simulatorUDID, projectPath: projectPath)
    }

    /// Execute a query action on a simulator to list UI elements
    /// - Parameters:
    ///   - simulatorUDID: UDID of the target simulator
    ///   - bundleId: Bundle ID of the target app
    ///   - role: Optional role filter
    ///   - depth: Query depth (default 3)
    ///   - projectPath: Path to the Xcode project
    /// - Returns: Result from XCUITest with elements array
    static func query(
        simulatorUDID: String,
        bundleId: String,
        role: String?,
        depth: Int,
        projectPath: String
    ) async throws -> Result {
        let command = Command(
            action: "query",
            identifier: nil,
            label: nil,
            text: nil,
            direction: nil,
            bundleId: bundleId,
            timeout: 15,
            clearFirst: nil,
            queryRole: role,
            queryDepth: depth
        )
        return try await executeCommand(command, simulatorUDID: simulatorUDID, projectPath: projectPath)
    }

    // MARK: - Retry Logic

    /// Execute an async throwing operation with exponential backoff retry
    /// - Parameters:
    ///   - maxAttempts: Maximum number of attempts (default 3)
    ///   - operation: The async throwing operation to execute
    /// - Returns: The result of the operation
    /// - Throws: The last error if all attempts fail
    private static func executeWithRetry<T>(
        maxAttempts: Int = 3,
        operation: @escaping () async throws -> T
    ) async throws -> T {
        var lastError: Error?

        for attempt in 1...maxAttempts {
            do {
                return try await operation()
            } catch {
                lastError = error
                log("XCUITestBridge: Attempt \(attempt)/\(maxAttempts) failed: \(error.localizedDescription)")

                // Don't sleep after the last attempt
                if attempt < maxAttempts {
                    // Exponential backoff: 500ms, 1000ms, 2000ms
                    let delayMs = 500 * (1 << (attempt - 1))  // 500, 1000, 2000
                    log("XCUITestBridge: Retrying in \(delayMs)ms...")
                    try await Task.sleep(nanoseconds: UInt64(delayMs) * 1_000_000)
                }
            }
        }

        // All attempts failed, throw the last error
        throw lastError!
    }

    // MARK: - Internal

    /// Timeout for XCUITest operations (allows for first-run compile time)
    private static let xcuiTestTimeout: TimeInterval = 90.0

    /// Timeout for query operations (larger element trees)
    private static let queryTimeout: TimeInterval = 120.0

    /// Execute a command via XCUITest with serial queue protection and retry logic
    private static func executeCommand(
        _ command: Command,
        simulatorUDID: String,
        projectPath: String
    ) async throws -> Result {
        // Use retry logic with exponential backoff for transient failures
        try await executeWithRetry(maxAttempts: 3) {
            // Use serial queue to prevent race conditions on shared temp files
            try await withCheckedThrowingContinuation { continuation in
                executionQueue.async {
                    Task {
                        do {
                            let result = try await executeCommandInternal(
                                command,
                                simulatorUDID: simulatorUDID,
                                projectPath: projectPath
                            )
                            continuation.resume(returning: result)
                        } catch {
                            continuation.resume(throwing: error)
                        }
                    }
                }
            }
        }
    }

    /// Internal command execution (called within serial queue)
    private static func executeCommandInternal(
        _ command: Command,
        simulatorUDID: String,
        projectPath: String
    ) async throws -> Result {
        // Resolve "booted" to actual UDID - xcodebuild requires real UDID
        let resolvedUDID = try await resolveUDID(simulatorUDID)

        // Clean up any existing files from previous runs
        try? FileManager.default.removeItem(atPath: commandPath)
        try? FileManager.default.removeItem(atPath: resultPath)

        // Always cleanup on exit (even on error)
        defer {
            try? FileManager.default.removeItem(atPath: commandPath)
            try? FileManager.default.removeItem(atPath: resultPath)
        }

        // Write command to file
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted]
        let commandData = try encoder.encode(command)
        try commandData.write(to: URL(fileURLWithPath: commandPath), options: .atomic)

        log("XCUITestBridge: Wrote command to \(commandPath)")
        log("XCUITestBridge: Command: \(command.action)")

        // Detect simulator platform (iOS vs watchOS)
        let platform = await detectPlatform(for: resolvedUDID)
        log("XCUITestBridge: Detected platform: \(platform)")

        // Determine timeout based on action type and platform
        // watchOS is significantly slower (~2x)
        let baseTimeout = command.action == "query" ? queryTimeout : xcuiTestTimeout
        let timeout = platform == .watchOS ? baseTimeout * 1.5 : baseTimeout

        // Run xcodebuild with catch-and-retry pattern for SDK mismatch (exit code 70)
        log("XCUITestBridge: Running xcodebuild (timeout: \(Int(timeout))s)")

        var result: (exitCode: Int32, stdout: String, stderr: String)
        let derivedDataPath = findDerivedDataPath(for: projectPath)

        do {
            // Try fast path with xctestrun if available
            if let xctestrunPath = findXCTestRun(in: derivedDataPath, platform: platform) {
                log("XCUITestBridge: Trying fast path with xctestrun: \(xctestrunPath)")
                result = try await runWithXCTestRun(
                    xctestrunPath: xctestrunPath,
                    simulatorUDID: resolvedUDID,
                    platform: platform,
                    timeout: timeout
                )

                // Exit 70 = SDK mismatch, need to rebuild with correct SDK
                if result.exitCode == 70 {
                    log("XCUITestBridge: Exit 70 detected (SDK mismatch)")

                    // Log SDK versions for diagnosis
                    if let xctestrunSDK = extractSDKVersion(from: xctestrunPath),
                       let simulatorSDK = await getSimulatorOSVersion(for: resolvedUDID) {
                        log("XCUITestBridge: xctestrun SDK: \(xctestrunSDK), simulator: \(simulatorSDK)")
                    }

                    // Clean stale DerivedData and rebuild
                    log("XCUITestBridge: Cleaning ListAll DerivedData for fresh build")
                    cleanListAllDerivedData(in: derivedDataPath)

                    log("XCUITestBridge: Running build-for-testing to regenerate xctestrun")
                    // Use 300s minimum - build-for-testing from scratch can take 3-5 minutes
                    let buildTimeout = max(300.0, timeout * 2)
                    let buildResult = try await buildForTesting(
                        projectPath: projectPath,
                        simulatorUDID: resolvedUDID,
                        platform: platform,
                        timeout: buildTimeout
                    )

                    if buildResult.exitCode != 0 {
                        log("XCUITestBridge: build-for-testing failed: \(buildResult.stderr.prefix(500))")
                        throw XCUITestBridgeError.testBuildFailed("build-for-testing failed with exit \(buildResult.exitCode)")
                    }

                    // Find newly generated xctestrun
                    guard let freshXctestrunPath = findXCTestRun(in: derivedDataPath, platform: platform) else {
                        throw XCUITestBridgeError.resultFileNotFound("build-for-testing did not generate xctestrun file")
                    }

                    log("XCUITestBridge: Retrying with fresh xctestrun: \(freshXctestrunPath)")
                    result = try await runWithXCTestRun(
                        xctestrunPath: freshXctestrunPath,
                        simulatorUDID: resolvedUDID,
                        platform: platform,
                        timeout: timeout
                    )
                }
            } else {
                // No xctestrun found - build it first, then use fast path
                log("XCUITestBridge: No xctestrun found, building test runner first")

                // Use 300s minimum - build-for-testing from scratch can take 3-5 minutes
                let buildTimeout = max(300.0, timeout * 2)
                let buildResult = try await buildForTesting(
                    projectPath: projectPath,
                    simulatorUDID: resolvedUDID,
                    platform: platform,
                    timeout: buildTimeout
                )

                if buildResult.exitCode != 0 {
                    log("XCUITestBridge: build-for-testing failed: \(buildResult.stderr.prefix(500))")
                    throw XCUITestBridgeError.testBuildFailed("build-for-testing failed with exit \(buildResult.exitCode)")
                }

                // Find the newly generated xctestrun
                guard let freshXctestrunPath = findXCTestRun(in: derivedDataPath, platform: platform) else {
                    throw XCUITestBridgeError.resultFileNotFound("build-for-testing did not generate xctestrun file")
                }

                log("XCUITestBridge: Using fresh xctestrun: \(freshXctestrunPath)")
                result = try await runWithXCTestRun(
                    xctestrunPath: freshXctestrunPath,
                    simulatorUDID: resolvedUDID,
                    platform: platform,
                    timeout: timeout
                )
            }
        } catch let error as ShellCommandError {
            // Convert shell timeout to XCUITest-specific error with recovery instructions
            if case .timeout = error {
                throw XCUITestBridgeError.operationTimedOut(action: command.action, timeout: timeout)
            }
            throw error
        }

        log("XCUITestBridge: xcodebuild exit code: \(result.exitCode)")

        if result.exitCode != 0 {
            // Log full output for debugging (increased from 500 to 2000 chars for better diagnosis)
            if !result.stderr.isEmpty {
                log("XCUITestBridge FULL stderr:\n\(result.stderr.prefix(2000))")
            }
            if !result.stdout.isEmpty {
                log("XCUITestBridge FULL stdout:\n\(result.stdout.prefix(2000))")
            }
        }

        // Read result from file
        guard FileManager.default.fileExists(atPath: resultPath) else {
            throw XCUITestBridgeError.resultFileNotFound(
                "XCUITest did not write result file. xcodebuild exit code: \(result.exitCode)"
            )
        }

        let resultData = try Data(contentsOf: URL(fileURLWithPath: resultPath))
        let testResult = try JSONDecoder().decode(Result.self, from: resultData)

        log("XCUITestBridge: Result - success: \(testResult.success), message: \(testResult.message)")

        return testResult
    }

    /// Run test using pre-built xctestrun file (fast path, ~8s)
    /// - Parameters:
    ///   - xctestrunPath: Path to the .xctestrun file
    ///   - simulatorUDID: Target simulator UDID
    ///   - platform: Simulator platform
    ///   - timeout: Execution timeout
    /// - Returns: Tuple with exit code, stdout, and stderr
    private static func runWithXCTestRun(
        xctestrunPath: String,
        simulatorUDID: String,
        platform: SimulatorPlatform,
        timeout: TimeInterval
    ) async throws -> (exitCode: Int32, stdout: String, stderr: String) {
        let arguments = [
            "test-without-building",
            "-xctestrun", xctestrunPath,
            "-destination", "platform=\(platform.destination),id=\(simulatorUDID)",
            "-only-testing:\(platform.testTarget)",
            "-parallel-testing-enabled", "NO",
            "-disable-concurrent-destination-testing"
        ]
        let result = try await ShellCommand.execute(xcodebuildPath, arguments: arguments, timeout: timeout)
        return (exitCode: result.exitCode, stdout: result.stdout, stderr: result.stderr)
    }

    /// Run full test with project build (slow path, ~90s+)
    /// - Parameters:
    ///   - projectPath: Path to the Xcode project
    ///   - simulatorUDID: Target simulator UDID
    ///   - platform: Simulator platform
    ///   - timeout: Execution timeout
    /// - Returns: Tuple with exit code, stdout, and stderr
    private static func runFullTest(
        projectPath: String,
        simulatorUDID: String,
        platform: SimulatorPlatform,
        timeout: TimeInterval
    ) async throws -> (exitCode: Int32, stdout: String, stderr: String) {
        let arguments = [
            "test",
            "-project", projectPath,
            "-scheme", platform.schemeName,
            "-destination", "platform=\(platform.destination),id=\(simulatorUDID)",
            "-only-testing:\(platform.testTarget)",
            "-parallel-testing-enabled", "NO"
        ]
        let result = try await ShellCommand.execute(xcodebuildPath, arguments: arguments, timeout: timeout)
        return (exitCode: result.exitCode, stdout: result.stdout, stderr: result.stderr)
    }

    /// Find the DerivedData path for a project
    private static func findDerivedDataPath(for projectPath: String) -> String {
        // Default DerivedData location
        let homeDir = FileManager.default.homeDirectoryForCurrentUser.path
        return "\(homeDir)/Library/Developer/Xcode/DerivedData"
    }

    /// Find the test bundle in DerivedData
    private static func findTestBundle(in derivedDataPath: String) -> String? {
        let fileManager = FileManager.default
        guard let contents = try? fileManager.contentsOfDirectory(atPath: derivedDataPath) else {
            return nil
        }

        // Look for ListAll-* directories
        for dir in contents where dir.hasPrefix("ListAll-") {
            let productsPath = "\(derivedDataPath)/\(dir)/Build/Products"
            guard let productContents = try? fileManager.contentsOfDirectory(atPath: productsPath) else {
                continue
            }

            // Look for Debug-iphonesimulator directory with our test bundle
            for productDir in productContents where productDir.contains("iphonesimulator") {
                let testBundlePath = "\(productsPath)/\(productDir)/ListAllUITests-Runner.app"
                if fileManager.fileExists(atPath: testBundlePath) {
                    return testBundlePath
                }
            }
        }

        return nil
    }

    /// Find the xctestrun file in DerivedData for a specific platform
    /// - Parameters:
    ///   - derivedDataPath: Path to DerivedData directory
    ///   - platform: Target platform (iOS, watchOS)
    /// - Returns: Path to xctestrun file, or nil if not found
    private static func findXCTestRun(in derivedDataPath: String, platform: SimulatorPlatform) -> String? {
        let fileManager = FileManager.default
        guard let contents = try? fileManager.contentsOfDirectory(atPath: derivedDataPath) else {
            return nil
        }

        let platformPattern = platform.xctestrunPattern

        // Look for ListAll-* directories
        for dir in contents where dir.hasPrefix("ListAll-") {
            let buildPath = "\(derivedDataPath)/\(dir)/Build/Products"
            guard let buildContents = try? fileManager.contentsOfDirectory(atPath: buildPath) else {
                continue
            }

            // Look for .xctestrun files matching the platform
            for file in buildContents where file.hasSuffix(".xctestrun") && file.contains(platformPattern) {
                return "\(buildPath)/\(file)"
            }
        }

        return nil
    }

    // MARK: - SDK Version Detection and Recovery

    /// Extract SDK version from xctestrun filename
    /// Example: "ListAll_iphonesimulator18.1-arm64.xctestrun" -> "18.1"
    private static func extractSDKVersion(from xctestrunPath: String) -> String? {
        let filename = (xctestrunPath as NSString).lastPathComponent
        let pattern = #"_(?:iphone|watch)simulator(\d+\.\d+)-"#
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(in: filename, range: NSRange(filename.startIndex..., in: filename)),
              let versionRange = Range(match.range(at: 1), in: filename) else {
            return nil
        }
        return String(filename[versionRange])
    }

    /// Get iOS/watchOS version for a simulator UDID
    private static func getSimulatorOSVersion(for udid: String) async -> String? {
        guard let result = try? await ShellCommand.simctl(["list", "devices", "-j"]) else {
            log("XCUITestBridge: Failed to execute simctl list devices")
            return nil
        }

        guard result.exitCode == 0 else {
            log("XCUITestBridge: simctl list devices failed with exit \(result.exitCode)")
            return nil
        }

        guard let data = result.stdout.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let devices = json["devices"] as? [String: [[String: Any]]] else {
            log("XCUITestBridge: Failed to parse simctl JSON output")
            return nil
        }

        let resolvedUDID = (try? await resolveUDID(udid)) ?? udid

        for (runtime, deviceList) in devices {
            if deviceList.contains(where: { ($0["udid"] as? String) == resolvedUDID }) {
                // Extract version from runtime like "com.apple.CoreSimulator.SimRuntime.iOS-18-2"
                let patterns = [#"iOS-(\d+)-(\d+)"#, #"watchOS-(\d+)-(\d+)"#]
                for pattern in patterns {
                    if let match = runtime.range(of: pattern, options: .regularExpression) {
                        return runtime[match]
                            .replacingOccurrences(of: "iOS-", with: "")
                            .replacingOccurrences(of: "watchOS-", with: "")
                            .replacingOccurrences(of: "-", with: ".")
                    }
                }
            }
        }
        log("XCUITestBridge: Could not find OS version for UDID \(resolvedUDID)")
        return nil
    }

    /// Clean ListAll DerivedData folders only
    private static func cleanListAllDerivedData(in derivedDataPath: String) {
        let fm = FileManager.default
        guard let contents = try? fm.contentsOfDirectory(atPath: derivedDataPath) else {
            log("XCUITestBridge: Cannot read DerivedData directory")
            return
        }

        for dir in contents where dir.hasPrefix("ListAll-") {
            let fullPath = "\(derivedDataPath)/\(dir)"
            log("XCUITestBridge: Cleaning DerivedData: \(fullPath)")
            do {
                try fm.removeItem(atPath: fullPath)
            } catch {
                log("XCUITestBridge: Failed to clean \(fullPath): \(error.localizedDescription)")
            }
        }
    }

    /// Build test target to generate fresh xctestrun
    private static func buildForTesting(
        projectPath: String,
        simulatorUDID: String,
        platform: SimulatorPlatform,
        timeout: TimeInterval
    ) async throws -> (exitCode: Int32, stdout: String, stderr: String) {
        let arguments = [
            "build-for-testing",
            "-project", projectPath,
            "-scheme", platform.schemeName,
            "-destination", "platform=\(platform.destination),id=\(simulatorUDID)",
            "-configuration", "Debug"
        ]
        let result = try await ShellCommand.execute(xcodebuildPath, arguments: arguments, timeout: timeout)
        return (exitCode: result.exitCode, stdout: result.stdout, stderr: result.stderr)
    }

    // MARK: - Simulator Device Type Detection

    /// Resolve "booted" UDID to an actual simulator UDID
    /// - Parameter udid: UDID string (may be "booted" or an actual UDID)
    /// - Returns: Resolved UDID (first booted simulator if "booted" was passed)
    static func resolveUDID(_ udid: String) async throws -> String {
        guard udid == "booted" else {
            return udid
        }

        let result = try await ShellCommand.simctl(["list", "devices", "-j"])

        guard result.exitCode == 0 else {
            throw XCUITestBridgeError.simulatorQueryFailed(result.stderr)
        }

        guard let data = result.stdout.data(using: .utf8) else {
            throw XCUITestBridgeError.invalidSimulatorData
        }

        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let devices = json["devices"] as? [String: [[String: Any]]] else {
            throw XCUITestBridgeError.invalidSimulatorData
        }

        // Find first booted simulator
        for (_, deviceList) in devices {
            for device in deviceList {
                if let state = device["state"] as? String,
                   state == "Booted",
                   let deviceUDID = device["udid"] as? String {
                    return deviceUDID
                }
            }
        }

        throw XCUITestBridgeError.simulatorQueryFailed("No booted simulator found")
    }

    /// Get the device type for a simulator UDID
    /// - Parameter udid: Simulator UDID (can be "booted" to auto-resolve)
    /// - Returns: Device type string (iPhone, iPad, Watch)
    static func getDeviceType(for udid: String) async throws -> String {
        // Resolve "booted" to actual UDID first
        let resolvedUDID = try await resolveUDID(udid)

        let result = try await ShellCommand.simctl(["list", "devices", "-j"])

        guard result.exitCode == 0 else {
            throw XCUITestBridgeError.simulatorQueryFailed(result.stderr)
        }

        guard let data = result.stdout.data(using: .utf8) else {
            throw XCUITestBridgeError.invalidSimulatorData
        }

        // Parse JSON to find device type
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let devices = json["devices"] as? [String: [[String: Any]]] else {
            throw XCUITestBridgeError.invalidSimulatorData
        }

        for (_, deviceList) in devices {
            for device in deviceList {
                if let deviceUDID = device["udid"] as? String, deviceUDID == resolvedUDID {
                    if let typeId = device["deviceTypeIdentifier"] as? String {
                        if typeId.contains("iPhone") { return "iPhone" }
                        if typeId.contains("iPad") { return "iPad" }
                        if typeId.contains("Watch") { return "Watch" }
                    }
                }
            }
        }

        return "Unknown"
    }

    /// Detect the simulator platform from a UDID
    /// - Parameter udid: Simulator UDID (can be "booted" to auto-resolve)
    /// - Returns: SimulatorPlatform enum value
    private static func detectPlatform(for udid: String) async -> SimulatorPlatform {
        do {
            let deviceType = try await getDeviceType(for: udid)
            switch deviceType {
            case "Watch":
                return .watchOS
            case "iPhone", "iPad":
                return .iOS
            default:
                return .unknown
            }
        } catch {
            log("XCUITestBridge: Failed to detect platform: \(error)")
            return .unknown
        }
    }

    /// Check if a UDID belongs to a simulator (vs macOS)
    /// - Parameter udid: Device identifier
    /// - Returns: True if it's a simulator UDID
    static func isSimulator(_ udid: String) -> Bool {
        // Simulator UDIDs are UUID format
        return UUID(uuidString: udid) != nil || udid == "booted"
    }
}

// MARK: - Errors

enum XCUITestBridgeError: LocalizedError {
    case resultFileNotFound(String)
    case simulatorQueryFailed(String)
    case invalidSimulatorData
    case testBuildFailed(String)
    case projectNotFound(String)
    case operationTimedOut(action: String, timeout: TimeInterval)

    var errorDescription: String? {
        switch self {
        case .resultFileNotFound(let details):
            return "XCUITest result file not found. \(details)"
        case .simulatorQueryFailed(let stderr):
            return "Failed to query simulators: \(stderr)"
        case .invalidSimulatorData:
            return "Could not parse simulator device data"
        case .testBuildFailed(let details):
            return "Failed to build/run XCUITest: \(details)"
        case .projectNotFound(let path):
            return "Xcode project not found at: \(path)"
        case .operationTimedOut(let action, let timeout):
            return """
                XCUITest '\(action)' timed out after \(Int(timeout))s.
                The simulator may be unresponsive. Recovery steps:
                1. Run listall_screenshot to check simulator state
                2. Run listall_shutdown_simulator(udid: "all") to stop simulators
                3. Run listall_boot_simulator to restart
                4. Retry the operation
                """
        }
    }
}
