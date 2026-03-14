//
//  MacModifierClickHandler.swift
//  ListAllMac
//
//  Modifier-click (Cmd+Click, Shift+Click) handler and conditional drag modifier.
//

import SwiftUI
import AppKit

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
