//
//  MacSnapshotHelper.swift
//  ListAllMacUITests
//
//  Created by Claude Code on 8.12.2025.
//  Adapted from Fastlane Snapshot for macOS
//

// -----------------------------------------------------
// IMPORTANT: When modifying this file, make sure to
//            increment the version number at the very
//            bottom of the file to notify users about
//            the new MacSnapshotHelper.swift
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
    case cannotFindHomeDirectory

    var debugDescription: String {
        switch self {
        case .cannotFindHomeDirectory:
            return "Couldn't find home directory location. Please check HOME env variable."
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
        // Log setup for debugging
        let setupMsg = "🔧 [macOS] setupSnapshot() called"
        NSLog(setupMsg)
        print(setupMsg)

        // Log environment variables
        let env = ProcessInfo.processInfo.environment
        NSLog("🔍 DEBUG: HOME=\(env["HOME"] ?? "NOT SET")")
        NSLog("🔍 DEBUG: NSHomeDirectory()=\(NSHomeDirectory())")
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

            // Verify cache directory is writable
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

            // Write marker file to verify setupSnapshot() completed
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
            NSLog("CacheDirectory is not set")
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
            NSLog("CacheDirectory is not set")
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
            NSLog("CacheDirectory is not set")
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
        // Log immediately so Fastlane can detect snapshot calls
        let logMessage = "snapshot: \(name)"
        NSLog(logMessage)
        print(logMessage)
        NSLog("🔍 DEBUG: Snapshot.snapshot('\(name)') called, timeout=\(timeout)")
        print("🔍 DEBUG: Snapshot.snapshot('\(name)') called, timeout=\(timeout)")

        // Write marker file to verify snapshot() is being called
        let markerPaths = [
            cacheDirectory?.appendingPathComponent("snapshot_marker_\(name).txt"),
            URL(fileURLWithPath: "/tmp/snapshot_marker_\(name).txt")
        ].compactMap { $0 }

        let timestamp = Date().timeIntervalSince1970
        let markerContent = "snapshot called: \(name) at \(timestamp)\n"
        if let markerData = markerContent.data(using: .utf8) {
            for markerPath in markerPaths {
                try? markerData.write(to: markerPath)
            }
        }

        // Write to debug log file
        let debugLogPaths = [
            cacheDirectory?.appendingPathComponent("snapshot_debug.log"),
            URL(fileURLWithPath: "/tmp/snapshot_debug.log")
        ].compactMap { $0 }

        let debugMessage = "[\(timestamp)] snapshot: \(name)\n"
        if let data = debugMessage.data(using: .utf8) {
            for debugLogPath in debugLogPaths {
                do {
                    if let fileHandle = try? FileHandle(forWritingTo: debugLogPath) {
                        fileHandle.seekToEndOfFile()
                        fileHandle.write(data)
                        fileHandle.closeFile()
                        break
                    } else {
                        try data.write(to: debugLogPath)
                        break
                    }
                } catch {
                    continue
                }
            }
        }

        // Verify setupSnapshot was called
        guard let app = self.app else {
            let errorMsg = "XCUIApplication is not set. Please call setupSnapshot(app) before snapshot()."
            NSLog("❌ ERROR: \(errorMsg)")
            print("❌ ERROR: \(errorMsg)")
            XCTFail(errorMsg)
            return
        }

        let appState = app.state.rawValue
        NSLog("🔍 DEBUG: Snapshot.app is set, app state: \(appState)")
        print("🔍 DEBUG: Snapshot.app is set, app state: \(appState)")

        if timeout > 0 {
            waitForLoadingIndicatorToDisappear(within: timeout)
        }

        if Snapshot.waitForAnimations {
            sleep(1) // Waiting for the animation to be finished
        }

        // macOS screenshot capture using XCUIScreen
        let screenshot = XCUIScreen.main.screenshot()
        let image = screenshot.image

        // Get screenshots directory
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
                let fallbackPath = URL(fileURLWithPath: "/tmp/fastlane_screenshots")
                screenshotsDir = fallbackPath
                NSLog("⚠️ Using fallback screenshots directory: \(fallbackPath.path)")
            }
        }

        guard let finalScreenshotsDir = screenshotsDir else {
            let errorMsg = "❌ CRITICAL: Cannot determine screenshots directory - screenshot will not be saved"
            NSLog(errorMsg)
            print(errorMsg)
            return
        }

        // For macOS, we use "Mac" as the device identifier
        let deviceName = "Mac"

        do {
            // Ensure the screenshots directory exists before writing
            let fileManager = FileManager.default
            if !fileManager.fileExists(atPath: finalScreenshotsDir.path) {
                try fileManager.createDirectory(at: finalScreenshotsDir, withIntermediateDirectories: true, attributes: nil)
                NSLog("✅ Created screenshots directory: \(finalScreenshotsDir.path)")
                print("✅ Created screenshots directory: \(finalScreenshotsDir.path)")
            }

            let path = finalScreenshotsDir.appendingPathComponent("\(deviceName)-\(name).png")
            NSLog("🔍 DEBUG: Attempting to save screenshot to: \(path.path)")
            print("🔍 DEBUG: Attempting to save screenshot to: \(path.path)")

            // Save PNG data
            guard let pngData = image.pngRepresentation() else {
                NSLog("❌ Failed to get PNG representation of screenshot")
                print("❌ Failed to get PNG representation of screenshot")
                return
            }

            try pngData.write(to: path, options: .atomic)
            NSLog("✅ Saved screenshot: \(path.lastPathComponent)")
            print("✅ Saved screenshot: \(path.lastPathComponent)")

        } catch let error {
            let errorMsg = "Problem writing screenshot: \(name) to \(finalScreenshotsDir.path)/\(deviceName)-\(name).png"
            NSLog("❌ \(errorMsg)")
            print("❌ \(errorMsg)")
            NSLog("❌ Error: \(error.localizedDescription)")
            print("❌ Error: \(error.localizedDescription)")
        }
    }

    class func waitForLoadingIndicatorToDisappear(within timeout: TimeInterval) {
        // macOS doesn't have the same loading indicators as iOS
        // This is a placeholder for compatibility
    }

    class func getCacheDirectory() throws -> URL {
        let cachePath = "Library/Caches/tools.fastlane"
        let homeDir = URL(fileURLWithPath: NSHomeDirectory())
        let cacheDir = homeDir.appendingPathComponent(cachePath)

        NSLog("🔍 Cache directory path: \(cacheDir.path)")

        // Ensure the cache directory exists
        let fileManager = FileManager.default
        if !fileManager.fileExists(atPath: cacheDir.path) {
            do {
                try fileManager.createDirectory(at: cacheDir, withIntermediateDirectories: true, attributes: nil)
                NSLog("✅ Created cache directory: \(cacheDir.path)")
            } catch {
                NSLog("⚠️ Failed to create cache directory: \(error.localizedDescription)")
            }
        }

        return cacheDir
    }
}

// Extension to convert NSImage to PNG data (macOS-specific)
extension NSImage {
    func pngRepresentation() -> Data? {
        guard let tiffRepresentation = self.tiffRepresentation,
              let bitmapImage = NSBitmapImageRep(data: tiffRepresentation) else {
            return nil
        }
        return bitmapImage.representation(using: .png, properties: [:])
    }
}

// Please don't remove the lines below
// They are used to detect outdated configuration files
// MacSnapshotHelperVersion [1.0]
