# macOS Image Gallery Size Presets

## Date
January 15, 2026

## Task Reference
Task 12.13: Add Image Gallery Size Presets (MINOR)

## Problem
The thumbnail size slider (80-200px) in the image gallery had no presets. Users had to manually drag the slider to find optimal thumbnail sizes, which was tedious especially when wanting to quickly switch between common sizes.

## Solution

### 1. ThumbnailSizePreset Enum
Created a new enum to define preset sizes with associated metadata:

```swift
enum ThumbnailSizePreset: Int, CaseIterable, Identifiable {
    case small = 80
    case medium = 120
    case large = 160

    var id: Int { rawValue }
    var size: Int { rawValue }

    var label: String {
        switch self {
        case .small: return "S"
        case .medium: return "M"
        case .large: return "L"
        }
    }

    var accessibilityLabel: String {
        switch self {
        case .small: return "Small thumbnail size"
        case .medium: return "Medium thumbnail size"
        case .large: return "Large thumbnail size"
        }
    }

    var tooltip: String {
        switch self {
        case .small: return "Small (\(size)px)"
        case .medium: return "Medium (\(size)px)"
        case .large: return "Large (\(size)px)"
        }
    }

    static func fromSize(_ size: CGFloat) -> ThumbnailSizePreset? {
        allCases.first { CGFloat($0.size) == size }
    }
}
```

### 2. Toolbar UI Updates
Added preset buttons (S, M, L) alongside the slider in MacImageGalleryToolbar:

```swift
HStack(spacing: 8) {
    // Preset buttons (S, M, L)
    HStack(spacing: 4) {
        ForEach(ThumbnailSizePreset.allCases) { preset in
            Button(action: {
                withAnimation(.easeInOut(duration: 0.2)) {
                    thumbnailSize = Double(preset.size)
                }
            }) {
                Text(preset.label)
                    .font(.caption.weight(.medium))
                    .frame(width: 24, height: 20)
            }
            .buttonStyle(.bordered)
            .tint(activePreset == preset ? .accentColor : nil)
            .accessibilityLabel(preset.accessibilityLabel)
            .help(preset.tooltip)
        }
    }

    Divider()
        .frame(height: 16)

    // Fine-tuning slider
    Slider(value: $thumbnailSize, in: 80...200, step: 10)
        .frame(width: 80)
}
```

### 3. Persistence with @AppStorage
Changed the thumbnail size from `@State` to `@AppStorage` for persistence:

```swift
// Before
@State private var thumbnailSize: CGFloat = 120

// After
@AppStorage("galleryThumbnailSize") private var thumbnailSize: Double = 120
```

Note: Used `Double` instead of `CGFloat` because `@AppStorage` works with `Double` natively.

## Key Design Decisions

1. **Preset Values**: Chose 80, 120, 160 based on:
   - 80px: Minimum slider value, shows many thumbnails
   - 120px: Default, good balance of size and count
   - 160px: Large enough for detail while still seeing multiple

2. **Global Persistence**: Stored globally rather than per-list for simplicity. Users typically prefer consistent thumbnail sizes across all lists.

3. **Animation**: Added smooth animation (0.2s) when clicking presets for better UX.

4. **Visual Feedback**: Active preset is highlighted with accent color tint.

5. **Slider Retained**: Kept the slider for fine-tuning between preset values (e.g., 100px, 130px).

## Accessibility Features

- VoiceOver labels for each preset button
- Accessibility identifier for UI testing
- Tooltips showing size in pixels
- Slider has accessibility label and value

## Files Modified

- `/Users/aleksi/source/listall/ListAll/ListAllMac/Views/Components/MacImageGalleryView.swift`
  - Added `ThumbnailSizePreset` enum
  - Updated `MacImageGalleryView` to use `@AppStorage`
  - Updated `MacImageGalleryToolbar` with preset buttons

## Tests Added

22 new tests in `ImageGallerySizePresetsTests`:
- Preset value tests (80, 120, 160)
- Preset detection from size
- Custom sizes return nil
- Preset labels (S, M, L)
- All presets available in allCases
- Slider range compatibility
- Default value is Medium
- Persistence tests
- Accessibility tests

## Related Patterns

This implementation follows the pattern used by:
- Photos app thumbnail size presets
- Finder icon size grid
- macOS system preferences for icon sizes

## Notes

- The type changed from `CGFloat` to `Double` required updating the toolbar binding and converting to `CGFloat` when passing to the grid.
- The `fromSize(_:)` method enables the UI to detect when the current size matches a preset for highlighting.
