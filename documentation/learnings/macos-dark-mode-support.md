---
title: macOS Dark Mode Color Implementation
date: 2026-01-06
severity: MEDIUM
category: macos
tags: [dark-mode, colors, swiftui, nscolor, appearance]
symptoms:
  - Image count badges invisible in dark mode
  - Hardcoded colors not adapting to appearance
  - Poor contrast in one mode or the other
root_cause: Using hardcoded Color.black/white with opacity instead of semantic or material colors
solution: Use material backgrounds with semantic colors; define light/dark variants in AccentColor asset
files_affected:
  - ListAllMac/Views/MacMainView.swift
  - ListAllMac/Views/MacQuickLookView.swift
  - Assets.xcassets/AccentColor.colorset/Contents.json
related:
  - macos-voiceover-accessibility.md
---

## Overlay Color Pattern

**Problem:** `Color.black.opacity(0.7)` becomes invisible in dark mode.

**Solution:** Layer material with semantic color:
```swift
// BAD
.foregroundColor(.white)
.background(Color.black.opacity(0.7))

// GOOD
.foregroundStyle(.white)
.background(.ultraThinMaterial.opacity(0.9))
.background(Color(nsColor: .darkGray))
```

## Appearance-Adaptive NSColor System Colors

- `NSColor.windowBackgroundColor` - main window background
- `NSColor.controlBackgroundColor` - control/grouped backgrounds
- `NSColor.textColor` - primary text
- `NSColor.secondaryLabelColor` - secondary/hint text
- `NSColor.darkGray` - badge backgrounds (works in both modes)

## SwiftUI Semantic Colors

Automatically adapt:
- `Color.primary` - text color
- `Color.secondary` - secondary text
- `Color.accentColor` - from asset catalog

## AccentColor Asset Configuration

Define both variants in `Contents.json`:
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

Dark variant should be lighter/more saturated for visibility.

## Patterns to Avoid

- `Color.black` / `Color.white` with opacity for overlays
- `Color(.sRGB, red:green:blue:)` hardcoded values
- Hex color strings without dark variants
- Text colors assuming light background

## Testing Colors

```swift
@Test func accentColorLoads() {
    let color = SwiftUIColor("AccentColor")
    #expect(color != nil)
}
```
