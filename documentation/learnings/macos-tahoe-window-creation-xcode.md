---
title: macOS Tahoe Window Creation and XCUITest Issues
date: 2025-12-22
severity: HIGH
category: macos
tags: [tahoe, macos-26, windowgroup, xcuitest, nshostingcontroller]
symptoms:
  - SwiftUI WindowGroup does not create window on app launch
  - App runs, menus appear, but no window
  - XCUITest elements have frames but isHittable returns false
  - click() on non-hittable elements causes test failures
  - Window screenshots capture full screen instead of window
root_cause: macOS Tahoe (26.x beta) SwiftUI WindowGroup bug plus XCUITest accessibility changes
solution: NSWindow fallback in AppDelegate plus coordinate-based tap fallback for non-hittable elements
files_affected:
  - ListAll/ListAllMac/ListAllMacApp.swift
  - ListAll/ListAllMacUITests/MacSnapshotHelper.swift
  - ListAll/ListAllMacUITests/MacScreenshotTests.swift
related: [macos-swiftui-window-accessibility-fix.md]
---

## Issue 1: No Window Created on Launch

SwiftUI's `WindowGroup` on macOS Tahoe (26.x beta) does not automatically create initial window.

**Detection**:
```bash
osascript -e 'tell application "System Events" to tell process "ListAll" to count windows'
# Returns 0 even though app is running
```

**Solution**: NSWindow fallback in AppDelegate:

```swift
class AppDelegate: NSObject, NSApplicationDelegate {
    private var fallbackWindow: NSWindow?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        NSApplication.shared.activate(ignoringOtherApps: true)

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
            self?.ensureMainWindowExists()
        }
    }

    private func ensureMainWindowExists() {
        let existingWindows = NSApp.windows.filter { window in
            window.isVisible && !window.isSheet && window.styleMask.contains(.titled)
        }
        guard existingWindows.isEmpty else { return }

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

## Issue 2: XCUITest Elements Not Hittable

Elements have frames, but `isHittable` returns false. Direct `click()` fails.

**Solution**: Coordinate-based tap fallback:

```swift
let element = app.outlines["ListsSidebar"].outlineRows.firstMatch
if element.waitForExistence(timeout: 10) {
    if element.isHittable {
        element.click()
    } else {
        let coordinate = element.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
        coordinate.tap()
    }
}
```

## Issue 3: Window Screenshot vs Full-Screen

`app.windows.firstMatch.exists` returns false for NSWindow fallback, causing full-screen capture.

**Solution**: Trust content accessibility as proof of window existence:

```swift
let sidebar = app.outlines.firstMatch
let contentAccessible = sidebar.waitForExistence(timeout: 10)
let mainWindow = app.windows.firstMatch
let windowAccessible = mainWindow.exists || mainWindow.isHittable || contentAccessible
```

## Verification

| Metric | Before Fix | After Fix |
|--------|-----------|-----------|
| Screenshots | 3840x1600 (full screen) | 1600x1304 (window only) |
| Tests | 3 failures | 5 passed |

## Key Learnings

- macOS betas may have SwiftUI bugs requiring native fallbacks
- XCUITest accessibility on macOS is less reliable than iOS - always have fallbacks
- `element.exists` returning false doesn't mean element isn't there
- Coordinate-based tapping is more reliable than direct `click()` on Tahoe
- NSWindow + NSHostingController is reliable fallback for SwiftUI window failures
