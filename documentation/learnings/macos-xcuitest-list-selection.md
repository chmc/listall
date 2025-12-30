# macOS XCUITest List Selection Issues

## Problem
On macOS Tahoe (15.x), SwiftUI `OutlineRow` elements in `NavigationSplitView` sidebars are often reported as "not hittable" by XCUITest even when visible. Coordinate-based taps and even double-taps fail to actually select the list item.

## Root Cause
1. SwiftUI's accessibility layer doesn't properly expose the `isHittable` property for some elements
2. NavigationSplitView's sidebar selection model may not respond to programmatic taps the same way as user interaction
3. The coordinate conversion for tap events may be incorrect in certain window configurations

## Solution: Keyboard Navigation Fallback

When list selection via tap/double-tap fails, use keyboard navigation:

```swift
// Strategy 1: Try double-click first
if firstRow.isHittable {
    firstRow.doubleClick()
} else {
    let coordinate = firstRow.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
    coordinate.doubleTap()
}
sleep(1)

// Strategy 2: If double-click didn't work, use keyboard navigation
let addButton = app.buttons["AddItemButton"].firstMatch
if !addButton.waitForExistence(timeout: 2) {
    // Click sidebar to focus it
    sidebar.click()
    usleep(500_000)  // 0.5 seconds
    // Press Down arrow to select first item, then Enter to confirm
    app.typeKey(.downArrow, modifierFlags: [])
    usleep(300_000)  // 0.3 seconds
    app.typeKey(.return, modifierFlags: [])
    sleep(1)
}
```

## Key Learnings

1. **Double-click is more reliable than single tap** for selection in lists
2. **Keyboard navigation works when mouse events fail** - this is a robust fallback
3. **Verify selection succeeded** by checking for UI elements that only appear when selected (like AddItemButton)
4. **Use predicates for truncated text** - sidebar often truncates list names, so use `BEGINSWITH` predicates:
   ```swift
   app.staticTexts.matching(NSPredicate(format: "label BEGINSWITH 'Grocery'")).firstMatch
   ```
5. **usleep() for sub-second delays** - Swift's `sleep()` only takes UInt32 (seconds), use `usleep()` for milliseconds

## Related Files
- `ListAllMacUITests/MacScreenshotTests.swift` - Screenshot tests with selection strategies
- `documentation/learnings/macos-tahoe-window-creation-xcode.md` - Related window/hittability issues

## Date
2024-12-30
