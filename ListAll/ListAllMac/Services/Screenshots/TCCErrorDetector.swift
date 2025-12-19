//
//  TCCErrorDetector.swift
//  ListAllMac
//
//  Created as part of MACOS_PLAN.md Phase 1: TDD Cycle 2
//  Purpose: Detect TCC (Transparency, Consent, and Control) permission errors in AppleScript stderr
//  TDD Phase: GREEN - Minimal implementation to pass all tests
//

import Foundation

/// Result of TCC error detection
struct TCCDetectionResult {
    /// Whether the error is identified as a TCC permission error
    let isTCCError: Bool

    /// Actionable message for the user (empty if not a TCC error)
    let actionableMessage: String

    /// Create a TCC error result
    static func tccError() -> TCCDetectionResult {
        TCCDetectionResult(
            isTCCError: true,
            actionableMessage: "TCC Automation permissions NOT granted. " +
                             "Fix: System Settings → Privacy & Security → Automation → Enable for Terminal/Xcode"
        )
    }

    /// Create a non-TCC error result
    static func notTCCError() -> TCCDetectionResult {
        TCCDetectionResult(isTCCError: false, actionableMessage: "")
    }
}

/// Detector for TCC permission errors in AppleScript execution
enum TCCErrorDetector {

    // MARK: - TCC Error Patterns

    /// Known patterns that indicate TCC permission denial
    private static let tccPatterns = [
        "osascript is not allowed",       // Pattern: "osascript is not allowed assistive access"
        "Not authorized",                 // Pattern: "Not authorized to send Apple events"
        "(-1743)"                         // Error code: -1743 = not authorized
    ]

    /// Known patterns that are NOT TCC errors (to avoid false positives)
    private static let nonTCCPatterns = [
        "syntax error",                   // AppleScript syntax errors
        "Variable is not defined",        // Variable/identifier errors
        "Expected end of line",           // Parsing errors
        "can't go after",                 // Grammar errors
        "timeout",                        // Timeout errors
        "timed out"                       // Alternative timeout message
    ]

    // MARK: - Detection

    /// Detect if stderr contains a TCC permission error
    /// - Parameter stderr: Standard error output from AppleScript execution
    /// - Returns: Detection result with TCC status and actionable message
    static func detectTCCError(stderr: String) -> TCCDetectionResult {
        // Handle empty/whitespace input
        let trimmed = stderr.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return .notTCCError()
        }

        // First check for non-TCC patterns (avoid false positives)
        for pattern in nonTCCPatterns {
            if stderr.contains(pattern) {
                return .notTCCError()
            }
        }

        // Then check for TCC patterns
        for pattern in tccPatterns {
            if stderr.contains(pattern) {
                return .tccError()
            }
        }

        // No TCC pattern found
        return .notTCCError()
    }
}
