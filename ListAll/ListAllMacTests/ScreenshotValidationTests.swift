//
//  ScreenshotValidationTests.swift
//  ListAllMacTests
//
//  Created as part of MACOS_PLAN.md Phase 2: TDD Cycle 2
//  Purpose: Test screenshot validation logic
//  TDD Phase: RED - Define expected validation behavior through failing tests
//

import XCTest
@testable import ListAll

/// Unit tests for screenshot validation
/// Tests detection of invalid, corrupt, or blank screenshots
final class ScreenshotValidationTests: XCTestCase {

    var validator: ScreenshotValidator!

    override func setUp() {
        super.setUp()
        validator = ScreenshotValidator()
    }

    override func tearDown() {
        validator = nil
        super.tearDown()
    }

    // MARK: - Test 1-3: Size Validation

    /// Test 1: Reject screenshots that are too small
    func test_validateScreenshot_rejectsTooSmall() {
        let tinyImage = MockScreenshotImage.tooSmall()

        let result = validator.validate(image: tinyImage)

        XCTAssertFalse(result.isValid, "Should reject too small screenshots")
        XCTAssertEqual(result.reason, .tooSmall, "Should report reason as tooSmall")
    }

    /// Test 2: Accept screenshots with valid dimensions
    func test_validateScreenshot_acceptsValidSize() {
        let validImage = MockScreenshotImage.valid()

        let result = validator.validate(image: validImage)

        XCTAssertTrue(result.isValid, "Should accept valid sized screenshots")
        XCTAssertNil(result.reason, "Valid screenshots should have no failure reason")
    }

    /// Test 3: Accept minimum acceptable size (800x600)
    func test_validateScreenshot_acceptsMinimumSize() {
        let minImage = MockScreenshotImage(size: CGSize(width: 800, height: 600), fileSize: 100000)

        let result = validator.validate(image: minImage)

        XCTAssertTrue(result.isValid, "Should accept minimum valid size 800x600")
    }

    // MARK: - Test 4-6: File Size Validation

    /// Test 4: Reject suspicious file size (too small for dimensions)
    func test_validateScreenshot_rejectsSuspiciousFileSize() {
        let corruptImage = MockScreenshotImage.suspicious()

        let result = validator.validate(image: corruptImage)

        XCTAssertFalse(result.isValid, "Should reject suspicious file sizes")
        XCTAssertEqual(result.reason, .suspiciousFileSize, "Should report reason as suspiciousFileSize")
    }

    /// Test 5: Accept valid file size for dimensions
    func test_validateScreenshot_acceptsValidFileSize() {
        let validImage = MockScreenshotImage.valid()

        let result = validator.validate(image: validImage)

        XCTAssertTrue(result.isValid, "Should accept valid file sizes")
    }

    /// Test 6: Calculate expected minimum file size based on dimensions
    func test_validateScreenshot_calculatesMinFileSize() {
        // Large image (2880x1800) should have at least ~1KB to be valid
        let largeButTiny = MockScreenshotImage(
            size: CGSize(width: 2880, height: 1800),
            fileSize: 100  // Way too small for this resolution
        )

        let result = validator.validate(image: largeButTiny)

        XCTAssertFalse(result.isValid, "Large dimensions with tiny file = corrupt")
    }

    // MARK: - Test 7-8: Blank Image Detection

    /// Test 7: Reject blank images
    func test_validateScreenshot_rejectsBlankImage() {
        let blankImage = MockScreenshotImage.blank()

        let result = validator.validate(image: blankImage)

        XCTAssertFalse(result.isValid, "Should reject blank images")
        // Could be suspiciousFileSize or blankImage depending on implementation
        XCTAssertTrue(result.reason == .blankImage || result.reason == .suspiciousFileSize,
                     "Should detect blank or suspicious file")
    }

    /// Test 8: Accept non-blank images
    func test_validateScreenshot_acceptsNonBlankImage() {
        let validImage = MockScreenshotImage.valid()

        let result = validator.validate(image: validImage)

        XCTAssertTrue(result.isValid, "Should accept non-blank images")
    }

    // MARK: - Test 9-10: Edge Cases

    /// Test 9: Handle zero dimensions
    func test_validateScreenshot_rejectsZeroDimensions() {
        let zeroImage = MockScreenshotImage(size: CGSize(width: 0, height: 0), fileSize: 1000)

        let result = validator.validate(image: zeroImage)

        XCTAssertFalse(result.isValid, "Should reject zero dimensions")
        XCTAssertEqual(result.reason, .tooSmall, "Zero dimensions = too small")
    }

    /// Test 10: Handle very large valid images
    func test_validateScreenshot_acceptsLargeValidImage() {
        // 5K retina display size
        let largeImage = MockScreenshotImage(
            size: CGSize(width: 5120, height: 2880),
            fileSize: 2000000  // 2MB is reasonable for this size
        )

        let result = validator.validate(image: largeImage)

        XCTAssertTrue(result.isValid, "Should accept large valid images")
    }
}
