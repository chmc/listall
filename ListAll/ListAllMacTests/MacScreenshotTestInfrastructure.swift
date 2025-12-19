//
//  MacScreenshotTestInfrastructure.swift
//  ListAllMacTests
//
//  Created as part of MACOS_PLAN.md Phase 0: Test Infrastructure
//  Purpose: Protocols and mocks for dependency injection in screenshot tests
//

import Foundation
import XCTest
import AppKit

// MARK: - AppleScript Execution Protocol

/// Protocol for executing AppleScript commands
/// Enables dependency injection for unit testing without real AppleScript execution
protocol AppleScriptExecuting {
    func execute(script: String, timeout: TimeInterval) throws -> AppleScriptResult
}

/// Result of AppleScript execution
struct AppleScriptResult: Equatable {
    let exitCode: Int
    let stdout: String
    let stderr: String
    let duration: TimeInterval

    static func success(output: String = "", duration: TimeInterval = 0.1) -> AppleScriptResult {
        AppleScriptResult(exitCode: 0, stdout: output, stderr: "", duration: duration)
    }

    static func failure(exitCode: Int, stderr: String, duration: TimeInterval = 0.1) -> AppleScriptResult {
        AppleScriptResult(exitCode: exitCode, stdout: "", stderr: stderr, duration: duration)
    }
}

/// Errors that can occur during AppleScript execution
enum AppleScriptError: Error, Equatable {
    case timeout
    case permissionDenied
    case executionFailed(exitCode: Int, stderr: String)
    case syntaxError

    static func == (lhs: AppleScriptError, rhs: AppleScriptError) -> Bool {
        switch (lhs, rhs) {
        case (.timeout, .timeout): return true
        case (.permissionDenied, .permissionDenied): return true
        case (.syntaxError, .syntaxError): return true
        case (.executionFailed(let l1, let l2), .executionFailed(let r1, let r2)):
            return l1 == r1 && l2 == r2
        default: return false
        }
    }

    /// User-friendly message for TCC errors
    var userMessage: String {
        switch self {
        case .timeout:
            return "AppleScript execution timed out"
        case .permissionDenied:
            return "TCC Automation permissions NOT granted. " +
                   "Fix: System Settings → Privacy & Security → Automation → Enable for Terminal/Xcode"
        case .executionFailed(let exitCode, let stderr):
            return "AppleScript failed with exit code \(exitCode): \(stderr)"
        case .syntaxError:
            return "AppleScript syntax error"
        }
    }
}

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

// MARK: - Screenshot Capture Protocol

/// Protocol for capturing screenshots
/// Enables dependency injection for unit testing without real XCUITest
protocol ScreenshotCapturing {
    func captureWindow(_ window: ScreenshotWindow) throws -> ScreenshotImage
    func captureFullScreen() throws -> ScreenshotImage
}

/// Protocol representing a window that can be screenshotted
protocol ScreenshotWindow {
    var exists: Bool { get }
    var isHittable: Bool { get }
    var frame: CGRect { get }
}

/// Protocol representing a captured screenshot image
protocol ScreenshotImage {
    var size: CGSize { get }
    var data: Data { get }
}

/// Capture method decision
enum CaptureMethod: Equatable {
    case window
    case fullscreen
}

// MARK: - Screenshot Error

/// Errors that can occur during screenshot capture
enum ScreenshotError: Error, Equatable {
    case windowNotAccessible
    case tccPermissionRequired
    case captureTimedOut
    case invalidImageSize(width: CGFloat, height: CGFloat)
    case suspiciousFileSize(bytes: Int)
    case validationFailed(reason: ValidationFailureReason)

    var userMessage: String {
        switch self {
        case .windowNotAccessible:
            return "Window is not accessible for screenshot"
        case .tccPermissionRequired:
            return "TCC Automation permissions NOT granted. " +
                   "Fix: System Settings → Privacy & Security → Automation → Enable for Terminal/Xcode"
        case .captureTimedOut:
            return "Screenshot capture timed out"
        case .invalidImageSize(let width, let height):
            return "Invalid screenshot size: \(width)x\(height). Expected >800x600"
        case .suspiciousFileSize(let bytes):
            return "Suspicious file size: \(bytes) bytes. Screenshot may be blank or corrupt"
        case .validationFailed(let reason):
            return "Screenshot validation failed: \(reason)"
        }
    }
}

/// Reasons for screenshot validation failure
enum ValidationFailureReason: Equatable {
    case tooSmall
    case suspiciousFileSize
    case blankImage
}

// MARK: - Screenshot Validation Result

/// Result of screenshot validation
struct ScreenshotValidationResult: Equatable {
    let isValid: Bool
    let reason: ValidationFailureReason?

    static let valid = ScreenshotValidationResult(isValid: true, reason: nil)

    static func invalid(_ reason: ValidationFailureReason) -> ScreenshotValidationResult {
        ScreenshotValidationResult(isValid: false, reason: reason)
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
class MockXCUIApp {
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
