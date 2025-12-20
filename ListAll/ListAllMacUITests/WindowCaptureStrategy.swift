//
//  WindowCaptureStrategy.swift
//  ListAllMac
//
//  Created as part of MACOS_PLAN.md Phase 2: TDD Cycle 1
//  Purpose: Decide between window capture and fullscreen fallback
//  TDD Phase: GREEN - Minimal implementation to pass all tests
//

import Foundation
import CoreGraphics

/// Strategy for deciding capture method based on window accessibility
/// Handles SwiftUI bug where window.exists returns false even when content is present
final class WindowCaptureStrategy {

    /// Minimum window size to consider valid for capture
    private let minimumWidth: CGFloat = 100
    private let minimumHeight: CGFloat = 100

    /// Decide the capture method based on window and content state
    /// - Parameters:
    ///   - window: The window to potentially capture
    ///   - contentElements: Optional app content for SwiftUI bug workaround
    /// - Returns: The recommended capture method
    func decideCaptureMethod(window: ScreenshotWindow?, contentElements: AppContentQuerying? = nil) -> CaptureMethod {
        // Default to fullscreen if no window
        guard let window = window else {
            return .fullscreen
        }

        // Check window frame size - tiny windows are not usable
        if window.frame.width < minimumWidth || window.frame.height < minimumHeight {
            return .fullscreen
        }

        // If window exists (even if not hittable), use window capture
        if window.exists {
            return .window
        }

        // SwiftUI bug workaround: window.exists may be false but content is present
        // Check content elements to detect this case
        if let content = contentElements, content.hasVisibleContent {
            return .window
        }

        // No window available and no content detected - fallback to fullscreen
        return .fullscreen
    }
}
