# macOS Native Sheet Presentation (Bypassing SwiftUI Issues)

## Problem

SwiftUI's `.sheet()` modifier on macOS has critical bugs that cause sheets to only appear **after the app is deactivated** (user clicks outside the window). This is caused by:

1. **RunLoop mode conflicts**: During event handling (like double-clicks), the run loop is in "event tracking" mode. `DispatchQueue.main.async` only executes in "default" mode, so sheet presentation is queued but never runs until the mode changes.

2. **NavigationSplitView animation bug**: Apple-confirmed bug (Xcode 14.3+) where animations inside NavigationSplitView detail pane don't work properly.

3. **CloudKit notification storms**: `@Published` property updates from sync can invalidate views during sheet presentation, causing the sheet state to be lost.

## Solution: Native AppKit Sheet Presenter

Bypass SwiftUI's sheet system entirely using `NSWindow.beginSheet()`:

```swift
import SwiftUI
import AppKit

class MacNativeSheetPresenter: NSObject {
    static let shared = MacNativeSheetPresenter()

    // CRITICAL: Store references because NSApp.keyWindow changes after beginSheet()
    private weak var currentParentWindow: NSWindow?
    private weak var currentSheetWindow: NSWindow?
    private var currentCancelHandler: (() -> Void)?

    func presentSheet<Content: View>(
        _ content: Content,
        in parentWindow: NSWindow? = nil,
        onCancel: (() -> Void)? = nil,
        completion: (() -> Void)? = nil
    ) {
        guard let parent = parentWindow ?? NSApp.keyWindow else { return }

        // Use custom hosting controller for ESC key support
        let hostingController = SheetHostingController(rootView: content)
        hostingController.onCancel = onCancel

        let sheetWindow = NSWindow(contentViewController: hostingController)
        sheetWindow.styleMask = [.titled, .closable]
        sheetWindow.isReleasedWhenClosed = false
        sheetWindow.setContentSize(hostingController.view.fittingSize)

        // Store references BEFORE beginSheet changes key window
        self.currentParentWindow = parent
        self.currentSheetWindow = sheetWindow
        self.currentCancelHandler = onCancel

        parent.beginSheet(sheetWindow) { [weak self] _ in
            self?.currentParentWindow = nil
            self?.currentSheetWindow = nil
            self?.currentCancelHandler = nil
            completion?()
        }
    }

    func dismissSheet(in window: NSWindow? = nil) {
        // Strategy 1: Use stored sheet reference with sheetParent (MOST RELIABLE)
        if let sheetWindow = currentSheetWindow,
           let parent = sheetWindow.sheetParent {
            parent.endSheet(sheetWindow)
            clearReferences()
            return
        }

        // Strategy 2: Use stored parent reference
        if let parent = window ?? currentParentWindow,
           let sheet = parent.attachedSheet {
            parent.endSheet(sheet)
            clearReferences()
            return
        }

        // Strategy 3: keyWindow IS the sheet (has sheetParent)
        if let keyWindow = NSApp.keyWindow,
           let parent = keyWindow.sheetParent {
            parent.endSheet(keyWindow)
            clearReferences()
            return
        }
    }

    private func clearReferences() {
        currentParentWindow = nil
        currentSheetWindow = nil
        currentCancelHandler = nil
    }
}
```

## Key Window Problem

**Critical insight**: When `beginSheet()` is called, the **sheet window becomes `NSApp.keyWindow`**, not the parent.

```swift
// WRONG: After beginSheet, this returns the SHEET, not the parent
let parent = NSApp.keyWindow
parent.attachedSheet  // Returns nil - sheet doesn't have an attached sheet!

// CORRECT: Use sheetParent property on the sheet
let sheet = NSApp.keyWindow
let parent = sheet.sheetParent  // Returns the actual parent window
parent.endSheet(sheet)  // Works!
```

## ESC Key Support

SwiftUI's `.keyboardShortcut(.escape)` doesn't work inside `NSHostingController` sheets. Use the responder chain:

```swift
private class SheetHostingController<Content: View>: NSHostingController<Content> {
    var onCancel: (() -> Void)?

    // Called when ESC is pressed (responder chain)
    override func cancelOperation(_ sender: Any?) {
        onCancel?()
    }
}
```

## Usage

```swift
// In your view
let cancelAction = {
    MacNativeSheetPresenter.shared.dismissSheet()
    // Reset state...
}

MacNativeSheetPresenter.shared.presentSheet(
    MySheetContent(
        onSave: { /* save and dismiss */ },
        onCancel: cancelAction
    ),
    onCancel: cancelAction  // ESC key support
) {
    // Completion when sheet dismissed
}
```

## Related APIs

- `NSWindow.beginSheet(_:completionHandler:)` - Present sheet
- `NSWindow.endSheet(_:)` - Dismiss sheet
- `NSWindow.sheetParent` - Get parent window from sheet
- `NSWindow.attachedSheet` - Get sheet from parent window
- `cancelOperation(_:)` - Responder chain method for ESC key

## When to Use

Use native AppKit sheets when:
- SwiftUI `.sheet()` only appears after app deactivation
- Sheet is inside `NavigationSplitView` detail pane
- CloudKit sync notifications cause view invalidation
- ESC key doesn't work with `.keyboardShortcut(.escape)`

## References

- [NSWindow.sheetParent Documentation](https://developer.apple.com/documentation/appkit/nswindow/1419052-sheetparent)
- [NSWindow.beginSheet Documentation](https://developer.apple.com/documentation/appkit/nswindow/1419653-beginsheet)
- [Apple Developer Forums - NavigationSplitView animation bug](https://developer.apple.com/forums/thread/728132)
