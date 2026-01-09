# macOS SwiftUI Window Accessibility Fix

## Problem Summary

**Issue**: SwiftUI WindowGroup windows on macOS are NOT visible in the accessibility hierarchy, causing XCUITest failures.

**Symptoms**:
- `app.windows.count` returns 0 in XCUITest
- `app.windows.firstMatch.waitForExistence(timeout: 10)` returns false
- `osascript -e 'tell application "System Events" to tell process "ListAll" to get count of windows'` returns 0
- Menu bar items ARE visible in accessibility (proves app is running)
- Window IS visible on screen (proves window exists)
- UI elements inside window (buttons, outlines) ARE accessible via `app.buttons`, `app.outlines`

## Root Cause Analysis

### 1. NSHostingView Hidden Accessibility Layer

SwiftUI on macOS uses `NSHostingView` to bridge SwiftUI views into AppKit. This creates a **hidden accessibility layer** that standard accessibility tools cannot track out of the box.

**Reference**: [MacPaw Research - Parsing macOS application UI](https://research.macpaw.com/publications/how-to-parse-macos-app-ui)

> "An additional layer is added by NSHostingView, which is not reflected in the structure fetched for the window. Other children's elements are placed on the hidden layer; none of the mentioned tools can track this layer out of the box."

### 2. SwiftUI WindowGroup Default Behavior

SwiftUI's `WindowGroup` on macOS does not automatically expose windows to the accessibility hierarchy in the same way AppKit `NSWindow` does. The window exists in the AppKit layer but may not be properly registered with the accessibility API.

**References**:
- [Apple Developer - WindowGroup Documentation](https://developer.apple.com/documentation/swiftui/windowgroup)
- [SwiftUI Window Management](https://swiftwithmajid.com/2022/11/02/window-management-in-swiftui/)

### 3. XCUITest Accessibility Hierarchy Limitations

XCTest's UI testing system is built on top of the Accessibility API, which means it can only see elements that have been loaded into the accessibility hierarchy. SwiftUI may delay or omit loading certain elements.

**Reference**: [Xebia - iOS UI Testing Limits](https://xebia.com/blog/ios-ui-testing-and-why-it-does-not-always-work-a-k-a-pushing-the-limits-of-the-xctest-framework/)

> "XCTest's UI Testing system is built on top of Accessibility, which means the system is only aware of elements that have been loaded into the accessibility hierarchy at the time of each request."

## Current Workaround in MacScreenshotTests.swift

The current implementation works around this issue by:

1. **Not relying on `app.windows`** - The code does NOT use `app.windows.count` to verify window existence
2. **Using content-based verification** - Instead checks for actual UI elements:
   ```swift
   let sidebar = app.outlines["ListsSidebar"]
   if sidebar.waitForExistence(timeout: 10) {
       print("✅ Window verified - found sidebar content")
   }
   ```

3. **AppleScript fallback** - Uses AppleScript to force window positioning when needed:
   ```swift
   tell application "System Events"
       tell process "ListAll"
           set frontmost to true
           if (count of windows) > 0 then
               perform action "AXRaise" of window 1
           end if
       end tell
   end tell
   ```

4. **Screenshot capture workaround** - Uses `mainWindow.screenshot()` which DOES work even though `mainWindow.exists` is false:
   ```swift
   let mainWindow = app.windows.firstMatch
   // mainWindow.exists returns false, but...
   let screenshot = mainWindow.screenshot()  // This still works!
   ```

## Why Screenshots Still Work

**Critical Discovery**: Even though `app.windows.firstMatch.exists` returns false, `app.windows.firstMatch.screenshot()` STILL CAPTURES THE WINDOW.

This proves the window IS in the accessibility hierarchy at some level - XCUITest just can't query it via the standard `exists` or `waitForExistence()` API.

The screenshot is captured because:
1. `XCUIElement.screenshot()` uses a different code path than `exists`
2. It likely queries the screen region directly via Core Graphics/Quartz
3. The window frame is known to XCUITest even if the window "element" is not queryable

## Solutions

### Solution 1: Current Workaround (RECOMMENDED - Already Implemented)

**Pros**:
- Already working in production
- No code changes needed
- Reliable across macOS versions

**Cons**:
- Slightly indirect (checking content instead of window)
- More verbose test code

**Implementation**: See `MacScreenshotTests.swift` lines 238-262, 299-334, 391-425

### Solution 2: Add Explicit Window Accessibility Identifier (ATTEMPTED - Does Not Work)

SwiftUI's WindowGroup does not support `.accessibilityIdentifier()` modifier:

```swift
WindowGroup {
    MacMainView()
}
.accessibilityIdentifier("MainWindow")  // ❌ Compiler error - modifier not available
```

This is a known SwiftUI limitation - window-level modifiers are restricted.

### Solution 3: Use NSWindow Bridge (COMPLEX - Not Recommended)

Create an `NSViewRepresentable` to access the underlying `NSWindow` and set accessibility properties:

```swift
struct WindowAccessor: NSViewRepresentable {
    let identifier: String

    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        DispatchQueue.main.async {
            view.window?.setAccessibilityIdentifier(identifier)
        }
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {}
}

// In MacMainView:
var body: some View {
    ZStack {
        WindowAccessor(identifier: "MainWindow")
        // Rest of view hierarchy
    }
}
```

**Cons**:
- Adds complexity
- Brittle (depends on view hierarchy timing)
- May break across macOS versions
- Not guaranteed to work with XCUITest's query system

### Solution 4: Migrate to AppKit NSWindow (NOT RECOMMENDED)

Replace SwiftUI `WindowGroup` with AppKit `NSWindow` management.

**Cons**:
- Loses all SwiftUI window management benefits
- Major refactoring required
- Against SwiftUI best practices
- Not future-proof

## Recommended Approach: Keep Current Implementation

The current workaround in `MacScreenshotTests.swift` is **correct and robust**:

1. ✅ Uses content-based verification instead of window queries
2. ✅ AppleScript fallback for edge cases
3. ✅ Screenshots work despite `exists` returning false
4. ✅ No code changes required to SwiftUI app
5. ✅ Reliable across macOS versions

## Additional Context

### Why Menu Bar IS Visible

The menu bar is managed by AppKit (`NSMenu`/`NSMenuItem`), not SwiftUI, so it has proper accessibility registration by default. This is why `AppCommands()` in `ListAllMacApp.swift` works fine with accessibility.

### Why Buttons/Outlines ARE Visible

SwiftUI DOES register individual UI elements (buttons, text fields, outlines) in the accessibility hierarchy when they have explicit identifiers:

```swift
List { ... }
    .accessibilityIdentifier("ListsSidebar")  // ✅ This works
```

It's only the WINDOW container itself that's not queryable via `app.windows`.

## Conclusion

**This is NOT a bug in your code** - it's a known limitation of SwiftUI's accessibility integration on macOS. The current implementation works around it correctly.

**No changes needed** - the screenshot tests are using the correct approach.

## References

- [Apple Developer - WindowGroup](https://developer.apple.com/documentation/swiftui/windowgroup)
- [MacPaw Research - NSHostingView Accessibility Layer](https://research.macpaw.com/publications/how-to-parse-macos-app-ui)
- [XCUITest SwiftUI Guide](https://www.swiftyplace.com/blog/xcuitest-ui-testing-swiftui)
- [Xebia - XCTest Framework Limits](https://xebia.com/blog/ios-ui-testing-and-why-it-does-not-always-work-a-k-a-pushing-the-limits-of-the-xctest-framework/)
- [SwiftUI Window Management](https://swiftwithmajid.com/2022/11/02/window-management-in-swiftui/)
- [Better Programming - SwiftUI Accessibility Identifiers](https://betterprogramming.pub/composing-accessibility-identifiers-for-swiftui-components-10849847bd10)
