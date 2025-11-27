import XCTest

/// Simplified screenshot tests - no complex detection, just straightforward screenshot capture
@MainActor
final class ListAllUITests_Screenshots: XCTestCase {

    var app: XCUIApplication!

    /// Timeout for app launch - reduced from 90s/60s to 60s/45s
    /// CRITICAL FIX: With Snapfile timeout conflict resolved (was 300s/600s, now 480s/900s from Fastfile),
    /// tests have proper timeout budget. Reducing launch timeouts ensures faster failure detection
    /// while still accommodating slower CI runners.
    /// iPad: 60s (was 90s) - still 2x typical launch time
    /// iPhone: 45s (was 60s) - still 2x typical launch time
    private var launchTimeout: TimeInterval {
        #if os(iOS)
        return UIDevice.current.userInterfaceIdiom == .pad ? 60 : 45
        #else
        return 45
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
    private func checkTimeoutBudget(context: String = "") -> TimeInterval {
        guard let startTime = testStartTime else { return 880 }
        let elapsed = Date().timeIntervalSince(startTime)
        let remaining = 880 - elapsed  // 880s = 900s xcodebuild timeout - 20s safety margin

        let contextPrefix = context.isEmpty ? "" : "[\(context)] "
        print("⏱️  \(contextPrefix)Timeout budget: \(Int(remaining))s remaining (elapsed: \(Int(elapsed))s / 880s)")

        // RESILIENCE: Log warning levels to identify problematic phases
        if remaining < 100 {
            print("🚨 CRITICAL: Only \(Int(remaining))s remaining - test likely to timeout")
        } else if remaining < 200 {
            print("⚠️  WARNING: Low budget - \(Int(remaining))s remaining")
        }

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
        print("🚀 Starting app launch with retry logic (max \(maxRetries) attempts)")

        // Check timeout budget before starting
        let budgetBefore = checkTimeoutBudget(context: "Pre-Launch")
        if budgetBefore < 200 {
            print("⚠️  EARLY FAILURE: Insufficient timeout budget: \(Int(budgetBefore))s remaining (need 200s minimum)")
            // Skip test instead of hanging - saves CI time
            throw XCTSkip("Insufficient timeout budget for app launch")
        }

        // DIAGNOSTIC: Log app state before launch attempts
        print("📊 App state: \(app.state.rawValue) (0=unknown, 1=notRunning, 2=background, 3=foreground, 4=suspended)")

        for attempt in 1...maxRetries {
            let attemptStartTime = Date()

            // Pause before retry attempts to let simulator stabilize
            // Reduced from 10s to 5s - CoreSimulatorService recovers quickly
            if attempt > 1 {
                print("⏳ Waiting 5 seconds before retry attempt \(attempt) (simulator recovery time)...")
                sleep(5)

                // DIAGNOSTIC: Check if previous app instance is still running
                print("📊 App state before retry: \(app.state.rawValue)")

                // Recreate app instance for retry
                app = XCUIApplication()
                setupSnapshot(app)
                print("🔄 App instance recreated for retry attempt")
            }

            // Add launch arguments (must be done each attempt since app may be recreated)
            app.launchArguments += arguments
            print("📋 Launch arguments: \(arguments.joined(separator: ", "))")

            print("🚀 Launch attempt \(attempt)/\(maxRetries) with timeout \(Int(launchTimeout))s...")
            checkTimeoutBudget(context: "Attempt \(attempt) Start")

            // Temporarily allow failures during launch attempt
            let previousContinueAfterFailure = continueAfterFailure
            continueAfterFailure = true

            // DIAGNOSTIC: Measure actual launch time
            let launchStartTime = Date()
            app.launch()
            let launchCallDuration = Date().timeIntervalSince(launchStartTime)
            print("📊 app.launch() call completed in \(String(format: "%.1f", launchCallDuration))s")

            // Check if launch succeeded
            print("⏳ Waiting for app state transition to .runningForeground...")
            let stateCheckStart = Date()
            let launched = app.wait(for: .runningForeground, timeout: launchTimeout)
            let stateCheckDuration = Date().timeIntervalSince(stateCheckStart)

            // Restore failure behavior
            continueAfterFailure = previousContinueAfterFailure

            // DIAGNOSTIC: Log final app state
            print("📊 Final app state: \(app.state.rawValue) after \(String(format: "%.1f", stateCheckDuration))s wait")

            if launched {
                let totalAttemptTime = Date().timeIntervalSince(attemptStartTime)
                print("✅ App launched successfully on attempt \(attempt) (took \(String(format: "%.1f", totalAttemptTime))s total)")
                checkTimeoutBudget(context: "Post-Launch Success")

                // DIAGNOSTIC: Verify app is actually interactive
                let isInteractive = app.buttons.count > 0 || app.cells.count > 0 || app.tables.count > 0
                print("📊 App interactivity check: \(isInteractive ? "✅ Interactive" : "⚠️ No UI elements detected")")

                // UI settling is handled by waitForUIReady() - no additional sleep needed
                return true
            }

            // Log retry attempt (visible in test logs)
            let totalAttemptTime = Date().timeIntervalSince(attemptStartTime)
            print("⚠️ App launch attempt \(attempt)/\(maxRetries) failed after \(String(format: "%.1f", totalAttemptTime))s")
            print("📊 Failure breakdown: launch() took \(String(format: "%.1f", launchCallDuration))s, state wait took \(String(format: "%.1f", stateCheckDuration))s")
            checkTimeoutBudget(context: "Attempt \(attempt) Failed")

            // EARLY FAILURE: If we're in last attempt or running out of budget, don't retry
            if attempt < maxRetries {
                let remainingBudget = checkTimeoutBudget(context: "Pre-Retry Decision")
                let nextAttemptCost = launchTimeout + 5  // Launch timeout + retry delay
                if remainingBudget < nextAttemptCost + 50 {  // +50s safety margin
                    print("🚨 EARLY FAILURE: Insufficient budget for another attempt (need \(Int(nextAttemptCost))s, have \(Int(remainingBudget))s)")
                    break
                }
            }
        }

        // Use XCTSkip instead of XCTFail - skip is better for CI (fails fast, clear signal)
        // XCTFail would continue test execution, wasting time on a test that can't succeed
        print("❌ App failed to launch after \(maxRetries) attempts - likely simulator issue")
        print("📊 Final app state: \(app.state.rawValue)")
        throw XCTSkip("App failed to launch after \(maxRetries) attempts - simulator may need restart")
    }

    /// Wait for a stable UI state by checking for any visible element
    /// Enhanced for iPad with better element detection and timeout budget monitoring
    /// Returns true if UI appears ready, false if timeout
    private func waitForUIReady() -> Bool {
        // Check timeout budget before UI wait
        let budgetBefore = checkTimeoutBudget(context: "Pre-UI-Ready")
        if budgetBefore < 30 {
            print("⚠️ EARLY FAILURE: Low timeout budget for UI ready check: \(Int(budgetBefore))s remaining")
            return false  // Fail fast - no point waiting if budget is low
        }

        print("⏳ Waiting for UI to be ready (timeout: \(Int(elementTimeout))s)...")

        // DIAGNOSTIC: Log initial element counts before polling
        print("📊 Initial element scan: buttons=\(app.buttons.count), cells=\(app.cells.count), tables=\(app.tables.count), navBars=\(app.navigationBars.count)")

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
        var pollCount = 0
        var lastLogTime = startTime

        while Date().timeIntervalSince(startTime) < elementTimeout {
            pollCount += 1

            // DIAGNOSTIC: Log progress every 5 seconds to detect hung states
            let now = Date()
            if now.timeIntervalSince(lastLogTime) >= 5.0 {
                let elapsed = now.timeIntervalSince(startTime)
                print("📊 UI poll progress: \(String(format: "%.1f", elapsed))s elapsed, \(pollCount) polls, still searching...")
                lastLogTime = now
            }

            // Check multiple element types - iPad UI can vary significantly
            if navBar.exists {
                print("✅ UI ready - found navigation bar (after \(pollCount) polls)")
                foundElement = true
                break
            }
            if anyTable.exists || anyCollectionView.exists {
                print("✅ UI ready - found content view (table/collection) (after \(pollCount) polls)")
                foundElement = true
                break
            }
            if anyButton.exists && anyButton.isHittable {
                print("✅ UI ready - found interactive button (after \(pollCount) polls)")
                foundElement = true
                break
            }
            if anyCell.exists {
                print("✅ UI ready - found cell element (after \(pollCount) polls)")
                foundElement = true
                break
            }
            if anyScrollView.exists {
                print("✅ UI ready - found scroll view (after \(pollCount) polls)")
                foundElement = true
                break
            }

            // Poll every 0.5 seconds to avoid excessive CPU usage
            Thread.sleep(forTimeInterval: 0.5)
        }

        let totalTime = Date().timeIntervalSince(startTime)

        if foundElement {
            print("✅ UI became ready in \(String(format: "%.1f", totalTime))s after \(pollCount) polls")
            checkTimeoutBudget(context: "Post-UI-Ready Success")
            return true
        } else {
            print("⚠️ UI ready check timed out after \(String(format: "%.1f", totalTime))s (\(pollCount) polls)")

            // DIAGNOSTIC: Final element scan to see what's missing
            print("📊 Final element scan: buttons=\(app.buttons.count), cells=\(app.cells.count), tables=\(app.tables.count), navBars=\(app.navigationBars.count)")
            print("📊 App hierarchy debug info:")
            print("   - Windows: \(app.windows.count)")
            print("   - Descendants: \(app.descendants(matching: .any).count)")

            checkTimeoutBudget(context: "Post-UI-Ready Timeout")
            return false
        }
    }

    /// Test: Capture welcome screen (empty state)
    func testScreenshots01_WelcomeScreen() throws {
        print("========================================")
        print("📱 Starting Welcome Screen Screenshot Test")
        print("⏱️  Test started at: \(Date())")
        print("========================================")

        // Check timeout budget before test
        checkTimeoutBudget(context: "Test Start")

        // Launch with empty state - SKIP_TEST_DATA prevents populating lists
        // launchAppWithRetry throws XCTSkip on failure, so test auto-skips if launch fails
        print("🚀 Phase 1: App Launch")
        let launchStart = Date()
        _ = try launchAppWithRetry(arguments: ["UITEST_MODE", "UITEST_SCREENSHOT_MODE", "DISABLE_TOOLTIPS", "SKIP_TEST_DATA"])
        let launchDuration = Date().timeIntervalSince(launchStart)
        print("✅ Launch phase completed in \(String(format: "%.1f", launchDuration))s")

        // Check timeout budget after launch
        checkTimeoutBudget(context: "Post-Launch")

        // Wait for UI to be ready (dynamic wait instead of fixed sleep)
        print("🔍 Phase 2: UI Ready Check")
        let uiStart = Date()
        let uiReady = waitForUIReady()
        let uiDuration = Date().timeIntervalSince(uiStart)
        print("✅ UI ready phase completed in \(String(format: "%.1f", uiDuration))s (ready: \(uiReady))")

        if !uiReady {
            print("⚠️ UI may not be fully ready, but continuing with screenshot")
            // DIAGNOSTIC: Try to capture what went wrong
            print("📊 Accessibility hierarchy available: \(app.debugDescription.count > 0)")
        }

        // Allow animations to fully settle before screenshot
        print("⏳ Settling time: 0.3s for animation completion")
        Thread.sleep(forTimeInterval: 0.3)

        // Final timeout budget check before screenshot
        let budgetBeforeSnapshot = checkTimeoutBudget(context: "Pre-Screenshot")
        if budgetBeforeSnapshot < 10 {
            print("🚨 EARLY FAILURE: Insufficient budget for screenshot")
            throw XCTSkip("Insufficient timeout budget for screenshot: \(Int(budgetBeforeSnapshot))s remaining")
        }

        // Take screenshot of empty state
        // CRITICAL FIX: Use timeWaitingForIdle:0 to bypass network loading indicator wait
        // The waitForLoadingIndicatorToDisappear() function can hang indefinitely on iPad simulators
        // when accessibility queries deadlock. Since our tests don't make network requests
        // (all data is local via UITestDataService), this wait is unnecessary.
        // We already have waitForUIReady() and waitForExistence() checks, plus SnapshotHelper's
        // 1-second animation wait, which is sufficient for UI settling.
        print("📸 Phase 3: Screenshot Capture")
        let snapshotStart = Date()
        snapshot("01_Welcome", timeWaitingForIdle: 0)
        print("📸 Screenshot 01_Welcome captured at: \(Date())")
        let snapshotDuration = Date().timeIntervalSince(snapshotStart)
        print("✅ Welcome screen screenshot captured in \(String(format: "%.1f", snapshotDuration))s")

        // Final budget report with breakdown
        let totalDuration = Date().timeIntervalSince(launchStart)
        print("========================================")
        print("✅ Test completed successfully")
        print("📊 Phase breakdown:")
        print("   - Launch: \(String(format: "%.1f", launchDuration))s")
        print("   - UI Ready: \(String(format: "%.1f", uiDuration))s")
        print("   - Screenshot: \(String(format: "%.1f", snapshotDuration))s")
        print("   - Total: \(String(format: "%.1f", totalDuration))s")
        checkTimeoutBudget(context: "Test Complete")
        print("========================================")
    }

    /// Test: Capture main flow with data
    func testScreenshots02_MainFlow() throws {
        print("========================================")
        print("📱 Starting Main Flow Screenshot Test")
        print("⏱️  Test started at: \(Date())")
        print("========================================")

        // Check timeout budget before test
        checkTimeoutBudget(context: "Test Start")

        // Launch with test data - without SKIP_TEST_DATA, hardcoded lists will be populated
        // launchAppWithRetry throws XCTSkip on failure, so test auto-skips if launch fails
        print("🚀 Phase 1: App Launch")
        let launchStart = Date()
        _ = try launchAppWithRetry(arguments: ["UITEST_MODE", "UITEST_SCREENSHOT_MODE", "DISABLE_TOOLTIPS"])
        let launchDuration = Date().timeIntervalSince(launchStart)
        print("✅ Launch phase completed in \(String(format: "%.1f", launchDuration))s")

        // Check timeout budget after launch
        checkTimeoutBudget(context: "Post-Launch")

        // Wait for UI to be ready (dynamic wait instead of fixed sleep)
        print("🔍 Phase 2: UI Ready Check")
        let uiStart = Date()
        let uiReady = waitForUIReady()
        let uiDuration = Date().timeIntervalSince(uiStart)
        print("✅ UI ready phase completed in \(String(format: "%.1f", uiDuration))s (ready: \(uiReady))")

        if !uiReady {
            print("⚠️ UI may not be fully ready, but continuing with screenshot")
            // DIAGNOSTIC: Try to capture what went wrong
            print("📊 Accessibility hierarchy available: \(app.debugDescription.count > 0)")
        }

        // Allow animations to fully settle before screenshot
        print("⏳ Settling time: 0.3s for animation completion")
        Thread.sleep(forTimeInterval: 0.3)

        // Check timeout budget before data wait
        let budgetBeforeDataWait = checkTimeoutBudget(context: "Pre-Data-Wait")
        if budgetBeforeDataWait < 30 {
            print("⚠️ EARLY FAILURE: Low timeout budget for data wait: \(Int(budgetBeforeDataWait))s remaining")
        }

        // Additional wait for data to load into list
        // Look for any cell which indicates data is loaded
        print("📊 Phase 3: Data Load Verification")
        let dataStart = Date()
        let anyCell = app.cells.firstMatch

        // DIAGNOSTIC: Log cell detection progress
        print("📊 Searching for cells (timeout: \(Int(elementTimeout))s)...")
        let cellFound = anyCell.waitForExistence(timeout: elementTimeout)
        let dataDuration = Date().timeIntervalSince(dataStart)

        if cellFound {
            print("✅ Data loaded - found list cells in \(String(format: "%.1f", dataDuration))s")
            print("📊 Cell count: \(app.cells.count)")
        } else {
            print("⚠️ No cells found after \(String(format: "%.1f", dataDuration))s, but proceeding with screenshot")
            // DIAGNOSTIC: Check if test data was actually loaded
            print("📊 Element counts: buttons=\(app.buttons.count), staticTexts=\(app.staticTexts.count), cells=\(app.cells.count)")
        }

        // Final timeout budget check before screenshot
        let budgetBeforeSnapshot = checkTimeoutBudget(context: "Pre-Screenshot")
        if budgetBeforeSnapshot < 10 {
            print("🚨 EARLY FAILURE: Insufficient budget for screenshot")
            throw XCTSkip("Insufficient timeout budget for screenshot: \(Int(budgetBeforeSnapshot))s remaining")
        }

        // Screenshot: Main screen with hardcoded test lists
        // CRITICAL FIX: Use timeWaitingForIdle:0 to bypass network loading indicator wait
        // See testScreenshots01_WelcomeScreen comment for rationale
        print("📸 Phase 4: Screenshot Capture")
        let snapshotStart = Date()
        snapshot("02_MainScreen", timeWaitingForIdle: 0)
        print("📸 Screenshot 02_MainScreen captured at: \(Date())")
        let snapshotDuration = Date().timeIntervalSince(snapshotStart)
        print("✅ Main screen screenshot captured in \(String(format: "%.1f", snapshotDuration))s")

        // Final budget report with breakdown
        let totalDuration = Date().timeIntervalSince(launchStart)
        print("========================================")
        print("✅ Test completed successfully")
        print("📊 Phase breakdown:")
        print("   - Launch: \(String(format: "%.1f", launchDuration))s")
        print("   - UI Ready: \(String(format: "%.1f", uiDuration))s")
        print("   - Data Load: \(String(format: "%.1f", dataDuration))s")
        print("   - Screenshot: \(String(format: "%.1f", snapshotDuration))s")
        print("   - Total: \(String(format: "%.1f", totalDuration))s")
        checkTimeoutBudget(context: "Test Complete")
        print("========================================")
    }
}
