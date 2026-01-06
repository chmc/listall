# Sharing Features

[< Back to Summary](./SUMMARY.md)

## Status: iOS 6/6 | macOS 6/6 (Complete)

---

## Feature Matrix

| Feature | iOS | macOS | Implementation |
|---------|:---:|:-----:|----------------|
| Share List as Text | ✅ | ✅ | Shared Service |
| Share List as JSON | ✅ | ✅ | Shared Service |
| Share All Data | ✅ | ✅ | Shared Service |
| Copy to Clipboard | ✅ | ✅ | Platform-Specific |
| Format Picker UI | ✅ | ✅ | Platform UI |
| Options (crossed out, desc, qty, dates, images) | ✅ | ✅ | Shared Service |

---

## Platform Differences

```
iOS: UIActivityViewController
macOS: NSSharingServicePicker with native services
```

---

## Implementation Files

**Shared**:
- `Services/SharingService.swift` - Share logic

**iOS**:
- `Views/Components/ShareFormatPickerView.swift`

**macOS**:
- `ListAllMac/Views/Components/MacShareFormatPickerView.swift`
