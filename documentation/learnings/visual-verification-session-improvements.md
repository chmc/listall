---
title: Visual Verification MCP Server Session Improvements
date: 2026-01-22
severity: MEDIUM
category: macos
tags:
  - mcp
  - visual-verification
  - screenshot
  - accessibility
  - element-matching
symptoms:
  - 15+ separate screenshot folders created during single verification session
  - Wrong UI element clicked when using partial label matches
  - Large query responses (~15k tokens) slowing down interactions
root_cause: Context-change check created new folder for every unique context; label matching used substring contains causing ambiguous clicks
solution: Remove context-change folder creation, implement priority-based matching (exact first, contains fallback), add optional query parameters
files_affected:
  - Tools/listall-mcp/Sources/listall-mcp/Services/ScreenshotStorage.swift
  - Tools/listall-mcp/Sources/listall-mcp/Services/AccessibilityService.swift
  - Tools/listall-mcp/Sources/listall-mcp/Tools/InteractionTools.swift
  - .claude/skills/visual-verification/SKILL.md
related:
  - mcp-visual-verification-runtime-fixes.md
---

## Problem

During visual verification of UI features, three issues degraded the experience:

1. **Folder fragmentation**: Each screenshot with a different context created a new folder, resulting in 15+ folders for a single verification session
2. **Element matching ambiguity**: Using `label.contains(searchTerm)` caused "Add" to match "Add Item" or "Address"
3. **Large query responses**: Full element trees with geometry data produced ~15k token responses

## Root Cause

### Folder Fragmentation
```swift
// BAD - new folder on every context change
if let folder = currentSessionFolder, currentSessionContext == sanitizedContext {
    return folder
}
// Falls through to create new folder

// GOOD - reuse folder regardless of context
if let folder = currentSessionFolder {
    return folder  // Context only affects filename, not folder
}
```

### Element Matching
```swift
// BAD - substring match causes wrong element selection
if let title = titleRef as? String, title.contains(label) {
    return element
}

// GOOD - priority-based: exact first, contains fallback
// Priority 1: Exact match
if elementTitle == label { return element }
// Priority 2: Contains (only if no exact match in entire tree)
```

### Large Responses
Query returned full geometry (position/size) for all elements by default, even when not needed.

## Solution

### 1. Session-Based Folder Logic
- First screenshot sets folder name using its context
- All subsequent screenshots go to same folder regardless of context
- Context becomes filename descriptor: `{platform}-{index:02d}-{context}.png`
- 5-minute timeout auto-resets session

### 2. Priority-Based Matching
```swift
// Try exact match first
if let exact = findElementWithMatchType(..., matchType: .exact) {
    return exact
}
// Fall back to contains only if no exact match
return findElementWithMatchType(..., matchType: .contains)
```

### 3. Optional Query Parameters
- `max_elements: Int?` - limits results (default: unlimited for tree, 100 for flat)
- `include_geometry: Bool` - includes position/size (default: true for backward compatibility)

## Prevention

- [ ] When adding session-based features, consider timeout behavior
- [ ] Default matching to exact match, use substring only as fallback
- [ ] Add optional parameters for expensive operations (default to current behavior)
- [ ] Review query response sizes during testing

## Key Insight

> Session state should persist across context changes; let users control folder boundaries via timeouts rather than automatic context detection.

---

## Problem: SwiftUI List Click Not Working (2026-01-22)

The `listall_click` MCP tool reports success but fails to select SwiftUI List items in the sidebar.

### Symptoms
- `listall_click` with identifier `SidebarListCell_Grocery Shopping` reports success
- List remains unselected (still shows "No List Selected")
- Elements have role `AXUnknown` instead of standard accessibility roles

### Root Cause
SwiftUI List items expose accessibility with role `AXUnknown`. The standard `AXPressAction` doesn't work, and the mouse event fallback doesn't trigger selection in outline/list views.

### Solution
Modified `AccessibilityService.click()` to:

1. **Detect AXRow elements**: Try `AXSelectedAttribute` for row selection
2. **Handle AXUnknown elements**: Traverse up to find parent `AXRow` and select it
3. **New helper**: `findParentRow(of:)` traverses parent hierarchy

```swift
// For AXRow elements (in outlines/lists), try to select them
if role == "AXRow" {
    let selectResult = AXUIElementSetAttributeValue(element, kAXSelectedAttribute as CFString, true as CFTypeRef)
    if selectResult == .success { return }
}

// For unknown roles (common in SwiftUI), find and select parent AXRow
if role == "AXUnknown" || role == "" {
    if let parentRow = findParentRow(of: element) {
        let selectResult = AXUIElementSetAttributeValue(parentRow, kAXSelectedAttribute as CFString, true as CFTypeRef)
        if selectResult == .success { return }
    }
}
```

### Workaround (Before MCP Restart)
Use AppleScript to select list rows directly:
```bash
osascript -e 'tell application "System Events"
    tell process "ListAll"
        tell outline 1 of scroll area 1 of group 1 of splitter group 1 of group 1 of window 1
            select row 2
        end tell
    end tell
end tell'
```

### UITEST_MODE Isolation Verified
The Peruna test confirmed UITEST_MODE works correctly:
- Fresh launch = clean test data (no "Peruna")
- Added items don't persist across launches
- App isolation working as designed
