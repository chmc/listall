import Foundation
import MCP

// MARK: - Diagnostics Tool

/// Comprehensive diagnostics tool for checking MCP server setup and requirements
enum DiagnosticsTool {
    // MARK: - Tool Definition

    /// Tool definition for listall_diagnostics
    static var diagnosticsTool: Tool {
        Tool(
            name: "listall_diagnostics",
            description: """
                Run comprehensive diagnostics to check all requirements for the ListAll MCP server.

                Checks performed:
                - Screen Recording and Accessibility permissions
                - Available and booted simulators (iOS, iPadOS, watchOS)
                - ListAllMac app installation
                - ListAll iOS app bundle for simulators
                - XCUITest runner build status
                - Xcode and developer tools availability

                Returns actionable guidance for any issues found.
                Run this first if you're having trouble with other MCP tools.
                """,
            inputSchema: .object([
                "type": .string("object"),
                "properties": .object([:]),
                "required": .array([])
            ])
        )
    }

    // MARK: - Tool Collection

    /// All diagnostic tools
    static var allTools: [Tool] {
        [diagnosticsTool]
    }

    /// Check if a tool name is a diagnostic tool
    static func isDiagnosticTool(_ name: String) -> Bool {
        allTools.contains { $0.name == name }
    }

    // MARK: - Tool Handler

    /// Route a tool call to the appropriate handler
    static func handleToolCall(name: String, arguments: [String: Value]?) async throws -> CallTool.Result {
        switch name {
        case "listall_diagnostics":
            return try await handleDiagnostics(arguments: arguments)
        default:
            throw MCPError.invalidParams("Unknown diagnostic tool: \(name)")
        }
    }

    // MARK: - Diagnostics Handler

    /// Handle listall_diagnostics tool call
    static func handleDiagnostics(arguments: [String: Value]?) async throws -> CallTool.Result {
        log("listall_diagnostics called")

        var output = "=== ListAll MCP Visual Verification Diagnostics ===\n\n"
        var issueCount = 0

        // 1. Check Permissions
        let (permissionOutput, permissionIssues) = await checkPermissions()
        output += permissionOutput
        issueCount += permissionIssues

        // 2. Check Simulators
        let (simulatorOutput, simulatorIssues) = await checkSimulators()
        output += simulatorOutput
        issueCount += simulatorIssues

        // 3. Check App Bundles
        let (appBundleOutput, appBundleIssues) = await checkAppBundles()
        output += appBundleOutput
        issueCount += appBundleIssues

        // 4. Check Xcode/Tools
        let (xcodeOutput, xcodeIssues) = await checkXcodeTools()
        output += xcodeOutput
        issueCount += xcodeIssues

        // 5. watchOS Performance Guidance
        let watchOSGuidance = generateWatchOSPerformanceGuidance()
        output += watchOSGuidance

        // Overall Status
        output += "OVERALL STATUS: "
        if issueCount == 0 {
            output += "READY\n"
            output += "  All checks passed. The MCP server is ready for use.\n"
        } else {
            output += "ISSUES FOUND (\(issueCount) item\(issueCount == 1 ? "" : "s") need attention)\n"
            output += "  Review the issues above and follow the guidance to resolve them.\n"
        }

        log("Diagnostics completed: \(issueCount) issues found")

        return CallTool.Result(content: [.text(output)])
    }

    // MARK: - Permission Checks

    /// Check macOS permissions (Screen Recording and Accessibility)
    private static func checkPermissions() async -> (String, Int) {
        var output = "PERMISSIONS:\n"
        var issues = 0

        // Screen Recording
        let screenRecordingGranted = await PermissionService.hasScreenRecordingPermission()
        if screenRecordingGranted {
            output += "  Screen Recording: GRANTED\n"
        } else {
            output += "  Screen Recording: NOT GRANTED\n"
            output += "    -> Open System Settings > Privacy & Security > Screen Recording\n"
            output += "    -> Add Terminal (or the app running this MCP server)\n"
            output += "    -> Restart Terminal after granting permission\n"
            issues += 1
        }

        // Accessibility
        let accessibilityGranted = PermissionService.hasAccessibilityPermission()
        if accessibilityGranted {
            output += "  Accessibility: GRANTED\n"
        } else {
            output += "  Accessibility: NOT GRANTED\n"
            output += "    -> Open System Settings > Privacy & Security > Accessibility\n"
            output += "    -> Add Terminal (or the app running this MCP server)\n"
            output += "    -> Restart Terminal after granting permission\n"
            issues += 1
        }

        output += "\n"
        return (output, issues)
    }

    // MARK: - Simulator Checks

    /// Check simulator availability and status
    private static func checkSimulators() async -> (String, Int) {
        var output = "SIMULATORS:\n"
        var issues = 0

        do {
            // Execute simctl list devices -j
            let result = try await ShellCommand.simctl(["list", "devices", "-j"])

            guard result.exitCode == 0,
                  let jsonData = result.stdout.data(using: .utf8) else {
                output += "  Status: ERROR - Could not list simulators\n"
                output += "    -> Make sure Xcode Command Line Tools are installed\n"
                output += "    -> Run: xcode-select --install\n"
                output += "\n"
                return (output, 1)
            }

            // Parse JSON response
            let decoder = JSONDecoder()
            let response = try decoder.decode(SimctlDevicesResponse.self, from: jsonData)

            // Count devices by type and state
            var bootedCount = 0
            var iOSCount = 0
            var watchOSCount = 0
            var totalAvailable = 0
            var bootedDevices: [String] = []

            for (_, deviceList) in response.devices {
                for device in deviceList where device.isAvailable {
                    totalAvailable += 1

                    if device.deviceType == "iPhone" || device.deviceType == "iPad" {
                        iOSCount += 1
                    } else if device.deviceType == "Apple Watch" {
                        watchOSCount += 1
                    }

                    if device.state == "Booted" {
                        bootedCount += 1
                        bootedDevices.append(device.name)
                    }
                }
            }

            // Report status
            if bootedCount > 0 {
                output += "  Booted: \(bootedCount) (\(bootedDevices.joined(separator: ", ")))\n"
            } else {
                output += "  Booted: 0\n"
                output += "    -> No simulators are currently booted\n"
                output += "    -> Use listall_boot_simulator to boot a simulator\n"
                // Not counting as an issue since simulators can be booted on demand
            }

            output += "  Available: \(totalAvailable) devices\n"
            output += "  iOS/iPadOS: \(iOSCount) devices\n"
            output += "  watchOS: \(watchOSCount) devices\n"
            if watchOSCount > 0 {
                output += "    -> See WATCHOS PERFORMANCE GUIDANCE section below for tips\n"
            }

            if totalAvailable == 0 {
                output += "    -> No simulators available\n"
                output += "    -> Open Xcode > Settings > Platforms to download simulator runtimes\n"
                issues += 1
            } else if iOSCount == 0 {
                output += "    -> No iOS/iPadOS simulators available\n"
                output += "    -> Open Xcode > Settings > Platforms to download iOS simulators\n"
                issues += 1
            }

        } catch {
            output += "  Status: ERROR - \(error.localizedDescription)\n"
            output += "    -> Make sure Xcode is installed and command line tools are set up\n"
            issues += 1
        }

        output += "\n"
        return (output, issues)
    }

    // MARK: - App Bundle Checks

    /// Check for app bundles (ListAllMac, iOS app, XCUITest runner)
    private static func checkAppBundles() async -> (String, Int) {
        var output = "APP BUNDLES:\n"
        var issues = 0

        // Check ListAllMac app - look in multiple locations
        // The app product name is "ListAll.app" even though the scheme is "ListAllMac"
        let fm = FileManager.default
        var macAppFound: String? = nil

        // 1. Check /Applications for both names
        let appPaths = [
            "/Applications/ListAll.app",
            "/Applications/ListAllMac.app",
            "\(NSHomeDirectory())/Applications/ListAll.app",
            "\(NSHomeDirectory())/Applications/ListAllMac.app"
        ]

        for path in appPaths {
            if fm.fileExists(atPath: path) {
                macAppFound = path
                break
            }
        }

        // 2. Check project's local DerivedData
        if macAppFound == nil {
            let projectDerivedData = fm.currentDirectoryPath + "/ListAll/DerivedData/Build/Products/Debug/ListAll.app"
            if fm.fileExists(atPath: projectDerivedData) {
                macAppFound = projectDerivedData
            }
        }

        // 3. Check global DerivedData for macOS builds
        if macAppFound == nil {
            macAppFound = await findMacOSAppBundle(in: "\(NSHomeDirectory())/Library/Developer/Xcode/DerivedData")
        }

        // 4. Check if app is currently running (can still screenshot it)
        var appRunning = false
        if macAppFound == nil {
            do {
                let result = try await ShellCommand.execute("/usr/bin/pgrep", arguments: ["-x", "ListAll"])
                appRunning = result.exitCode == 0
            } catch {
                // Ignore errors
            }
        }

        if let path = macAppFound {
            output += "  ListAllMac: FOUND at \(path)\n"
        } else if appRunning {
            output += "  ListAllMac: RUNNING (available for screenshots)\n"
        } else {
            output += "  ListAllMac: NOT FOUND\n"
            output += "    -> Build from Xcode: open ListAll.xcodeproj, select ListAllMac scheme\n"
            output += "    -> Or run: xcodebuild -project ListAll/ListAll.xcodeproj -scheme ListAllMac -configuration Debug build\n"
            // Not counting as critical issue - macOS testing is optional
        }

        // Check for iOS app build (in DerivedData or project build folder)
        let derivedDataPath = "\(NSHomeDirectory())/Library/Developer/Xcode/DerivedData"
        let iOSAppFound = await findIOSAppBundle(in: derivedDataPath)
        if let appPath = iOSAppFound {
            output += "  ListAll iOS: FOUND at \(appPath)\n"
        } else {
            output += "  ListAll iOS: NOT BUILT\n"
            output += "    -> Build iOS target in Xcode: xcodebuild -scheme ListAll -sdk iphonesimulator\n"
            // Not counting as critical issue - can be built on demand
        }

        // Check for watchOS app build
        let watchAppFound = await findWatchAppBundle(in: derivedDataPath)
        if let (appPath, bundleId) = watchAppFound {
            output += "  ListAll watchOS: FOUND (bundle: \(bundleId))\n"
            output += "    -> Path: \(appPath)\n"
        } else {
            output += "  ListAll watchOS: NOT BUILT\n"
            output += "    -> Build watch target: xcodebuild -scheme 'ListAllWatch Watch App' -sdk watchsimulator\n"
            // Not counting as critical issue - can be built on demand
        }

        // Check for iOS XCUITest runner
        let xcuiTestRunnerFound = await findXCUITestRunner(in: derivedDataPath)
        if let runnerPath = xcuiTestRunnerFound {
            output += "  XCUITest Runner (iOS): FOUND at \(runnerPath)\n"
        } else {
            output += "  XCUITest Runner (iOS): NOT BUILT\n"
            output += "    -> Build for testing: xcodebuild build-for-testing -scheme ListAll -sdk iphonesimulator\n"
            issues += 1 // This is needed for simulator interactions
        }

        // Check for watchOS XCUITest runner
        let watchXCUITestRunnerFound = await findWatchXCUITestRunner(in: derivedDataPath)
        if let runnerPath = watchXCUITestRunnerFound {
            output += "  XCUITest Runner (watchOS): FOUND at \(runnerPath)\n"
        } else {
            output += "  XCUITest Runner (watchOS): NOT BUILT\n"
            output += "    -> Build for testing: xcodebuild build-for-testing -scheme 'ListAllWatch Watch App' -sdk watchsimulator\n"
            // Not counting as critical issue - watchOS testing is optional
        }

        output += "\n"
        return (output, issues)
    }

    /// Find iOS app bundle in DerivedData
    private static func findIOSAppBundle(in derivedDataPath: String) async -> String? {
        // Look for ListAll.app in DerivedData
        let fm = FileManager.default
        guard let contents = try? fm.contentsOfDirectory(atPath: derivedDataPath) else {
            return nil
        }

        for item in contents where item.hasPrefix("ListAll-") {
            let buildPath = "\(derivedDataPath)/\(item)/Build/Products"
            if let buildContents = try? fm.contentsOfDirectory(atPath: buildPath) {
                for buildItem in buildContents where buildItem.contains("iphonesimulator") {
                    let appPath = "\(buildPath)/\(buildItem)/ListAll.app"
                    if fm.fileExists(atPath: appPath) {
                        return appPath
                    }
                }
            }
        }
        return nil
    }

    /// Find watchOS app bundle in DerivedData and extract bundle ID from Info.plist
    private static func findWatchAppBundle(in derivedDataPath: String) async -> (path: String, bundleId: String)? {
        let fm = FileManager.default
        guard let contents = try? fm.contentsOfDirectory(atPath: derivedDataPath) else {
            return nil
        }

        for item in contents where item.hasPrefix("ListAll-") {
            let buildPath = "\(derivedDataPath)/\(item)/Build/Products"
            if let buildContents = try? fm.contentsOfDirectory(atPath: buildPath) {
                // Look for watchsimulator directories
                for buildItem in buildContents where buildItem.contains("watchsimulator") {
                    // Watch app structure: ListAllWatch Watch App.app
                    let watchAppNames = [
                        "ListAllWatch Watch App.app",
                        "ListAll Watch App.app",
                        "ListAllWatch.app"
                    ]
                    for appName in watchAppNames {
                        let appPath = "\(buildPath)/\(buildItem)/\(appName)"
                        if fm.fileExists(atPath: appPath) {
                            // Extract bundle ID from Info.plist
                            let infoPlistPath = "\(appPath)/Info.plist"
                            if let bundleId = extractBundleId(from: infoPlistPath) {
                                return (appPath, bundleId)
                            }
                            // Fallback to standard bundle ID if can't read plist
                            return (appPath, "io.github.chmc.ListAll.watchkitapp")
                        }
                    }
                }
            }
        }
        return nil
    }

    /// Extract CFBundleIdentifier from Info.plist
    private static func extractBundleId(from infoPlistPath: String) -> String? {
        guard let plistData = FileManager.default.contents(atPath: infoPlistPath),
              let plist = try? PropertyListSerialization.propertyList(from: plistData, options: [], format: nil) as? [String: Any],
              let bundleId = plist["CFBundleIdentifier"] as? String else {
            return nil
        }
        return bundleId
    }

    /// Find macOS app bundle in DerivedData
    private static func findMacOSAppBundle(in derivedDataPath: String) async -> String? {
        // Look for ListAll.app macOS build in DerivedData
        let fm = FileManager.default
        guard let contents = try? fm.contentsOfDirectory(atPath: derivedDataPath) else {
            return nil
        }

        for item in contents where item.hasPrefix("ListAll-") {
            let buildPath = "\(derivedDataPath)/\(item)/Build/Products"
            if let buildContents = try? fm.contentsOfDirectory(atPath: buildPath) {
                // Look for Debug (macOS) folder - not iphonesimulator
                for buildItem in buildContents where buildItem == "Debug" {
                    let appPath = "\(buildPath)/\(buildItem)/ListAll.app"
                    if fm.fileExists(atPath: appPath) {
                        // Verify it's a macOS app by checking the executable architecture
                        let execPath = "\(appPath)/Contents/MacOS/ListAll"
                        if fm.fileExists(atPath: execPath) {
                            return appPath
                        }
                    }
                }
            }
        }
        return nil
    }

    /// Find iOS XCUITest runner in DerivedData
    private static func findXCUITestRunner(in derivedDataPath: String) async -> String? {
        // Look for ListAllUITests-Runner.app in DerivedData
        let fm = FileManager.default
        guard let contents = try? fm.contentsOfDirectory(atPath: derivedDataPath) else {
            return nil
        }

        for item in contents where item.hasPrefix("ListAll-") {
            let buildPath = "\(derivedDataPath)/\(item)/Build/Products"
            if let buildContents = try? fm.contentsOfDirectory(atPath: buildPath) {
                for buildItem in buildContents where buildItem.contains("iphonesimulator") {
                    let runnerPath = "\(buildPath)/\(buildItem)/ListAllUITests-Runner.app"
                    if fm.fileExists(atPath: runnerPath) {
                        return runnerPath
                    }
                }
            }
        }
        return nil
    }

    /// Find watchOS XCUITest runner in DerivedData
    private static func findWatchXCUITestRunner(in derivedDataPath: String) async -> String? {
        // Look for ListAllWatch Watch AppUITests-Runner.app in DerivedData
        let fm = FileManager.default
        guard let contents = try? fm.contentsOfDirectory(atPath: derivedDataPath) else {
            return nil
        }

        for item in contents where item.hasPrefix("ListAll-") {
            let buildPath = "\(derivedDataPath)/\(item)/Build/Products"
            if let buildContents = try? fm.contentsOfDirectory(atPath: buildPath) {
                for buildItem in buildContents where buildItem.contains("watchsimulator") {
                    let runnerPath = "\(buildPath)/\(buildItem)/ListAllWatch Watch AppUITests-Runner.app"
                    if fm.fileExists(atPath: runnerPath) {
                        return runnerPath
                    }
                }
            }
        }
        return nil
    }

    // MARK: - Xcode/Tools Checks

    /// Check Xcode and developer tools
    private static func checkXcodeTools() async -> (String, Int) {
        var output = "XCODE:\n"
        var issues = 0

        // Check Xcode version
        do {
            let versionResult = try await ShellCommand.execute("/usr/bin/xcodebuild", arguments: ["-version"])
            if versionResult.exitCode == 0 {
                // Parse version from output like "Xcode 16.2\nBuild version 16C5032a"
                let versionLine = versionResult.stdout.components(separatedBy: "\n").first ?? ""
                let version = versionLine.replacingOccurrences(of: "Xcode ", with: "")
                output += "  Version: \(version)\n"
            } else {
                output += "  Version: ERROR - xcodebuild failed\n"
                output += "    -> Make sure Xcode is installed from the App Store\n"
                issues += 1
            }
        } catch {
            output += "  Version: NOT FOUND\n"
            output += "    -> Install Xcode from the App Store\n"
            issues += 1
        }

        // Check xcodebuild path
        do {
            let whichResult = try await ShellCommand.execute("/usr/bin/which", arguments: ["xcodebuild"])
            if whichResult.exitCode == 0 {
                let path = whichResult.stdout.trimmingCharacters(in: .whitespacesAndNewlines)
                output += "  xcodebuild: \(path)\n"
            } else {
                output += "  xcodebuild: NOT FOUND\n"
                output += "    -> Run: xcode-select --install\n"
                issues += 1
            }
        } catch {
            output += "  xcodebuild: ERROR\n"
            issues += 1
        }

        // Check simctl path
        do {
            let whichResult = try await ShellCommand.execute("/usr/bin/which", arguments: ["xcrun"])
            if whichResult.exitCode == 0 {
                let path = whichResult.stdout.trimmingCharacters(in: .whitespacesAndNewlines)
                output += "  xcrun: \(path)\n"

                // Verify simctl works
                let simctlResult = try await ShellCommand.simctl(["help"])
                if simctlResult.exitCode == 0 {
                    output += "  simctl: Available (via xcrun simctl)\n"
                } else {
                    output += "  simctl: ERROR - simctl not working\n"
                    issues += 1
                }
            } else {
                output += "  xcrun: NOT FOUND\n"
                output += "    -> Run: xcode-select --install\n"
                issues += 1
            }
        } catch {
            output += "  xcrun: ERROR\n"
            issues += 1
        }

        // Check selected Xcode path
        do {
            let selectResult = try await ShellCommand.execute("/usr/bin/xcode-select", arguments: ["-p"])
            if selectResult.exitCode == 0 {
                let path = selectResult.stdout.trimmingCharacters(in: .whitespacesAndNewlines)
                output += "  Developer Path: \(path)\n"
            }
        } catch {
            // Not critical, just informational
        }

        output += "\n"
        return (output, issues)
    }

    // MARK: - watchOS Performance Guidance

    /// Generate watchOS-specific performance guidance
    private static func generateWatchOSPerformanceGuidance() -> String {
        var output = "WATCHOS PERFORMANCE GUIDANCE:\n"
        output += "  Single action: 8-15 seconds (normal for warm simulator)\n"
        output += "  Batched (3 actions): 12-15 seconds total\n"
        output += "  Screenshot: 1-2 seconds\n"
        output += "  Query: 15-20 seconds (depends on UI complexity)\n"
        output += "\n"
        output += "  Tips:\n"
        output += "  - Use listall_batch for multi-action sequences (saves ~50% time)\n"
        output += "  - Screenshots are fast - use them liberally for verification\n"
        output += "  - Pre-boot simulator: listall_boot_simulator before interactions\n"
        output += "  - Maximum batch size for watchOS: 5 actions\n"
        output += "\n"
        output += "  Known Limitations:\n"
        output += "  - Digital Crown: NOT supported - use swipe gestures instead\n"
        output += "  - Force Touch: NOT supported (deprecated by Apple)\n"
        output += "  - Accessibility identifiers: May not propagate from SwiftUI to XCUITest\n"
        output += "\n"
        return output
    }
}
