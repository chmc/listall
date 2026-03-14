//
//  MacViewModifiers.swift
//  ListAllMac
//
//  Custom view modifiers for double-click, modifier-click, and conditional drag.
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

// MARK: - Conditional Draggable Modifier (Task 13.2)

/// View modifier that conditionally applies .draggable based on isEnabled flag
/// Used to disable dragging for archived list items
struct ConditionalDraggable: ViewModifier {
    let item: Item
    let isEnabled: Bool

    func body(content: Content) -> some View {
        if isEnabled {
            content.draggable(item)
        } else {
            content
        }
    }
}

// MARK: - Modifier Click Handler (Cmd+Click, Shift+Click)

/// View modifier that adds Cmd+Click and Shift+Click detection using event monitoring
/// Does NOT block drag-and-drop - uses mouseUp detection with distance threshold
struct ModifierClickHandler: ViewModifier {
    let onCommandClick: () -> Void
    let onShiftClick: () -> Void

    func body(content: Content) -> some View {
        content.background(
            ModifierClickMonitorView(
                onCommandClick: onCommandClick,
                onShiftClick: onShiftClick
            )
        )
    }
}

/// NSViewRepresentable that installs an event monitor for modified clicks
struct ModifierClickMonitorView: NSViewRepresentable {
    let onCommandClick: () -> Void
    let onShiftClick: () -> Void

    func makeNSView(context: Context) -> ModifierClickMonitorNSView {
        ModifierClickMonitorNSView(
            onCommandClick: onCommandClick,
            onShiftClick: onShiftClick
        )
    }

    func updateNSView(_ nsView: ModifierClickMonitorNSView, context: Context) {
        nsView.onCommandClick = onCommandClick
        nsView.onShiftClick = onShiftClick
    }
}

/// NSView that monitors for modifier clicks (Cmd+Click, Shift+Click) using local event monitor
/// Uses mouseUp detection with distance threshold to distinguish clicks from drags
/// This approach does NOT block drag-and-drop since it only observes mouseUp events
class ModifierClickMonitorNSView: NSView {
    var onCommandClick: () -> Void
    var onShiftClick: () -> Void
    private var eventMonitor: Any?
    private var mouseDownLocation: NSPoint?
    private var mouseDownTime: Date?

    init(onCommandClick: @escaping () -> Void, onShiftClick: @escaping () -> Void) {
        self.onCommandClick = onCommandClick
        self.onShiftClick = onShiftClick
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

        // Monitor both mouseDown and mouseUp to detect clicks vs drags
        eventMonitor = NSEvent.addLocalMonitorForEvents(matching: [.leftMouseDown, .leftMouseUp]) { [weak self] event in
            guard let self = self,
                  let window = self.window,
                  event.window == window else {
                return event
            }

            let locationInWindow = event.locationInWindow
            let locationInView = self.convert(locationInWindow, from: nil)

            // Check if event is within our bounds
            guard self.bounds.contains(locationInView) else {
                self.mouseDownLocation = nil
                self.mouseDownTime = nil
                return event
            }

            if event.type == .leftMouseDown {
                // Only track single clicks (not double-clicks which are handled by onDoubleClick)
                if event.clickCount == 1 {
                    self.mouseDownLocation = locationInView
                    self.mouseDownTime = Date()
                }
            } else if event.type == .leftMouseUp {
                defer {
                    self.mouseDownLocation = nil
                    self.mouseDownTime = nil
                }

                // Check if this was a click (not a drag)
                // A click is: short duration (<300ms) AND minimal movement (<5 points)
                guard let downLocation = self.mouseDownLocation,
                      let downTime = self.mouseDownTime else {
                    return event
                }

                let timeDelta = Date().timeIntervalSince(downTime)
                let distance = hypot(locationInView.x - downLocation.x,
                                    locationInView.y - downLocation.y)

                let isClick = timeDelta < 0.3 && distance < 5

                if isClick && event.clickCount == 1 {
                    let modifiers = event.modifierFlags

                    if modifiers.contains(.command) {
                        // Cmd+Click: Toggle selection
                        self.perform(#selector(self.invokeCommandClick), with: nil, afterDelay: 0)
                    } else if modifiers.contains(.shift) {
                        // Shift+Click: Range selection
                        self.perform(#selector(self.invokeShiftClick), with: nil, afterDelay: 0)
                    }
                    // NOTE: Plain click (no modifiers) intentionally NOT handled here
                    // to avoid interfering with SwiftUI List's native selection behavior
                }
            }

            return event  // CRITICAL: Let event continue to other handlers (including drag)
        }
    }

    @objc private func invokeCommandClick() {
        onCommandClick()
    }

    @objc private func invokeShiftClick() {
        onShiftClick()
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

/// Extension to make modifier-click handler easy to use
extension View {
    /// Adds Cmd+Click and Shift+Click detection to a view
    /// - Parameters:
    ///   - command: Action to perform on Cmd+Click
    ///   - shift: Action to perform on Shift+Click
    /// - Note: Does NOT block drag-and-drop functionality
    func onModifierClick(
        command: @escaping () -> Void,
        shift: @escaping () -> Void
    ) -> some View {
        modifier(ModifierClickHandler(
            onCommandClick: command,
            onShiftClick: shift
        ))
    }
}
