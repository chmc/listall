---
title: macOS Item Drag-Drop Between Lists Regression
date: 2026-01-10
severity: HIGH
category: macos
tags: [drag-drop, focusable, tap-gesture, swiftui, sonoma]
symptoms:
  - Items can only be dropped onto empty lists or sidebar cells
  - Drag doesn't START at all - clicking down on item does nothing
  - Works on iOS but broken on macOS
root_cause: Three issues - missing dropDestination, focusable() capturing mouse clicks, TapGesture blocking drag initiation
solution: Restore dropDestination, use focusable(interactions .activate), remove TapGesture from item rows
files_affected:
  - ListAll/ListAllMac/Views/MacMainView.swift
related: [swiftui-list-drag-drop-ordering.md]
---

## Root Causes

### 1. Missing Drop Destination

`.dropDestination(for: ItemTransferData.self)` was accidentally removed from `itemsListView`.

### 2. Focus Captures Mouse Clicks (macOS Sonoma+)

In macOS Sonoma (14.0+), default `.focusable()` supports ALL focus interactions (edit + activate). It captures mouse-down events to potentially start text editing, blocking drag gesture recognition.

**Fix**: Use `.focusable(interactions: .activate)`:

```swift
// BEFORE (broken)
.draggable(item)
.focusable()  // Captures mouse clicks, blocks drag

// AFTER (working)
.draggable(item)
.focusable(interactions: .activate)  // Only activate focus, allows drag
```

### 3. TapGesture Blocks Drag (THE REAL ISSUE)

`.simultaneousGesture(TapGesture())` captures mouse-down events, blocking drag initiation entirely.

**Key Finding**: Only `.onTapGesture(count: 2)` is safe - it does NOT capture single clicks or drag initiation.

```swift
// BROKEN - blocks drag
.simultaneousGesture(TapGesture().onEnded { ... })

// SAFE - doesn't block drag
.onTapGesture(count: 2) { ... }
```

## Three Drop Destinations Required

MacMainView.swift needs THREE `.dropDestination` modifiers:

1. **Sidebar list cells** - Drop items onto a list in sidebar
2. **Empty list state view** - Drop items onto empty lists
3. **itemsListView** - Drop items onto lists with items

## Prevention Checklist

- [ ] Verify 3 `.dropDestination` occurrences exist
- [ ] Ensure `.focusable(interactions: .activate)` is used, NOT `.focusable()`
- [ ] NEVER add `.onTapGesture` or `.simultaneousGesture(TapGesture())` to item rows
- [ ] Only use `.onTapGesture(count: 2)` or `.onDoubleClick`
- [ ] Test drag-drop manually between lists with items

## Selection Mode Alternatives

Without tap gesture, selection mode still works via:
- Checkbox button (click to toggle)
- Double-click (triggers selection toggle)
- Context menu (Select/Deselect option)

## References

- [WWDC23: The SwiftUI cookbook for focus](https://developer.apple.com/videos/play/wwdc2023/10162/)
- [Apple: focusable(_:interactions:)](https://developer.apple.com/documentation/swiftui/view/focusable(_:interactions:))
