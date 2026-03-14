//
//  MacDoubleClickModifier.swift
//  ListAllMac
//
//  Native double-click handler using NSEvent monitoring.
//

import SwiftUI
import AppKit

// MARK: - Native Double-Click Handler
// Uses NSEvent.addLocalMonitorForEvents to detect double-clicks without blocking the run loop.
//
// KEY INSIGHT (from deep research): The reason sheets only appear after app deactivation:
// 1. During event handling, the run loop is in "event tracking" mode
// 2. DispatchQueue.main.async only executes in "default" mode
// 3. So sheet presentation is queued but never runs until mode changes
// 4. App deactivation forces a mode change, which finally presents the sheet
//
// SOLUTION: Use performSelector(afterDelay:) which works in ALL run loop modes,
// not just the default mode like DispatchQueue.main.async

/// View modifier that adds reliable double-click detection using event monitoring
struct DoubleClickHandler: ViewModifier {
    let handler: () -> Void

    func body(content: Content) -> some View {
        content.background(
            DoubleClickMonitorView(handler: handler)
        )
    }
}

/// NSViewRepresentable that installs an event monitor for double-clicks
struct DoubleClickMonitorView: NSViewRepresentable {
    let handler: () -> Void

    func makeNSView(context: Context) -> DoubleClickMonitorNSView {
        DoubleClickMonitorNSView(handler: handler)
    }

    func updateNSView(_ nsView: DoubleClickMonitorNSView, context: Context) {
        nsView.handler = handler
    }
}

/// NSView that monitors for double-clicks using local event monitor
/// This approach doesn't block events and works with all run loop modes
class DoubleClickMonitorNSView: NSView {
    var handler: () -> Void
    private var eventMonitor: Any?

    init(handler: @escaping () -> Void) {
        self.handler = handler
        super.init(frame: .zero)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()

        if window != nil {
            installEventMonitor()
        } else {
            removeEventMonitor()
        }
    }

    private func installEventMonitor() {
        guard eventMonitor == nil else { return }

        eventMonitor = NSEvent.addLocalMonitorForEvents(matching: .leftMouseDown) { [weak self] event in
            guard let self = self,
                  let window = self.window,
                  event.window == window,
                  event.clickCount == 2 else {
                return event
            }

            // Convert event location to view coordinates
            let locationInWindow = event.locationInWindow
            let locationInView = self.convert(locationInWindow, from: nil)

            // Check if click is within our bounds
            if self.bounds.contains(locationInView) {
                // CRITICAL FIX: Use performSelector(afterDelay:) instead of DispatchQueue.main.async
                // performSelector works in ALL run loop modes (including event tracking mode)
                // This breaks the deadlock where sheets only appear after app deactivation
                self.perform(#selector(self.invokeHandler), with: nil, afterDelay: 0)
            }

            return event  // Let event continue to other handlers
        }
    }

    @objc private func invokeHandler() {
        handler()
    }

    private func removeEventMonitor() {
        if let monitor = eventMonitor {
            NSEvent.removeMonitor(monitor)
            eventMonitor = nil
        }
    }

    deinit {
        removeEventMonitor()
    }
}

/// Extension to make double-click handler easy to use
extension View {
    func onDoubleClick(perform action: @escaping () -> Void) -> some View {
        modifier(DoubleClickHandler(handler: action))
    }
}
