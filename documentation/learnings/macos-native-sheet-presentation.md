---
title: macOS Native Sheet Presentation Bypassing SwiftUI Issues
date: 2025-12-18
severity: HIGH
category: macos
tags: [sheet, appkit, nswindow, runloop, navigationsplitview]
symptoms:
  - SwiftUI .sheet() only appears AFTER app is deactivated (user clicks outside window)
  - Sheet inside NavigationSplitView detail pane doesn't animate
  - ESC key doesn't work with .keyboardShortcut(.escape) in sheets
  - CloudKit sync causes sheet state to be lost
root_cause: RunLoop mode conflicts during event handling plus Apple NavigationSplitView animation bug
solution: Bypass SwiftUI sheet system using NSWindow.beginSheet() with AppKit
files_affected:
  - ListAll/ListAllMac/Utilities/MacNativeSheetPresenter.swift
related: [macos-nsapp-init-crash.md, macos-cloudkit-sync-analysis.md, macos-realtime-sync-fix.md]
---

## Why SwiftUI Sheets Break

1. **RunLoop mode conflicts**: During double-clicks, run loop is in "event tracking" mode. `DispatchQueue.main.async` only executes in "default" mode, so sheet presentation queues but never runs.

2. **NavigationSplitView bug**: Apple-confirmed (Xcode 14.3+) animations inside detail pane don't work properly.

3. **CloudKit notification storms**: `@Published` property updates from sync invalidate views during sheet presentation.

## Solution: Native AppKit Sheet

```swift
class MacNativeSheetPresenter: NSObject {
    static let shared = MacNativeSheetPresenter()

    // CRITICAL: Store references - NSApp.keyWindow changes after beginSheet()
    private weak var currentParentWindow: NSWindow?
    private weak var currentSheetWindow: NSWindow?

    func presentSheet<Content: View>(_ content: Content, onCancel: (() -> Void)? = nil) {
        guard let parent = NSApp.keyWindow else { return }

        let hostingController = SheetHostingController(rootView: content)
        hostingController.onCancel = onCancel

        let sheetWindow = NSWindow(contentViewController: hostingController)
        sheetWindow.styleMask = [.titled, .closable]
        sheetWindow.isReleasedWhenClosed = false

        // Store references BEFORE beginSheet changes key window
        self.currentParentWindow = parent
        self.currentSheetWindow = sheetWindow

        parent.beginSheet(sheetWindow) { [weak self] _ in
            self?.currentParentWindow = nil
            self?.currentSheetWindow = nil
        }
    }

    func dismissSheet() {
        // Strategy 1: Use stored sheet reference with sheetParent
        if let sheetWindow = currentSheetWindow,
           let parent = sheetWindow.sheetParent {
            parent.endSheet(sheetWindow)
            return
        }
        // Strategy 2: keyWindow IS the sheet
        if let keyWindow = NSApp.keyWindow,
           let parent = keyWindow.sheetParent {
            parent.endSheet(keyWindow)
        }
    }
}
```

## Key Window Gotcha

**CRITICAL**: When `beginSheet()` is called, the sheet window becomes `NSApp.keyWindow`, not the parent.

```swift
// WRONG - returns SHEET, not parent
let parent = NSApp.keyWindow
parent.attachedSheet  // nil - sheet doesn't have attached sheet!

// CORRECT - use sheetParent property on the sheet
let sheet = NSApp.keyWindow
let parent = sheet.sheetParent  // Actual parent window
parent.endSheet(sheet)
```

## ESC Key Support

SwiftUI's `.keyboardShortcut(.escape)` doesn't work in NSHostingController sheets. Use responder chain:

```swift
class SheetHostingController<Content: View>: NSHostingController<Content> {
    var onCancel: (() -> Void)?

    override func cancelOperation(_ sender: Any?) {
        onCancel?()
    }
}
```

## When to Use

- SwiftUI `.sheet()` only appears after app deactivation
- Sheet is inside `NavigationSplitView` detail pane
- CloudKit sync causes view invalidation
- ESC key doesn't work with `.keyboardShortcut(.escape)`
