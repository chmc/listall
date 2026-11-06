# Image Features

[< Back to Summary](./SUMMARY.md)

## Status: iOS 11/11 | iPad 11/11 | macOS 13/15 | watchOS N/A

*Count = ✅ / applicable rows (N/A excluded). The watch app does not show images.*

---

## Feature Matrix

| Feature | iOS | iPad | macOS | watchOS | Implementation |
|---------|:---:|:----:|:-----:|:-------:|----------------|
| Add Images to Items | ✅ | ✅ | ✅ | N/A | Platform-Specific |
| View Image Thumbnails | ✅ | ✅ | ✅ | N/A | Shared Service |
| View Full-Screen Images | ✅ | ✅ | ✅ | N/A | Platform-Specific |
| Delete Images | ✅ | ✅ | ✅ | N/A | Shared Service |
| Reorder Images | ✅ | ✅ | ✅ | N/A | Shared Service |
| Image Compression | ✅ | ✅ | ✅ | N/A | Shared Service |
| Thumbnail Caching | ✅ | ✅ | ✅ | N/A | Shared Service |
| Multi-Image Support (10 max) | ✅ | ✅ | ⚠️ | N/A | macOS supports multiple images but enforces no per-item cap; only 10 per drop (`MacImageDropHandler.swift:26`) |
| Explicit 10-Image Limit UI (n/10, add disabled) | ✅ | ✅ | ❌ | N/A | `ItemEditView.swift:162-182` |
| Image Validation | ✅ | ✅ | ✅ | N/A | Shared Service |
| Pinch-to-Zoom | ✅ | ✅ | N/A | N/A | iOS target |
| Quick Look Preview | N/A | N/A | ✅ | N/A | macOS only |
| Drag-Drop Images | N/A | N/A | ✅ | N/A | macOS only |
| Paste Images (Cmd+V) | N/A | N/A | ✅ | N/A | macOS only |
| Multi-Select Images | N/A | N/A | ✅ | N/A | macOS only |
| Collapsible Image Section (edit sheet) | N/A | N/A | ✅ | N/A | `MacEditItemImageSection`, `MacMainView.swift:2879`, `2952-2959`, `3105` (thumbnail preview `3244-3253`) |

---

## Gaps

- macOS: no 10-images-per-item limit (neither enforced nor shown).

---

## Platform Differences

### iOS / iPad
- Camera capture (UIImagePickerController)
- Photo library picker (PHPickerViewController)
- Camera permission handling
- Pinch-to-zoom in viewer
- Double-tap zoom
- Swipe between images
- "n/10" counter; add button disabled at the limit

### macOS-Specific
- File picker for images
- Drag-and-drop from Finder
- Clipboard paste (Cmd+V)
- Quick Look panel (Space)
- Thumbnail size slider
- Multi-select with Cmd+click/Shift+click
- Copy to clipboard (Cmd+C)
- Collapsible image section with thumbnail previews in the edit sheet (collapsed by default)

---

## Implementation Files

**Shared**:
- `Services/ImageService.swift` - Compression, thumbnails, validation
- `Models/ItemImage.swift` - Image model

**iOS / iPad**:
- `Views/Components/ImagePickerView.swift`
- `Views/Components/ImageThumbnailView.swift`
- `Views/ItemEditView.swift` - Image section with 10-image limit

**macOS**:
- `ListAllMac/Views/Components/MacImageGalleryView.swift`
- `ListAllMac/Views/Components/MacImageDropHandler.swift`
- `ListAllMac/Views/Components/MacImageClipboardManager.swift`
- `ListAllMac/Views/Components/QuickLookPreviewItem.swift`
