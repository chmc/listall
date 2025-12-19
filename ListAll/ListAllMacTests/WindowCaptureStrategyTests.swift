//
//  WindowCaptureStrategyTests.swift
//  ListAllMacTests
//
//  Created as part of MACOS_PLAN.md Phase 2: TDD Cycle 1
//  Purpose: Test capture method decision logic
//  TDD Phase: RED - Define expected behavior through failing tests
//

import XCTest
@testable import ListAll

/// Unit tests for window capture strategy decisions
/// Tests the logic for choosing between window capture and fullscreen fallback
final class WindowCaptureStrategyTests: XCTestCase {

    var strategy: WindowCaptureStrategy!

    override func setUp() {
        super.setUp()
        strategy = WindowCaptureStrategy()
    }

    override func tearDown() {
        strategy = nil
        super.tearDown()
    }

    // MARK: - Test 1-4: Window Accessible Cases

    /// Test 1: Choose window capture when window exists and is hittable
    func test_captureStrategy_choosesWindowWhenAccessible() {
        let mockWindow = MockScreenshotWindow.accessible()

        let decision = strategy.decideCaptureMethod(window: mockWindow)

        XCTAssertEqual(decision, .window, "Should choose window capture when window is accessible")
    }

    /// Test 2: Choose window capture when window exists but not hittable (partial access)
    func test_captureStrategy_choosesWindowWhenExistsButNotHittable() {
        let mockWindow = MockScreenshotWindow(exists: true, isHittable: false)

        let decision = strategy.decideCaptureMethod(window: mockWindow)

        XCTAssertEqual(decision, .window, "Should still try window capture when window exists")
    }

    /// Test 3: Consider window usable when it has sufficient frame size
    func test_captureStrategy_checksWindowFrameSize() {
        let mockWindow = MockScreenshotWindow(
            exists: true,
            isHittable: true,
            frame: CGRect(x: 0, y: 0, width: 1200, height: 800)
        )

        let decision = strategy.decideCaptureMethod(window: mockWindow)

        XCTAssertEqual(decision, .window, "Should use window with valid frame")
    }

    /// Test 4: Fallback when window frame is too small
    func test_captureStrategy_fallsBackForTinyWindow() {
        let mockWindow = MockScreenshotWindow(
            exists: true,
            isHittable: true,
            frame: CGRect(x: 0, y: 0, width: 50, height: 30)
        )

        let decision = strategy.decideCaptureMethod(window: mockWindow)

        XCTAssertEqual(decision, .fullscreen, "Should fallback for tiny window")
    }

    // MARK: - Test 5-8: SwiftUI Bug Workaround (exists=false but content present)

    /// Test 5: Use window capture when exists=false but content elements found
    func test_captureStrategy_usesContentVerificationWhenExistsFalse() {
        let mockWindow = MockScreenshotWindow.inaccessible()
        let mockApp = MockXCUIApp(hasSidebar: true, hasButtons: true, hasOutlineRows: false)

        let decision = strategy.decideCaptureMethod(window: mockWindow, contentElements: mockApp)

        XCTAssertEqual(decision, .window, "Should use window when content exists (SwiftUI bug workaround)")
    }

    /// Test 6: Use window capture when exists=false but sidebar found
    func test_captureStrategy_usesWindowWhenSidebarFound() {
        let mockWindow = MockScreenshotWindow.inaccessible()
        let mockApp = MockXCUIApp(hasSidebar: true, hasButtons: false, hasOutlineRows: false)

        let decision = strategy.decideCaptureMethod(window: mockWindow, contentElements: mockApp)

        XCTAssertEqual(decision, .window, "Should use window when sidebar exists")
    }

    /// Test 7: Use window capture when exists=false but buttons found
    func test_captureStrategy_usesWindowWhenButtonsFound() {
        let mockWindow = MockScreenshotWindow.inaccessible()
        let mockApp = MockXCUIApp(hasSidebar: false, hasButtons: true, hasOutlineRows: false)

        let decision = strategy.decideCaptureMethod(window: mockWindow, contentElements: mockApp)

        XCTAssertEqual(decision, .window, "Should use window when buttons exist")
    }

    /// Test 8: Use window capture when exists=false but outline rows found
    func test_captureStrategy_usesWindowWhenOutlineRowsFound() {
        let mockWindow = MockScreenshotWindow.inaccessible()
        let mockApp = MockXCUIApp(hasSidebar: false, hasButtons: false, hasOutlineRows: true)

        let decision = strategy.decideCaptureMethod(window: mockWindow, contentElements: mockApp)

        XCTAssertEqual(decision, .window, "Should use window when outline rows exist")
    }

    // MARK: - Test 9-12: Fullscreen Fallback Cases

    /// Test 9: Fallback to fullscreen when window inaccessible and no content
    func test_captureStrategy_fallsBackWhenNoContent() {
        let mockWindow = MockScreenshotWindow.inaccessible()
        let mockApp = MockXCUIApp(hasSidebar: false, hasButtons: false, hasOutlineRows: false)

        let decision = strategy.decideCaptureMethod(window: mockWindow, contentElements: mockApp)

        XCTAssertEqual(decision, .fullscreen, "Should fallback to fullscreen when no content")
    }

    /// Test 10: Fallback to fullscreen when window nil
    func test_captureStrategy_fallsBackWhenWindowNil() {
        let decision = strategy.decideCaptureMethod(window: nil)

        XCTAssertEqual(decision, .fullscreen, "Should fallback to fullscreen when window is nil")
    }

    /// Test 11: Fallback to fullscreen when content elements nil and window inaccessible
    func test_captureStrategy_fallsBackWhenContentNilAndWindowInaccessible() {
        let mockWindow = MockScreenshotWindow.inaccessible()

        let decision = strategy.decideCaptureMethod(window: mockWindow, contentElements: nil)

        XCTAssertEqual(decision, .fullscreen, "Should fallback when no content info and window inaccessible")
    }

    /// Test 12: Default to fullscreen is safe fallback
    func test_captureStrategy_defaultIsFullscreen() {
        // Empty state - no window, no content
        let decision = strategy.decideCaptureMethod(window: nil, contentElements: nil)

        XCTAssertEqual(decision, .fullscreen, "Default should be fullscreen as safe fallback")
    }
}
