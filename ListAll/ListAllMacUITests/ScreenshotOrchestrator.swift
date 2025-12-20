//
//  ScreenshotOrchestrator.swift
//  ListAllMac
//
//  Created as part of MACOS_PLAN.md Phase 3: Integration Tests
//  Purpose: Coordinate screenshot capture with app hiding, validation
//  TDD Phase: GREEN - Implementation to pass all 20 integration tests
//

import Foundation

/// Orchestrates the full screenshot capture flow:
/// 1. Hide background apps via AppleScript
/// 2. Capture screenshot (window or fullscreen)
/// 3. Validate the captured image
///
/// Responsibilities:
/// - Coordinate AppHidingScriptGenerator + AppleScriptExecuting
/// - Use WindowCaptureStrategy to decide capture method
/// - Use ScreenshotValidator to validate captured images
/// - Convert AppleScriptError to ScreenshotError appropriately
/// - Support retry logic for transient failures
///
/// Note: Not marked as Sendable or @MainActor to avoid Swift concurrency inference issues
/// that cause crashes during test cleanup on background threads
final class ScreenshotOrchestrator {

    // MARK: - Dependencies

    private let scriptExecutor: AppleScriptExecuting
    private let captureStrategy: WindowCaptureStrategy
    private let validator: ScreenshotValidator
    private let workspace: WorkspaceQuerying
    private let screenshotCapture: ScreenshotCapturing
    private let scriptGenerator: AppHidingScriptGenerator
    private let retryCount: Int
    private let defaultTimeout: TimeInterval = 30.0

    // MARK: - Initialization

    init(
        scriptExecutor: AppleScriptExecuting,
        captureStrategy: WindowCaptureStrategy,
        validator: ScreenshotValidator,
        workspace: WorkspaceQuerying,
        screenshotCapture: ScreenshotCapturing,
        retryCount: Int = 0
    ) {
        self.scriptExecutor = scriptExecutor
        self.captureStrategy = captureStrategy
        self.validator = validator
        self.workspace = workspace
        self.screenshotCapture = screenshotCapture
        self.scriptGenerator = AppHidingScriptGenerator()
        self.retryCount = retryCount
    }

    // MARK: - Public API

    /// Hide background apps before taking screenshot
    /// - Parameters:
    ///   - excluding: App names to exclude from hiding
    ///   - timeout: Maximum time to wait for AppleScript
    /// - Throws: AppleScriptError if script fails or times out
    ///           ScreenshotError.tccPermissionRequired if TCC permissions denied
    func hideBackgroundApps(excluding: [String] = [], timeout: TimeInterval? = nil) throws {
        let timeoutToUse = timeout ?? defaultTimeout

        // Generate the hide script
        let script = scriptGenerator.generateHideScript(excludedApps: excluding)

        // Execute with retry logic, but NOT for TCC errors
        var lastError: Error?
        let maxAttempts = retryCount + 1

        for attempt in 1...maxAttempts {
            do {
                _ = try scriptExecutor.execute(script: script, timeout: timeoutToUse)
                return // Success
            } catch let error as AppleScriptError {
                lastError = error

                // Convert TCC permission errors to ScreenshotError
                if case .permissionDenied = error {
                    throw ScreenshotError.tccPermissionRequired
                }

                // Don't retry on timeout or syntax errors
                if case .timeout = error {
                    throw error
                }
                if case .syntaxError = error {
                    throw error
                }

                // Retry transient execution failures (but not on last attempt)
                if attempt < maxAttempts {
                    continue
                } else {
                    throw error
                }
            } catch {
                lastError = error
                throw error
            }
        }

        // If we get here, all retries failed
        if let error = lastError {
            throw error
        }
    }

    /// Capture screenshot with optional window
    /// - Parameters:
    ///   - window: Window to capture, or nil for fullscreen
    ///   - fallbackToFullscreen: If true, use fullscreen when window unavailable
    /// - Returns: Screenshot result
    /// - Throws: ScreenshotError if capture fails
    func captureScreenshot(
        window: ScreenshotWindow?,
        fallbackToFullscreen: Bool = true
    ) throws -> ScreenshotResult {
        // Decide capture method
        let method = captureStrategy.decideCaptureMethod(window: window)

        // If method is fullscreen but fallback not allowed, throw error
        if method == .fullscreen && !fallbackToFullscreen {
            throw ScreenshotError.windowNotAccessible
        }

        // Capture the screenshot
        let image: ScreenshotImage
        switch method {
        case .window:
            guard let window = window else {
                throw ScreenshotError.windowNotAccessible
            }
            image = try screenshotCapture.captureWindow(window)
        case .fullscreen:
            image = try screenshotCapture.captureFullScreen()
        }

        // Validate the screenshot
        let validationResult = validator.validate(image: image)
        if !validationResult.isValid {
            if let reason = validationResult.reason {
                throw ScreenshotError.validationFailed(reason: reason)
            }
        }

        // Return result (mock implementation - no actual file path)
        return ScreenshotResult(
            filename: "screenshot.png",
            wasValidated: true,
            captureMethod: method,
            imagePath: nil
        )
    }

    /// Capture and validate screenshot in one operation
    /// - Parameters:
    ///   - named: Screenshot name (without extension)
    ///   - window: Window to capture
    ///   - fallbackToFullscreen: If true, use fullscreen when window unavailable
    /// - Returns: Screenshot result with validation
    /// - Throws: ScreenshotError if capture or validation fails
    func captureAndValidate(
        named: String,
        window: ScreenshotWindow?,
        fallbackToFullscreen: Bool = true
    ) throws -> ScreenshotResult {
        // Step 1: Hide background apps
        do {
            try hideBackgroundApps()
        } catch let error as AppleScriptError {
            // Convert TCC permission errors
            if case .permissionDenied = error {
                throw ScreenshotError.tccPermissionRequired
            }
            // Propagate other AppleScript errors
            throw error
        }

        // Step 2: Capture and validate screenshot
        var result = try captureScreenshot(window: window, fallbackToFullscreen: fallbackToFullscreen)

        // Step 3: Update filename with Mac prefix
        result = ScreenshotResult(
            filename: "Mac-\(named).png",
            wasValidated: result.wasValidated,
            captureMethod: result.captureMethod,
            imagePath: result.imagePath
        )

        return result
    }
}
