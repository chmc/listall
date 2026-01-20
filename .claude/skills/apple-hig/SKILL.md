---
name: apple-hig
description: Apple Human Interface Guidelines patterns and antipatterns for iOS, iPadOS, macOS, and watchOS. Use when designing UI, reviewing designs, or implementing platform-appropriate interfaces.
---

# Apple Human Interface Guidelines

> **Scope**: iOS, iPadOS, macOS, watchOS. Does not cover visionOS spatial computing patterns.

## Navigation Patterns

### iOS

**Patterns (Do This):**
- **Tab Bars**: 3-5 tabs at bottom for top-level navigation
- **Navigation Stack**: Hierarchical with standard back button, swipe-right to go back
- **Modal Sheets**: For scoped tasks, page sheet on larger devices

**Antipatterns (Avoid This):**
- **Hamburger menus**: Poor discoverability vs tab bars
- **Custom back buttons**: Users expect standard behavior
- **Modal overuse**: Creates fragmented experiences

### iPadOS

**Patterns:**
- **Split Views**: Side-by-side for larger screens
- **Sidebars**: Leading-edge navigation for app sections
- **Popovers**: For controls on larger screens (not modals)

**Antipatterns:**
- Phone-only patterns that don't leverage screen real estate
- Modal dialogs when popovers work better

### macOS

**Patterns:**
- **Sidebar Navigation**: Leading-edge for sections
- **Toolbars**: Top-positioned for frequent commands
- **Menu Bar**: Complete list of all app commands
- **Window Management**: Standard traffic lights, resizable

**Antipatterns:**
- iOS-style tab bars or back buttons
- Missing menu bar items (context menu items must be in menu bar)
- Non-standard window behaviors

### watchOS

**Patterns:**
- **Vertical Navigation**: Digital Crown scrolling (watchOS 10+)
- **Shallow Hierarchy**: 2-3 levels maximum
- **Glanceable**: 2-3 seconds to consume info

**Antipatterns:**
- Deep navigation hierarchies
- Complex multi-step interactions
- Gesture-based hidden menus

---

## Layout & Spacing

**Patterns:**
- Always respect safe area layout guides (Dynamic Island, notch, home indicator)
- Use size classes for adaptive layouts (compact vs regular)
- Auto Layout with constraints for Dynamic Type support
- Sufficient white space for visual hierarchy

**Antipatterns:**
- Ignoring safe areas (content hidden behind system elements)
- Fixed/hard-coded frame sizes
- Overcrowded interfaces without breathing room

---

## Typography

**Patterns:**
- **SF Pro**: System font (Text for ≤19pt, Display for ≥20pt)
- **SF Compact**: For watchOS
- **Dynamic Type**: Support user's preferred text size (required for accessibility)
- **Text Styles**: Use semantic styles (headline, body, caption)

**Antipatterns:**
- Fixed font sizes (breaks Dynamic Type)
- Custom fonts without Dynamic Type support
- Arbitrary sizes instead of text styles

### Text Style Hierarchy
```
Large Title → Title 1-3 → Headline → Body → Callout → Subheadline → Footnote → Caption 1-2
```

---

## Color System

**Patterns:**
- **Semantic Colors**: `systemBlue`, `systemRed`, etc. (adapt to Light/Dark)
- **Label Colors**: Primary, Secondary, Tertiary, Quaternary for hierarchy
- **Background Colors**: System and grouped variants
- **Dark Mode**: Automatic with semantic colors

**Antipatterns:**
- Hard-coded RGB values (don't adapt to Dark Mode)
- Information conveyed by color alone (accessibility failure)
- Insufficient contrast (<4.5:1 for normal text, <3:1 for large)

### Color Example
```swift
// Good: Semantic colors
Text("Title").foregroundColor(.primary)
Text("Subtitle").foregroundColor(.secondary)

// Bad: Hard-coded
Text("Title").foregroundColor(Color(red: 0, green: 0, blue: 0))
```

---

## SF Symbols

**Patterns:**
- Use SF Symbols for consistency (5,000+ icons)
- Match symbol weight to text weight
- **Rendering Modes**: Monochrome, Hierarchical, Palette, Multicolor
- **Variants**: `.fill` for tab bars, `.outline` for nav bars

**Antipatterns:**
- Custom icons when SF Symbol exists
- Mismatched weights between symbols and text
- Wrong variant for context

### Symbol Example
```swift
// Tab bar (filled)
Image(systemName: "house.fill")

// Navigation bar (outline)
Image(systemName: "gear")

// Hierarchical rendering
Image(systemName: "folder.badge.plus")
    .symbolRenderingMode(.hierarchical)
```

---

## Controls & Inputs

### Platform-Appropriate Controls

| Platform | Use | Avoid |
|----------|-----|-------|
| iOS | Switches, Steppers, Segmented | Checkboxes, Radio buttons |
| macOS | Checkboxes, Radio buttons, Pop-ups | iOS Switches |

### Button Hierarchy (SwiftUI)
```swift
Button("Primary") { }.buttonStyle(.borderedProminent)  // Primary action
Button("Secondary") { }.buttonStyle(.bordered)          // Secondary
Button("Tertiary") { }.buttonStyle(.plain)              // Tertiary
```

### Touch Targets
- **Minimum 44×44 points** for all interactive elements
- Smaller targets cause 25%+ tap error rates
- Critical for accessibility

**Antipatterns:**
- Platform-inappropriate controls
- Buttons smaller than 44×44 points
- Ambiguous button hierarchy

---

## Accessibility Requirements

**Patterns:**
- **VoiceOver**: All interactive elements need meaningful labels
- **Dynamic Type**: Support text scaling (not optional)
- **Color Contrast**: 4.5:1 for normal text, 3:1 for large
- **Touch Targets**: 44×44 points minimum
- **Reduce Motion**: Respect user preference

**Antipatterns:**
- Missing accessibility labels on images/buttons
- Fixed text sizes
- Color-only information (red/green status)
- Testing accessibility only at the end

### Accessibility Example
```swift
Image(systemName: "star.fill")
    .accessibilityLabel("Favorite")

Button(action: deleteItem) {
    Image(systemName: "trash")
}
.accessibilityLabel("Delete item")
```

---

## Platform-Specific Quick Reference

### iOS Essentials
- Tab bars preferred over hamburger menus
- Bottom navigation for thumb accessibility
- Swipe-right from left edge = back
- Dynamic Island and home indicator safe areas

### iPadOS Essentials
- Leverage split views and sidebars
- Popovers instead of action sheets
- Support drag and drop between apps
- Apple Pencil precision input

### macOS Essentials
- Full menu bar with all commands
- Keyboard shortcuts (⌘ for primary actions)
- Resizable windows with standard controls
- Toolbars at top, customizable

### watchOS Essentials
- Digital Crown is primary input
- Keep navigation shallow (2-3 levels)
- Glanceable content (2-3 seconds)
- Large tap targets (44pt minimum)

---

## Debug Checklist

When reviewing UI implementation:

1. **Navigation**: Platform-appropriate pattern?
2. **Safe Areas**: Respecting all insets?
3. **Dynamic Type**: Text scales correctly?
4. **Dark Mode**: All colors adapt?
5. **Accessibility**: Labels, contrast, targets?
6. **Controls**: Platform-appropriate widgets?
7. **SF Symbols**: Using system icons where available?
