# macOS VoiceOver Accessibility Implementation

## Date: 2025-01-06

## Context
Implemented comprehensive VoiceOver accessibility support for the ListAll macOS app (Task 11.2).

## Key Learnings

### 1. Accessibility Modifier Hierarchy
Apply accessibility modifiers in this order for best VoiceOver experience:
```swift
.accessibilityLabel("Primary content description")
.accessibilityValue("Dynamic state or value")
.accessibilityHint("What happens on activation")
.accessibilityAddTraits([.isButton, .isSelected])
.accessibilityIdentifier("TestIdentifier") // For UI tests only
```

### 2. Element Grouping for Complex Views
Use `.accessibilityElement(children: .combine)` for rows with multiple child elements:
```swift
HStack {
    // Multiple child views...
}
.accessibilityElement(children: .combine)
.accessibilityLabel(combinedLabel)
.accessibilityHint("Double-tap to edit")
```

This prevents VoiceOver from reading each child separately, creating a cleaner navigation experience.

### 3. Dynamic Accessibility Labels
Create computed properties for complex labels:
```swift
private var itemAccessibilityLabel: String {
    var label = item.title
    label += ", \(item.isCrossedOut ? "completed" : "active")"
    if item.quantity > 1 {
        label += ", quantity \(item.quantity)"
    }
    if item.hasImages {
        label += ", \(item.imageCount) \(item.imageCount == 1 ? "image" : "images")"
    }
    return label
}
```

### 4. Hiding Decorative Elements
Use `.accessibilityHidden(true)` for:
- Decorative icons (magnifying glass in search fields)
- Visual badges that duplicate information already in labels
- App icons and branding images

### 5. Proper Use of Traits
- `.isHeader` - Section titles, sheet titles, navigation titles
- `.isButton` - Automatically applied to Button views
- `.isImage` - Image thumbnails and photos
- `.isSelected` - Currently selected items in lists

### 6. Accessibility Values for State
Use `.accessibilityValue()` for:
- Selection states: `"Selected"` or `""`
- Counts: `"3 active, 5 total items"`
- Toggle states: Current state description

### 7. Hints Should Describe Actions
Good hints:
- "Opens sheet to create new list"
- "Double-tap to toggle completion status"
- "Permanently removes this item"

Bad hints (avoid these):
- "Tap here" (too vague)
- "Button" (redundant with trait)

### 8. Testing Strategy
Create pure unit tests that verify accessibility attributes without triggering:
- Core Data access (causes permission dialogs on unsigned builds)
- App Groups access
- CloudKit operations

Test patterns:
```swift
@Test func itemRowHasAccessibilityLabel() {
    let item = Item(title: "Test", listId: UUID())
    #expect(!item.title.isEmpty)
    #expect(item.displayTitle == "Test")
}
```

### 9. SwiftUI Accessibility on macOS
Some differences from iOS:
- `.help()` provides tooltip text but is separate from accessibility
- Context menus need accessible button labels
- Hover-revealed buttons need explicit accessibility

## Files Modified
- MacMainView.swift - Main view with sidebar and detail
- MacSettingsView.swift - Settings tabs
- MacImageGalleryView.swift - Image gallery
- MacItemOrganizationView.swift - Filter/sort controls
- MacShareFormatPickerView.swift - Share options
- MacSuggestionListView.swift - Item suggestions
- MacQuickLookView.swift - Quick Look integration

## Test Coverage
- 59 new VoiceOver tests
- Test suites: Labels, Hints, Values, Traits, Containers, Keyboard, Dynamic Content
- All 108 macOS tests passing

## Related Resources
- [Apple: Accessibility for Developers](https://developer.apple.com/accessibility/)
- [Apple: SwiftUI Accessibility](https://developer.apple.com/documentation/swiftui/accessibility)
- [WCAG 2.1 Guidelines](https://www.w3.org/WAI/WCAG21/quickref/)
