# macOS Dark Mode Implementation

## Date: 2026-01-06

## Context
Implemented dark mode support for the ListAll macOS app (Task 11.3).

## Key Learnings

### 1. Avoid Hardcoded Colors for Overlays
**Problem**: Image count badges using `Color.black.opacity(0.7)` become invisible in dark mode.

**Solution**: Use material backgrounds with semantic colors:
```swift
// BAD - invisible in dark mode
.foregroundColor(.white)
.background(Color.black.opacity(0.7))

// GOOD - works in both modes
.foregroundStyle(.white)
.background(.ultraThinMaterial.opacity(0.9))
.background(Color(nsColor: .darkGray))
```

The layered approach:
1. `.ultraThinMaterial` provides vibrancy/blur effect that adapts
2. `NSColor.darkGray` ensures readable contrast in both modes

### 2. NSColor System Colors
macOS provides appearance-adaptive system colors:
- `NSColor.windowBackgroundColor` - main window background
- `NSColor.controlBackgroundColor` - control/grouped backgrounds
- `NSColor.textColor` - primary text
- `NSColor.secondaryLabelColor` - secondary/hint text
- `NSColor.darkGray` - good for badge backgrounds

### 3. SwiftUI Semantic Colors
SwiftUI colors that automatically adapt:
- `Color.primary` - adapts to text color
- `Color.secondary` - adapts to secondary text
- `Color.accentColor` - uses AccentColor from asset catalog

### 4. AccentColor Asset Configuration
AccentColor must define both light and dark variants in `Contents.json`:
```json
{
  "colors": [
    {
      "color": { "components": { "red": "0.000", "green": "0.000", "blue": "1.000" } },
      "idiom": "universal"
    },
    {
      "appearances": [{ "appearance": "luminosity", "value": "dark" }],
      "color": { "components": { "red": "0.200", "green": "0.400", "blue": "1.000" } },
      "idiom": "universal"
    }
  ]
}
```

Dark mode variant should be lighter/more saturated for better visibility.

### 5. Testing Dark Mode Colors
Pure unit tests can verify color availability without rendering:
```swift
@Test func accentColorLoads() {
    let color = SwiftUIColor("AccentColor")
    #expect(color != nil)
}

@Test func nsColorDarkGrayConvertsToSwiftUI() {
    let nsColor = NSColor.darkGray
    let swiftUIColor = SwiftUIColor(nsColor: nsColor)
    #expect(swiftUIColor != nil)
}
```

### 6. Views That Already Work
Most SwiftUI views with semantic colors work automatically:
- `Color.secondary.opacity(0.1)` - adapts in both modes
- `Color.accentColor.opacity(0.1)` - adapts in both modes
- System colors like `Color.green`, `Color.orange` - adapt appropriately

### 7. Problematic Patterns to Avoid
- `Color.black` / `Color.white` with opacity for overlays
- `Color(.sRGB, red:green:blue:)` hardcoded RGB values
- Hex color strings without dark variants
- Text colors that assume light background

## Files Modified
- `MacMainView.swift` - Image badge colors
- `MacQuickLookView.swift` - Thumbnail badge colors
- `AccentColor.colorset/Contents.json` - Light/dark variants
- `ListAllMacTests.swift` - DarkModeColorTests class

## Test Coverage
- 19 dark mode unit tests
- All 133 macOS tests pass

## Related Resources
- [Apple Human Interface Guidelines: Dark Mode](https://developer.apple.com/design/human-interface-guidelines/dark-mode)
- [SwiftUI Color Documentation](https://developer.apple.com/documentation/swiftui/color)
- [NSColor System Colors](https://developer.apple.com/documentation/appkit/nscolor)
