# macOS Tahoe (26.x) Window Creation & XCUITest Accessibility Issues

## Date
2025-12-22

## Problem Summary
On macOS Tahoe (26.x), macOS screenshot generation via XCUITest failed due to two separate issues:
1. SwiftUI's `WindowGroup` does not create windows on app launch
2. XCUITest elements are "not hittable" even when visible and accessible

## Root Causes

### Issue 1: No Window Created on Launch
SwiftUI's `WindowGroup` scene on macOS Tahoe (26.x beta) does not automatically create the initial window when the app launches. The app runs, menus appear, but no window is created.

**Detection**:
```bash
# Check NSApp windows count from shell
osascript -e 'tell application "System Events" to tell process "ListAll" to count windows'
# Returns 0 even though app is running
```

**Solution**: Implement NSWindow fallback in `AppDelegate`:

```swift
class AppDelegate: NSObject, NSApplicationDelegate {
    private var fallbackWindow: NSWindow?

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Always set activation policy on Tahoe
        NSApp.setActivationPolicy(.regular)
        NSApplication.shared.activate(ignoringOtherApps: true)

        // Check for missing windows after 1 second
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
            self?.ensureMainWindowExists()
        }
    }

    private func ensureMainWindowExists() {
        let existingWindows = NSApp.windows.filter { window in
            window.isVisible && !window.isSheet && window.styleMask.contains(.titled)
        }

        guard existingWindows.isEmpty else { return }

        // Create fallback window manually
        let contentView = MacMainView()
            .environmentObject(DataManager.shared)
            .environment(\.managedObjectContext, CoreDataManager.shared.viewContext)

        let hostingController = NSHostingController(rootView: contentView)
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 1200, height: 800),
            styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )

        window.title = "ListAll"
        window.contentViewController = hostingController
        window.center()
        window.makeKeyAndOrderFront(nil)
        self.fallbackWindow = window
    }
}
```

### Issue 2: XCUITest Elements Not Hittable
On macOS Tahoe, XCUITest can find elements (they have frames), but `isHittable` returns false even though they're visible. Calling `click()` on these elements causes test failures.

**Detection**:
```
Not hittable: OutlineRow, {{678.0, 317.0}, {140.0, 19.0}}
```

**Solution**: Use coordinate-based tap as fallback:

```swift
let element = app.outlines["ListsSidebar"].outlineRows.firstMatch
if element.waitForExistence(timeout: 10) {
    if element.isHittable {
        element.click()
    } else {
        // Fallback: tap at element's center coordinates
        let coordinate = element.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
        coordinate.tap()
    }
}
```

### Issue 3: Window Screenshot vs Full-Screen Fallback
XCUITest's `app.windows.firstMatch.exists` returns false for NSWindow fallback windows, causing screenshot code to use full-screen capture instead of window-only capture.

**Solution**: Trust content element accessibility as proof of window existence:

```swift
// In MacSnapshotHelper.swift
let sidebar = app.outlines.firstMatch
let contentAccessible = sidebar.waitForExistence(timeout: 10)

let mainWindow = app.windows.firstMatch
let windowExists = mainWindow.exists
let windowHittable = mainWindow.isHittable
// If content is accessible, window MUST exist
let windowAccessible = windowExists || windowHittable || contentAccessible
```

## Files Modified
- `ListAll/ListAllMac/ListAllMacApp.swift` - Added NSWindow fallback in AppDelegate
- `ListAll/ListAllMacUITests/MacSnapshotHelper.swift` - Fixed window accessibility detection
- `ListAll/ListAllMacUITests/MacScreenshotTests.swift` - Added coordinate tap fallback for non-hittable elements

## Verification
Before fix:
- Screenshots: 3840×1600 (full screen with desktop background)
- Tests: 3 failures ("Not hittable: OutlineRow")

After fix:
- Screenshots: 1600×1304 (window only, clean)
- Tests: 5 passed, 0 failures

## Key Learnings
1. macOS beta versions (Tahoe 26.x) may have SwiftUI bugs requiring native fallbacks
2. XCUITest accessibility on macOS is less reliable than on iOS - always have fallback strategies
3. `element.exists` returning false doesn't mean the element isn't there - verify via content elements
4. Coordinate-based tapping is more reliable than direct `click()` on macOS Tahoe
5. NSWindow + NSHostingController is a reliable fallback for SwiftUI window creation failures
