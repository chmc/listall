//
//  TCCPermissionDetectionTests.swift
//  ListAllMacTests
//
//  Created as part of MACOS_PLAN.md Phase 1: TDD Cycle 2
//  Purpose: Test TCC (Transparency, Consent, and Control) permission error detection
//  TDD Phase: RED - Define expected behavior through failing tests
//

import XCTest
@testable import ListAll

/// Test suite for TCC permission error detection
/// Tests the ability to distinguish TCC permission errors from other failure types
final class TCCPermissionDetectionTests: XCTestCase {

    // MARK: - Test 1: Detect "osascript is not allowed" pattern

    func test_detectTCCError_identifiesPermissionDenied() {
        // Arrange
        let stderr = "osascript is not allowed assistive access. (-1719)"

        // Act
        let result = TCCErrorDetector.detectTCCError(stderr: stderr)

        // Assert
        XCTAssertTrue(result.isTCCError, "Should identify 'osascript is not allowed' as TCC error")
        XCTAssertTrue(result.actionableMessage.contains("System Settings"),
                      "Should provide actionable fix with System Settings")
        XCTAssertTrue(result.actionableMessage.contains("Privacy & Security"),
                      "Should mention Privacy & Security")
        XCTAssertTrue(result.actionableMessage.contains("Automation"),
                      "Should mention Automation section")
    }

    // MARK: - Test 2: Detect "Not authorized" pattern

    func test_detectTCCError_identifiesNotAuthorized() {
        // Arrange
        let stderr = "Not authorized to send Apple events to System Events. (-1743)"

        // Act
        let result = TCCErrorDetector.detectTCCError(stderr: stderr)

        // Assert
        XCTAssertTrue(result.isTCCError, "Should identify 'Not authorized' as TCC error")
        XCTAssertTrue(result.actionableMessage.contains("System Settings"),
                      "Should provide actionable fix instructions")
    }

    // MARK: - Test 3: Detect error code -1743

    func test_detectTCCError_identifiesErrorCode1743() {
        // Arrange
        let stderr = "execution error: Application is not allowed. (-1743)"

        // Act
        let result = TCCErrorDetector.detectTCCError(stderr: stderr)

        // Assert
        XCTAssertTrue(result.isTCCError, "Should identify error code -1743 as TCC error")
        XCTAssertTrue(result.actionableMessage.contains("System Settings"),
                      "Should provide System Settings fix")
    }

    // MARK: - Test 4: Distinguish from syntax errors

    func test_detectTCCError_doesNotMisidentifySyntaxErrors() {
        // Arrange
        let syntaxErrors = [
            "syntax error: Expected end of line but found identifier. (-2741)",
            "execution error: Variable is not defined. (-2753)",
            "A identifier can't go after this identifier. (-2740)"
        ]

        // Act & Assert
        for stderr in syntaxErrors {
            let result = TCCErrorDetector.detectTCCError(stderr: stderr)
            XCTAssertFalse(result.isTCCError,
                          "Should NOT identify '\(stderr)' as TCC error")
            XCTAssertTrue(result.actionableMessage.isEmpty,
                         "Should not provide TCC fix for syntax errors")
        }
    }

    // MARK: - Test 5: Provide actionable message for TCC errors

    func test_detectTCCError_returnsActionableMessage() {
        // Arrange
        let stderr = "osascript is not allowed assistive access. (-1719)"

        // Act
        let result = TCCErrorDetector.detectTCCError(stderr: stderr)

        // Assert
        XCTAssertTrue(result.isTCCError, "Should detect TCC error")

        // Verify actionable message contains all required elements
        let message = result.actionableMessage
        XCTAssertFalse(message.isEmpty, "Should provide actionable message")
        XCTAssertTrue(message.contains("TCC") || message.contains("permission"),
                      "Message should mention TCC or permissions")
        XCTAssertTrue(message.contains("System Settings"),
                      "Message should mention System Settings")
        XCTAssertTrue(message.contains("Privacy & Security"),
                      "Message should mention Privacy & Security")
        XCTAssertTrue(message.contains("Automation"),
                      "Message should mention Automation")
        XCTAssertTrue(message.contains("Terminal") || message.contains("Xcode"),
                      "Message should mention Terminal or Xcode")
    }

    // MARK: - Test 6: Distinguish from timeout errors

    func test_detectTCCError_distinguishesFromTimeout() {
        // Arrange
        let timeoutErrors = [
            "execution error: Operation timed out.",
            "timeout",
            "The operation couldn't be completed. (timeout)"
        ]

        // Act & Assert
        for stderr in timeoutErrors {
            let result = TCCErrorDetector.detectTCCError(stderr: stderr)
            XCTAssertFalse(result.isTCCError,
                          "Should NOT identify timeout '\(stderr)' as TCC error")
            XCTAssertTrue(result.actionableMessage.isEmpty,
                         "Should not provide TCC fix for timeout errors")
        }
    }

    // MARK: - Test 7: Handle empty stderr gracefully

    func test_detectTCCError_handlesEmptyStderr() {
        // Arrange
        let emptyInputs = ["", "   ", "\n", "\t"]

        // Act & Assert
        for stderr in emptyInputs {
            let result = TCCErrorDetector.detectTCCError(stderr: stderr)
            XCTAssertFalse(result.isTCCError,
                          "Should NOT identify empty/whitespace as TCC error")
            XCTAssertTrue(result.actionableMessage.isEmpty,
                         "Should not provide message for empty input")
        }
    }
}
