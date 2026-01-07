# Import/Export Features

[< Back to Summary](./SUMMARY.md)

## Status: iOS 15/15 | macOS 15/15

---

## Feature Matrix

| Feature | iOS | macOS | Implementation |
|---------|:---:|:-----:|----------------|
| Export to JSON | ✅ | ✅ | Shared Service |
| Export to CSV | ✅ | ✅ | Shared Service |
| Export to Plain Text | ✅ | ✅ | Shared Service |
| Copy to Clipboard | ✅ | ✅ | Platform-Specific |
| Export to File | ✅ | ✅ | Platform-Specific |
| Import from JSON | ✅ | ✅ | Shared Service |
| Import from Plain Text | ✅ | ✅ | Shared Service |
| Import Preview | ✅ | ✅ | Platform-Specific UI |
| Import Strategy: Merge | ✅ | ✅ | Shared Service |
| Import Strategy: Replace | ✅ | ✅ | Shared Service |
| Import Strategy: Append | ✅ | ✅ | Shared Service |
| Import Progress | ✅ | ✅ | Platform-Specific UI |
| Export Options UI | ✅ | ✅ | Platform UI |
| Include Archived Lists | ✅ | ✅ | Shared Service |
| Include Images (base64) | ✅ | ✅ | Shared Service |

---

## Gaps (macOS)

No gaps - macOS has full feature parity with iOS.

---

## Platform Differences

```
iOS: UIActivityViewController (share sheet)
macOS: NSSavePanel + NSSharingServicePicker
```

---

## Implementation Files

**Shared**:
- `Services/ExportService.swift` - Export logic
- `Services/ImportService.swift` - Import logic
- `ViewModels/ExportViewModel.swift`
- `ViewModels/ImportViewModel.swift`

**iOS**:
- `Views/ImportView.swift`
- `Views/ExportView.swift`
- `Views/Components/ImportPreviewView.swift`

**macOS**:
- `ListAllMac/Views/MacMainView.swift` - Export sheets
- `ListAllMac/Views/MacSettingsView.swift` - Import integration
- `ListAllMac/Views/Components/MacImportPreviewSheet.swift` - Import preview UI
- `ListAllMac/Views/Components/MacImportProgressView.swift` - Import progress UI
