//
//  ScreenshotTypes.swift
//  ListAllMac
//
//  Created as part of MACOS_PLAN.md Phase 2: TDD Cycle 1
//  Purpose: Production types for screenshot capture strategy
//

import Foundation
import CoreGraphics

// MARK: - Screenshot Window Protocol

/// Protocol representing a window that can be screenshotted
/// Abstraction allows for dependency injection in tests
protocol ScreenshotWindow {
    var exists: Bool { get }
    var isHittable: Bool { get }
    var frame: CGRect { get }
}

// MARK: - Screenshot Image Protocol

/// Protocol representing a captured screenshot image
protocol ScreenshotImage {
    var size: CGSize { get }
    var data: Data { get }
}

// MARK: - Capture Method

/// Capture method decision
enum CaptureMethod: Equatable {
    case window
    case fullscreen
}

// MARK: - App Content Protocol

/// Protocol for checking app content elements
/// Used to detect SwiftUI bug where window.exists=false but content is present
protocol AppContentQuerying {
    var hasSidebar: Bool { get }
    var hasButtons: Bool { get }
    var hasOutlineRows: Bool { get }
    var hasVisibleContent: Bool { get }
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

// MARK: - Screenshot Result

/// Result of screenshot capture and validation
struct ScreenshotResult {
    let filename: String
    let wasValidated: Bool
    let captureMethod: CaptureMethod
    let imagePath: String?
}

// MARK: - Screenshot Capture Protocol

/// Protocol for capturing screenshots
/// Enables dependency injection for unit testing without real XCUITest
protocol ScreenshotCapturing {
    func captureWindow(_ window: ScreenshotWindow) throws -> ScreenshotImage
    func captureFullScreen() throws -> ScreenshotImage
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
