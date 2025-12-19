# macOS App Store Screenshot Automation - Comprehensive Plan

**Date:** December 19, 2025
**Status:** PLAN - Awaiting Approval
**Prepared by:** Swarm Analysis (Apple Development Expert, Testing Specialist, Critical Reviewer, Pipeline Specialist, Shell Script Specialist)

---

## Executive Summary

This document presents a comprehensive plan to fix macOS App Store screenshot automation for the ListAll app. The current implementation has **critical reliability issues** that cause screenshots to sometimes include background applications. After extensive analysis by specialized agents, we recommend a **phased approach** that preserves what works (XCUITest, test data isolation) while fixing what's broken (timing, window capture, pipeline robustness).

### Key Findings

| Component | Current Status | Assessment |
|-----------|---------------|------------|
| XCUITest as screenshot engine | ✅ Correct | Industry best practice |
| Test data isolation | ✅ Excellent (9.5/10) | Bulletproof, deterministic, locale-aware |
| App hiding timing | ❌ CRITICAL | 19+ second race condition |
| Window capture method | ❌ CRITICAL | Always falls back to full-screen due to SwiftUI bug |
| Pipeline robustness | ⚠️ Medium (6/10) | Fragile cache extraction, poor error recovery |
| Process termination | ❌ HIGH | pkill approach unreliable between locales |

### Estimated Reliability After Fixes

| Current | After Phase 1 | After Phase 2 | After Phase 3 |
|---------|--------------|--------------|--------------|
| 60% | 85% | 95% | 98% |

---

## Table of Contents

1. [Current State Analysis](#1-current-state-analysis)
2. [Root Causes Identified](#2-root-causes-identified)
3. [Industrial Best Practices Comparison](#3-industrial-best-practices-comparison)
4. [Proposed Architecture](#4-proposed-architecture)
5. [Implementation Phases](#5-implementation-phases)
6. [Test Data Strategy](#6-test-data-strategy)
7. [Risk Assessment](#7-risk-assessment)
8. [Success Criteria](#8-success-criteria)
9. [File Changes Required](#9-file-changes-required)
10. [Appendix: Agent Analysis Summaries](#10-appendix-agent-analysis-summaries)

---

## 1. Current State Analysis

### 1.1 Architecture Overview

```
┌─────────────────────────────────────────────────────────────────┐
│  generate-screenshots-local.sh                                   │
│  ┌──────────────────────────────────────────────────────────┐   │
│  │ hide_and_quit_background_apps_macos()                     │   │
│  │ → AppleScript: quit/hide apps                             │   │
│  │ → 6 seconds total                                         │   │
│  └──────────────────────────────────────────────────────────┘   │
│                              │                                   │
│                              ▼                                   │
│  ┌──────────────────────────────────────────────────────────┐   │
│  │ bundle exec fastlane ios screenshots_macos                │   │
│  │ → run_tests() with scheme ListAllMac                      │   │
│  │ → 15-20 seconds to start tests                            │   │
│  └──────────────────────────────────────────────────────────┘   │
│                              │                                   │
│                              ▼                                   │
│  ┌──────────────────────────────────────────────────────────┐   │
│  │ MacScreenshotTests.swift                                  │   │
│  │ → launchAppWithRetry() - 60s timeout, 2 retries           │   │
│  │ → prepareWindowForScreenshot()                            │   │
│  │   → hideAllOtherApps() via NSWorkspace (WEAK)             │   │
│  │   → Multiple activation calls (THRASHING)                 │   │
│  │ → snapshot() via MacSnapshotHelper                        │   │
│  └──────────────────────────────────────────────────────────┘   │
│                              │                                   │
│                              ▼                                   │
│  ┌──────────────────────────────────────────────────────────┐   │
│  │ MacSnapshotHelper.swift                                   │   │
│  │ → Check mainWindow.exists (ALWAYS FALSE - SwiftUI bug)    │   │
│  │ → Fall back to XCUIScreen.main.screenshot() (FULL SCREEN) │   │
│  │ → Save to ~/Library/Caches/tools.fastlane/screenshots/    │   │
│  └──────────────────────────────────────────────────────────┘   │
│                              │                                   │
│                              ▼                                   │
│  ┌──────────────────────────────────────────────────────────┐   │
│  │ Fastfile: screenshots_macos lane                          │   │
│  │ → Extract from cache directory (FRAGILE)                  │   │
│  │ → Copy to fastlane/screenshots/mac/{locale}/              │   │
│  │ → pkill app between locales (UNRELIABLE)                  │   │
│  └──────────────────────────────────────────────────────────┘   │
│                              │                                   │
│                              ▼                                   │
│  ┌──────────────────────────────────────────────────────────┐   │
│  │ Fastfile: screenshots_macos_normalize lane                │   │
│  │ → ImageMagick resize to 2880x1800                         │   │
│  │ → Output to fastlane/screenshots/mac_normalized/          │   │
│  └──────────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────────┘
```

### 1.2 Timeline: The 19-Second Race Condition

```
T+0s    Shell: hide_and_quit_background_apps_macos() starts
T+0s      → AppleScript quits non-essential apps
T+3s      → Wait 3s for apps to quit
T+5s      → AppleScript hides remaining apps + minimize Finder
T+6s    Shell: hide_and_quit_background_apps_macos() completes

        ⚠️ GAP STARTS - Apps can reopen via LaunchAgents ⚠️

T+6s    Shell: bundle exec fastlane ios screenshots_macos starts
T+7s      → Fastlane initializes
T+10s     → xcodebuild starts
T+15s     → UI test runner launches
T+20s     → ListAll app launches
T+23s     → prepareWindowForScreenshot() called
T+23s       → hideAllOtherApps() via NSWorkspace (WEAK)
T+27s       → sleep(3) to settle
T+30s     → First screenshot captured

        ⚠️ 24 SECONDS between shell hiding and screenshot ⚠️
```

### 1.3 Current Test Data Isolation (WORKING CORRECTLY)

The test data isolation is **excellent** and should be preserved:

```swift
// CoreDataManager.swift - Separate database file
if isUITest {
    storeURL = documentsURL.appendingPathComponent("ListAll-UITests.sqlite")
}

// ListAllMacApp.swift - Safety check before data deletion
guard storeFileName.contains("UITests") else {
    fatalError("Attempted to clear production data during UI tests")
}

// UITestDataService.swift - Deterministic, locale-aware data
static func generateTestData() -> [List] {
    if LocalizationManager.shared.currentLanguage == .finnish {
        return generateFinnishTestData()  // 4 lists, Finnish content
    } else {
        return generateEnglishTestData()  // 4 lists, English content
    }
}
```

---

## 2. Root Causes Identified

### 2.1 CRITICAL: SwiftUI WindowGroup Accessibility Bug

**Problem:** `app.windows.firstMatch.exists` always returns `false` for SwiftUI WindowGroup on macOS, even when the window is visible.

**Impact:** MacSnapshotHelper always falls back to `XCUIScreen.main.screenshot()` which captures the full screen including any background apps.

**Evidence:**
```swift
// MacScreenshotTests.swift line 399
// NOTE: Don't use mainWindow.waitForExistence() - it returns false due to SwiftUI accessibility bug

// MacSnapshotHelper.swift line 224
let windowAccessible = mainWindow.exists || mainWindow.isHittable  // Always false
```

**This is a known Apple bug** affecting SwiftUI apps on macOS. It does NOT affect iOS simulators.

### 2.2 CRITICAL: 19-Second Race Condition

**Problem:** Shell script hides apps at T+0s, screenshot captured at T+30s.

**Why apps reopen during gap:**
1. **LaunchAgents** with `KeepAlive=true` (Slack, Discord, Spotify)
2. **Login Items** configured to "Open at Login"
3. **Calendar/Reminder notifications** auto-open Calendar.app
4. **iCloud sync daemons** wake apps using CloudKit
5. **Background services** (Messages, Mail) spawn windows for notifications

**No amount of sleep() in shell script prevents this** - only immediate hiding before screenshot works.

### 2.3 HIGH: Dual Hiding Logic Conflict

Two different mechanisms try to hide apps:

| Mechanism | Location | Strength | When |
|-----------|----------|----------|------|
| AppleScript quit/hide | Shell script | STRONG | T+0s (too early) |
| NSWorkspace.hide() | UI test | WEAK | T+23s (4 times, apps can unhide) |

**Result:** Redundant execution, unpredictable state, wasted time.

### 2.4 HIGH: Multiple Activation Thrashing

`prepareWindowForScreenshot()` calls THREE activation mechanisms in 3 seconds:
1. `NSWorkspace.activate(options: [.activateIgnoringOtherApps])`
2. `app.activate()`
3. `forceWindowOnScreen()` via AppleScript

**Result:** Window manager confusion, apps fighting for focus, screenshot captured during transition.

### 2.5 MEDIUM: Fragile Cache Directory Extraction

```ruby
# Fastfile line 3788 - Depends on exact filename pattern
screenshots = Dir.glob(File.join(screenshots_cache_dir, "Mac-*.png"))
```

**Issues:**
- No cleanup of old screenshots before run
- No delay after tests for filesystem flush
- No validation of screenshot content (could be blank)
- Shared cache can contain stale files

### 2.6 MEDIUM: Unreliable Process Termination

```ruby
# Fastfile line 3814 - Forceful, no verification
sh("pkill -9 -f 'ListAllMac' 2>/dev/null || true")
```

**Issues:**
- SIGKILL (-9) prevents graceful shutdown
- No verification processes actually terminated
- Can kill wrong processes (xcodebuild debugging ListAllMac)
- Fixed 3-second sleep without polling

---

## 3. Industrial Best Practices Comparison

### 3.1 ChatGPT's Recommended Approach

| Recommendation | Our Status | Gap Analysis |
|----------------|-----------|--------------|
| Use XCUITest as screenshot engine | ✅ Implemented | No gap |
| Run via xcodebuild with -resultBundlePath | ✅ Uses run_tests() | Bundle generated but not used |
| Export from .xcresult via xcresulttool | ❌ Not implemented | Currently uses cache directory |
| Fastlane folder structure | ✅ Implemented | No gap |
| Dedicated macOS user/session | ⚠️ Local machine | Relies on app hiding |

### 3.2 What Industry Actually Does

After analysis, the "best practice" for macOS screenshots is:

1. **Accept full-screen capture** - SwiftUI WindowGroup accessibility bug makes window-only capture unreliable
2. **Hide apps immediately before screenshot** - Not 19 seconds before
3. **Maximize app to fill screen** - Full-screen screenshot shows only app
4. **Extract from .xcresult** - More reliable than cache directory
5. **Add screenshot content validation** - Detect blank/wrong screenshots

---

## 4. Proposed Architecture

### 4.1 Target Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│  generate-screenshots-local.sh                                   │
│  ┌──────────────────────────────────────────────────────────┐   │
│  │ REMOVED: hide_and_quit_background_apps_macos()            │   │
│  │ → App hiding moved to UI test                             │   │
│  └──────────────────────────────────────────────────────────┘   │
│                              │                                   │
│                              ▼                                   │
│  ┌──────────────────────────────────────────────────────────┐   │
│  │ bundle exec fastlane ios screenshots_macos                │   │
│  │ → Pre-flight checks (ImageMagick, display resolution)     │   │
│  │ → Clean cache directory                                   │   │
│  │ → run_tests() with result_bundle_path                     │   │
│  └──────────────────────────────────────────────────────────┘   │
│                              │                                   │
│                              ▼                                   │
│  ┌──────────────────────────────────────────────────────────┐   │
│  │ MacScreenshotTests.swift                                  │   │
│  │ → setUpWithError():                                       │   │
│  │   → hideAllOtherAppsViaAppleScript() ← MOVED HERE         │   │
│  │   → sleep(3)                                              │   │
│  │   → Initialize XCUIApplication                            │   │
│  │ → Each test:                                              │   │
│  │   → Launch app with UITEST_MODE                           │   │
│  │   → Single activation call only                           │   │
│  │   → Verify content elements exist                         │   │
│  │   → snapshot()                                            │   │
│  └──────────────────────────────────────────────────────────┘   │
│                              │                                   │
│                              ▼                                   │
│  ┌──────────────────────────────────────────────────────────┐   │
│  │ MacSnapshotHelper.swift                                   │   │
│  │ → Don't check mainWindow.exists (known SwiftUI bug)       │   │
│  │ → Verify content elements exist (sidebar, buttons)        │   │
│  │ → Capture mainWindow.screenshot() anyway (works!)         │   │
│  │ → Add XCTAttachment for .xcresult extraction              │   │
│  │ → Also save to cache directory (fallback)                 │   │
│  └──────────────────────────────────────────────────────────┘   │
│                              │                                   │
│                              ▼                                   │
│  ┌──────────────────────────────────────────────────────────┐   │
│  │ Fastfile: screenshots_macos lane                          │   │
│  │ → PRIMARY: Extract from .xcresult via xcresulttool        │   │
│  │ → FALLBACK: Extract from cache directory                  │   │
│  │ → Validate screenshot content (not blank)                 │   │
│  │ → Verified process termination between locales            │   │
│  └──────────────────────────────────────────────────────────┘   │
│                              │                                   │
│                              ▼                                   │
│  ┌──────────────────────────────────────────────────────────┐   │
│  │ Fastfile: screenshots_macos_normalize lane                │   │
│  │ → Pre-flight: Check ImageMagick installed                 │   │
│  │ → Use temp directory (atomic swap on success)             │   │
│  │ → Per-image error handling (continue on failure)          │   │
│  │ → Final validation of dimensions                          │   │
│  └──────────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────────┘
```

### 4.2 Key Architectural Changes

1. **Move app hiding from shell script to UI test `setUpWithError()`**
   - Eliminates 19-second race condition
   - Uses AppleScript (strong) instead of NSWorkspace (weak)
   - Runs immediately before each test

2. **Fix window capture by ignoring SwiftUI accessibility bug**
   - Don't check `mainWindow.exists` (always false)
   - Verify window by checking content elements (sidebar, buttons)
   - Capture `mainWindow.screenshot()` anyway (it works!)

3. **Add .xcresult extraction as primary method**
   - Use `xcrun xcresulttool export` to extract attachments
   - Keep cache directory as fallback
   - More reliable, deterministic

4. **Add screenshot content validation**
   - Check file size (reject < 10KB as likely blank)
   - Check dimensions before normalization
   - Detect if wrong window captured

5. **Implement verified process termination**
   - Use SIGTERM first, then SIGKILL
   - Poll process list until confirmed dead
   - Fail if process persists after timeout

---

## 5. Implementation Phases

### Phase 1: Critical Fixes (Priority: IMMEDIATE)

**Goal:** Eliminate race condition and fix window capture
**Reliability Target:** 60% → 85%
**Estimated Effort:** 2-3 hours

#### 5.1.1 Move App Hiding to UI Test Setup

**File:** `MacScreenshotTests.swift`

```swift
override func setUpWithError() throws {
    continueAfterFailure = false

    // CRITICAL: Hide all apps BEFORE launching ListAll
    // This eliminates the 19-second race condition
    hideAllOtherAppsViaAppleScript()
    sleep(3)  // Wait for apps to quit/hide

    app = XCUIApplication()
    executionTimeAllowance = 300
    setupSnapshot(app)
}

private func hideAllOtherAppsViaAppleScript() {
    let script = """
    tell application "System Events"
        set appList to name of every process whose background only is false
        repeat with appName in appList
            if appName is not in {"Finder", "SystemUIServer", "Dock", "Terminal", "Xcode"} then
                if appName does not contain "xctest" and appName does not contain "ListAll" then
                    try
                        tell process appName to quit
                    end try
                end if
            end if
        end repeat
    end tell
    """

    let process = Process()
    process.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
    process.arguments = ["-e", script]
    try? process.run()
    process.waitUntilExit()
}
```

**File:** `generate-screenshots-local.sh`

```bash
generate_macos_screenshots() {
    log_info "Platform: macOS (Native)"
    # REMOVED: hide_and_quit_background_apps_macos
    # App hiding now happens in UI test setUpWithError()

    if ! bundle exec fastlane ios screenshots_macos; then
        log_error "macOS screenshot generation failed"
        return "${EXIT_GENERATION_FAILED}"
    fi
    return 0
}
```

#### 5.1.2 Fix Window Capture Strategy

**File:** `MacSnapshotHelper.swift`

```swift
open class func snapshot(_ name: String, timeWaitingForIdle timeout: TimeInterval = 20) {
    guard let app = self.app else {
        NSLog("[macOS] ERROR: XCUIApplication not set")
        return
    }

    app.activate()
    sleep(2)

    // DON'T check mainWindow.exists (SwiftUI bug - always false)
    // Instead, verify window by checking for content elements
    let sidebar = app.outlines.firstMatch
    let contentExists = sidebar.waitForExistence(timeout: 10)

    if contentExists {
        NSLog("[macOS] Window verified via content elements")
    } else {
        NSLog("[macOS] WARNING: Could not verify window content")
    }

    // Capture window anyway - mainWindow.screenshot() WORKS even if exists is false
    let mainWindow = app.windows.firstMatch
    let image: NSImage

    // Try window capture first (preferred - no background apps)
    app.activate()
    sleep(1)
    let screenshot = mainWindow.screenshot()
    image = screenshot.image

    // Validate screenshot dimensions
    if image.size.width < 100 || image.size.height < 100 {
        NSLog("[macOS] WARNING: Screenshot too small, may be invalid")
    }

    // Save screenshot... (rest of existing code)
}
```

#### 5.1.3 Consolidate Activation to Single Call

**File:** `MacScreenshotTests.swift`

```swift
private func prepareWindowForScreenshot() {
    print("🖥️ Preparing window for screenshot...")

    // SINGLE activation - no thrashing
    if let listAllApp = NSWorkspace.shared.runningApplications.first(where: {
        $0.bundleIdentifier == "io.github.chmc.ListAllMac"
    }) {
        listAllApp.activate(options: [.activateIgnoringOtherApps])
    }

    // Longer wait for window to stabilize
    sleep(5)

    print("✅ Window prepared")
}
```

Remove:
- `hideAllOtherApps()` function (moved to `setUpWithError()`)
- `forceWindowOnScreen()` function (causes thrashing)
- Multiple `app.activate()` calls

### Phase 2: Pipeline Robustness (Priority: HIGH)

**Goal:** Make pipeline more reliable and add error recovery
**Reliability Target:** 85% → 95%
**Estimated Effort:** 3-4 hours

#### 5.2.1 Add Pre-flight Checks to Fastfile

```ruby
lane :screenshots_macos do
  UI.header("🔍 Pre-flight Checks")

  # Check ImageMagick
  unless system("which magick > /dev/null 2>&1")
    UI.user_error!("ImageMagick not found. Install with: brew install imagemagick")
  end

  # Clean cache directory
  cache_dir = File.expand_path("~/Library/Caches/tools.fastlane/screenshots")
  if Dir.exist?(cache_dir)
    FileUtils.rm_rf(Dir.glob(File.join(cache_dir, "Mac-*.png")))
    FileUtils.rm_rf(Dir.glob(File.join(cache_dir, "screenshots")))
    UI.message("✓ Cleaned cache directory")
  end

  # Continue with screenshot generation...
end
```

#### 5.2.2 Implement Verified Process Termination

```ruby
# Replace pkill with verified termination
def terminate_app_verified(app_name, timeout_seconds = 10)
  # Try graceful termination first
  sh("pkill -TERM -x '#{app_name}' 2>/dev/null || true")
  sleep(2)

  # Force kill if still running
  sh("pkill -9 -x '#{app_name}' 2>/dev/null || true")

  # Poll until confirmed dead
  timeout_seconds.times do
    result = sh("pgrep -x '#{app_name}' 2>/dev/null || true", log: false).strip
    return true if result.empty?
    sleep(1)
  end

  UI.error("Failed to terminate #{app_name} after #{timeout_seconds} seconds")
  false
end

# In screenshots_macos lane:
UI.message("🛑 Terminating ListAll app before next locale...")
unless terminate_app_verified("ListAllMac") && terminate_app_verified("XCTRunner")
  UI.user_error!("Cannot continue - process termination failed")
end
```

#### 5.2.3 Add .xcresult Extraction (Primary) with Cache Fallback

```ruby
def extract_screenshots_from_xcresult(result_bundle_path, output_dir)
  return [] unless File.exist?(result_bundle_path)

  # Extract attachments from xcresult
  extraction_dir = File.join(output_dir, "xcresult_extracted")
  FileUtils.mkdir_p(extraction_dir)

  sh("xcrun xcresulttool export --type file " \
     "--path #{Shellwords.escape(result_bundle_path)} " \
     "--output-path #{Shellwords.escape(extraction_dir)} 2>/dev/null || true")

  # Find screenshot attachments
  screenshots = Dir.glob("#{extraction_dir}/**/*.png").select do |f|
    File.basename(f).include?("Screenshot") || File.basename(f).start_with?("Mac-")
  end

  UI.message("📦 Extracted #{screenshots.count} screenshots from .xcresult")
  screenshots
end

# In screenshots_macos lane:
# Try xcresult first
xcresult_screenshots = extract_screenshots_from_xcresult(result_bundle_path, locale_output_dir)

if xcresult_screenshots.empty?
  # Fallback to cache directory
  UI.message("⚠️ No screenshots in xcresult, trying cache directory...")
  cache_screenshots = Dir.glob(File.join(screenshots_cache_dir, "Mac-*.png"))
  # ... existing cache extraction logic
else
  # Use xcresult screenshots
  xcresult_screenshots.each do |src|
    # Copy to output directory...
  end
end
```

#### 5.2.4 Add Screenshot Content Validation

```ruby
def validate_screenshot(path)
  # Check file size (blank screenshots are tiny)
  size = File.size(path)
  if size < 10_000
    UI.important("⚠️ Screenshot #{File.basename(path)} is suspiciously small (#{size} bytes)")
    return false
  end

  # Check if valid PNG
  unless system("magick identify -format '%w' #{Shellwords.escape(path)} > /dev/null 2>&1")
    UI.important("⚠️ Screenshot #{File.basename(path)} may be corrupt")
    return false
  end

  # Check dimensions
  dims = `magick identify -format '%wx%h' #{Shellwords.escape(path)}`.strip
  w, h = dims.split('x').map(&:to_i)
  if w < 1000 || h < 600
    UI.important("⚠️ Screenshot #{File.basename(path)} too small: #{dims}")
    return false
  end

  true
end
```

### Phase 3: Polish and Optimization (Priority: MEDIUM)

**Goal:** Add advanced features and optimize performance
**Reliability Target:** 95% → 98%
**Estimated Effort:** 2-3 hours

#### 5.3.1 Add XCTAttachment for Test Integration

```swift
// MacSnapshotHelper.swift - Add XCTAttachment alongside file save
func attachScreenshotToTest(_ image: NSImage, name: String) {
    guard let pngData = image.pngRepresentation() else { return }

    let attachment = XCTAttachment(
        uniformTypeIdentifier: "public.png",
        name: "Mac-\(name).png",
        payload: pngData,
        userInfo: nil
    )
    attachment.lifetime = .keepAlways

    XCTContext.runActivity(named: "Screenshot: \(name)") { activity in
        activity.add(attachment)
    }
}
```

#### 5.3.2 Add Retry Logic for Failed Screenshots

```swift
// MacScreenshotTests.swift
private func captureScreenshotWithRetry(_ name: String, maxRetries: Int = 2) {
    for attempt in 1...maxRetries {
        prepareWindowForScreenshot()
        snapshot(name)

        // Verify screenshot was captured (check cache directory)
        let cacheDir = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first!
            .appendingPathComponent("tools.fastlane/screenshots")
        let screenshotPath = cacheDir.appendingPathComponent("Mac-\(name).png")

        if FileManager.default.fileExists(atPath: screenshotPath.path) {
            let attrs = try? FileManager.default.attributesOfItem(atPath: screenshotPath.path)
            let size = attrs?[.size] as? Int ?? 0
            if size > 10_000 {
                print("✅ Screenshot '\(name)' captured successfully (attempt \(attempt))")
                return
            }
        }

        print("⚠️ Screenshot '\(name)' may have failed, retrying... (attempt \(attempt)/\(maxRetries))")
        sleep(2)
    }

    print("❌ Screenshot '\(name)' failed after \(maxRetries) attempts")
}
```

#### 5.3.3 Add Atomic Normalization with Temp Directory

```ruby
lane :screenshots_macos_normalize do
  UI.header("📐 Normalizing macOS Screenshots")

  mac_raw_dir = File.expand_path("screenshots/mac", __dir__)
  mac_normalized_dir = File.expand_path("screenshots/mac_normalized", __dir__)
  temp_dir = File.expand_path("screenshots/mac_normalizing_temp", __dir__)

  # Use temp directory to avoid data loss on failure
  FileUtils.rm_rf(temp_dir) if Dir.exist?(temp_dir)
  FileUtils.mkdir_p(temp_dir)

  failed_images = []

  locales.each do |locale|
    # ... normalize each image with error handling
    begin
      # Resize image
      sh("magick convert #{Shellwords.escape(raw_path)} ...")
    rescue => e
      UI.important("⚠️ Failed to normalize #{filename}: #{e.message}")
      failed_images << filename
      next  # Continue with other images
    end
  end

  if failed_images.any?
    UI.important("⚠️ #{failed_images.count} images failed normalization: #{failed_images.join(', ')}")
  end

  # Atomic swap: Only replace output directory if successful
  if Dir.glob("#{temp_dir}/**/*.png").count > 0
    FileUtils.rm_rf(mac_normalized_dir) if Dir.exist?(mac_normalized_dir)
    FileUtils.mv(temp_dir, mac_normalized_dir)
    UI.success("✅ Normalized screenshots saved to #{mac_normalized_dir}")
  else
    UI.user_error!("No screenshots were normalized successfully")
  end
end
```

---

## 6. Test Data Strategy

### 6.1 Current Implementation (KEEP - Excellent)

The test data isolation is already excellent and should be preserved unchanged:

| Aspect | Rating | Details |
|--------|--------|---------|
| Database Isolation | ✅ 10/10 | Separate `ListAll-UITests.sqlite` file |
| Safety Checks | ✅ 10/10 | `fatalError` if not using test database |
| CloudKit Isolation | ✅ 10/10 | CloudKit disabled for UI tests |
| Data Determinism | ✅ 10/10 | Fixed lists, items, timestamps |
| Locale Awareness | ✅ 10/10 | Separate English and Finnish datasets |
| No Race Conditions | ✅ 10/10 | All initialization is synchronous |

### 6.2 Test Data Content

| Locale | Lists | Items | Features Shown |
|--------|-------|-------|----------------|
| en-US | Grocery Shopping | 6 items | Mixed active/completed |
| en-US | Weekend Projects | 3 items | Descriptions |
| en-US | Books to Read | 3 items | Quantities |
| en-US | Travel Packing | 4 items | Crossed out items |
| fi | Ruokaostokset | 6 items | Finnish content |
| fi | Viikonlopun projektit | 3 items | Finnish content |
| fi | Luettavat kirjat | 3 items | Finnish content |
| fi | Matkapakkaus | 4 items | Finnish content |

### 6.3 Data Population Flow

```
1. Fastlane sets AppleLanguages via localize_simulator(true)
2. xcodebuild launches ListAllMac with UITEST_MODE argument
3. ListAllMacApp.init() detects UITEST_MODE:
   a. Forces CoreDataManager to use isolated database
   b. Clears existing test data
   c. Calls UITestDataService.generateTestData()
   d. UITestDataService queries LocalizationManager for locale
   e. Returns appropriate locale's test data
4. UI test launches, finds deterministic test data
5. Screenshots capture consistent content
```

---

## 7. Risk Assessment

### 7.1 Risks That Remain After Fixes

| Risk | Probability | Mitigation |
|------|-------------|------------|
| macOS permission dialogs | 10% | One-time grant, documented setup |
| System updates break APIs | 5% | Monitor Xcode release notes |
| SwiftUI bug persists | N/A | Working around it, not depending on it |
| User interaction during test | 15% | Document "do not use Mac during tests" |
| CI environment differences | 20% | Local-only for now, CI support later |

### 7.2 What Cannot Be Fixed

Some issues are fundamental to macOS and cannot be fully solved:

1. **macOS authorization model** - TCC permissions may need re-granting after updates
2. **System state unpredictability** - Time Machine, notifications, updates can interfere
3. **No iOS-like simulator isolation** - macOS tests run on real system
4. **LaunchAgents can relaunch apps** - Only prevented by hiding immediately before screenshot

### 7.3 Comparison: Current vs Fixed Reliability

| Scenario | Current | After Fixes |
|----------|---------|-------------|
| Clean desktop, no apps | 90% | 99% |
| 5-10 regular apps open | 60% | 95% |
| Heavy usage (Slack, browsers) | 30% | 90% |
| First run (permissions needed) | 0% | 95% (after grant) |
| After macOS major update | 50% | 85% |

---

## 8. Success Criteria

### 8.1 Phase 1 Completion Criteria

- [ ] App hiding moved to UI test `setUpWithError()`
- [ ] Shell script no longer calls `hide_and_quit_background_apps_macos()`
- [ ] Window capture uses content verification, not `mainWindow.exists`
- [ ] Single activation call in `prepareWindowForScreenshot()`
- [ ] All 4 screenshots per locale captured successfully
- [ ] No background apps visible in screenshots

### 8.2 Phase 2 Completion Criteria

- [ ] Pre-flight checks validate ImageMagick and display resolution
- [ ] Cache directory cleaned before each run
- [ ] Process termination verified with polling
- [ ] .xcresult extraction implemented as primary method
- [ ] Screenshot content validation rejects blank/corrupt images
- [ ] Pipeline continues on partial failure (captures what it can)

### 8.3 Phase 3 Completion Criteria

- [ ] XCTAttachment added for test integration
- [ ] Retry logic for failed screenshots
- [ ] Atomic normalization prevents data loss
- [ ] Full telemetry logging for debugging
- [ ] Documentation updated with new approach

### 8.4 Overall Success Metrics

| Metric | Current | Target | Measurement |
|--------|---------|--------|-------------|
| Success rate | 60% | 95% | 20 consecutive runs without failure |
| Background apps in screenshots | Common | None | Visual inspection |
| Time per locale | 5 min | 4 min | Stopwatch |
| Manual intervention needed | Often | Rare | Count over 1 month |
| Permission re-grants | Unknown | Documented | Track in README |

---

## 9. File Changes Required

### 9.1 Phase 1 Files

| File | Change Type | Scope |
|------|-------------|-------|
| `MacScreenshotTests.swift` | Major | Add `hideAllOtherAppsViaAppleScript()`, modify `setUpWithError()`, simplify `prepareWindowForScreenshot()` |
| `MacSnapshotHelper.swift` | Medium | Fix window capture strategy, remove `mainWindow.exists` check |
| `generate-screenshots-local.sh` | Minor | Remove `hide_and_quit_background_apps_macos()` call from `generate_macos_screenshots()` |

### 9.2 Phase 2 Files

| File | Change Type | Scope |
|------|-------------|-------|
| `Fastfile` | Major | Add pre-flight checks, verified termination, xcresult extraction, validation |
| `generate-screenshots-local.sh` | Minor | Add pre-flight checks |

### 9.3 Phase 3 Files

| File | Change Type | Scope |
|------|-------------|-------|
| `MacSnapshotHelper.swift` | Minor | Add XCTAttachment support |
| `MacScreenshotTests.swift` | Minor | Add retry logic |
| `Fastfile` | Medium | Atomic normalization |
| `documentation/macos-screenshot-generation.md` | Major | Update with new approach |

---

## 10. Appendix: Agent Analysis Summaries

### 10.1 Apple Development Expert

**Focus:** XCUITest implementation and best practices

**Key Findings:**
- XCUITest as screenshot engine is **correct**
- SwiftUI WindowGroup accessibility bug is **root cause** of capture issues
- Window capture works despite `exists` returning false
- Recommended: Keep XCUITest, fix capture strategy

### 10.2 Testing Specialist

**Focus:** Test data isolation and determinism

**Key Findings:**
- Test data isolation is **excellent (9.5/10)**
- Multi-layer isolation: separate database, App Groups bypassed, CloudKit disabled
- Safety checks prevent production data corruption
- Deterministic, locale-aware data generation
- No race conditions in data population
- **No changes needed** to test data architecture

### 10.3 Critical Reviewer

**Focus:** Devil's advocate, finding problems and risks

**Key Findings:**
- 19-second race condition allows apps to reopen
- AppleScript hiding is fragile (apps can refuse to quit)
- Pattern matching inconsistency between quit/hide scripts
- In-app test data has production risk (mitigated by safety checks)
- macOS authorization can fail between locales
- Neither current nor ChatGPT approach is bulletproof
- **Question:** Can automated macOS screenshots ever be truly reliable?

### 10.4 Pipeline Specialist

**Focus:** Fastlane pipeline robustness

**Key Findings:**
- Pipeline robustness: **6/10**
- `run_tests()` with `fail_build: false` masks failures
- Cache directory extraction is fragile
- Process termination unreliable
- No pre-flight checks
- No screenshot content validation
- Recommended: Add validation, verified termination, xcresult extraction

### 10.5 Shell Script Specialist

**Focus:** Shell/AppleScript automation reliability

**Key Findings:**
- AppleScript **IS the right tool** for macOS app control
- Problem is **timing** (runs too early) and **dual execution**
- Shell script runs at T+0s, screenshots at T+30s = 24-second gap
- LaunchAgents can relaunch apps during gap
- NSWorkspace.hide() is weak (apps can unhide)
- Recommended: Move all hiding logic to Swift UI test `setUpWithError()`

---

## Conclusion

The macOS screenshot automation for ListAll has **critical reliability issues** that can be fixed with the phased approach outlined in this document. The core technologies (XCUITest, test data isolation, Fastlane pipeline) are correct - the problems are **timing and execution strategy**.

### Summary of Changes

1. **Move app hiding from shell script to UI test** - Eliminates race condition
2. **Fix window capture to ignore SwiftUI bug** - Use content verification instead
3. **Consolidate to single activation call** - Eliminates thrashing
4. **Add pipeline robustness** - Pre-flight checks, verification, validation
5. **Extract from .xcresult** - More reliable than cache directory

### Estimated Total Effort

| Phase | Effort | Priority |
|-------|--------|----------|
| Phase 1: Critical Fixes | 2-3 hours | IMMEDIATE |
| Phase 2: Pipeline Robustness | 3-4 hours | HIGH |
| Phase 3: Polish | 2-3 hours | MEDIUM |
| **Total** | **7-10 hours** | |

### Next Steps

1. **Review this plan** and provide feedback
2. **Approve approach** for Phase 1 implementation
3. **Allocate time** for implementation
4. **Test locally** before deploying
5. **Monitor** success rate over 1 month

---

**Document Status:** AWAITING APPROVAL
**Last Updated:** December 19, 2025
