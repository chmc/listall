//
//  AppleScriptProtocols.swift
//  ListAllMac
//
//  Created as part of MACOS_PLAN.md Phase 1: TDD Cycle 3
//  Purpose: Define protocols and types for AppleScript execution
//  This allows production code to implement the protocol and test code to mock it
//

import Foundation

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
