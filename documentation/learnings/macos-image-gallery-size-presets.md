---
title: macOS Image Gallery Size Presets
date: 2026-01-15
severity: LOW
category: macos
tags: [swiftui, image-gallery, thumbnails, appstorage, presets, accessibility]
symptoms: [tedious manual slider adjustment, no quick way to switch thumbnail sizes]
root_cause: Thumbnail slider (80-200px) had no presets for common sizes
solution: Added S/M/L preset buttons alongside slider with persistence via @AppStorage
files_affected: [ListAllMac/Views/Components/MacImageGalleryView.swift]
related: [macos-voiceover-accessibility.md, macos-settings-window-resizable.md]
---

## Problem

Thumbnail size slider (80-200px) required manual dragging. No way to quickly switch between common sizes.

## Solution

### ThumbnailSizePreset Enum

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

    static func fromSize(_ size: CGFloat) -> ThumbnailSizePreset? {
        allCases.first { CGFloat($0.size) == size }
    }
}
```

### Toolbar UI

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
        }
    }

    Divider().frame(height: 16)

    // Fine-tuning slider
    Slider(value: $thumbnailSize, in: 80...200, step: 10)
        .frame(width: 80)
}
```

### Persistence with @AppStorage

```swift
// Note: Use Double, not CGFloat - @AppStorage works with Double natively
@AppStorage("galleryThumbnailSize") private var thumbnailSize: Double = 120
```

## Design Decisions

| Decision | Rationale |
|----------|-----------|
| Preset values 80/120/160 | Min slider, default balance, detail with multiple |
| Global persistence | Users prefer consistent sizes across lists |
| 0.2s animation | Smooth transition when clicking presets |
| Slider retained | Fine-tuning between presets (100px, 130px, etc.) |
| Accent color highlight | Visual feedback for active preset |

## Similar Patterns

- Photos app thumbnail presets
- Finder icon size grid
- macOS system preferences icon sizes

## Test Coverage

22 tests: preset values, detection, labels, slider compatibility, default value, persistence, accessibility.
