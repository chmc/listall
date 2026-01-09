# macOS Screenshot Generation - Best Practice Implementation Plan

## Executive Summary

**The correct approach**: Try window-only screenshots via XCUITest first, with fallback to full-screen capture. Post-process all screenshots to 2880x1800 (16:10) for App Store.

**Current issues identified**:
1. Using `XCUIScreen.main.screenshot()` captures entire screen (antipattern)
2. Multiple overlapping workarounds (shell script + UI test both hiding apps)
3. Race conditions between preparation and capture
4. Technical debt from debugging (emoji logging, marker files)
5. No window state verification before screenshot

---

## CRITICAL: Pre-Implementation Validation Required

**Before implementing this plan, the core assumption MUST be validated.**

### Validation Test

Run this minimal test to prove window screenshot works on macOS with SwiftUI:

```swift
func testWindowScreenshotCapability() {
    let app = XCUIApplication()
    app.launchArguments = ["UITEST_MODE"]
    app.launch()

    // Wait for UI
    let sidebar = app.outlines.firstMatch
    XCTAssertTrue(sidebar.waitForExistence(timeout: 10), "Sidebar should exist")

    // Check window accessibility
    let mainWindow = app.windows.firstMatch
    print("DEBUG: window.exists = \(mainWindow.exists)")
    print("DEBUG: window.isHittable = \(mainWindow.isHittable)")
    print("DEBUG: window.frame = \(mainWindow.frame)")

    // Attempt window screenshot
    if mainWindow.exists || mainWindow.isHittable {
        let screenshot = mainWindow.screenshot()
        print("SUCCESS: Window screenshot size = \(screenshot.image.size)")
        XCTAssertGreaterThan(screenshot.image.size.width, 0)
    } else {
        print("FAILURE: Window not accessible for screenshot")
        XCTFail("Window screenshot not possible - need alternative approach")
    }
}
```

**Expected outcomes**:
- If `window.exists == true`: Window screenshot will work, proceed with plan
- If `window.exists == false` but `isHittable == true`: May still work, test it
- If both are false: Window screenshot WILL NOT work, use full-screen only

---

## Research Findings

### Apple App Store Requirements
- **Resolution**: 2880×1800 pixels (16:10 aspect ratio) recommended
- **Minimum**: 1280×800 pixels
- **Format**: PNG or JPEG, RGB, no transparency
- **Count**: 1-10 per locale (3 minimum recommended)

### Industry Standard 2025 (Jesse Squires)
1. XCUITest captures raw window screenshots
2. **Retrobatch** post-processing adds:
   - Corner radius: 24pt
   - Border: 1pt (#D9D9D9 light / #636363 dark)
   - Drop shadow: (0,-50) offset, 70pt blur, 60% opacity
3. Overlay on desktop background (optional)
4. Resize to 2880×1800

### SwiftUI Window Accessibility Issue

**Known bug**: SwiftUI's `WindowGroup` on macOS may not expose windows to the accessibility hierarchy correctly. This causes:
- `app.windows.firstMatch.exists` returns `false`
- `app.windows.firstMatch.screenshot()` crashes with "Element does not exist"

**However**: Content elements (buttons, outlines, text) ARE accessible even when window is not.

---

## Recommended Approach

### Strategy: Window Screenshot with Graceful Fallback

1. **Pre-check window accessibility** using `exists` and `isHittable` properties
2. **If accessible**: Capture window-only screenshot (clean, no background)
3. **If not accessible**: Hide other apps, then capture full screen
4. **Post-process**: Normalize all screenshots to 2880×1800

**Key insight**: The fallback path (full-screen) still needs app hiding to work correctly.

---

## Implementation Plan

### Phase 0: Validation (REQUIRED FIRST)

Run the validation test above. Document results:
- [ ] Window exists: yes/no
- [ ] Window isHittable: yes/no
- [ ] Window screenshot succeeds: yes/no
- [ ] Screenshot dimensions: ____

**Decision point**: If window screenshot fails, skip to "Alternative: Full-Screen Only" section.

### Phase 1: Implement Screenshot with Fallback

**File**: `ListAll/ListAllMacUITests/MacSnapshotHelper.swift`

**IMPORTANT**: `XCUIElement.screenshot()` does NOT throw exceptions - it crashes if element doesn't exist. Must use pre-checks, not try-catch.

```swift
/// Capture screenshot with window-first strategy and full-screen fallback
/// Returns: NSImage of the captured screenshot
private func captureScreenshot(app: XCUIApplication, name: String) -> NSImage {
    // Step 1: Activate and stabilize
    app.activate()

    // Step 2: Wait for content to prove UI is ready
    let sidebar = app.outlines.firstMatch
    guard sidebar.waitForExistence(timeout: 10) else {
        NSLog("[macOS] WARNING: Content not accessible, using full-screen fallback")
        return captureFullScreenWithAppHiding(app: app)
    }

    // Step 3: Check if window is accessible
    let mainWindow = app.windows.firstMatch
    let windowAccessible = mainWindow.exists || mainWindow.isHittable

    NSLog("[macOS] Window check: exists=\(mainWindow.exists), isHittable=\(mainWindow.isHittable)")

    // Step 4: Capture using appropriate method
    if windowAccessible {
        // Window is accessible - capture window only (preferred)
        app.activate()
        sleep(1)  // Brief stabilization
        let screenshot = mainWindow.screenshot()
        NSLog("[macOS] SUCCESS: Window-only screenshot captured")
        return screenshot.image
    } else {
        // Window not accessible - use full-screen with app hiding
        NSLog("[macOS] Window not accessible, using full-screen fallback")
        return captureFullScreenWithAppHiding(app: app)
    }
}

/// Fallback: Hide other apps then capture full screen
private func captureFullScreenWithAppHiding(app: XCUIApplication) -> NSImage {
    // Hide other apps first (essential for clean full-screen capture)
    hideAllOtherApps()
    sleep(2)  // Allow apps to hide

    // Activate our app
    app.activate()
    sleep(1)

    // Capture full screen
    let screenshot = XCUIScreen.main.screenshot()
    NSLog("[macOS] Full-screen screenshot captured (will be cropped in post-processing)")
    return screenshot.image
}
```

**Key changes from original plan**:
1. Use `exists`/`isHittable` checks instead of try-catch (screenshot() doesn't throw)
2. KEEP `hideAllOtherApps()` for the fallback path
3. Add logging to track which method was used

### Phase 2: Selective Workaround Removal

**KEEP for fallback path**:
- `hideAllOtherApps()` in MacScreenshotTests.swift - needed for full-screen fallback

**REMOVE** (only needed if window capture always works):
- AppleScript window forcing in MacSnapshotHelper.swift
- Duplicate activation attempts
- Shell script app hiding (consolidate into UI test only)

**Conditional removal**: Only remove these AFTER validation confirms window screenshot works >90% of the time.

### Phase 3: Fix Post-Processing

**File**: `fastlane/Fastfile`

**Problem**: `sips -z` can distort images if aspect ratio differs.

**Solution**: Use ImageMagick with proper resize and crop:

```ruby
lane :screenshots_macos_normalize do
  Dir.glob("fastlane/screenshots/mac/**/*.png").each do |file|
    # Resize to cover 2880x1800, then crop to exact size (maintains aspect ratio)
    sh("convert '#{file}' -resize 2880x1800^ -gravity center -extent 2880x1800 '#{file}'")
  end

  UI.success("Normalized macOS screenshots to 2880x1800")
end
```

**Fallback if ImageMagick not available**:
```ruby
# Using sips (built-in macOS) - may letterbox instead of crop
sh("sips --resampleHeightWidth 1800 2880 '#{file}'")
```

### Phase 4: Add Telemetry

Track which capture method succeeds to inform future decisions:

```swift
enum ScreenshotMethod: String {
    case windowOnly = "window"
    case fullScreenFallback = "fullscreen"
}

// At end of test run, log statistics
private static var screenshotStats: [String: ScreenshotMethod] = [:]

func logScreenshotStats() {
    let windowCount = screenshotStats.values.filter { $0 == .windowOnly }.count
    let fallbackCount = screenshotStats.values.filter { $0 == .fullScreenFallback }.count
    let total = screenshotStats.count

    NSLog("[macOS] Screenshot stats: window=\(windowCount)/\(total), fallback=\(fallbackCount)/\(total)")

    if fallbackCount > windowCount {
        NSLog("[macOS] WARNING: Fallback used more than window capture - consider full-screen as primary")
    }
}
```

### Phase 5: Clean Up Technical Debt

**Only after validation confirms approach works**:

- Remove excessive debug logging (keep essential logs)
- Remove marker file writing
- Replace remaining `sleep()` with `waitForExistence()` where possible
- Use accessibility identifiers instead of hardcoded text

---

## Alternative: Full-Screen Only (If Validation Fails)

If the validation test proves window screenshot does NOT work:

**Accept full-screen capture as the correct approach for macOS SwiftUI apps.**

In this case:
1. Keep `hideAllOtherApps()` as the primary mechanism
2. Keep AppleScript window activation
3. Focus on making full-screen + crop reliable
4. Remove the complexity of trying window capture first

This is a valid outcome - the App Store only cares about the final 2880x1800 image, not how it was captured.

---

## Files to Modify

| File | Changes | Conditional |
|------|---------|-------------|
| MacSnapshotHelper.swift | Add window-first capture with fallback | Always |
| MacScreenshotTests.swift | Keep hideAllOtherApps() for fallback | Always |
| fastlane/Fastfile | Fix post-processing to use ImageMagick | Always |
| generate-screenshots-local.sh | Remove app hiding (consolidate to UI test) | After validation |

---

## Risk Assessment

### Risk 1: Window screenshot never works
**Mitigation**: Fallback to full-screen with app hiding. Telemetry will show if fallback is always used, prompting us to simplify to full-screen only.

### Risk 2: Fallback produces different visual results
**Mitigation**: Post-processing normalizes both to 2880x1800. Visually inspect both methods' output during validation.

### Risk 3: App hiding race condition (existing issue)
**Mitigation**: Move all app hiding to UI test (eliminate shell script timing), use longer stabilization wait.

### Risk 4: Post-processing distorts images
**Mitigation**: Use ImageMagick with center-crop instead of sips stretch.

---

## Rollback Plan

If implementation causes regressions:

1. **Immediate**: Revert MacSnapshotHelper.swift changes
2. **Restore**: Full-screen capture as primary (current behavior)
3. **Keep**: Any post-processing improvements (independent of capture method)

Git commands:
```bash
git checkout HEAD~1 -- ListAll/ListAllMacUITests/MacSnapshotHelper.swift
git checkout HEAD~1 -- ListAll/ListAllMacUITests/MacScreenshotTests.swift
```

---

## Success Criteria

1. [ ] Validation test passes (window or fallback works)
2. [ ] Screenshots capture ListAll without other apps visible
3. [ ] Post-processing produces valid 2880×1800 images
4. [ ] Test passes reliably (no flaky failures)
5. [ ] Telemetry shows >50% window capture success (or decision to use full-screen only)

---

## Testing Checklist

Before merging:

- [ ] Run validation test, document results
- [ ] Test on macOS 14 Sonoma
- [ ] Test on macOS 15 Sequoia (if available)
- [ ] Verify fallback triggers correctly when window inaccessible
- [ ] Inspect post-processed screenshots for quality
- [ ] Run full screenshot generation for all locales
- [ ] Verify screenshots meet App Store requirements

---

## References

- [Apple Screenshot Specifications](https://developer.apple.com/help/app-store-connect/reference/screenshot-specifications/)
- [Jesse Squires - Automate Mac Screenshots 2025](https://www.jessesquires.com/blog/2025/03/24/automate-perfect-mac-screenshots/)
- [MacPaw Research - Parsing macOS UI](https://research.macpaw.com/publications/how-to-parse-macos-app-ui)

---

## Revision History

| Date | Change | Reason |
|------|--------|--------|
| 2025-12-16 | Initial plan | Research findings |
| 2025-12-16 | Added validation phase | Critical review: core assumption unvalidated |
| 2025-12-16 | Fixed error handling | Critical review: screenshot() doesn't throw |
| 2025-12-16 | Keep hideAllOtherApps for fallback | Critical review: fallback needs it |
| 2025-12-16 | Added rollback plan | Critical review: need recovery path |
| 2025-12-16 | Fixed post-processing | Critical review: sips distorts images |
