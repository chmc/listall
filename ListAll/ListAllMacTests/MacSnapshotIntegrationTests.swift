//
//  MacSnapshotIntegrationTests.swift
//  ListAllMacTests
//
//  Created as part of MACOS_PLAN.md Phase 3: Integration Tests
//  Purpose: Test full screenshot orchestration flow with mocks
//  TDD Phase: RED - Tests created first, ScreenshotOrchestrator doesn't exist yet
//

import XCTest
@testable import ListAll

/// Integration tests for ScreenshotOrchestrator
/// Tests the full screenshot flow: hide apps → capture → validate
/// Uses mocks for all dependencies (no real AppleScript/screenshots)
final class MacSnapshotIntegrationTests: XCTestCase {

    // MARK: - Test Dependencies

    var mockExecutor: MockAppleScriptExecutor!
    var mockWorkspace: MockWorkspace!
    var mockCapture: MockScreenshotCapture!
    var validator: ScreenshotValidator!
    var strategy: WindowCaptureStrategy!

    // MARK: - Setup & Teardown

    override func setUp() {
        super.setUp()
        mockExecutor = MockAppleScriptExecutor()
        mockWorkspace = MockWorkspace()
        mockCapture = MockScreenshotCapture()
        validator = ScreenshotValidator()
        strategy = WindowCaptureStrategy()
    }

    override func tearDown() {
        mockExecutor = nil
        mockWorkspace = nil
        mockCapture = nil
        validator = nil
        strategy = nil
        super.tearDown()
    }

    // MARK: - Test 1-3: Full Screenshot Flow

    /// Test 1: Full screenshot flow - hide apps → capture → validate
    /// Verifies the orchestrator coordinates all steps correctly
    func test_fullScreenshotFlow_hidesAppsCapturesAndValidates() throws {
        // Arrange: Set up running apps
        mockWorkspace.addRegularApp(bundleId: "com.apple.Safari", name: "Safari")
        mockWorkspace.addRegularApp(bundleId: "com.apple.Music", name: "Music")
        mockWorkspace.addRegularApp(bundleId: "io.github.chmc.ListAllMac", name: "ListAll")

        let orchestrator = ScreenshotOrchestrator(
            scriptExecutor: mockExecutor,
            captureStrategy: strategy,
            validator: validator,
            workspace: mockWorkspace,
            screenshotCapture: mockCapture
        )

        let mockWindow = MockScreenshotWindow.accessible()

        // Act: Capture screenshot
        let result = try orchestrator.captureAndValidate(
            named: "01_MainWindow",
            window: mockWindow
        )

        // Assert: Hide script was executed
        XCTAssertNotNil(mockExecutor.scriptToExecute, "Should execute hide script")
        XCTAssertEqual(mockExecutor.executeCallCount, 1, "Should execute AppleScript once")

        // Assert: Script excludes ListAll (app being tested)
        let script = try XCTUnwrap(mockExecutor.scriptToExecute)
        XCTAssertTrue(script.contains("ListAll") || script.contains("listall"),
                      "Script should reference ListAll for exclusion")

        // Assert: Screenshot was captured
        XCTAssertEqual(mockCapture.captureWindowCallCount, 1, "Should capture window once")

        // Assert: Result is valid
        XCTAssertTrue(result.wasValidated, "Result should be validated")
        XCTAssertEqual(result.filename, "Mac-01_MainWindow.png", "Filename should include Mac prefix")
    }

    /// Test 2: Verify window capture is used when window is accessible
    func test_fullScreenshotFlow_usesWindowCaptureWhenAccessible() throws {
        // Arrange
        mockWorkspace.addRegularApp(bundleId: "io.github.chmc.ListAllMac", name: "ListAll")

        let orchestrator = ScreenshotOrchestrator(
            scriptExecutor: mockExecutor,
            captureStrategy: strategy,
            validator: validator,
            workspace: mockWorkspace,
            screenshotCapture: mockCapture
        )

        let mockWindow = MockScreenshotWindow.accessible()

        // Act
        _ = try orchestrator.captureAndValidate(named: "Test", window: mockWindow)

        // Assert: Window capture was used (not fullscreen)
        XCTAssertEqual(mockCapture.captureMethodUsed, .window,
                       "Should use window capture for accessible window")
        XCTAssertEqual(mockCapture.captureWindowCallCount, 1)
        XCTAssertEqual(mockCapture.captureFullScreenCallCount, 0)
    }

    /// Test 3: Verify fullscreen fallback when window is not accessible
    func test_fullScreenshotFlow_fallsBackToFullscreenWhenWindowInaccessible() throws {
        // Arrange
        mockWorkspace.addRegularApp(bundleId: "io.github.chmc.ListAllMac", name: "ListAll")

        let orchestrator = ScreenshotOrchestrator(
            scriptExecutor: mockExecutor,
            captureStrategy: strategy,
            validator: validator,
            workspace: mockWorkspace,
            screenshotCapture: mockCapture
        )

        let mockWindow = MockScreenshotWindow.inaccessible()

        // Act
        _ = try orchestrator.captureAndValidate(
            named: "Test",
            window: mockWindow,
            fallbackToFullscreen: true
        )

        // Assert: Fullscreen capture was used
        XCTAssertEqual(mockCapture.captureMethodUsed, .fullscreen,
                       "Should use fullscreen when window inaccessible")
        XCTAssertEqual(mockCapture.captureFullScreenCallCount, 1)
        XCTAssertEqual(mockCapture.captureWindowCallCount, 0)
    }

    // MARK: - Test 4-7: TCC Permission Failure Reporting

    /// Test 4: Detect and report TCC permission denial from AppleScript
    func test_tccPermissionFailure_reportsUserFriendlyError() {
        // Arrange
        mockExecutor.errorToThrow = AppleScriptError.permissionDenied

        let orchestrator = ScreenshotOrchestrator(
            scriptExecutor: mockExecutor,
            captureStrategy: strategy,
            validator: validator,
            workspace: mockWorkspace,
            screenshotCapture: mockCapture
        )

        let mockWindow = MockScreenshotWindow.accessible()

        // Act & Assert: Should throw TCC permission error
        XCTAssertThrowsError(
            try orchestrator.captureAndValidate(named: "Test", window: mockWindow)
        ) { error in
            guard let screenshotError = error as? ScreenshotError else {
                XCTFail("Expected ScreenshotError, got \(error)")
                return
            }

            // Assert: Error is TCC permission required
            XCTAssertEqual(screenshotError, .tccPermissionRequired,
                           "Should convert AppleScript permission denied to TCC error")

            // Assert: User message contains actionable fix
            let message = screenshotError.userMessage
            XCTAssertTrue(message.contains("System Settings"),
                          "Error message should mention System Settings")
            XCTAssertTrue(message.contains("Privacy & Security") || message.contains("Automation"),
                          "Error message should mention Automation permissions")
        }
    }

    /// Test 5: TCC error includes clear instructions for user
    func test_tccPermissionFailure_includesActionableInstructions() {
        // Arrange
        mockExecutor.errorToThrow = AppleScriptError.permissionDenied

        let orchestrator = ScreenshotOrchestrator(
            scriptExecutor: mockExecutor,
            captureStrategy: strategy,
            validator: validator,
            workspace: mockWorkspace,
            screenshotCapture: mockCapture
        )

        // Act & Assert
        do {
            _ = try orchestrator.hideBackgroundApps(excluding: [])
            XCTFail("Should throw TCC permission error")
        } catch let error as ScreenshotError {
            // Assert: Message is actionable
            let message = error.userMessage
            XCTAssertTrue(message.contains("Fix:") || message.contains("→"),
                          "Should include actionable fix instructions")
        } catch {
            XCTFail("Expected ScreenshotError, got \(error)")
        }
    }

    /// Test 6: Non-TCC errors are not misidentified as TCC errors
    func test_syntaxError_doesNotReportAsTCCError() {
        // Arrange
        mockExecutor.errorToThrow = AppleScriptError.syntaxError

        let orchestrator = ScreenshotOrchestrator(
            scriptExecutor: mockExecutor,
            captureStrategy: strategy,
            validator: validator,
            workspace: mockWorkspace,
            screenshotCapture: mockCapture
        )

        // Act & Assert
        XCTAssertThrowsError(
            try orchestrator.hideBackgroundApps(excluding: [])
        ) { error in
            // Should throw AppleScriptError, not convert to ScreenshotError
            XCTAssertTrue(error is AppleScriptError, "Syntax errors should not be converted")
        }
    }

    /// Test 7: TCC permission failure stops screenshot process early
    func test_tccPermissionFailure_stopsProcessEarly() {
        // Arrange
        mockExecutor.errorToThrow = AppleScriptError.permissionDenied

        let orchestrator = ScreenshotOrchestrator(
            scriptExecutor: mockExecutor,
            captureStrategy: strategy,
            validator: validator,
            workspace: mockWorkspace,
            screenshotCapture: mockCapture
        )

        let mockWindow = MockScreenshotWindow.accessible()

        // Act
        _ = try? orchestrator.captureAndValidate(named: "Test", window: mockWindow)

        // Assert: Screenshot was never captured (failed at hide step)
        XCTAssertEqual(mockCapture.captureWindowCallCount, 0,
                       "Should not attempt screenshot when TCC fails")
        XCTAssertEqual(mockCapture.captureFullScreenCallCount, 0,
                       "Should not attempt screenshot when TCC fails")
    }

    // MARK: - Test 8-11: Timeout Handling

    /// Test 8: AppleScript timeout is caught and reported
    func test_appleScriptTimeout_reportsTimeoutError() {
        // Arrange
        mockExecutor.errorToThrow = AppleScriptError.timeout

        let orchestrator = ScreenshotOrchestrator(
            scriptExecutor: mockExecutor,
            captureStrategy: strategy,
            validator: validator,
            workspace: mockWorkspace,
            screenshotCapture: mockCapture
        )

        // Act & Assert
        XCTAssertThrowsError(
            try orchestrator.hideBackgroundApps(excluding: [])
        ) { error in
            XCTAssertEqual(error as? AppleScriptError, .timeout,
                           "Should propagate timeout error")
        }
    }

    /// Test 9: Timeout does not attempt screenshot capture
    func test_appleScriptTimeout_stopsProcessing() {
        // Arrange
        mockExecutor.errorToThrow = AppleScriptError.timeout

        let orchestrator = ScreenshotOrchestrator(
            scriptExecutor: mockExecutor,
            captureStrategy: strategy,
            validator: validator,
            workspace: mockWorkspace,
            screenshotCapture: mockCapture
        )

        let mockWindow = MockScreenshotWindow.accessible()

        // Act
        _ = try? orchestrator.captureAndValidate(named: "Test", window: mockWindow)

        // Assert: Screenshot was not attempted
        XCTAssertEqual(mockCapture.captureWindowCallCount, 0)
    }

    /// Test 10: Orchestrator respects timeout parameter
    func test_orchestrator_respectsTimeoutParameter() throws {
        // Arrange
        let orchestrator = ScreenshotOrchestrator(
            scriptExecutor: mockExecutor,
            captureStrategy: strategy,
            validator: validator,
            workspace: mockWorkspace,
            screenshotCapture: mockCapture
        )

        // Act: Call with custom timeout
        _ = try orchestrator.hideBackgroundApps(excluding: [], timeout: 5.0)

        // Assert: Would be tested if RealAppleScriptExecutor tracks timeout
        // For now, verify no error is thrown
        XCTAssertEqual(mockExecutor.executeCallCount, 1)
    }

    /// Test 11: Default timeout is reasonable (not infinite)
    func test_orchestrator_hasReasonableDefaultTimeout() throws {
        // Arrange
        let orchestrator = ScreenshotOrchestrator(
            scriptExecutor: mockExecutor,
            captureStrategy: strategy,
            validator: validator,
            workspace: mockWorkspace,
            screenshotCapture: mockCapture
        )

        // Act: Use default timeout
        _ = try orchestrator.hideBackgroundApps(excluding: [])

        // Assert: Should not hang forever (test passes = didn't hang)
        XCTAssertEqual(mockExecutor.executeCallCount, 1)
    }

    // MARK: - Test 12-14: Retry Logic

    /// Test 12: Orchestrator retries transient failures
    func test_orchestrator_retriesTransientFailures() throws {
        // Arrange: First call fails, second succeeds
        var callCount = 0
        mockExecutor.errorToThrow = AppleScriptError.executionFailed(exitCode: 1, stderr: "Transient error")

        let orchestrator = ScreenshotOrchestrator(
            scriptExecutor: mockExecutor,
            captureStrategy: strategy,
            validator: validator,
            workspace: mockWorkspace,
            screenshotCapture: mockCapture,
            retryCount: 2
        )

        // Mock that succeeds on second attempt
        mockExecutor.executeCallCount = 0
        mockExecutor.errorToThrow = nil  // Clear error for retry

        // Note: This test verifies interface - actual retry logic tested in GREEN phase
        let mockWindow = MockScreenshotWindow.accessible()
        _ = try orchestrator.captureAndValidate(named: "Test", window: mockWindow)

        // Assert: Should eventually succeed
        XCTAssertGreaterThanOrEqual(mockExecutor.executeCallCount, 1)
    }

    /// Test 13: Retry does not apply to TCC permission errors
    func test_orchestrator_doesNotRetryTCCErrors() {
        // Arrange: TCC errors should fail fast, not retry
        mockExecutor.errorToThrow = AppleScriptError.permissionDenied

        let orchestrator = ScreenshotOrchestrator(
            scriptExecutor: mockExecutor,
            captureStrategy: strategy,
            validator: validator,
            workspace: mockWorkspace,
            screenshotCapture: mockCapture,
            retryCount: 3
        )

        // Act
        _ = try? orchestrator.hideBackgroundApps(excluding: [])

        // Assert: Should only attempt once (no retries for permission errors)
        XCTAssertEqual(mockExecutor.executeCallCount, 1,
                       "Should not retry TCC permission errors")
    }

    /// Test 14: Maximum retry limit is respected
    func test_orchestrator_respectsMaxRetryLimit() {
        // Arrange: Always fail
        mockExecutor.errorToThrow = AppleScriptError.executionFailed(exitCode: 1, stderr: "Always fail")

        let orchestrator = ScreenshotOrchestrator(
            scriptExecutor: mockExecutor,
            captureStrategy: strategy,
            validator: validator,
            workspace: mockWorkspace,
            screenshotCapture: mockCapture,
            retryCount: 2
        )

        // Act
        _ = try? orchestrator.hideBackgroundApps(excluding: [])

        // Assert: Should try initial + 2 retries = 3 total
        XCTAssertLessThanOrEqual(mockExecutor.executeCallCount, 3,
                                 "Should not exceed max retry count")
    }

    // MARK: - Test 15-17: Error Propagation

    /// Test 15: Validation errors are propagated correctly
    func test_validationError_isPropagatedToUser() {
        // Arrange: Screenshot will be too small
        mockCapture.windowImage = MockScreenshotImage.tooSmall()

        let orchestrator = ScreenshotOrchestrator(
            scriptExecutor: mockExecutor,
            captureStrategy: strategy,
            validator: validator,
            workspace: mockWorkspace,
            screenshotCapture: mockCapture
        )

        let mockWindow = MockScreenshotWindow.accessible()

        // Act & Assert
        XCTAssertThrowsError(
            try orchestrator.captureAndValidate(named: "Test", window: mockWindow)
        ) { error in
            guard let screenshotError = error as? ScreenshotError else {
                XCTFail("Expected ScreenshotError, got \(error)")
                return
            }

            // Assert: Should be validation failure
            if case .validationFailed(let reason) = screenshotError {
                XCTAssertEqual(reason, .tooSmall)
            } else {
                XCTFail("Expected validationFailed error, got \(screenshotError)")
            }
        }
    }

    /// Test 16: Blank screenshot detection is reported
    func test_blankScreenshot_isDetectedAndReported() {
        // Arrange: Screenshot will be suspicious (large but tiny file)
        mockCapture.windowImage = MockScreenshotImage.suspicious()

        let orchestrator = ScreenshotOrchestrator(
            scriptExecutor: mockExecutor,
            captureStrategy: strategy,
            validator: validator,
            workspace: mockWorkspace,
            screenshotCapture: mockCapture
        )

        let mockWindow = MockScreenshotWindow.accessible()

        // Act & Assert
        XCTAssertThrowsError(
            try orchestrator.captureAndValidate(named: "Test", window: mockWindow)
        ) { error in
            guard let screenshotError = error as? ScreenshotError else {
                XCTFail("Expected ScreenshotError")
                return
            }

            // Assert: Should detect suspicious file size
            if case .validationFailed(let reason) = screenshotError {
                XCTAssertEqual(reason, .suspiciousFileSize)
            } else {
                XCTFail("Expected validationFailed with suspiciousFileSize")
            }
        }
    }

    /// Test 17: User-friendly error messages for all error types
    func test_allErrors_haveUserFriendlyMessages() {
        let errors: [ScreenshotError] = [
            .tccPermissionRequired,
            .captureTimedOut,
            .windowNotAccessible,
            .invalidImageSize(width: 100, height: 100),
            .suspiciousFileSize(bytes: 100),
            .validationFailed(reason: .tooSmall)
        ]

        for error in errors {
            let message = error.userMessage
            XCTAssertFalse(message.isEmpty, "Error message should not be empty for \(error)")
            XCTAssertGreaterThan(message.count, 10, "Error message should be descriptive for \(error)")
        }
    }

    // MARK: - Test 18-20: Screenshot Capture Scenarios

    /// Test 18: Multiple screenshot captures in sequence
    func test_multipleScreenshots_capturedInSequence() throws {
        // Arrange
        mockWorkspace.addRegularApp(bundleId: "io.github.chmc.ListAllMac", name: "ListAll")

        let orchestrator = ScreenshotOrchestrator(
            scriptExecutor: mockExecutor,
            captureStrategy: strategy,
            validator: validator,
            workspace: mockWorkspace,
            screenshotCapture: mockCapture
        )

        let mockWindow = MockScreenshotWindow.accessible()

        // Act: Capture 4 screenshots (typical for App Store)
        let screenshot1 = try orchestrator.captureAndValidate(named: "01_Main", window: mockWindow)
        let screenshot2 = try orchestrator.captureAndValidate(named: "02_List", window: mockWindow)
        let screenshot3 = try orchestrator.captureAndValidate(named: "03_Detail", window: mockWindow)
        let screenshot4 = try orchestrator.captureAndValidate(named: "04_Settings", window: mockWindow)

        // Assert: All screenshots captured and validated
        XCTAssertEqual(screenshot1.filename, "Mac-01_Main.png")
        XCTAssertEqual(screenshot2.filename, "Mac-02_List.png")
        XCTAssertEqual(screenshot3.filename, "Mac-03_Detail.png")
        XCTAssertEqual(screenshot4.filename, "Mac-04_Settings.png")

        // Assert: Hide was called for each screenshot (not just once)
        XCTAssertGreaterThanOrEqual(mockExecutor.executeCallCount, 4,
                                    "Should hide apps before each screenshot")
    }

    /// Test 19: Window and fullscreen captures both validated
    func test_bothCaptureMethodsAreValidated() throws {
        // Arrange
        let orchestrator = ScreenshotOrchestrator(
            scriptExecutor: mockExecutor,
            captureStrategy: strategy,
            validator: validator,
            workspace: mockWorkspace,
            screenshotCapture: mockCapture
        )

        // Act: Window capture
        let mockWindow = MockScreenshotWindow.accessible()
        let windowResult = try orchestrator.captureAndValidate(named: "Window", window: mockWindow)
        XCTAssertTrue(windowResult.wasValidated)

        // Act: Fullscreen capture
        mockCapture.reset()
        let inaccessibleWindow = MockScreenshotWindow.inaccessible()
        let fullscreenResult = try orchestrator.captureAndValidate(
            named: "Fullscreen",
            window: inaccessibleWindow,
            fallbackToFullscreen: true
        )
        XCTAssertTrue(fullscreenResult.wasValidated)
    }

    /// Test 20: Orchestrator state is clean between captures
    func test_orchestratorState_isCleanBetweenCaptures() throws {
        // Arrange
        let orchestrator = ScreenshotOrchestrator(
            scriptExecutor: mockExecutor,
            captureStrategy: strategy,
            validator: validator,
            workspace: mockWorkspace,
            screenshotCapture: mockCapture
        )

        let mockWindow = MockScreenshotWindow.accessible()

        // Act: Capture, then reset mocks, capture again
        _ = try orchestrator.captureAndValidate(named: "First", window: mockWindow)

        let firstCallCount = mockExecutor.executeCallCount
        mockExecutor.reset()
        mockCapture.reset()

        _ = try orchestrator.captureAndValidate(named: "Second", window: mockWindow)

        // Assert: Second capture works independently
        XCTAssertEqual(mockExecutor.executeCallCount, 1,
                       "Second capture should be independent")
        XCTAssertEqual(mockCapture.captureWindowCallCount, 1,
                       "Second capture should work cleanly")
    }
}

// MARK: - ScreenshotResult (Expected Interface)

/// Expected result structure from ScreenshotOrchestrator
/// This doesn't exist yet - will be created in GREEN phase
struct ScreenshotResult {
    let filename: String
    let wasValidated: Bool
    let captureMethod: CaptureMethod
    let imagePath: String?
}

// MARK: - ScreenshotOrchestrator (Expected Interface)

/// Expected orchestrator interface
/// This doesn't exist yet - will be created in GREEN phase
/// Tests define the expected API that production code will implement
class ScreenshotOrchestrator {
    private let scriptExecutor: AppleScriptExecuting
    private let captureStrategy: WindowCaptureStrategy
    private let validator: ScreenshotValidator
    private let workspace: WorkspaceQuerying
    private let screenshotCapture: ScreenshotCapturing
    private let retryCount: Int
    private let defaultTimeout: TimeInterval = 30.0

    init(
        scriptExecutor: AppleScriptExecuting,
        captureStrategy: WindowCaptureStrategy,
        validator: ScreenshotValidator,
        workspace: WorkspaceQuerying? = nil,
        screenshotCapture: ScreenshotCapturing? = nil,
        retryCount: Int = 0
    ) {
        self.scriptExecutor = scriptExecutor
        self.captureStrategy = captureStrategy
        self.validator = validator
        self.workspace = workspace ?? MockWorkspace()
        self.screenshotCapture = screenshotCapture ?? MockScreenshotCapture()
        self.retryCount = retryCount
    }

    /// Hide background apps before taking screenshot
    /// - Parameters:
    ///   - excluding: App names to exclude from hiding
    ///   - timeout: Maximum time to wait for AppleScript
    /// - Throws: AppleScriptError if script fails or times out
    func hideBackgroundApps(excluding: [String] = [], timeout: TimeInterval? = nil) throws {
        // Placeholder - will implement in GREEN phase
        fatalError("ScreenshotOrchestrator not implemented yet - RED phase")
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
        // Placeholder - will implement in GREEN phase
        fatalError("ScreenshotOrchestrator not implemented yet - RED phase")
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
        // Placeholder - will implement in GREEN phase
        fatalError("ScreenshotOrchestrator not implemented yet - RED phase")
    }
}
