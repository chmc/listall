# macOS Settings Window Resizable - Learning Document

## Date
January 15, 2026

## Task Reference
Task 12.9: Make Settings Window Resizable (IMPORTANT)

## Problem Description

The macOS Settings window had a fixed size of 500x350 points:

```swift
.frame(width: 500, height: 350)
```

This caused issues for:
1. **Accessibility users** - Users with large text (Dynamic Type) could not see clipped content
2. **Localization** - Languages with longer strings (German, Finnish) had truncated text
3. **User preference** - Users could not resize the window to their preference

## Solution Implemented

Changed the frame modifier to use minimum and ideal constraints:

```swift
.frame(minWidth: 500, idealWidth: 550, minHeight: 350, idealHeight: 400)
```

### Constraint Values

| Constraint | Value | Purpose |
|------------|-------|---------|
| minWidth | 500 | Ensures tabs and form layout fit properly |
| idealWidth | 550 | Comfortable default with breathing room |
| minHeight | 350 | Ensures all sections are visible |
| idealHeight | 400 | Room for longer localized strings |

## macOS Window Sizing Best Practices

### Pattern: Use Min/Ideal Constraints for Resizable Windows

When you want a window to be resizable with sensible defaults:

```swift
// Good: Resizable with constraints
.frame(minWidth: 500, idealWidth: 550, minHeight: 350, idealHeight: 400)

// Good: Resizable with only minimum
.frame(minWidth: 400, minHeight: 300)

// Antipattern: Fixed size - window cannot resize
.frame(width: 500, height: 350)
```

### Why This Works

1. **minWidth/minHeight** - Prevents layout breakage when resized too small
2. **idealWidth/idealHeight** - Sets the initial window size when first opened
3. **No maxWidth/maxHeight** - Allows window to expand as needed
4. **macOS Window Management** - System automatically remembers user-adjusted size

### When to Use Fixed Size

Only use fixed frame for:
- Alert dialogs with fixed content
- Popovers with simple content
- Preview windows that must maintain aspect ratio

### Settings Window Considerations

macOS Settings windows typically:
- Have multiple tabs with varying content heights
- Need to accommodate different text sizes
- Should allow resizing for user preference
- Should remember the user's preferred size

## Files Modified

- `/Users/aleksi/source/listall/ListAll/ListAllMac/Views/MacSettingsView.swift` (line 58)

## Testing

17 tests in `SettingsWindowResizableTests` verify:
- Frame uses min/ideal pattern (not fixed)
- Minimum constraints prevent layout breakage
- Ideal constraints provide comfortable defaults
- Supports accessibility use cases (large text)
- Supports different languages (longer strings)
- All 5 settings tabs exist and function

## References

- [Apple HIG: Window Anatomy](https://developer.apple.com/design/human-interface-guidelines/windows)
- [SwiftUI frame modifier documentation](https://developer.apple.com/documentation/swiftui/view/frame(minwidth:idealwidth:maxwidth:minheight:idealheight:maxheight:alignment:))
- Task 12.9 in `/documentation/TODO.md`
