# Sharing Features

[< Back to Summary](./SUMMARY.md)

## Status: iOS 6/7 | iPad 6/7 | macOS 7/7 | watchOS N/A

*Count = ✅ / applicable rows (N/A excluded). The watch app has no sharing.*

---

## Feature Matrix

| Feature | iOS | iPad | macOS | watchOS | Implementation |
|---------|:---:|:----:|:-----:|:-------:|----------------|
| Share List as Text | ✅ | ✅ | ✅ | N/A | Shared Service |
| Share List as JSON | ✅ | ✅ | ✅ | N/A | Shared Service |
| Share List as CSV | ❌ | ❌ | ✅ | N/A | `ShareFormat.csv` (`SharingService.swift:16`); macOS picker `MacShareFormatPickerView.swift:70-78`; iOS `ShareFormatPickerView` offers Plain Text / JSON only |
| Share All Data | ✅ | ✅ | ✅ | N/A | Shared Service |
| Copy to Clipboard | ✅ | ✅ | ✅ | N/A | Platform-Specific |
| Format Picker UI | ✅ | ✅ | ✅ | N/A | Platform UI |
| Options (crossed out, desc, qty, dates, images) | ✅ | ✅ | ✅ | N/A | Shared Service |

---

## Gaps

- iOS/iPad: no CSV option when sharing a single list (the shared service supports it).

---

## Platform Differences

```
iOS / iPad: UIActivityViewController
macOS: NSSharingServicePicker with native services
```

---

## Implementation Files

**Shared**:
- `Services/SharingService.swift` - Share logic

**iOS / iPad**:
- `Views/Components/ShareFormatPickerView.swift`

**macOS**:
- `ListAllMac/Views/Components/MacShareFormatPickerView.swift`
