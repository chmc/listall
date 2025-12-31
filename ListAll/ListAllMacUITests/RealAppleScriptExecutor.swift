//
//  RealAppleScriptExecutor.swift
//  ListAllMac
//
//  Created as part of MACOS_PLAN.md Phase 1: TDD Cycle 3
//  Purpose: Execute AppleScript with timeout handling using osascript CLI
//  TDD Phase: GREEN - Fixed main thread deadlock by using osascript instead of NSAppleScript
//
//  FIX: NSAppleScript with DispatchSemaphore caused main thread deadlock when called from
//  @MainActor context. osascript CLI runs as a separate process, avoiding this issue.
//

import Foundation

/// Real AppleScript executor using osascript CLI with timeout handling
/// Uses Process for execution to avoid main thread deadlock issues with NSAppleScript
final class RealAppleScriptExecutor: AppleScriptExecuting {

    // MARK: - AppleScriptExecuting Protocol

    /// Execute AppleScript with timeout using osascript CLI
    /// Uses Process to avoid main thread deadlock (NSAppleScript + semaphore can deadlock on main thread)
    /// - Parameters:
    ///   - script: AppleScript code to execute
    ///   - timeout: Maximum time to wait for script completion
    /// - Returns: Result containing exit code, stdout, stderr, and duration
    /// - Throws: AppleScriptError if script fails, times out, or TCC permission denied
    func execute(script: String, timeout: TimeInterval) throws -> AppleScriptResult {
        let start = Date()

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
        process.arguments = ["-e", script]

        let stdoutPipe = Pipe()
        let stderrPipe = Pipe()
        process.standardOutput = stdoutPipe
        process.standardError = stderrPipe

        // Start the process
        do {
            try process.run()
        } catch {
            throw AppleScriptError.executionFailed(exitCode: -1, stderr: "Failed to launch osascript: \(error.localizedDescription)")
        }

        // Wait with timeout using a background thread
        let semaphore = DispatchSemaphore(value: 0)
        var processTerminated = false

        DispatchQueue.global(qos: .userInitiated).async {
            process.waitUntilExit()
            processTerminated = true
            semaphore.signal()
        }

        let deadline = DispatchTime.now() + timeout
        let waitResult = semaphore.wait(timeout: deadline)

        let duration = Date().timeIntervalSince(start)

        // Handle timeout
        if waitResult == .timedOut {
            if process.isRunning {
                process.terminate()
            }
            throw AppleScriptError.timeout
        }

        // Read stdout and stderr
        let stdoutData = stdoutPipe.fileHandleForReading.readDataToEndOfFile()
        let stderrData = stderrPipe.fileHandleForReading.readDataToEndOfFile()

        let stdout = String(data: stdoutData, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let stderr = String(data: stderrData, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

        let exitCode = Int(process.terminationStatus)

        // Check for errors
        if exitCode != 0 {
            // Check for TCC permission errors
            if stderr.contains("-1743") ||
               stderr.lowercased().contains("not authorized") ||
               stderr.lowercased().contains("not allowed") ||
               stderr.contains("System Events got an error") && stderr.contains("is not allowed") {
                throw AppleScriptError.permissionDenied
            }

            // Check for syntax errors
            if stderr.lowercased().contains("syntax error") ||
               stderr.lowercased().contains("expected") && stderr.lowercased().contains("but found") {
                throw AppleScriptError.syntaxError
            }

            // General execution failure
            throw AppleScriptError.executionFailed(exitCode: exitCode, stderr: stderr)
        }

        // Success
        return AppleScriptResult(
            exitCode: exitCode,
            stdout: stdout,
            stderr: stderr,
            duration: duration
        )
    }
}
