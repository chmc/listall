import Foundation

/// Screen Recording permission state from two independent signals.
/// Only `CGPreflightScreenCaptureAccess()` decides "not granted": a ScreenCaptureKit error alone is not proof
/// (2026-11-06 diagnostics reported NOT GRANTED from an SC error while listall_screenshot_macos worked).
public struct ScreenRecordingStatus: Sendable, Equatable {
    public enum State: Sendable, Equatable {
        case granted
        /// TCC preflight says granted, but listing shareable content failed for another reason
        case grantedCheckFailed
        case notGranted
    }

    public let state: State
    public let shareableContentError: String?

    public init(preflightGranted: Bool, shareableContentError: String?) {
        self.shareableContentError = shareableContentError
        if !preflightGranted {
            state = .notGranted
        } else if shareableContentError != nil {
            state = .grantedCheckFailed
        } else {
            state = .granted
        }
    }

    /// Whether screenshot tools should be expected to work
    public var isUsable: Bool { state != .notGranted }

    /// One-line status for diagnostics output
    public var summary: String {
        switch state {
        case .granted:
            return "GRANTED"
        case .grantedCheckFailed:
            return "GRANTED (preflight), but listing windows failed: \(shareableContentError ?? "unknown error"). "
                + "Authoritative test: listall_screenshot_macos"
        case .notGranted:
            return "NOT GRANTED"
        }
    }
}
