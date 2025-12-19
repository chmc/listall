//
//  ScreenshotValidator.swift
//  ListAllMac
//
//  Created as part of MACOS_PLAN.md Phase 2: TDD Cycle 2
//  Purpose: Production implementation for screenshot validation
//  TDD Phase: RED → GREEN → REFACTOR
//

import Foundation

/// Validates screenshot images for quality and correctness
/// Detects too small, blank, or corrupt screenshots
class ScreenshotValidator {

    /// Minimum acceptable screenshot dimensions
    private let minimumWidth: CGFloat = 800
    private let minimumHeight: CGFloat = 600

    /// Initialize screenshot validator
    init() {}

    /// Validate a screenshot image
    /// - Parameter image: Screenshot image to validate
    /// - Returns: Validation result with isValid flag and optional failure reason
    func validate(image: ScreenshotImage) -> ScreenshotValidationResult {
        // 1. Check minimum dimensions (800x600)
        if !isValidSize(image.size) {
            return .invalid(.tooSmall)
        }

        // 2. Check file size is reasonable for dimensions
        if !isValidFileSize(image.data.count, for: image.size) {
            return .invalid(.suspiciousFileSize)
        }

        // All validations passed
        return .valid
    }

    // MARK: - Private Validation Helpers

    /// Check if image size meets minimum requirements
    /// - Parameter size: Image dimensions
    /// - Returns: True if size is acceptable (>= 800x600)
    private func isValidSize(_ size: CGSize) -> Bool {
        return size.width >= minimumWidth && size.height >= minimumHeight
    }

    /// Check if file size is reasonable for image dimensions
    /// Heuristic: ~1KB per 100,000 pixels minimum
    /// Example: 2880x1800 = 5,184,000 pixels → minimum ~52KB
    /// - Parameters:
    ///   - fileSize: File size in bytes
    ///   - size: Image dimensions
    /// - Returns: True if file size seems reasonable for dimensions
    private func isValidFileSize(_ fileSize: Int, for size: CGSize) -> Bool {
        let pixels = size.width * size.height

        // Minimum bytes per pixel (very conservative - ~0.01 bytes/pixel)
        // This catches completely blank or corrupt images
        let minimumBytesPerPixel: CGFloat = 0.01
        let minimumExpectedBytes = Int(pixels * minimumBytesPerPixel)

        return fileSize >= minimumExpectedBytes
    }
}
