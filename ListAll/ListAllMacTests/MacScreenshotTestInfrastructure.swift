//
//  MacScreenshotTestInfrastructure.swift
//  ListAllMacTests
//
//  Created as part of MACOS_PLAN.md Phase 0: Test Infrastructure
//  Purpose: Mocks for dependency injection in screenshot tests
//

import Foundation
import XCTest
import AppKit
@testable import ListAll

// Note: Production types (ScreenshotWindow, ScreenshotImage, CaptureMethod, etc.) are defined in
// ListAllMac/Services/Screenshots/ScreenshotTypes.swift
// AppleScriptExecuting, AppleScriptResult, and AppleScriptError are defined in
// ListAllMac/Services/Screenshots/AppleScriptProtocols.swift
// They are imported via @testable import ListAll

// MARK: - Workspace Query Protocol

/// Protocol for querying running applications
/// Enables dependency injection for unit testing without real NSWorkspace
protocol WorkspaceQuerying {
    func runningApplications() -> [RunningApp]
}

/// Representation of a running application
struct RunningApp: Equatable {
    let bundleIdentifier: String?
    let localizedName: String?
    let activationPolicy: Int  // NSApplication.ActivationPolicy.rawValue

    /// Check if this is a regular (visible) application
    var isRegularApp: Bool {
        activationPolicy == 0  // NSApplication.ActivationPolicy.regular.rawValue
    }
}

// MARK: - Mock Implementations

/// Mock AppleScript executor for unit testing
class MockAppleScriptExecutor: AppleScriptExecuting {
    var scriptToExecute: String?
    var resultToReturn = AppleScriptResult.success()
    var errorToThrow: Error?
    var executeCallCount = 0

    func execute(script: String, timeout: TimeInterval) throws -> AppleScriptResult {
        executeCallCount += 1
        scriptToExecute = script
        if let error = errorToThrow { throw error }
        return resultToReturn
    }

    func reset() {
        scriptToExecute = nil
        resultToReturn = AppleScriptResult.success()
        errorToThrow = nil
        executeCallCount = 0
    }
}

/// Mock workspace for unit testing
class MockWorkspace: WorkspaceQuerying {
    var runningApps: [RunningApp] = []
    var runningApplicationsCallCount = 0

    func runningApplications() -> [RunningApp] {
        runningApplicationsCallCount += 1
        return runningApps
    }

    func reset() {
        runningApps = []
        runningApplicationsCallCount = 0
    }

    /// Helper to add a mock regular app
    func addRegularApp(bundleId: String, name: String) {
        runningApps.append(RunningApp(
            bundleIdentifier: bundleId,
            localizedName: name,
            activationPolicy: 0
        ))
    }

    /// Helper to add a mock background app
    func addBackgroundApp(bundleId: String, name: String) {
        runningApps.append(RunningApp(
            bundleIdentifier: bundleId,
            localizedName: name,
            activationPolicy: 1
        ))
    }
}

/// Mock screenshot window for unit testing
class MockScreenshotWindow: ScreenshotWindow {
    var exists: Bool
    var isHittable: Bool
    var frame: CGRect

    init(exists: Bool = false, isHittable: Bool = false,
         frame: CGRect = CGRect(x: 0, y: 0, width: 1200, height: 800)) {
        self.exists = exists
        self.isHittable = isHittable
        self.frame = frame
    }

    static func accessible(frame: CGRect = CGRect(x: 0, y: 0, width: 1200, height: 800)) -> MockScreenshotWindow {
        MockScreenshotWindow(exists: true, isHittable: true, frame: frame)
    }

    static func inaccessible() -> MockScreenshotWindow {
        MockScreenshotWindow(exists: false, isHittable: false)
    }
}

/// Mock screenshot image for unit testing
class MockScreenshotImage: ScreenshotImage {
    var size: CGSize
    var data: Data

    init(size: CGSize = CGSize(width: 2880, height: 1800),
         isBlank: Bool = false,
         fileSize: Int = 100000) {
        self.size = size
        // For blank images, create minimal data; otherwise create data of specified size
        if isBlank {
            self.data = Data(count: 100)
        } else {
            self.data = Data(count: fileSize)
        }
    }

    static func valid(width: CGFloat = 2880, height: CGFloat = 1800) -> MockScreenshotImage {
        MockScreenshotImage(size: CGSize(width: width, height: height), fileSize: 500000)
    }

    static func tooSmall() -> MockScreenshotImage {
        MockScreenshotImage(size: CGSize(width: 50, height: 30), fileSize: 1000)
    }

    static func blank(width: CGFloat = 2880, height: CGFloat = 1800) -> MockScreenshotImage {
        MockScreenshotImage(size: CGSize(width: width, height: height), isBlank: true)
    }

    static func suspicious(width: CGFloat = 2880, height: CGFloat = 1800) -> MockScreenshotImage {
        // Large dimensions but tiny file size = likely corrupt
        MockScreenshotImage(size: CGSize(width: width, height: height), fileSize: 500)
    }
}

/// Mock screenshot capture for unit testing
class MockScreenshotCapture: ScreenshotCapturing {
    var captureMethodUsed: CaptureMethod?
    var windowImage: ScreenshotImage = MockScreenshotImage.valid()
    var fullscreenImage: ScreenshotImage = MockScreenshotImage.valid()
    var windowError: Error?
    var fullscreenError: Error?
    var captureWindowCallCount = 0
    var captureFullScreenCallCount = 0

    func captureWindow(_ window: ScreenshotWindow) throws -> ScreenshotImage {
        captureWindowCallCount += 1
        captureMethodUsed = .window
        if let error = windowError { throw error }
        return windowImage
    }

    func captureFullScreen() throws -> ScreenshotImage {
        captureFullScreenCallCount += 1
        captureMethodUsed = .fullscreen
        if let error = fullscreenError { throw error }
        return fullscreenImage
    }

    func reset() {
        captureMethodUsed = nil
        windowImage = MockScreenshotImage.valid()
        fullscreenImage = MockScreenshotImage.valid()
        windowError = nil
        fullscreenError = nil
        captureWindowCallCount = 0
        captureFullScreenCallCount = 0
    }
}

// MARK: - XCUIApplication Mock Support

/// Mock XCUIApplication-like element for testing
/// Implements AppContentQuerying for use with WindowCaptureStrategy
class MockXCUIApp: AppContentQuerying {
    var hasSidebar: Bool
    var hasButtons: Bool
    var hasOutlineRows: Bool

    init(hasSidebar: Bool = false, hasButtons: Bool = false, hasOutlineRows: Bool = false) {
        self.hasSidebar = hasSidebar
        self.hasButtons = hasButtons
        self.hasOutlineRows = hasOutlineRows
    }

    /// Check if app has visible content elements
    var hasVisibleContent: Bool {
        hasSidebar || hasButtons || hasOutlineRows
    }
}
