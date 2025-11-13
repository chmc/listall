//
//  SnapshotHelper.swift
//  Example
//
//  Created by Felix Krause on 10/8/15.
//

// -----------------------------------------------------
// IMPORTANT: When modifying this file, make sure to
//            increment the version number at the very
//            bottom of the file to notify users about
//            the new SnapshotHelper.swift
// -----------------------------------------------------

import Foundation
import XCTest

@MainActor
func setupSnapshot(_ app: XCUIApplication, waitForAnimations: Bool = true) {
    Snapshot.setupSnapshot(app, waitForAnimations: waitForAnimations)
}

@MainActor
func snapshot(_ name: String, waitForLoadingIndicator: Bool) {
    if waitForLoadingIndicator {
        Snapshot.snapshot(name)
    } else {
        Snapshot.snapshot(name, timeWaitingForIdle: 0)
    }
}

/// - Parameters:
///   - name: The name of the snapshot
///   - timeout: Amount of seconds to wait until the network loading indicator disappears. Pass `0` if you don't want to wait.
@MainActor
func snapshot(_ name: String, timeWaitingForIdle timeout: TimeInterval = 20) {
    Snapshot.snapshot(name, timeWaitingForIdle: timeout)
}

enum SnapshotError: Error, CustomDebugStringConvertible {
    case cannotFindSimulatorHomeDirectory
    case cannotRunOnPhysicalDevice

    var debugDescription: String {
        switch self {
        case .cannotFindSimulatorHomeDirectory:
            return "Couldn't find simulator home location. Please, check SIMULATOR_HOST_HOME env variable."
        case .cannotRunOnPhysicalDevice:
            return "Can't use Snapshot on a physical device."
        }
    }
}

@objcMembers
@MainActor
open class Snapshot: NSObject {
    static var app: XCUIApplication?
    static var waitForAnimations = true
    static var cacheDirectory: URL?
    static var screenshotsDirectory: URL? {
        return cacheDirectory?.appendingPathComponent("screenshots", isDirectory: true)
    }
    static var deviceLanguage = ""
    static var currentLocale = ""

    open class func setupSnapshot(_ app: XCUIApplication, waitForAnimations: Bool = true) {
        // CRITICAL: Use both NSLog and print to ensure visibility in logs
        // NSLog may not be captured with test_without_building, but print should be
        let setupMsg = "🔧 setupSnapshot() called"
        NSLog(setupMsg)
        print(setupMsg)
        
        // CRITICAL DIAGNOSTICS: Log environment variables
        let env = ProcessInfo.processInfo.environment
        NSLog("🔍 DEBUG: SIMULATOR_HOST_HOME=\(env["SIMULATOR_HOST_HOME"] ?? "NOT SET")")
        NSLog("🔍 DEBUG: SIMULATOR_DEVICE_NAME=\(env["SIMULATOR_DEVICE_NAME"] ?? "NOT SET")")
        NSLog("🔍 DEBUG: HOME=\(env["HOME"] ?? "NOT SET")")
        NSLog("🔍 DEBUG: NSHomeDirectory()=\(NSHomeDirectory())")
        print("🔍 DEBUG: SIMULATOR_HOST_HOME=\(env["SIMULATOR_HOST_HOME"] ?? "NOT SET")")
        print("🔍 DEBUG: SIMULATOR_DEVICE_NAME=\(env["SIMULATOR_DEVICE_NAME"] ?? "NOT SET")")
        print("🔍 DEBUG: HOME=\(env["HOME"] ?? "NOT SET")")
        print("🔍 DEBUG: NSHomeDirectory()=\(NSHomeDirectory())")
        
        Snapshot.app = app
        Snapshot.waitForAnimations = waitForAnimations

        do {
            let cacheDir = try getCacheDirectory()
            Snapshot.cacheDirectory = cacheDir
            let cacheMsg = "✅ Cache directory set to: \(cacheDir.path)"
            NSLog(cacheMsg)
            print(cacheMsg)
            
            // CRITICAL: Verify cache directory is writable
            let fileManager = FileManager.default
            if !fileManager.fileExists(atPath: cacheDir.path) {
                try fileManager.createDirectory(at: cacheDir, withIntermediateDirectories: true, attributes: nil)
                NSLog("✅ Created cache directory: \(cacheDir.path)")
                print("✅ Created cache directory: \(cacheDir.path)")
            }
            
            // Test write access
            let testFile = cacheDir.appendingPathComponent(".test_write")
            do {
                try "test".write(to: testFile, atomically: true, encoding: .utf8)
                try fileManager.removeItem(at: testFile)
                NSLog("✅ Cache directory is writable")
                print("✅ Cache directory is writable")
            } catch {
                NSLog("⚠️ Cache directory exists but may not be writable: \(error.localizedDescription)")
                print("⚠️ Cache directory exists but may not be writable: \(error.localizedDescription)")
            }
            
            if let screenshotsDir = screenshotsDirectory {
                let screenshotsMsg = "✅ Screenshots directory will be: \(screenshotsDir.path)"
                NSLog(screenshotsMsg)
                print(screenshotsMsg)
                
                // Ensure screenshots directory exists
                if !fileManager.fileExists(atPath: screenshotsDir.path) {
                    try fileManager.createDirectory(at: screenshotsDir, withIntermediateDirectories: true, attributes: nil)
                    NSLog("✅ Created screenshots directory: \(screenshotsDir.path)")
                    print("✅ Created screenshots directory: \(screenshotsDir.path)")
                }
            } else {
                let warningMsg = "⚠️ screenshotsDirectory is nil after setting cacheDirectory"
                NSLog(warningMsg)
                print(warningMsg)
            }
            setLanguage(app)
            setLocale(app)
            setLaunchArguments(app)
            
            // CRITICAL: Write marker file to verify setupSnapshot() completed
            let markerPath = cacheDir.appendingPathComponent("setupSnapshot_completed.txt")
            let markerContent = "setupSnapshot() completed at \(Date())\nCache directory: \(cacheDir.path)\nScreenshots directory: \(screenshotsDirectory?.path ?? "nil")"
            do {
                try markerContent.write(to: markerPath, atomically: true, encoding: .utf8)
                NSLog("✅ Created setupSnapshot completion marker: \(markerPath.path)")
                print("✅ Created setupSnapshot completion marker: \(markerPath.path)")
            } catch {
                NSLog("⚠️ Could not write setupSnapshot marker: \(error.localizedDescription)")
                print("⚠️ Could not write setupSnapshot marker: \(error.localizedDescription)")
            }
            
            let successMsg = "✅ setupSnapshot() completed successfully"
            NSLog(successMsg)
            print(successMsg)
        } catch let error {
            let errorMsg = "❌ setupSnapshot() failed: \(error.localizedDescription)"
            let errorDetails = "❌ Error details: \(error)"
            NSLog(errorMsg)
            NSLog(errorDetails)
            print(errorMsg)
            print(errorDetails)
            // CRITICAL: Don't silently fail - ensure we still have a cache directory
            // Try to use a fallback directory
            let fallbackCache = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("fastlane_screenshots")
            do {
                try FileManager.default.createDirectory(at: fallbackCache, withIntermediateDirectories: true, attributes: nil)
                Snapshot.cacheDirectory = fallbackCache
                let fallbackMsg = "⚠️ Using fallback cache directory: \(fallbackCache.path)"
                NSLog(fallbackMsg)
                print(fallbackMsg)
            } catch {
                let fatalMsg = "❌ CRITICAL: Could not create fallback cache directory. Screenshots will not be saved."
                NSLog(fatalMsg)
                print(fatalMsg)
            }
        }
    }

    class func setLanguage(_ app: XCUIApplication) {
        guard let cacheDirectory = self.cacheDirectory else {
            NSLog("CacheDirectory is not set - probably running on a physical device?")
            return
        }

        let path = cacheDirectory.appendingPathComponent("language.txt")

        do {
            let trimCharacterSet = CharacterSet.whitespacesAndNewlines
            deviceLanguage = try String(contentsOf: path, encoding: .utf8).trimmingCharacters(in: trimCharacterSet)
            app.launchArguments += ["-AppleLanguages", "(\(deviceLanguage))"]
        } catch {
            NSLog("Couldn't detect/set language...")
        }
    }

    class func setLocale(_ app: XCUIApplication) {
        guard let cacheDirectory = self.cacheDirectory else {
            NSLog("CacheDirectory is not set - probably running on a physical device?")
            return
        }

        let path = cacheDirectory.appendingPathComponent("locale.txt")

        do {
            let trimCharacterSet = CharacterSet.whitespacesAndNewlines
            currentLocale = try String(contentsOf: path, encoding: .utf8).trimmingCharacters(in: trimCharacterSet)
        } catch {
            NSLog("Couldn't detect/set locale...")
        }

        if currentLocale.isEmpty && !deviceLanguage.isEmpty {
            currentLocale = Locale(identifier: deviceLanguage).identifier
        }

        if !currentLocale.isEmpty {
            app.launchArguments += ["-AppleLocale", "\"\(currentLocale)\""]
        }
    }

    class func setLaunchArguments(_ app: XCUIApplication) {
        guard let cacheDirectory = self.cacheDirectory else {
            NSLog("CacheDirectory is not set - probably running on a physical device?")
            return
        }

        let path = cacheDirectory.appendingPathComponent("snapshot-launch_arguments.txt")
        app.launchArguments += ["-FASTLANE_SNAPSHOT", "YES", "-ui_testing"]

        do {
            let launchArguments = try String(contentsOf: path, encoding: String.Encoding.utf8)
            let regex = try NSRegularExpression(pattern: "(\\\".+?\\\"|\\S+)", options: [])
            let matches = regex.matches(in: launchArguments, options: [], range: NSRange(location: 0, length: launchArguments.count))
            let results = matches.map { result -> String in
                (launchArguments as NSString).substring(with: result.range)
            }
            app.launchArguments += results
        } catch {
            NSLog("Couldn't detect/set launch_arguments...")
        }
    }

    open class func snapshot(_ name: String, timeWaitingForIdle timeout: TimeInterval = 20) {
        // CRITICAL: Log immediately so Fastlane can detect snapshot calls even if later code fails
        // Use both NSLog and print to ensure visibility in logs
        let logMessage = "snapshot: \(name)"
        NSLog(logMessage) // more information about this, check out https://docs.fastlane.tools/actions/snapshot/#how-does-it-work
        print(logMessage) // Also print to stdout for better log capture
        NSLog("🔍 DEBUG: Snapshot.snapshot('\(name)') called, timeout=\(timeout)")
        print("🔍 DEBUG: Snapshot.snapshot('\(name)') called, timeout=\(timeout)")
        
        // CRITICAL: Write marker file to verify snapshot() is being called
        // This works even if NSLog/print output isn't captured
        let markerPaths = [
            cacheDirectory?.appendingPathComponent("snapshot_marker_\(name).txt"),
            URL(fileURLWithPath: "/tmp/snapshot_marker_\(name).txt"),
            FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first?.appendingPathComponent("snapshot_marker_\(name).txt")
        ].compactMap { $0 }
        
        let timestamp = Date().timeIntervalSince1970
        let markerContent = "snapshot called: \(name) at \(timestamp)\n"
        if let markerData = markerContent.data(using: .utf8) {
            for markerPath in markerPaths {
                try? markerData.write(to: markerPath)
            }
        }
        
        // CRITICAL: Write to debug log file even if cacheDirectory is nil
        // This helps diagnose issues when setupSnapshot() fails
        let debugLogPaths = [
            cacheDirectory?.appendingPathComponent("snapshot_debug.log"),
            URL(fileURLWithPath: "/tmp/snapshot_debug.log"), // Fallback location
            FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first?.appendingPathComponent("snapshot_debug.log")
        ].compactMap { $0 }
        
        let debugMessage = "[\(timestamp)] snapshot: \(name)\n"
        if let data = debugMessage.data(using: .utf8) {
            for debugLogPath in debugLogPaths {
                do {
                    // Try to open existing file for appending
                    if let fileHandle = try? FileHandle(forWritingTo: debugLogPath) {
                        fileHandle.seekToEndOfFile()
                        fileHandle.write(data)
                        fileHandle.closeFile()
                        break
                    } else {
                        // File doesn't exist, create it
                        try data.write(to: debugLogPath)
                        break
                    }
                } catch {
                    // Try next path if this one fails
                    continue
                }
            }
        }
        
        // Verify setupSnapshot was called
        if self.app == nil {
            let errorMsg = "XCUIApplication is not set. Please call setupSnapshot(app) before snapshot()."
            NSLog("❌ ERROR: \(errorMsg)")
            print("❌ ERROR: \(errorMsg)")
            // Also write error to debug log
            let errorData = "[\(Date().timeIntervalSince1970)] ERROR: \(errorMsg)\n".data(using: .utf8)
            for debugLogPath in debugLogPaths {
                try? errorData?.write(to: debugLogPath)
            }
            // CRITICAL: Fail the test explicitly so we can see the failure
            // This prevents silent failures where snapshot() is called but setupSnapshot() wasn't
            let fatalMsg = "❌ FATAL: snapshot('\(name)') called but setupSnapshot() was not called or failed. Screenshot will not be saved."
            NSLog(fatalMsg)
            print(fatalMsg)
            // Write to cache directory (accessible by both test and Fastlane processes)
            // CRITICAL: Use cache directory instead of /tmp because /tmp may be process-specific in CI
            if let cacheDir = self.cacheDirectory {
                let fatalMarkerPath = cacheDir.appendingPathComponent("snapshot_setup_failed.txt")
                try? fatalMsg.write(to: fatalMarkerPath, atomically: true, encoding: .utf8)
            }
            // Also write to /tmp as fallback
            let tmpMarkerPath = URL(fileURLWithPath: "/tmp/snapshot_setup_failed.txt")
            try? fatalMsg.write(to: tmpMarkerPath, atomically: true, encoding: .utf8)
            // Don't return silently - fail the test so it's visible
            XCTFail(fatalMsg)
            return
        }
        
        // Since we've already checked that app is not nil above, we can safely unwrap
        let appState = self.app?.state.rawValue ?? 0
        NSLog("🔍 DEBUG: Snapshot.app is set, app state: \(appState)")
        print("🔍 DEBUG: Snapshot.app is set, app state: \(appState)")
        
        if timeout > 0 {
            waitForLoadingIndicatorToDisappear(within: timeout)
        }

        if Snapshot.waitForAnimations {
            sleep(1) // Waiting for the animation to be finished (kind of)
        }

        #if os(OSX)
            guard let app = self.app else {
                NSLog("XCUIApplication is not set. Please call setupSnapshot(app) before snapshot().")
                return
            }

            app.typeKey(XCUIKeyboardKeySecondaryFn, modifierFlags: [])
        #else

            guard self.app != nil else {
                NSLog("XCUIApplication is not set. Please call setupSnapshot(app) before snapshot().")
                return
            }

            let screenshot = XCUIScreen.main.screenshot()
            #if os(iOS) && !targetEnvironment(macCatalyst)
            let image = XCUIDevice.shared.orientation.isLandscape ?  fixLandscapeOrientation(image: screenshot.image) : screenshot.image
            #else
            let image = screenshot.image
            #endif

            // CRITICAL FIX: SIMULATOR_DEVICE_NAME may not be set when using test_without_building
            // Fall back to extracting device name from destination or using a default
            // CRITICAL: If screenshotsDirectory is nil, try to create it or use fallback location
            var screenshotsDir: URL?
            if let dir = screenshotsDirectory {
                screenshotsDir = dir
            } else {
                // Fallback: Try to recreate cache directory
                NSLog("⚠️ screenshotsDirectory is nil - attempting to recreate cache directory")
                do {
                    let fallbackCacheDir = try getCacheDirectory()
                    screenshotsDir = fallbackCacheDir.appendingPathComponent("screenshots", isDirectory: true)
                    Snapshot.cacheDirectory = fallbackCacheDir
                    NSLog("✅ Recreated cache directory: \(fallbackCacheDir.path)")
                } catch {
                    // Last resort: Use /tmp or document directory
                    let fallbackPaths = [
                        URL(fileURLWithPath: "/tmp/fastlane_screenshots"),
                        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first?.appendingPathComponent("screenshots")
                    ]
                    for fallbackPath in fallbackPaths {
                        if let path = fallbackPath {
                            screenshotsDir = path
                            NSLog("⚠️ Using fallback screenshots directory: \(path.path)")
                            break
                        }
                    }
                }
            }
            
            guard let finalScreenshotsDir = screenshotsDir else {
                // CRITICAL: Cannot determine screenshots directory - log error and return
                // File system save is the primary method, so we can't proceed without a directory
                let errorMsg = "❌ CRITICAL: Cannot determine screenshots directory - screenshot will not be saved"
                NSLog(errorMsg)
                print(errorMsg)
                NSLog("   Cache directory: \(cacheDirectory?.path ?? "nil")")
                print("   Cache directory: \(cacheDirectory?.path ?? "nil")")
                NSLog("   SIMULATOR_HOST_HOME: \(ProcessInfo.processInfo.environment["SIMULATOR_HOST_HOME"] ?? "NOT SET")")
                print("   SIMULATOR_HOST_HOME: \(ProcessInfo.processInfo.environment["SIMULATOR_HOST_HOME"] ?? "NOT SET")")
                return
            }
            
            // Try to get simulator name from environment, cache file, or fall back to extracting from app
            var simulator: String
            if let envSimulator = ProcessInfo().environment["SIMULATOR_DEVICE_NAME"], !envSimulator.isEmpty {
                simulator = envSimulator
                NSLog("✅ Using SIMULATOR_DEVICE_NAME from environment: \(simulator)")
            } else if let cacheDirectory = self.cacheDirectory {
                // CRITICAL FIX: Try reading from cache file (created by Fastfile)
                // This works around the issue where environment variables aren't passed with test_without_building
                let deviceNameFile = cacheDirectory.appendingPathComponent("device_name.txt")
                do {
                    let deviceNameFromFile = try String(contentsOf: deviceNameFile, encoding: .utf8).trimmingCharacters(in: .whitespacesAndNewlines)
                    if !deviceNameFromFile.isEmpty {
                        simulator = deviceNameFromFile
                        NSLog("✅ Using device name from cache file: \(simulator)")
                    } else {
                        throw NSError(domain: "SnapshotHelper", code: 1, userInfo: [NSLocalizedDescriptionKey: "Empty device name file"])
                    }
                } catch {
                    NSLog("⚠️ Could not read device_name.txt from cache: \(error.localizedDescription)")
                    // Fall through to other methods
                    simulator = ""
                }
            } else {
                simulator = ""
            }
            
            // If we still don't have a simulator name, try fallback methods
            if simulator.isEmpty {
                // Fallback: Try to get device name from app's device info or use a default
                // Fastlane snapshot should set this, but with test_without_building it may not
                if let app = self.app {
                    // Try to extract from destination environment variable
                    if let destination = ProcessInfo().environment["XCODE_DESTINATION"],
                       let nameMatch = destination.components(separatedBy: ",").first(where: { $0.contains("name=") }) {
                        simulator = nameMatch.replacingOccurrences(of: "name=", with: "").trimmingCharacters(in: .whitespaces)
                        NSLog("✅ Using device name from XCODE_DESTINATION: \(simulator)")
                    } else {
                        // Last resort: use a sanitized version based on screen size or default
                        let screenSize = app.windows.firstMatch.frame.size
                        if screenSize.width > 1000 {
                            simulator = "iPadPro13inchM4" // Default for large iPad
                        } else {
                            simulator = "iPhone16ProMax" // Default for iPhone
                        }
                        NSLog("⚠️ SIMULATOR_DEVICE_NAME not set, using fallback based on screen size: \(simulator)")
                    }
                } else {
                    NSLog("⚠️ Cannot determine simulator name - app is nil")
                    return
                }
            }

            do {
                // CRITICAL: Ensure the screenshots directory exists before writing
                let fileManager = FileManager.default
                if !fileManager.fileExists(atPath: finalScreenshotsDir.path) {
                    try fileManager.createDirectory(at: finalScreenshotsDir, withIntermediateDirectories: true, attributes: nil)
                    NSLog("✅ Created screenshots directory: \(finalScreenshotsDir.path)")
                    print("✅ Created screenshots directory: \(finalScreenshotsDir.path)")
                }
                
                // The simulator name contains "Clone X of " inside the screenshot file when running parallelized UI Tests on concurrent devices
                let regex = try NSRegularExpression(pattern: "Clone [0-9]+ of ")
                let range = NSRange(location: 0, length: simulator.count)
                simulator = regex.stringByReplacingMatches(in: simulator, range: range, withTemplate: "")

                let path = finalScreenshotsDir.appendingPathComponent("\(simulator)-\(name).png")
                NSLog("🔍 DEBUG: Attempting to save screenshot to: \(path.path)")
                print("🔍 DEBUG: Attempting to save screenshot to: \(path.path)")
                
                #if swift(<5.0)
                    try UIImagePNGRepresentation(image)?.write(to: path, options: .atomic)
                #else
                    try image.pngData()?.write(to: path, options: .atomic)
                #endif
                NSLog("✅ Saved screenshot: \(path.lastPathComponent)")
                print("✅ Saved screenshot: \(path.lastPathComponent)")
                
            } catch let error {
                let errorMsg = "Problem writing screenshot: \(name) to \(finalScreenshotsDir.path)/\(simulator)-\(name).png"
                NSLog("❌ \(errorMsg)")
                print("❌ \(errorMsg)")
                NSLog("❌ Error: \(error.localizedDescription)")
                print("❌ Error: \(error.localizedDescription)")
                NSLog("❌ Error details: \(error)")
                print("❌ Error details: \(error)")
                
                // CRITICAL: File save failed - screenshot was not saved
                // The error has been logged above for debugging
                NSLog("⚠️ Screenshot could not be saved to file system")
                print("⚠️ Screenshot could not be saved to file system")
            }
        #endif
    }

    class func fixLandscapeOrientation(image: UIImage) -> UIImage {
        #if os(watchOS)
            return image
        #else
            if #available(iOS 10.0, *) {
                let format = UIGraphicsImageRendererFormat()
                format.scale = image.scale
                let renderer = UIGraphicsImageRenderer(size: image.size, format: format)
                return renderer.image { context in
                    image.draw(in: CGRect(x: 0, y: 0, width: image.size.width, height: image.size.height))
                }
            } else {
                return image
            }
        #endif
    }

    class func waitForLoadingIndicatorToDisappear(within timeout: TimeInterval) {
        #if os(tvOS)
            return
        #endif

        guard let app = self.app else {
            NSLog("XCUIApplication is not set. Please call setupSnapshot(app) before snapshot().")
            return
        }

        let networkLoadingIndicator = app.otherElements.deviceStatusBars.networkLoadingIndicators.element
        let networkLoadingIndicatorDisappeared = XCTNSPredicateExpectation(predicate: NSPredicate(format: "exists == false"), object: networkLoadingIndicator)
        _ = XCTWaiter.wait(for: [networkLoadingIndicatorDisappeared], timeout: timeout)
    }

    class func getCacheDirectory() throws -> URL {
        let cachePath = "Library/Caches/tools.fastlane"
        // on OSX config is stored in /Users/<username>/Library
        // and on iOS/tvOS/WatchOS it's in simulator's home dir
        #if os(OSX)
            let homeDir = URL(fileURLWithPath: NSHomeDirectory())
            return homeDir.appendingPathComponent(cachePath)
        #elseif arch(i386) || arch(x86_64) || arch(arm64)
            // CRITICAL FIX: Fastlane snapshot should set SIMULATOR_HOST_HOME, but with test_without_building it may not
            // Fall back to HOME environment variable or NSHomeDirectory() if SIMULATOR_HOST_HOME is not set
            // Try multiple fallback strategies to ensure we always find a valid directory
            var simulatorHostHome: String?
            
            // Strategy 1: Check SIMULATOR_HOST_HOME (set by Fastlane)
            simulatorHostHome = ProcessInfo().environment["SIMULATOR_HOST_HOME"]
            
            // Strategy 2: Read from cache file (workaround for test_without_building not passing env vars)
            // Try multiple possible cache locations to find the file
            if simulatorHostHome == nil || simulatorHostHome!.isEmpty {
                let possibleCacheDirs = [
                    URL(fileURLWithPath: NSHomeDirectory()).appendingPathComponent("Library/Caches/tools.fastlane"),
                    URL(fileURLWithPath: "/Users/runner/Library/Caches/tools.fastlane"),
                    URL(fileURLWithPath: ProcessInfo().environment["HOME"] ?? "").appendingPathComponent("Library/Caches/tools.fastlane"),
                    URL(fileURLWithPath: "/tmp/tools.fastlane")
                ]
                
                for cacheDir in possibleCacheDirs {
                    let hostHomeFile = cacheDir.appendingPathComponent("simulator_host_home.txt")
                    if FileManager.default.fileExists(atPath: hostHomeFile.path) {
                        do {
                            let hostHomePath = try String(contentsOf: hostHomeFile, encoding: .utf8).trimmingCharacters(in: .whitespacesAndNewlines)
                            if !hostHomePath.isEmpty && FileManager.default.fileExists(atPath: hostHomePath) {
                                simulatorHostHome = hostHomePath
                                NSLog("✅ Read SIMULATOR_HOST_HOME from file: \(hostHomePath)")
                                break
                            }
                        } catch {
                            // Continue to next strategy
                        }
                    }
                }
            }
            
            // Strategy 3: Check HOME environment variable
            if simulatorHostHome == nil || simulatorHostHome!.isEmpty {
                simulatorHostHome = ProcessInfo().environment["HOME"]
            }
            
            // Strategy 4: Use NSHomeDirectory() (should always work in simulator)
            if simulatorHostHome == nil || simulatorHostHome!.isEmpty {
                simulatorHostHome = NSHomeDirectory()
            }
            
            // Strategy 5: Last resort - use /Users/runner (common CI path) or /tmp
            if simulatorHostHome == nil || simulatorHostHome!.isEmpty {
                simulatorHostHome = "/Users/runner"
                // Verify it exists, if not use /tmp
                if !FileManager.default.fileExists(atPath: simulatorHostHome!) {
                    simulatorHostHome = "/tmp"
                }
            }
            
            NSLog("🔍 SIMULATOR_HOST_HOME: \(ProcessInfo().environment["SIMULATOR_HOST_HOME"] ?? "not set")")
            NSLog("🔍 HOME: \(ProcessInfo().environment["HOME"] ?? "not set")")
            NSLog("🔍 NSHomeDirectory(): \(NSHomeDirectory())")
            NSLog("🔍 Using home directory: \(simulatorHostHome ?? "NIL - THIS SHOULD NEVER HAPPEN")")
            
            guard let home = simulatorHostHome, !home.isEmpty else {
                // This should never happen with our fallbacks, but handle it gracefully
                let fallback = "/tmp"
                NSLog("⚠️ All home directory strategies failed, using fallback: \(fallback)")
                return URL(fileURLWithPath: fallback).appendingPathComponent(cachePath)
            }
            
            let homeDir = URL(fileURLWithPath: home)
            let cacheDir = homeDir.appendingPathComponent(cachePath)
            NSLog("🔍 Cache directory path: \(cacheDir.path)")
            
            // CRITICAL: Ensure the cache directory exists
            let fileManager = FileManager.default
            if !fileManager.fileExists(atPath: cacheDir.path) {
                do {
                    try fileManager.createDirectory(at: cacheDir, withIntermediateDirectories: true, attributes: nil)
                    NSLog("✅ Created cache directory: \(cacheDir.path)")
                } catch {
                    NSLog("⚠️ Failed to create cache directory: \(error.localizedDescription)")
                    // Continue anyway - snapshot() will try to create the screenshots subdirectory
                }
            }
            
            return cacheDir
        #else
            throw SnapshotError.cannotRunOnPhysicalDevice
        #endif
    }
}

private extension XCUIElementAttributes {
    var isNetworkLoadingIndicator: Bool {
        if hasAllowListedIdentifier { return false }

        let hasOldLoadingIndicatorSize = frame.size == CGSize(width: 10, height: 20)
        let hasNewLoadingIndicatorSize = frame.size.width.isBetween(46, and: 47) && frame.size.height.isBetween(2, and: 3)

        return hasOldLoadingIndicatorSize || hasNewLoadingIndicatorSize
    }

    var hasAllowListedIdentifier: Bool {
        let allowListedIdentifiers = ["GeofenceLocationTrackingOn", "StandardLocationTrackingOn"]

        return allowListedIdentifiers.contains(identifier)
    }

    func isStatusBar(_ deviceWidth: CGFloat) -> Bool {
        if elementType == .statusBar { return true }
        guard frame.origin == .zero else { return false }

        let oldStatusBarSize = CGSize(width: deviceWidth, height: 20)
        let newStatusBarSize = CGSize(width: deviceWidth, height: 44)

        return [oldStatusBarSize, newStatusBarSize].contains(frame.size)
    }
}

private extension XCUIElementQuery {
    var networkLoadingIndicators: XCUIElementQuery {
        let isNetworkLoadingIndicator = NSPredicate { (evaluatedObject, _) in
            guard let element = evaluatedObject as? XCUIElementAttributes else { return false }

            return element.isNetworkLoadingIndicator
        }

        return self.containing(isNetworkLoadingIndicator)
    }

    @MainActor
    var deviceStatusBars: XCUIElementQuery {
        guard let app = Snapshot.app else {
            fatalError("XCUIApplication is not set. Please call setupSnapshot(app) before snapshot().")
        }

        let deviceWidth = app.windows.firstMatch.frame.width

        let isStatusBar = NSPredicate { (evaluatedObject, _) in
            guard let element = evaluatedObject as? XCUIElementAttributes else { return false }

            return element.isStatusBar(deviceWidth)
        }

        return self.containing(isStatusBar)
    }
}

private extension CGFloat {
    func isBetween(_ numberA: CGFloat, and numberB: CGFloat) -> Bool {
        return numberA...numberB ~= self
    }
}

// Please don't remove the lines below
// They are used to detect outdated configuration files
// SnapshotHelperVersion [1.30]
