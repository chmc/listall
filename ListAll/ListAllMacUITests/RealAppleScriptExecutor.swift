//
//  RealAppleScriptExecutor.swift
//  ListAllMac
//
//  Created as part of MACOS_PLAN.md Phase 1: TDD Cycle 3
//  Purpose: Execute AppleScript with timeout handling using DispatchSemaphore
//  TDD Phase: GREEN - Minimal implementation to pass all tests
//

import Foundation
import Carbon

/// Real AppleScript executor using NSAppleScript with timeout handling
/// Uses DispatchSemaphore for efficient timeout (not busy-wait)
final class RealAppleScriptExecutor: AppleScriptExecuting {

    // MARK: - AppleScriptExecuting Protocol

    /// Execute AppleScript with timeout
    /// Uses DispatchSemaphore for efficient timeout handling (not busy-wait)
    /// - Parameters:
    ///   - script: AppleScript code to execute
    ///   - timeout: Maximum time to wait for script completion
    /// - Returns: Result containing exit code, stdout, stderr, and duration
    /// - Throws: AppleScriptError if script fails, times out, or TCC permission denied
    func execute(script: String, timeout: TimeInterval) throws -> AppleScriptResult {
        let start = Date()

        // Semaphore for timeout handling
        let semaphore = DispatchSemaphore(value: 0)

        // Result storage (thread-safe via semaphore)
        var scriptOutput: String = ""
        var scriptError: String = ""
        var exitCode: Int = 0
        var executionError: AppleScriptError?

        // Execute on background queue
        DispatchQueue.global(qos: .userInitiated).async {
            let appleScript = NSAppleScript(source: script)

            var errorDict: NSDictionary?
            let result = appleScript?.executeAndReturnError(&errorDict)

            if let error = errorDict {
                // Extract error information
                let errorMessage = error[NSAppleScript.errorMessage] as? String ?? "Unknown error"
                let errorNumber = error[NSAppleScript.errorNumber] as? Int ?? -1

                scriptError = errorMessage
                exitCode = errorNumber

                // Check for TCC errors (error -1743)
                if errorNumber == -1743 ||
                   errorMessage.lowercased().contains("not authorized") ||
                   errorMessage.lowercased().contains("not allowed") {
                    executionError = .permissionDenied
                } else if errorMessage.lowercased().contains("syntax error") ||
                          errorMessage.lowercased().contains("expected") {
                    executionError = .syntaxError
                } else {
                    executionError = .executionFailed(exitCode: errorNumber, stderr: errorMessage)
                }
            } else if let result = result {
                // Success - extract string result
                scriptOutput = result.stringValue ?? ""
                exitCode = 0
            }

            semaphore.signal()
        }

        // Wait for completion or timeout using DispatchSemaphore
        let deadline = DispatchTime.now() + timeout
        let waitResult = semaphore.wait(timeout: deadline)

        let duration = Date().timeIntervalSince(start)

        // Check if timed out
        if waitResult == .timedOut {
            throw AppleScriptError.timeout
        }

        // Check for execution error
        if let error = executionError {
            throw error
        }

        // Success
        return AppleScriptResult(
            exitCode: exitCode,
            stdout: scriptOutput,
            stderr: scriptError,
            duration: duration
        )
    }
}
