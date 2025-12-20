//
//  RealScreenshotCapture.swift
//  ListAllMacUITests
//
//  Created as part of MACOS_PLAN.md Phase 4: E2E Refactoring
//  Purpose: Real implementation of ScreenshotCapturing for E2E tests using XCUITest
//

import Foundation
import XCTest
import AppKit

// MARK: - XCUIScreenshot Wrapper

/// Wrapper for XCUIScreenshot that conforms to ScreenshotImage protocol
struct XCUIScreenshotWrapper: ScreenshotImage {
    private let screenshot: XCUIScreenshot
    private let nsImage: NSImage

    init(screenshot: XCUIScreenshot) {
        self.screenshot = screenshot
        self.nsImage = screenshot.image
    }

    var size: CGSize {
        return nsImage.size
    }

    var data: Data {
        // Convert NSImage to PNG data
        // This matches the pattern used in MacSnapshotHelper.swift
        guard let tiffRepresentation = nsImage.tiffRepresentation,
              let bitmapImage = NSBitmapImageRep(data: tiffRepresentation),
              let pngData = bitmapImage.representation(using: .png, properties: [:]) else {
            // Return empty data if conversion fails
            // The validator will catch this as suspicious file size
            return Data()
        }
        return pngData
    }
}

// MARK: - XCUIElement Wrapper

/// Wrapper for XCUIElement that conforms to ScreenshotWindow protocol
struct XCUIElementWrapper: ScreenshotWindow {
    // Internal access so RealScreenshotCapture can access it
    let xcuiElement: XCUIElement

    init(element: XCUIElement) {
        self.xcuiElement = element
    }

    var exists: Bool {
        return xcuiElement.exists
    }

    var isHittable: Bool {
        return xcuiElement.isHittable
    }

    var frame: CGRect {
        return xcuiElement.frame
    }
}

// MARK: - Real Screenshot Capture

/// Real implementation of ScreenshotCapturing using XCUITest APIs
/// This is used in E2E tests to capture actual screenshots
class RealScreenshotCapture: ScreenshotCapturing {

    /// Captures a screenshot of the specified window
    /// - Parameter window: The window to capture (must be XCUIElementWrapper)
    /// - Returns: Screenshot image wrapped in ScreenshotImage protocol
    /// - Throws: ScreenshotError if capture fails
    func captureWindow(_ window: ScreenshotWindow) throws -> ScreenshotImage {
        // Unwrap to get the XCUIElement
        guard let windowWrapper = window as? XCUIElementWrapper else {
            throw ScreenshotError.windowNotAccessible
        }

        // XCUIElement.screenshot() will crash if element doesn't exist
        // Pre-check existence (matches MacSnapshotHelper pattern)
        guard window.exists || window.isHittable else {
            throw ScreenshotError.windowNotAccessible
        }

        // Use XCUIElement's screenshot method
        let screenshot = windowWrapper.xcuiElement.screenshot()
        return XCUIScreenshotWrapper(screenshot: screenshot)
    }

    /// Captures a full-screen screenshot
    /// - Returns: Screenshot image wrapped in ScreenshotImage protocol
    /// - Throws: ScreenshotError if capture fails
    func captureFullScreen() throws -> ScreenshotImage {
        // Use XCUIScreen.main.screenshot() for full-screen capture
        // This matches MacSnapshotHelper.swift line 246
        let screenshot = XCUIScreen.main.screenshot()
        return XCUIScreenshotWrapper(screenshot: screenshot)
    }
}

// MARK: - XCUIElementWrapper Extension for XCUIElement

extension XCUIElement {
    /// Convenience wrapper to convert XCUIElement to ScreenshotWindow
    var asScreenshotWindow: ScreenshotWindow {
        return XCUIElementWrapper(element: self)
    }
}
