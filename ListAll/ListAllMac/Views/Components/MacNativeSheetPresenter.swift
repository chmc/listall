//
//  MacNativeSheetPresenter.swift
//  ListAllMac
//
//  Native AppKit sheet presentation that bypasses SwiftUI's unreliable sheet system.
//  Uses NSWindow.beginSheet() directly for immediate, reliable presentation.
//
//  ESC Key Support: Uses a custom NSHostingController that intercepts cancelOperation:
//  to properly handle ESC key presses, since SwiftUI's .keyboardShortcut(.escape)
//  doesn't work reliably inside NSHostingController sheets.
//

import SwiftUI
import AppKit

// MARK: - Custom Hosting Controller for ESC Key Support

/// Custom NSHostingController that intercepts ESC key presses via cancelOperation:
/// SwiftUI's .keyboardShortcut(.escape) doesn't work inside NSHostingController sheets,
/// so we handle it at the AppKit level through the responder chain.
private class SheetHostingController<Content: View>: NSHostingController<Content> {
    /// Callback to invoke when ESC is pressed (cancelOperation: in responder chain)
    var onCancel: (() -> Void)?

    /// Handle ESC key press via the responder chain
    /// This is called when the user presses ESC or chooses Edit > Cancel
    override func cancelOperation(_ sender: Any?) {
        print("⌨️ SheetHostingController: ESC pressed (cancelOperation)")
        onCancel?()
    }
}

// MARK: - Native Sheet Presenter

/// Native AppKit-based sheet presenter that works reliably on macOS
/// This bypasses SwiftUI's sheet system which has RunLoop mode issues
class MacNativeSheetPresenter: NSObject {

    /// Shared instance for global access
    static let shared = MacNativeSheetPresenter()

    /// Store reference to parent window (needed because NSApp.keyWindow returns the sheet after presentation)
    private weak var currentParentWindow: NSWindow?

    /// Store reference to sheet window for direct dismissal (most reliable approach)
    private weak var currentSheetWindow: NSWindow?

    /// Store cancel handler for ESC key support
    private var currentCancelHandler: (() -> Void)?

    private override init() {}

    /// Present a SwiftUI view as a native AppKit sheet
    /// - Parameters:
    ///   - content: The SwiftUI view to present
    ///   - parentWindow: The parent window (nil = key window)
    ///   - onCancel: Called when ESC is pressed (optional - for ESC key support)
    ///   - completion: Called when sheet is dismissed
    func presentSheet<Content: View>(
        _ content: Content,
        in parentWindow: NSWindow? = nil,
        onCancel: (() -> Void)? = nil,
        completion: (() -> Void)? = nil
    ) {
        // Get the parent window (use key window if not specified)
        guard let parent = parentWindow ?? NSApp.keyWindow else {
            print("❌ MacNativeSheetPresenter: No parent window available")
            return
        }

        // Create custom hosting controller with ESC key support
        let hostingController = SheetHostingController(rootView: content)
        hostingController.onCancel = onCancel

        // Create sheet window
        let sheetWindow = NSWindow(contentViewController: hostingController)
        sheetWindow.styleMask = [.titled, .closable]
        sheetWindow.isReleasedWhenClosed = false

        // Calculate sheet size from content
        let contentSize = hostingController.view.fittingSize
        sheetWindow.setContentSize(contentSize)

        // CRITICAL: Store references BEFORE beginSheet() changes key window
        // After beginSheet(), NSApp.keyWindow will return the sheet, not the parent
        self.currentParentWindow = parent
        self.currentSheetWindow = sheetWindow
        self.currentCancelHandler = onCancel

        print("🎭 MacNativeSheetPresenter: Presenting sheet with size \(contentSize)")
        print("🎭 Parent: \(parent), Sheet: \(sheetWindow)")

        // Present as modal sheet
        parent.beginSheet(sheetWindow) { [weak self] response in
            print("🎭 MacNativeSheetPresenter: Sheet dismissed with response: \(response.rawValue)")
            // Clear references when sheet completes
            self?.currentParentWindow = nil
            self?.currentSheetWindow = nil
            self?.currentCancelHandler = nil
            completion?()
        }
    }

    /// Dismiss the currently presented sheet
    /// - Parameter window: The parent window (nil = use stored reference)
    func dismissSheet(in window: NSWindow? = nil) {
        // Strategy 1: Use stored sheet reference with sheetParent (MOST RELIABLE)
        // The sheet knows its parent via sheetParent property
        if let sheetWindow = currentSheetWindow,
           let parent = sheetWindow.sheetParent {
            print("🎭 MacNativeSheetPresenter: Dismissing via stored sheet reference")
            parent.endSheet(sheetWindow)
            currentParentWindow = nil
            currentSheetWindow = nil
            return
        }

        // Strategy 2: Use stored parent reference with attachedSheet
        if let parent = window ?? currentParentWindow,
           let sheet = parent.attachedSheet {
            print("🎭 MacNativeSheetPresenter: Dismissing via stored parent reference")
            parent.endSheet(sheet)
            currentParentWindow = nil
            currentSheetWindow = nil
            return
        }

        // Strategy 3: Check if keyWindow IS the sheet (has sheetParent)
        // This happens because sheet becomes key window after presentation
        if let keyWindow = NSApp.keyWindow,
           let parent = keyWindow.sheetParent {
            print("🎭 MacNativeSheetPresenter: Dismissing via keyWindow.sheetParent")
            parent.endSheet(keyWindow)
            currentParentWindow = nil
            currentSheetWindow = nil
            return
        }

        // Strategy 4: Search all windows for attached sheets (last resort)
        for appWindow in NSApp.windows {
            if let sheet = appWindow.attachedSheet {
                print("🎭 MacNativeSheetPresenter: Dismissing via window search")
                appWindow.endSheet(sheet)
                currentParentWindow = nil
                currentSheetWindow = nil
                return
            }
        }

        print("⚠️ MacNativeSheetPresenter: No sheet to dismiss")
        print("   currentParentWindow: \(currentParentWindow?.description ?? "nil")")
        print("   currentSheetWindow: \(currentSheetWindow?.description ?? "nil")")
        print("   NSApp.keyWindow: \(NSApp.keyWindow?.description ?? "nil")")
    }
}

/// View modifier to make dismissing sheets easier
extension View {
    func dismissNativeSheet() {
        MacNativeSheetPresenter.shared.dismissSheet()
    }
}

/// Environment key for dismissing native sheets
struct DismissNativeSheetKey: EnvironmentKey {
    static let defaultValue: () -> Void = {
        MacNativeSheetPresenter.shared.dismissSheet()
    }
}

extension EnvironmentValues {
    var dismissNativeSheet: () -> Void {
        get { self[DismissNativeSheetKey.self] }
        set { self[DismissNativeSheetKey.self] = newValue }
    }
}
