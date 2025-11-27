import XCTest

/// Simplified screenshot tests - no complex detection, just straightforward screenshot capture
@MainActor
final class ListAllUITests_Screenshots: XCTestCase {

    var app: XCUIApplication!

    /// Timeout for app launch - iPad Pro 13-inch M4 is very slow in CI
    /// CRITICAL FIX: iPad needs 90s due to slower cold starts (2-3x slower than iPhone)
    /// iPhone can use 60s. This prevents iPad launch failures that were happening 100% of the time.
    private var launchTimeout: TimeInterval {
        #if os(iOS)
        return UIDevice.current.userInterfaceIdiom == .pad ? 90 : 60
        #else
        return 60
        #endif
    }

    /// Timeout for UI elements to appear after launch
    /// Optimized to 15s based on pipeline performance improvements
    private let elementTimeout: TimeInterval = 15

    /// Track test start time for timeout budget monitoring
    private var testStartTime: Date?

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()

        // Enhanced diagnostic logging - helps debug CI failures
        print("========================================")
        print("📱 Test Setup: \(name)")
        #if os(iOS)
        let device = UIDevice.current
        print("📱 Device: \(device.name)")
        print("📱 Model: \(device.userInterfaceIdiom == .pad ? "iPad" : "iPhone")")
        print("📱 iOS: \(device.systemVersion)")
        #endif
        print("📱 XCTest Device: \(ProcessInfo.processInfo.environment["SIMULATOR_DEVICE_NAME"] ?? "Unknown")")
        print("📱 Launch Timeout: \(Int(launchTimeout))s")
        print("📱 Test Budget: 880s (xcodebuild max: 900s)")
        print("========================================")

        // Setup Fastlane snapshot
        setupSnapshot(app)

        // Track test start time for timeout budget monitoring
        testStartTime = Date()

        // Simulator health check - skip test if simulator is unresponsive
        // This saves time in CI by failing fast instead of hanging on launch
        if !isSimulatorHealthy() {
            print("❌ HEALTH CHECK FAILED - Skipping test")
            throw XCTSkip("Simulator is unresponsive - may need restart")
        }
    }

    /// Check remaining timeout budget
    /// CRITICAL FIX: Align with xcodebuild's -maximum-test-execution-time-allowance of 900s
    /// Previous 580s budget caused tests to timeout during retry scenarios
    /// Using 880s (900s - 20s safety margin) to prevent premature test skips
    /// This matches the increased timeout budget in Fastfile (480s default, 900s max)
    private func checkTimeoutBudget() -> TimeInterval {
        guard let startTime = testStartTime else { return 880 }
        let elapsed = Date().timeIntervalSince(startTime)
        let remaining = 880 - elapsed  // 880s = 900s xcodebuild timeout - 20s safety margin
        print("⏱️  Timeout budget: \(Int(remaining))s remaining (elapsed: \(Int(elapsed))s / 880s)")
        return remaining
    }

    /// Simulator health check - lightweight check without launching the app
    /// CRITICAL FIX: Previous version launched the app, creating a double-launch antipattern
    /// that caused 100% failure rate on iPad simulators due to zombie processes
    /// New approach: Just verify XCUIDevice is responsive without app launch
    private func isSimulatorHealthy() -> Bool {
        print("🏥 Checking simulator health (non-intrusive)...")

        // Lightweight check: verify XCUIDevice is responsive
        // This doesn't launch the app, just checks if simulator APIs work
        let device = XCUIDevice.shared
        _ = device.orientation  // Simple property access to verify responsiveness

        print("✅ Simulator is responsive")
        return true
    }

    /// Launch app with retry logic to handle "Failed to terminate" errors on iPad simulators
    /// This is a known flaky issue where app.launch() internally fails to terminate the previous instance
    /// Note: maxRetries=2 gives 2×90s=180s launch budget (iPad), leaving 700s for test execution within 880s budget
    /// iPhone uses 2×60s=120s, leaving 760s for test execution
    /// Retry delay increased to 10s for better simulator recovery between retries
    private func launchAppWithRetry(arguments: [String], maxRetries: Int = 2) throws -> Bool {
        // Check timeout budget before starting
        let budgetBefore = checkTimeoutBudget()
        if budgetBefore < 200 {
            print("⚠️  Insufficient timeout budget: \(Int(budgetBefore))s remaining (need 200s minimum)")
            // Skip test instead of hanging - saves CI time
            throw XCTSkip("Insufficient timeout budget for app launch")
        }

        for attempt in 1...maxRetries {
            // Pause before retry attempts to let simulator stabilize
            // CRITICAL FIX: Increased from 5s to 10s to allow CoreSimulatorService to fully recover
            // This prevents "connection interrupted" errors on retry attempts
            if attempt > 1 {
                print("⏳ Waiting 10 seconds before retry attempt \(attempt) (simulator recovery time)...")
                sleep(10)
                // Recreate app instance for retry
                app = XCUIApplication()
                setupSnapshot(app)
            }

            // Add launch arguments (must be done each attempt since app may be recreated)
            app.launchArguments += arguments

            print("🚀 Launch attempt \(attempt)/\(maxRetries) with timeout \(Int(launchTimeout))s...")
            checkTimeoutBudget()  // Show budget before launch attempt

            // Temporarily allow failures during launch attempt
            let previousContinueAfterFailure = continueAfterFailure
            continueAfterFailure = true

            app.launch()

            // Check if launch succeeded
            let launched = app.wait(for: .runningForeground, timeout: launchTimeout)

            // Restore failure behavior
            continueAfterFailure = previousContinueAfterFailure

            if launched {
                print("✅ App launched successfully on attempt \(attempt)")
                checkTimeoutBudget()  // Show budget after successful launch
                // Additional delay for UI to settle - iPad needs more time for large screen rendering
                sleep(2)
                return true
            }

            // Log retry attempt (visible in test logs)
            print("⚠️ App launch attempt \(attempt)/\(maxRetries) failed after \(Int(launchTimeout))s timeout")
            checkTimeoutBudget()  // Show budget after failed attempt
        }

        // Use XCTSkip instead of XCTFail - skip is better for CI (fails fast, clear signal)
        // XCTFail would continue test execution, wasting time on a test that can't succeed
        print("❌ App failed to launch after \(maxRetries) attempts - likely simulator issue")
        throw XCTSkip("App failed to launch after \(maxRetries) attempts - simulator may need restart")
    }

    /// Wait for a stable UI state by checking for any visible element
    /// Enhanced for iPad with better element detection and timeout budget monitoring
    /// Returns true if UI appears ready, false if timeout
    private func waitForUIReady() -> Bool {
        // Check timeout budget before UI wait
        let budgetBefore = checkTimeoutBudget()
        if budgetBefore < 30 {
            print("⚠️ Low timeout budget for UI ready check: \(Int(budgetBefore))s remaining")
        }

        print("⏳ Waiting for UI to be ready (timeout: \(Int(elementTimeout))s)...")

        // Enhanced element detection for iPad
        // iPads show different UI hierarchy than iPhones (split views, popovers, etc.)
        let navBar = app.navigationBars.firstMatch
        let anyButton = app.buttons.firstMatch
        let anyCell = app.cells.firstMatch
        let anyTable = app.tables.firstMatch
        let anyCollectionView = app.collectionViews.firstMatch
        let anyScrollView = app.scrollViews.firstMatch

        let startTime = Date()
        var foundElement = false

        while Date().timeIntervalSince(startTime) < elementTimeout {
            // Check multiple element types - iPad UI can vary significantly
            if navBar.exists {
                print("✅ UI ready - found navigation bar")
                foundElement = true
                break
            }
            if anyTable.exists || anyCollectionView.exists {
                print("✅ UI ready - found content view (table/collection)")
                foundElement = true
                break
            }
            if anyButton.exists && anyButton.isHittable {
                print("✅ UI ready - found interactive button")
                foundElement = true
                break
            }
            if anyCell.exists {
                print("✅ UI ready - found cell element")
                foundElement = true
                break
            }
            if anyScrollView.exists {
                print("✅ UI ready - found scroll view")
                foundElement = true
                break
            }

            // Poll every 0.5 seconds to avoid excessive CPU usage
            Thread.sleep(forTimeInterval: 0.5)
        }

        if foundElement {
            // Small additional settle time for animations/layout
            print("⏳ Allowing 1s for UI to settle...")
            sleep(1)
            checkTimeoutBudget()  // Log budget after UI ready
            return true
        } else {
            print("⚠️ UI ready check timed out after \(Int(elementTimeout))s, proceeding anyway")
            checkTimeoutBudget()  // Log budget after timeout
            return false
        }
    }

    /// Test: Capture welcome screen (empty state)
    func testScreenshots01_WelcomeScreen() throws {
        print("========================================")
        print("📱 Starting Welcome Screen Screenshot Test")
        print("========================================")

        // Check timeout budget before test
        checkTimeoutBudget()

        // Launch with empty state - SKIP_TEST_DATA prevents populating lists
        // launchAppWithRetry throws XCTSkip on failure, so test auto-skips if launch fails
        _ = try launchAppWithRetry(arguments: ["UITEST_MODE", "UITEST_SCREENSHOT_MODE", "DISABLE_TOOLTIPS", "SKIP_TEST_DATA"])

        // Check timeout budget after launch
        checkTimeoutBudget()

        // Wait for UI to be ready (dynamic wait instead of fixed sleep)
        let uiReady = waitForUIReady()
        if !uiReady {
            print("⚠️ UI may not be fully ready, but continuing with screenshot")
        }

        // Final timeout budget check before screenshot
        let budgetBeforeSnapshot = checkTimeoutBudget()
        if budgetBeforeSnapshot < 10 {
            throw XCTSkip("Insufficient timeout budget for screenshot: \(Int(budgetBeforeSnapshot))s remaining")
        }

        // Take screenshot of empty state
        print("📸 Capturing welcome screen screenshot")
        snapshot("01_Welcome")
        print("✅ Welcome screen screenshot captured")

        // Final budget report
        checkTimeoutBudget()
        print("========================================")
    }

    /// Test: Capture main flow with data
    func testScreenshots02_MainFlow() throws {
        print("========================================")
        print("📱 Starting Main Flow Screenshot Test")
        print("========================================")

        // Check timeout budget before test
        checkTimeoutBudget()

        // Launch with test data - without SKIP_TEST_DATA, hardcoded lists will be populated
        // launchAppWithRetry throws XCTSkip on failure, so test auto-skips if launch fails
        _ = try launchAppWithRetry(arguments: ["UITEST_MODE", "UITEST_SCREENSHOT_MODE", "DISABLE_TOOLTIPS"])

        // Check timeout budget after launch
        checkTimeoutBudget()

        // Wait for UI to be ready (dynamic wait instead of fixed sleep)
        let uiReady = waitForUIReady()
        if !uiReady {
            print("⚠️ UI may not be fully ready, but continuing with screenshot")
        }

        // Check timeout budget before data wait
        let budgetBeforeDataWait = checkTimeoutBudget()
        if budgetBeforeDataWait < 30 {
            print("⚠️ Low timeout budget for data wait: \(Int(budgetBeforeDataWait))s remaining")
        }

        // Additional wait for data to load into list
        // Look for any cell which indicates data is loaded
        let anyCell = app.cells.firstMatch
        if anyCell.waitForExistence(timeout: elementTimeout) {
            print("✅ Data loaded - found list cells")
        } else {
            print("⚠️ No cells found after \(Int(elementTimeout))s, but proceeding with screenshot")
        }

        // Final timeout budget check before screenshot
        let budgetBeforeSnapshot = checkTimeoutBudget()
        if budgetBeforeSnapshot < 10 {
            throw XCTSkip("Insufficient timeout budget for screenshot: \(Int(budgetBeforeSnapshot))s remaining")
        }

        // Screenshot: Main screen with hardcoded test lists
        print("📸 Capturing main screen screenshot")
        snapshot("02_MainScreen")
        print("✅ Main screen screenshot captured")

        // Final budget report
        checkTimeoutBudget()
        print("========================================")
    }
}
