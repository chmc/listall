import Foundation
import ApplicationServices
import AppKit

// MARK: - Accessibility Service

/// Service for interacting with macOS applications via the Accessibility API
enum AccessibilityService {
    // MARK: - Permission Checking

    /// Check if Accessibility permission is granted
    /// - Returns: true if permission is granted, false otherwise
    static func hasAccessibilityPermission() -> Bool {
        // AXIsProcessTrusted returns whether the app has accessibility permission
        return AXIsProcessTrusted()
    }

    /// Request accessibility permission (opens System Settings)
    static func requestAccessibilityPermission() {
        // The key value is "AXTrustedCheckOptionPrompt" - use it directly to avoid concurrency issues
        let options: [String: Bool] = ["AXTrustedCheckOptionPrompt": true]
        AXIsProcessTrustedWithOptions(options as CFDictionary)
    }

    // MARK: - Application Reference

    /// Get AXUIElement reference for a running application
    /// - Parameters:
    ///   - bundleId: Bundle identifier (e.g., "io.github.chmc.ListAllMac")
    ///   - appName: Application name (e.g., "ListAllMac")
    /// - Returns: AXUIElement for the application, or nil if not found
    static func getApplicationElement(bundleId: String? = nil, appName: String? = nil) -> AXUIElement? {
        let runningApps = NSWorkspace.shared.runningApplications

        let targetApp = runningApps.first { app in
            if let bundleId = bundleId {
                return app.bundleIdentifier == bundleId
            } else if let appName = appName {
                return app.localizedName == appName
            }
            return false
        }

        guard let app = targetApp else {
            return nil
        }

        return AXUIElementCreateApplication(app.processIdentifier)
    }

    // MARK: - App Activation

    /// Ensures the target application is active before sending CGEvent-based input
    /// CGEvents (keyboard, mouse, scroll) are posted to the system event queue and go to
    /// the frontmost application, so we must activate the app first.
    /// Uses polling with timeout instead of fixed delay for reliability.
    /// - Parameters:
    ///   - bundleId: Bundle identifier (e.g., "io.github.chmc.ListAllMac")
    ///   - appName: Application name (e.g., "ListAllMac")
    /// - Throws: AccessibilityError if app not found or activation fails
    static func ensureAppActivated(bundleId: String? = nil, appName: String? = nil) async throws {
        let runningApps = NSWorkspace.shared.runningApplications

        let targetApp = runningApps.first { app in
            if let bundleId = bundleId {
                return app.bundleIdentifier == bundleId
            } else if let appName = appName {
                return app.localizedName == appName
            }
            return false
        }

        let appIdentifier = bundleId ?? appName ?? "unknown"
        guard let app = targetApp else {
            throw AccessibilityError.applicationNotFound(appIdentifier)
        }

        // If already active, nothing to do
        if app.isActive {
            return
        }

        // Activate the app (brings to front)
        app.activate()

        // Poll for activation (max 1 second = 20 × 50ms)
        var attempts = 0
        while !app.isActive && attempts < 20 {
            try await Task.sleep(nanoseconds: 50_000_000) // 50ms
            attempts += 1
        }

        if !app.isActive {
            throw AccessibilityError.activationFailed(appIdentifier)
        }
    }

    // MARK: - Element Search

    /// Find UI element by accessibility identifier or label
    /// Uses priority-based matching: exact match first, contains match as fallback
    /// - Parameters:
    ///   - root: Root element to search from
    ///   - identifier: Accessibility identifier to match
    ///   - label: Accessibility label to match (alternative to identifier)
    ///   - role: Optional role filter (e.g., "AXButton", "AXTextField")
    ///   - maxDepth: Maximum recursion depth to prevent stack overflow (default: 20)
    /// - Returns: Matching element, or nil if not found
    static func findElement(
        in root: AXUIElement,
        identifier: String? = nil,
        label: String? = nil,
        role: String? = nil,
        maxDepth: Int = 20
    ) -> AXUIElement? {
        // Priority 1: Try exact match first
        if let exactMatch = findElementWithMatchType(
            in: root,
            identifier: identifier,
            label: label,
            role: role,
            matchType: .exact,
            maxDepth: maxDepth
        ) {
            return exactMatch
        }

        // Priority 2: Fall back to contains match (only for label, not identifier)
        if label != nil {
            return findElementWithMatchType(
                in: root,
                identifier: identifier,
                label: label,
                role: role,
                matchType: .contains,
                maxDepth: maxDepth
            )
        }

        return nil
    }

    /// Match type for element search
    private enum MatchType {
        case exact     // Exact string match
        case contains  // Substring match (fallback)
    }

    /// Internal find function with explicit match type
    private static func findElementWithMatchType(
        in root: AXUIElement,
        identifier: String?,
        label: String?,
        role: String?,
        matchType: MatchType,
        maxDepth: Int
    ) -> AXUIElement? {
        guard maxDepth > 0 else { return nil }

        // Check if current element matches
        if let element = matchElement(root, identifier: identifier, label: label, role: role, matchType: matchType) {
            return element
        }

        // Recursively search children
        var childrenRef: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(root, kAXChildrenAttribute as CFString, &childrenRef)

        guard result == .success, let children = childrenRef as? [AXUIElement] else {
            return nil
        }

        for child in children {
            if let found = findElementWithMatchType(
                in: child,
                identifier: identifier,
                label: label,
                role: role,
                matchType: matchType,
                maxDepth: maxDepth - 1
            ) {
                return found
            }
        }

        return nil
    }

    /// Check if an element matches the search criteria
    /// - Parameters:
    ///   - element: Element to check
    ///   - identifier: Accessibility identifier to match (always exact match)
    ///   - label: Label to match (exact or contains based on matchType)
    ///   - role: Role filter
    ///   - matchType: Whether to use exact or contains matching for labels
    private static func matchElement(
        _ element: AXUIElement,
        identifier: String?,
        label: String?,
        role: String?,
        matchType: MatchType = .exact
    ) -> AXUIElement? {
        // Check role if specified
        if let role = role {
            var roleRef: CFTypeRef?
            AXUIElementCopyAttributeValue(element, kAXRoleAttribute as CFString, &roleRef)
            if let elementRole = roleRef as? String, elementRole != role {
                return nil
            }
        }

        // Check accessibility identifier (always exact match)
        if let identifier = identifier {
            var identifierRef: CFTypeRef?
            AXUIElementCopyAttributeValue(element, kAXIdentifierAttribute as CFString, &identifierRef)
            if let elementId = identifierRef as? String, elementId == identifier {
                return element
            }
        }

        // Check accessibility label (description, title, or value)
        if let label = label {
            // Helper to check if string matches based on match type
            let matches: (String) -> Bool = { value in
                switch matchType {
                case .exact:
                    return value == label
                case .contains:
                    return value.contains(label)
                }
            }

            // Try description first
            var descRef: CFTypeRef?
            AXUIElementCopyAttributeValue(element, kAXDescriptionAttribute as CFString, &descRef)
            if let desc = descRef as? String, matches(desc) {
                return element
            }

            // Try title
            var titleRef: CFTypeRef?
            AXUIElementCopyAttributeValue(element, kAXTitleAttribute as CFString, &titleRef)
            if let title = titleRef as? String, matches(title) {
                return element
            }

            // Try value for static text
            var valueRef: CFTypeRef?
            AXUIElementCopyAttributeValue(element, kAXValueAttribute as CFString, &valueRef)
            if let value = valueRef as? String, matches(value) {
                return element
            }
        }

        return nil
    }

    // MARK: - Actions

    /// Click (press) a UI element
    /// - Parameter element: Element to click
    /// - Throws: AccessibilityError if action fails
    static func click(_ element: AXUIElement) throws {
        // Check element's role
        var roleRef: CFTypeRef?
        AXUIElementCopyAttributeValue(element, kAXRoleAttribute as CFString, &roleRef)
        let role = roleRef as? String ?? ""

        // For AXRow elements (in outlines/lists), try to select them
        if role == "AXRow" {
            let selectResult = AXUIElementSetAttributeValue(element, kAXSelectedAttribute as CFString, true as CFTypeRef)
            if selectResult == .success {
                return
            }
        }

        // For unknown roles (common in SwiftUI), try to find and select parent AXRow
        if role == "AXUnknown" || role == "" {
            if let parentRow = findParentRow(of: element) {
                let selectResult = AXUIElementSetAttributeValue(parentRow, kAXSelectedAttribute as CFString, true as CFTypeRef)
                if selectResult == .success {
                    return
                }
            }
        }

        // Try the standard accessibility press action
        let result = AXUIElementPerformAction(element, kAXPressAction as CFString)
        if result == .success {
            return
        }

        // If press action failed or is unsupported, fall back to mouse click simulation
        // This works better for list items and other complex views
        try clickUsingMouseEvent(element)
    }

    /// Find the parent AXRow of an element (for outline/list selection)
    /// - Parameter element: Element to search from
    /// - Returns: Parent AXRow element, or nil if not found
    private static func findParentRow(of element: AXUIElement) -> AXUIElement? {
        var current: AXUIElement? = element
        var depth = 0
        let maxDepth = 10

        while let elem = current, depth < maxDepth {
            // Get parent
            var parentRef: CFTypeRef?
            let result = AXUIElementCopyAttributeValue(elem, kAXParentAttribute as CFString, &parentRef)
            guard result == .success, let parent = parentRef else {
                return nil
            }

            // Check parent's role
            let parentElement = parent as! AXUIElement
            var roleRef: CFTypeRef?
            AXUIElementCopyAttributeValue(parentElement, kAXRoleAttribute as CFString, &roleRef)

            if let parentRole = roleRef as? String, parentRole == "AXRow" {
                return parentElement
            }

            current = parentElement
            depth += 1
        }

        return nil
    }

    /// Click an element by simulating mouse events at its center
    /// - Parameter element: Element to click
    /// - Throws: AccessibilityError if click fails
    private static func clickUsingMouseEvent(_ element: AXUIElement) throws {
        // Get element position
        var positionRef: CFTypeRef?
        let posResult = AXUIElementCopyAttributeValue(element, kAXPositionAttribute as CFString, &positionRef)
        guard posResult == .success else {
            throw AccessibilityError.attributeNotFound("position")
        }

        var position = CGPoint.zero
        if let posValue = positionRef {
            AXValueGetValue(posValue as! AXValue, .cgPoint, &position)
        }

        // Get element size
        var sizeRef: CFTypeRef?
        let sizeResult = AXUIElementCopyAttributeValue(element, kAXSizeAttribute as CFString, &sizeRef)
        guard sizeResult == .success else {
            throw AccessibilityError.attributeNotFound("size")
        }

        var size = CGSize.zero
        if let sizeValue = sizeRef {
            AXValueGetValue(sizeValue as! AXValue, .cgSize, &size)
        }

        // Calculate center of element
        let centerX = position.x + size.width / 2
        let centerY = position.y + size.height / 2
        let clickPoint = CGPoint(x: centerX, y: centerY)

        // Simulate mouse click (move, down, up)
        let moveEvent = CGEvent(mouseEventSource: nil, mouseType: .mouseMoved, mouseCursorPosition: clickPoint, mouseButton: .left)
        moveEvent?.post(tap: .cghidEventTap)

        Thread.sleep(forTimeInterval: 0.05)

        let mouseDown = CGEvent(mouseEventSource: nil, mouseType: .leftMouseDown, mouseCursorPosition: clickPoint, mouseButton: .left)
        mouseDown?.post(tap: .cghidEventTap)

        Thread.sleep(forTimeInterval: 0.05)

        let mouseUp = CGEvent(mouseEventSource: nil, mouseType: .leftMouseUp, mouseCursorPosition: clickPoint, mouseButton: .left)
        mouseUp?.post(tap: .cghidEventTap)
    }

    /// Set focus on an element
    /// - Parameter element: Element to focus
    /// - Throws: AccessibilityError if action fails
    static func focus(_ element: AXUIElement) throws {
        let result = AXUIElementSetAttributeValue(element, kAXFocusedAttribute as CFString, true as CFTypeRef)
        guard result == .success else {
            throw AccessibilityError.actionFailed("focus", result)
        }
    }

    /// Type text into the focused element or a specific element
    /// - Parameters:
    ///   - text: Text to type
    ///   - element: Optional specific element to type into
    /// - Throws: AccessibilityError if action fails
    static func typeText(_ text: String, into element: AXUIElement? = nil) throws {
        if let element = element {
            // Set value directly on the element
            let result = AXUIElementSetAttributeValue(element, kAXValueAttribute as CFString, text as CFTypeRef)
            guard result == .success else {
                throw AccessibilityError.actionFailed("type", result)
            }
        } else {
            // Use CGEvent to type into focused element
            try typeTextUsingKeyEvents(text)
        }
    }

    /// Type text using keyboard events (simulates actual typing)
    private static func typeTextUsingKeyEvents(_ text: String) throws {
        let source = CGEventSource(stateID: .hidSystemState)

        for character in text {
            guard let keyCode = keyCodeForCharacter(character) else {
                continue // Skip characters we can't type
            }

            let keyDown = CGEvent(keyboardEventSource: source, virtualKey: keyCode, keyDown: true)
            let keyUp = CGEvent(keyboardEventSource: source, virtualKey: keyCode, keyDown: false)

            // Handle shift for uppercase
            if character.isUppercase {
                keyDown?.flags = .maskShift
                keyUp?.flags = .maskShift
            }

            keyDown?.post(tap: .cghidEventTap)
            keyUp?.post(tap: .cghidEventTap)

            // Small delay between keystrokes
            Thread.sleep(forTimeInterval: 0.01)
        }
    }

    /// Get key code for a character (basic implementation)
    private static func keyCodeForCharacter(_ char: Character) -> CGKeyCode? {
        // Basic mapping for common characters
        let lowercased = char.lowercased().first ?? char
        let keyMap: [Character: CGKeyCode] = [
            "a": 0, "s": 1, "d": 2, "f": 3, "h": 4, "g": 5, "z": 6, "x": 7, "c": 8, "v": 9,
            "b": 11, "q": 12, "w": 13, "e": 14, "r": 15, "y": 16, "t": 17, "1": 18, "2": 19,
            "3": 20, "4": 21, "6": 22, "5": 23, "=": 24, "9": 25, "7": 26, "-": 27, "8": 28,
            "0": 29, "]": 30, "o": 31, "u": 32, "[": 33, "i": 34, "p": 35, "l": 37, "j": 38,
            "'": 39, "k": 40, ";": 41, "\\": 42, ",": 43, "/": 44, "n": 45, "m": 46, ".": 47,
            " ": 49, "`": 50
        ]
        return keyMap[lowercased]
    }

    /// Scroll an element
    /// - Parameters:
    ///   - element: Element to scroll within
    ///   - direction: Scroll direction
    ///   - amount: Scroll amount in pixels (positive scrolls down/right, negative scrolls up/left)
    /// - Throws: AccessibilityError if action fails
    static func scroll(in element: AXUIElement, direction: ScrollDirection, amount: CGFloat) throws {
        // Get element position for scroll event
        var positionRef: CFTypeRef?
        let posResult = AXUIElementCopyAttributeValue(element, kAXPositionAttribute as CFString, &positionRef)
        guard posResult == .success else {
            throw AccessibilityError.attributeNotFound("position")
        }

        var position = CGPoint.zero
        if let posValue = positionRef {
            AXValueGetValue(posValue as! AXValue, .cgPoint, &position)
        }

        // Get element size
        var sizeRef: CFTypeRef?
        let sizeResult = AXUIElementCopyAttributeValue(element, kAXSizeAttribute as CFString, &sizeRef)
        guard sizeResult == .success else {
            throw AccessibilityError.attributeNotFound("size")
        }

        var size = CGSize.zero
        if let sizeValue = sizeRef {
            AXValueGetValue(sizeValue as! AXValue, .cgSize, &size)
        }

        // Calculate center of element
        let centerX = position.x + size.width / 2
        let centerY = position.y + size.height / 2

        // Create scroll event
        let scrollEvent = CGEvent(
            scrollWheelEvent2Source: nil,
            units: .pixel,
            wheelCount: 1,
            wheel1: direction == .vertical ? Int32(amount) : 0,
            wheel2: direction == .horizontal ? Int32(amount) : 0,
            wheel3: 0
        )

        // Move cursor to element center first
        let moveEvent = CGEvent(mouseEventSource: nil, mouseType: .mouseMoved, mouseCursorPosition: CGPoint(x: centerX, y: centerY), mouseButton: .left)
        moveEvent?.post(tap: .cghidEventTap)

        Thread.sleep(forTimeInterval: 0.05)

        scrollEvent?.post(tap: .cghidEventTap)
    }

    // MARK: - Element Query

    /// Get UI element tree for debugging
    /// - Parameters:
    ///   - root: Root element to start from
    ///   - depth: Maximum depth to traverse (default 10)
    ///   - maxElements: Optional maximum number of elements to include (nil = unlimited)
    ///   - includeGeometry: Whether to include position/size (default true for backward compatibility)
    /// - Returns: Dictionary representing the element tree
    static func getElementTree(
        from root: AXUIElement,
        depth: Int = 10,
        maxElements: Int? = nil,
        includeGeometry: Bool = true
    ) -> [String: Any] {
        var elementCount = 0
        return getElementTreeRecursive(
            from: root,
            depth: depth,
            maxElements: maxElements,
            includeGeometry: includeGeometry,
            elementCount: &elementCount
        )
    }

    /// Internal recursive helper for getElementTree with element counting
    private static func getElementTreeRecursive(
        from root: AXUIElement,
        depth: Int,
        maxElements: Int?,
        includeGeometry: Bool,
        elementCount: inout Int
    ) -> [String: Any] {
        guard depth > 0 else { return [:] }

        // Check max elements limit
        if let max = maxElements, elementCount >= max {
            return [:]
        }
        elementCount += 1

        var info: [String: Any] = [:]

        // Get role
        var roleRef: CFTypeRef?
        if AXUIElementCopyAttributeValue(root, kAXRoleAttribute as CFString, &roleRef) == .success {
            info["role"] = roleRef as? String ?? "unknown"
        }

        // Get identifier
        var identifierRef: CFTypeRef?
        if AXUIElementCopyAttributeValue(root, kAXIdentifierAttribute as CFString, &identifierRef) == .success {
            info["identifier"] = identifierRef as? String
        }

        // Get title
        var titleRef: CFTypeRef?
        if AXUIElementCopyAttributeValue(root, kAXTitleAttribute as CFString, &titleRef) == .success {
            info["title"] = titleRef as? String
        }

        // Get description
        var descRef: CFTypeRef?
        if AXUIElementCopyAttributeValue(root, kAXDescriptionAttribute as CFString, &descRef) == .success {
            info["description"] = descRef as? String
        }

        // Get value (for text fields, etc.)
        var valueRef: CFTypeRef?
        if AXUIElementCopyAttributeValue(root, kAXValueAttribute as CFString, &valueRef) == .success {
            if let stringValue = valueRef as? String {
                info["value"] = stringValue
            } else if let numberValue = valueRef as? NSNumber {
                info["value"] = numberValue
            }
        }

        // Get enabled state
        var enabledRef: CFTypeRef?
        if AXUIElementCopyAttributeValue(root, kAXEnabledAttribute as CFString, &enabledRef) == .success {
            info["enabled"] = enabledRef as? Bool
        }

        // Include geometry only if requested (default true for backward compatibility)
        if includeGeometry {
            // Get position
            var positionRef: CFTypeRef?
            if AXUIElementCopyAttributeValue(root, kAXPositionAttribute as CFString, &positionRef) == .success {
                var position = CGPoint.zero
                if let posValue = positionRef {
                    AXValueGetValue(posValue as! AXValue, .cgPoint, &position)
                    info["position"] = ["x": position.x, "y": position.y]
                }
            }

            // Get size
            var sizeRef: CFTypeRef?
            if AXUIElementCopyAttributeValue(root, kAXSizeAttribute as CFString, &sizeRef) == .success {
                var size = CGSize.zero
                if let sizeValue = sizeRef {
                    AXValueGetValue(sizeValue as! AXValue, .cgSize, &size)
                    info["size"] = ["width": size.width, "height": size.height]
                }
            }
        }

        // Get children (respecting maxElements limit)
        var childrenRef: CFTypeRef?
        if AXUIElementCopyAttributeValue(root, kAXChildrenAttribute as CFString, &childrenRef) == .success {
            if let children = childrenRef as? [AXUIElement], !children.isEmpty {
                var childTrees: [[String: Any]] = []
                for child in children {
                    // Check limit before processing each child
                    if let max = maxElements, elementCount >= max {
                        break
                    }
                    let childTree = getElementTreeRecursive(
                        from: child,
                        depth: depth - 1,
                        maxElements: maxElements,
                        includeGeometry: includeGeometry,
                        elementCount: &elementCount
                    )
                    if !childTree.isEmpty {
                        childTrees.append(childTree)
                    }
                }
                if !childTrees.isEmpty {
                    info["children"] = childTrees
                }
            }
        }

        return info
    }

    /// Find all elements matching criteria
    /// - Parameters:
    ///   - root: Root element to search from
    ///   - role: Optional role filter
    ///   - maxResults: Maximum number of results
    ///   - includeGeometry: Whether to include position/size (default true for backward compatibility)
    /// - Returns: Array of element info dictionaries
    static func findAllElements(
        in root: AXUIElement,
        role: String? = nil,
        maxResults: Int = 100,
        includeGeometry: Bool = true
    ) -> [[String: Any]] {
        var results: [[String: Any]] = []
        collectElements(
            from: root,
            role: role,
            results: &results,
            maxResults: maxResults,
            includeGeometry: includeGeometry
        )
        return results
    }

    private static func collectElements(
        from element: AXUIElement,
        role: String?,
        results: inout [[String: Any]],
        maxResults: Int,
        includeGeometry: Bool
    ) {
        guard results.count < maxResults else { return }

        // Check if this element matches
        var shouldInclude = true
        if let role = role {
            var roleRef: CFTypeRef?
            AXUIElementCopyAttributeValue(element, kAXRoleAttribute as CFString, &roleRef)
            if let elementRole = roleRef as? String {
                shouldInclude = elementRole == role
            } else {
                shouldInclude = false
            }
        }

        if shouldInclude {
            results.append(getElementInfo(element, includeGeometry: includeGeometry))
        }

        // Recurse into children
        var childrenRef: CFTypeRef?
        if AXUIElementCopyAttributeValue(element, kAXChildrenAttribute as CFString, &childrenRef) == .success {
            if let children = childrenRef as? [AXUIElement] {
                for child in children {
                    collectElements(
                        from: child,
                        role: role,
                        results: &results,
                        maxResults: maxResults,
                        includeGeometry: includeGeometry
                    )
                    if results.count >= maxResults { break }
                }
            }
        }
    }

    /// Get info for a single element (without children)
    /// - Parameters:
    ///   - element: Element to get info for
    ///   - includeGeometry: Whether to include position/size (default true)
    private static func getElementInfo(_ element: AXUIElement, includeGeometry: Bool = true) -> [String: Any] {
        var info: [String: Any] = [:]

        // Get role
        var roleRef: CFTypeRef?
        if AXUIElementCopyAttributeValue(element, kAXRoleAttribute as CFString, &roleRef) == .success {
            info["role"] = roleRef as? String
        }

        // Get identifier
        var identifierRef: CFTypeRef?
        if AXUIElementCopyAttributeValue(element, kAXIdentifierAttribute as CFString, &identifierRef) == .success {
            info["identifier"] = identifierRef as? String
        }

        // Get title
        var titleRef: CFTypeRef?
        if AXUIElementCopyAttributeValue(element, kAXTitleAttribute as CFString, &titleRef) == .success {
            info["title"] = titleRef as? String
        }

        // Get description
        var descRef: CFTypeRef?
        if AXUIElementCopyAttributeValue(element, kAXDescriptionAttribute as CFString, &descRef) == .success {
            info["description"] = descRef as? String
        }

        // Get value (for text fields, etc.)
        var valueRef: CFTypeRef?
        if AXUIElementCopyAttributeValue(element, kAXValueAttribute as CFString, &valueRef) == .success {
            if let stringValue = valueRef as? String {
                info["value"] = stringValue
            }
        }

        // Include geometry only if requested
        if includeGeometry {
            // Get position
            var positionRef: CFTypeRef?
            if AXUIElementCopyAttributeValue(element, kAXPositionAttribute as CFString, &positionRef) == .success {
                var position = CGPoint.zero
                if let posValue = positionRef {
                    AXValueGetValue(posValue as! AXValue, .cgPoint, &position)
                    info["position"] = ["x": position.x, "y": position.y]
                }
            }

            // Get size
            var sizeRef: CFTypeRef?
            if AXUIElementCopyAttributeValue(element, kAXSizeAttribute as CFString, &sizeRef) == .success {
                var size = CGSize.zero
                if let sizeValue = sizeRef {
                    AXValueGetValue(sizeValue as! AXValue, .cgSize, &size)
                    info["size"] = ["width": size.width, "height": size.height]
                }
            }
        }

        return info
    }
}

// MARK: - Types

/// Scroll direction for swipe/scroll operations
enum ScrollDirection {
    case vertical
    case horizontal
}

/// Errors from accessibility operations
enum AccessibilityError: Error, LocalizedError {
    case permissionDenied
    case applicationNotFound(String)
    case elementNotFound(String)
    case actionFailed(String, AXError)
    case attributeNotFound(String)
    case activationFailed(String)

    var errorDescription: String? {
        switch self {
        case .permissionDenied:
            return "Accessibility permission is not granted. Grant in System Settings > Privacy & Security > Accessibility"
        case .applicationNotFound(let identifier):
            return "Application '\(identifier)' not found or not running"
        case .elementNotFound(let description):
            return "UI element not found: \(description)"
        case .actionFailed(let action, let error):
            return "Failed to perform '\(action)' action: \(accessibilityErrorDescription(error))"
        case .attributeNotFound(let attribute):
            return "Attribute '\(attribute)' not found on element"
        case .activationFailed(let identifier):
            return "Failed to activate application '\(identifier)' within timeout"
        }
    }
}

/// Convert AXError to readable description
private func accessibilityErrorDescription(_ error: AXError) -> String {
    switch error {
    case .success: return "Success"
    case .failure: return "Generic failure"
    case .illegalArgument: return "Illegal argument"
    case .invalidUIElement: return "Invalid UI element"
    case .invalidUIElementObserver: return "Invalid observer"
    case .cannotComplete: return "Cannot complete (element may have changed)"
    case .attributeUnsupported: return "Attribute unsupported"
    case .actionUnsupported: return "Action unsupported"
    case .notificationUnsupported: return "Notification unsupported"
    case .notImplemented: return "Not implemented"
    case .notificationAlreadyRegistered: return "Notification already registered"
    case .notificationNotRegistered: return "Notification not registered"
    case .apiDisabled: return "Accessibility API disabled"
    case .noValue: return "No value"
    case .parameterizedAttributeUnsupported: return "Parameterized attribute unsupported"
    case .notEnoughPrecision: return "Not enough precision"
    @unknown default: return "Unknown error (\(error.rawValue))"
    }
}
