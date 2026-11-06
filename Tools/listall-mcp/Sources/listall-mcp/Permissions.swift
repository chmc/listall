import Foundation
import ScreenCaptureKit
import ApplicationServices
import MCPHelpers

// MARK: - Permission Checking

/// Service for checking macOS privacy permissions required for MCP tools
enum PermissionService {
    /// Check Screen Recording permission from the TCC preflight plus a ScreenCaptureKit probe.
    /// Only the preflight decides "not granted"; an SC error is reported with its domain/code instead of hidden.
    static func screenRecordingStatus() async -> ScreenRecordingStatus {
        let preflightGranted = CGPreflightScreenCaptureAccess()
        var shareableContentError: String?
        do {
            _ = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
        } catch {
            let nsError = error as NSError
            shareableContentError = "\(nsError.domain) \(nsError.code): \(nsError.localizedDescription)"
            log("ScreenCaptureKit shareable content check failed: \(shareableContentError ?? "")")
        }
        return ScreenRecordingStatus(preflightGranted: preflightGranted, shareableContentError: shareableContentError)
    }

    /// Check if Accessibility permission is granted
    /// - Returns: true if permission is granted, false otherwise
    static func hasAccessibilityPermission() -> Bool {
        return AXIsProcessTrusted()
    }

    /// Request Accessibility permission (opens System Settings)
    static func requestAccessibilityPermission() {
        // The key value is "AXTrustedCheckOptionPrompt" - use it directly to avoid concurrency issues
        let options: [String: Bool] = ["AXTrustedCheckOptionPrompt": true]
        AXIsProcessTrustedWithOptions(options as CFDictionary)
    }

    /// Get detailed permission status for diagnostics
    /// - Returns: Dictionary with permission statuses
    static func getPermissionStatus() async -> [String: Any] {
        let screenRecording = await screenRecordingStatus()
        let accessibility = hasAccessibilityPermission()

        return [
            "screen_recording": [
                "granted": screenRecording.isUsable,
                "description": screenRecording.isUsable
                    ? "Screen Recording: \(screenRecording.summary)"
                    : "Screen Recording permission NOT granted. Grant in System Settings > Privacy & Security > Screen Recording",
                "required_for": ["listall_screenshot_macos"]
            ],
            "accessibility": [
                "granted": accessibility,
                "description": accessibility
                    ? "Accessibility permission granted"
                    : "Accessibility permission NOT granted. Grant in System Settings > Privacy & Security > Accessibility",
                "required_for": ["listall_click", "listall_type", "listall_swipe", "listall_query"]
            ]
        ]
    }
}

// MARK: - Permission Error Messages

/// Provides user-friendly error messages for permission issues
enum PermissionError {
    /// Generate actionable error message for Screen Recording permission
    static var screenRecordingDenied: String {
        """
        Screen Recording permission is required but not granted.

        To grant permission:
        1. Open System Settings
        2. Go to Privacy & Security > Screen Recording
        3. Enable permission for Terminal (or the app running the MCP server)
        4. You may need to restart Terminal after granting permission

        Note: The MCP server process needs this permission to capture window screenshots.
        """
    }

    /// Generate actionable error message for Accessibility permission
    static var accessibilityDenied: String {
        """
        Accessibility permission is required but not granted.

        To grant permission:
        1. Open System Settings
        2. Go to Privacy & Security > Accessibility
        3. Click the '+' button and add Terminal (or the app running the MCP server)
        4. Make sure the checkbox is enabled
        5. You may need to restart Terminal after granting permission

        Note: The MCP server process needs this permission to interact with UI elements.
        """
    }
}
