---
title: macOS VoiceOver Accessibility Implementation
date: 2025-01-06
severity: MEDIUM
category: macos
tags: [accessibility, voiceover, swiftui, testing, app-groups]
symptoms:
  - VoiceOver reads child elements separately instead of combined
  - Decorative icons announced unnecessarily
  - Permission dialogs during test execution on unsigned builds
root_cause: Missing accessibility modifiers and improper element grouping; tests accessing App Groups trigger permission dialogs
solution: Apply accessibility modifiers in correct order, group elements with .combine, write pure unit tests avoiding App Groups access
files_affected:
  - ListAllMac/Views/MacMainView.swift
  - ListAllMac/Views/MacSettingsView.swift
  - ListAllMac/Views/MacImageGalleryView.swift
  - ListAllMac/Views/MacItemOrganizationView.swift
related:
  - macos-dark-mode-support.md
---

## Accessibility Modifier Hierarchy

Apply modifiers in this order:
```swift
.accessibilityLabel("Primary content description")
.accessibilityValue("Dynamic state or value")
.accessibilityHint("What happens on activation")
.accessibilityAddTraits([.isButton, .isSelected])
.accessibilityIdentifier("TestIdentifier")  // UI tests only
```

## Element Grouping

Use `.accessibilityElement(children: .combine)` for rows with multiple children:
```swift
HStack { /* children */ }
    .accessibilityElement(children: .combine)
    .accessibilityLabel(combinedLabel)
    .accessibilityHint("Double-tap to edit")
```

## Dynamic Labels

Create computed properties for complex state:
```swift
private var itemAccessibilityLabel: String {
    var label = item.title
    label += ", \(item.isCrossedOut ? "completed" : "active")"
    if item.quantity > 1 { label += ", quantity \(item.quantity)" }
    return label
}
```

## Hiding Decorative Elements

Use `.accessibilityHidden(true)` for:
- Decorative icons (magnifying glass in search)
- Visual badges duplicating label info
- App icons and branding

## Trait Usage

- `.isHeader` - Section/sheet/navigation titles
- `.isButton` - Auto-applied to Button views
- `.isImage` - Thumbnails and photos
- `.isSelected` - Selected items in lists

## macOS-Specific Notes

- `.help()` provides tooltip text (separate from accessibility)
- Context menus need accessible button labels
- Hover-revealed buttons need explicit accessibility

## Testing Without Permission Dialogs

Unsigned builds trigger "access data from other apps" dialogs when accessing App Groups.

**Solution:**
```swift
// GOOD - Pure unit test (no dialog)
func testItemAccessibilityLabel() {
    let item = Item(title: "Test", listId: UUID())
    #expect(!item.title.isEmpty)
}

// BAD - Triggers dialog
func testDataManagerListCount() {
    let count = DataManager.shared.lists.count  // App Groups access!
}
```

Use `TestHelpers.createTestDataManager()` for isolated in-memory Core Data when needed.
