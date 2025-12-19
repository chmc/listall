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

    /// Telemetry: tracks which capture method was used for each screenshot
    /// Key: screenshot name, Value: "window" or "fullscreen"
    static var screenshotStats: [String: String] = [:]

    /// Log telemetry summary at end of test run
    class func logScreenshotStats() {
        let windowCount = screenshotStats.values.filter { $0 == "window" }.count
        let fullscreenCount = screenshotStats.values.filter { $0 == "fullscreen" }.count
        let total = screenshotStats.count

        NSLog("[macOS] Screenshot stats: window=\(windowCount)/\(total), fullscreen=\(fullscreenCount)/\(total)")

        if fullscreenCount > windowCount && total > 0 {
            NSLog("[macOS] WARNING: Fullscreen fallback used more than window capture - consider investigating")
        }
    }

    open class func setupSnapshot(_ app: XCUIApplication, waitForAnimations: Bool = true) {
        NSLog("[macOS] setupSnapshot() called")

        Snapshot.app = app
        Snapshot.waitForAnimations = waitForAnimations
        screenshotStats = [:]  // Reset telemetry for this test run

        do {
            let cacheDir = try getCacheDirectory()
            Snapshot.cacheDirectory = cacheDir

            // Ensure directories exist
            let fileManager = FileManager.default
            if !fileManager.fileExists(atPath: cacheDir.path) {
                try fileManager.createDirectory(at: cacheDir, withIntermediateDirectories: true, attributes: nil)
            }

            if let screenshotsDir = screenshotsDirectory {
                if !fileManager.fileExists(atPath: screenshotsDir.path) {
                    try fileManager.createDirectory(at: screenshotsDir, withIntermediateDirectories: true, attributes: nil)
                }
                NSLog("[macOS] Screenshots directory: \(screenshotsDir.path)")
            }

            setLanguage(app)
            setLocale(app)
            setLaunchArguments(app)

            NSLog("[macOS] setupSnapshot() completed")
        } catch let error {
            NSLog("[macOS] setupSnapshot() failed: \(error.localizedDescription)")

            // Try fallback directory
            let fallbackCache = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("fastlane_screenshots")
            do {
                try FileManager.default.createDirectory(at: fallbackCache, withIntermediateDirectories: true, attributes: nil)
                Snapshot.cacheDirectory = fallbackCache
                NSLog("[macOS] Using fallback cache: \(fallbackCache.path)")
            } catch {
                NSLog("[macOS] CRITICAL: Could not create fallback cache directory")
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
        // Log for Fastlane to detect snapshot calls
        NSLog("snapshot: \(name)")

        // Verify setupSnapshot was called
        guard let app = self.app else {
            NSLog("[macOS] ERROR: XCUIApplication not set. Call setupSnapshot(app) first.")
            XCTFail("XCUIApplication is not set")
            return
        }

        if timeout > 0 {
            waitForLoadingIndicatorToDisappear(within: timeout)
        }

        if Snapshot.waitForAnimations {
            sleep(1) // Waiting for the animation to be finished
        }

        // macOS screenshot capture with window-first strategy and full-screen fallback
        // CRITICAL: XCUIElement.screenshot() crashes if element doesn't exist - must pre-check
        guard let app = self.app else {
            NSLog("[macOS] ERROR: XCUIApplication is not set")
            return
        }

        // Step 1: Activate app and wait for UI to stabilize
        app.activate()
        sleep(2)

        // Step 2: Verify content elements exist (proves window is in accessibility hierarchy)
        let sidebar = app.outlines.firstMatch
        let contentAccessible = sidebar.waitForExistence(timeout: 10)

        // Step 3: Check window accessibility for screenshot method decision
        let mainWindow = app.windows.firstMatch
        let windowAccessible = mainWindow.exists || mainWindow.isHittable

        NSLog("[macOS] Screenshot '\(name)': content=\(contentAccessible), window.exists=\(mainWindow.exists), window.isHittable=\(mainWindow.isHittable)")

        // Step 4: Capture screenshot using appropriate method
        let image: NSImage
        var captureMethod: String

        if windowAccessible {
            // Window is accessible - capture window only (preferred, clean without background apps)
            app.activate()
            sleep(1)
            let screenshot = mainWindow.screenshot()
            image = screenshot.image
            captureMethod = "window"
            NSLog("[macOS] SUCCESS: Window-only screenshot captured (\(image.size))")
        } else {
            // Window not accessible - use full-screen fallback
            // Full-screen captures the screen region, may include background apps
            NSLog("[macOS] Window not accessible, using full-screen fallback")
            app.activate()
            sleep(1)
            let screenshot = XCUIScreen.main.screenshot()
            image = screenshot.image
            captureMethod = "fullscreen"
            NSLog("[macOS] Full-screen screenshot captured (\(image.size))")
        }

        // Track telemetry for method analysis
        screenshotStats[name] = captureMethod

        // Get screenshots directory
        var screenshotsDir: URL?
        if let dir = screenshotsDirectory {
            screenshotsDir = dir
        } else {
            // Fallback: Try to recreate cache directory
            do {
                let fallbackCacheDir = try getCacheDirectory()
                screenshotsDir = fallbackCacheDir.appendingPathComponent("screenshots", isDirectory: true)
                Snapshot.cacheDirectory = fallbackCacheDir
            } catch {
                screenshotsDir = URL(fileURLWithPath: "/tmp/fastlane_screenshots")
            }
        }

        guard let finalScreenshotsDir = screenshotsDir else {
            NSLog("[macOS] CRITICAL: Cannot determine screenshots directory")
            return
        }

        // For macOS, we use "Mac" as the device identifier
        let deviceName = "Mac"

        do {
            // Ensure the screenshots directory exists before writing
            let fileManager = FileManager.default
            if !fileManager.fileExists(atPath: finalScreenshotsDir.path) {
                try fileManager.createDirectory(at: finalScreenshotsDir, withIntermediateDirectories: true, attributes: nil)
            }

            let path = finalScreenshotsDir.appendingPathComponent("\(deviceName)-\(name).png")

            // Save PNG data
            guard let pngData = image.pngRepresentation() else {
                NSLog("[macOS] Failed to get PNG representation")
                return
            }

            try pngData.write(to: path, options: .atomic)
            NSLog("[macOS] Saved: \(path.lastPathComponent)")

        } catch let error {
            NSLog("[macOS] Failed to save '\(name)': \(error.localizedDescription)")
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

        // Ensure the cache directory exists
        let fileManager = FileManager.default
        if !fileManager.fileExists(atPath: cacheDir.path) {
            try fileManager.createDirectory(at: cacheDir, withIntermediateDirectories: true, attributes: nil)
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
// MacSnapshotHelperVersion [1.1]
