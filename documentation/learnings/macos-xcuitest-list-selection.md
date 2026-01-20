---
title: macOS XCUITest List Selection Fails - Use Keyboard Navigation
date: 2024-12-30
severity: MEDIUM
category: testing
tags: [xcuitest, macos, swiftui, navigation, sidebar, accessibility]
symptoms:
  - OutlineRow elements reported as "not hittable"
  - Tap and double-tap fail to select list items
  - Coordinate-based taps don't work
root_cause: SwiftUI accessibility layer doesn't properly expose isHittable for NavigationSplitView sidebar elements on macOS Tahoe
solution: Use keyboard navigation (Down Arrow + Return) as fallback when tap/click selection fails
files_affected:
  - ListAllMacUITests/MacScreenshotTests.swift
related:
  - macos-uitest-authorization-fix.md
  - macos-uitest-code-signing-sandbox.md
---

## Selection Strategy

```swift
// Strategy 1: Try double-click first
if firstRow.isHittable {
    firstRow.doubleClick()
} else {
    firstRow.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).doubleTap()
}
sleep(1)

// Strategy 2: Keyboard navigation fallback
let addButton = app.buttons["AddItemButton"].firstMatch
if !addButton.waitForExistence(timeout: 2) {
    sidebar.click()  // Focus sidebar
    usleep(500_000)
    app.typeKey(.downArrow, modifierFlags: [])
    usleep(300_000)
    app.typeKey(.return, modifierFlags: [])
    sleep(1)
}
```

## Key Learnings

1. **Double-click more reliable than single tap** for list selection
2. **Keyboard navigation works when mouse events fail** - robust fallback
3. **Verify selection succeeded** by checking for UI elements that appear after selection
4. **Use predicates for truncated text** in sidebar:
   ```swift
   app.staticTexts.matching(NSPredicate(format: "label BEGINSWITH 'Grocery'")).firstMatch
   ```
5. **usleep() for sub-second delays** - sleep() only takes seconds
