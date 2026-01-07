# Image Features

[< Back to Summary](./SUMMARY.md)

## Status: iOS 14/14 | macOS 14/14 (0 gaps - Pinch-to-Zoom N/A, macOS uses Quick Look)

---

## Feature Matrix

| Feature | iOS | macOS | Implementation |
|---------|:---:|:-----:|----------------|
| Add Images to Items | ✅ | ✅ | Platform-Specific |
| View Image Thumbnails | ✅ | ✅ | Shared Service |
| View Full-Screen Images | ✅ | ✅ | Platform-Specific |
| Delete Images | ✅ | ✅ | Shared Service |
| Reorder Images | ✅ | ✅ | Shared Service |
| Image Compression | ✅ | ✅ | Shared Service |
| Thumbnail Caching | ✅ | ✅ | Shared Service |
| Multi-Image Support (10 max) | ✅ | ✅ | Shared Model |
| Image Validation | ✅ | ✅ | Shared Service |
| Pinch-to-Zoom | ✅ | N/A | iOS only |
| Quick Look Preview | N/A | ✅ | macOS only |
| Drag-Drop Images | N/A | ✅ | macOS only |
| Paste Images (Cmd+V) | N/A | ✅ | macOS only |
| Multi-Select Images | N/A | ✅ | macOS only |

---

## Platform Differences

### iOS-Specific
- Camera capture (UIImagePickerController)
- Photo library picker (PHPickerViewController)
- Camera permission handling
- Pinch-to-zoom in viewer
- Double-tap zoom
- Swipe between images

### macOS-Specific
- File picker for images
- Drag-and-drop from Finder
- Clipboard paste (Cmd+V)
- Quick Look panel (Space)
- Thumbnail size slider
- Multi-select with Cmd+click/Shift+click
- Copy to clipboard (Cmd+C)

---

## Implementation Files

**Shared**:
- `Services/ImageService.swift` - Compression, thumbnails, validation
- `Models/ItemImage.swift` - Image model

**iOS**:
- `Views/Components/ImagePickerView.swift`
- `Views/Components/ImageGalleryView.swift`

**macOS**:
- `ListAllMac/Views/Components/MacImageGalleryView.swift`
- `ListAllMac/Views/Components/MacImageDropHandler.swift`
- `ListAllMac/Views/Components/MacImageClipboardManager.swift`
- `ListAllMac/Views/Components/QuickLookPreviewItem.swift`
