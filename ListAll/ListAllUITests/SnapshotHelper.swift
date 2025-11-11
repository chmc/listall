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
        NSLog("🔧 setupSnapshot() called")
        Snapshot.app = app
        Snapshot.waitForAnimations = waitForAnimations

        do {
            let cacheDir = try getCacheDirectory()
            Snapshot.cacheDirectory = cacheDir
            NSLog("✅ Cache directory set to: \(cacheDir.path)")
            if let screenshotsDir = screenshotsDirectory {
                NSLog("✅ Screenshots directory will be: \(screenshotsDir.path)")
            } else {
                NSLog("⚠️ screenshotsDirectory is nil after setting cacheDirectory")
            }
            setLanguage(app)
            setLocale(app)
            setLaunchArguments(app)
            NSLog("✅ setupSnapshot() completed successfully")
        } catch let error {
            NSLog("❌ setupSnapshot() failed: \(error.localizedDescription)")
            NSLog("❌ Error details: \(error)")
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
        
        // CRITICAL: Also write to a file for debugging when NSLog isn't captured
        // This helps diagnose issues when using test_without_building
        if let cacheDir = cacheDirectory {
            let debugLogPath = cacheDir.appendingPathComponent("snapshot_debug.log")
            let timestamp = Date().timeIntervalSince1970
            let debugMessage = "[\(timestamp)] snapshot: \(name)\n"
            if let data = debugMessage.data(using: .utf8) {
                if let fileHandle = try? FileHandle(forWritingTo: debugLogPath) {
                    fileHandle.seekToEndOfFile()
                    fileHandle.write(data)
                    fileHandle.closeFile()
                } else {
                    // File doesn't exist, create it
                    try? data.write(to: debugLogPath)
                }
            }
        }
        
        // Verify setupSnapshot was called
        if self.app == nil {
            let errorMsg = "XCUIApplication is not set. Please call setupSnapshot(app) before snapshot()."
            NSLog("❌ ERROR: \(errorMsg)")
            print("❌ ERROR: \(errorMsg)")
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
            guard let screenshotsDir = screenshotsDirectory else {
                NSLog("⚠️ screenshotsDirectory is nil - cannot save screenshot")
                return
            }
            
            // Try to get simulator name from environment, or fall back to extracting from app
            var simulator: String
            if let envSimulator = ProcessInfo().environment["SIMULATOR_DEVICE_NAME"], !envSimulator.isEmpty {
                simulator = envSimulator
            } else {
                // Fallback: Try to get device name from app's device info or use a default
                // Fastlane snapshot should set this, but with test_without_building it may not
                if let app = self.app {
                    // Try to extract from destination environment variable
                    if let destination = ProcessInfo().environment["XCODE_DESTINATION"],
                       let nameMatch = destination.components(separatedBy: ",").first(where: { $0.contains("name=") }) {
                        simulator = nameMatch.replacingOccurrences(of: "name=", with: "").trimmingCharacters(in: .whitespaces)
                    } else {
                        // Last resort: use a sanitized version based on screen size or default
                        let screenSize = app.windows.firstMatch.frame.size
                        if screenSize.width > 1000 {
                            simulator = "iPadPro13inchM4" // Default for large iPad
                        } else {
                            simulator = "iPhone16ProMax" // Default for iPhone
                        }
                        NSLog("⚠️ SIMULATOR_DEVICE_NAME not set, using fallback: \(simulator)")
                    }
                } else {
                    NSLog("⚠️ Cannot determine simulator name - app is nil")
                    return
                }
            }

            do {
                // CRITICAL: Ensure the screenshots directory exists before writing
                let fileManager = FileManager.default
                if !fileManager.fileExists(atPath: screenshotsDir.path) {
                    try fileManager.createDirectory(at: screenshotsDir, withIntermediateDirectories: true, attributes: nil)
                    NSLog("✅ Created screenshots directory: \(screenshotsDir.path)")
                    print("✅ Created screenshots directory: \(screenshotsDir.path)")
                }
                
                // The simulator name contains "Clone X of " inside the screenshot file when running parallelized UI Tests on concurrent devices
                let regex = try NSRegularExpression(pattern: "Clone [0-9]+ of ")
                let range = NSRange(location: 0, length: simulator.count)
                simulator = regex.stringByReplacingMatches(in: simulator, range: range, withTemplate: "")

                let path = screenshotsDir.appendingPathComponent("\(simulator)-\(name).png")
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
                let errorMsg = "Problem writing screenshot: \(name) to \(screenshotsDir.path)/\(simulator)-\(name).png"
                NSLog("❌ \(errorMsg)")
                print("❌ \(errorMsg)")
                NSLog("❌ Error: \(error.localizedDescription)")
                print("❌ Error: \(error.localizedDescription)")
                NSLog("❌ Error details: \(error)")
                print("❌ Error details: \(error)")
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
            let simulatorHostHome = ProcessInfo().environment["SIMULATOR_HOST_HOME"] 
                                    ?? ProcessInfo().environment["HOME"]
                                    ?? NSHomeDirectory()
            NSLog("🔍 SIMULATOR_HOST_HOME: \(ProcessInfo().environment["SIMULATOR_HOST_HOME"] ?? "not set")")
            NSLog("🔍 HOME: \(ProcessInfo().environment["HOME"] ?? "not set")")
            NSLog("🔍 NSHomeDirectory(): \(NSHomeDirectory())")
            NSLog("🔍 Using home directory: \(simulatorHostHome)")
            let homeDir = URL(fileURLWithPath: simulatorHostHome)
            let cacheDir = homeDir.appendingPathComponent(cachePath)
            NSLog("🔍 Cache directory path: \(cacheDir.path)")
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
