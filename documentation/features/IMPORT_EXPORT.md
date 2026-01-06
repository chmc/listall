# Import/Export Features

[< Back to Summary](./SUMMARY.md)

## Status: iOS 15/15 | macOS 13/15

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
| Import Preview | ✅ | ❌ | iOS only |
| Import Strategy: Merge | ✅ | ✅ | Shared Service |
| Import Strategy: Replace | ✅ | ✅ | Shared Service |
| Import Strategy: Append | ✅ | ✅ | Shared Service |
| Import Progress | ✅ | ❌ | iOS only |
| Export Options UI | ✅ | ✅ | Platform UI |
| Include Archived Lists | ✅ | ✅ | Shared Service |
| Include Images (base64) | ✅ | ✅ | Shared Service |

---

## Gaps (macOS)

| Feature | Priority | iOS Implementation | Notes |
|---------|:--------:|-------------------|-------|
| Import Preview | HIGH | ImportPreviewView with summary | Shows what will be imported before commit |
| Import Progress | HIGH | Progress bar with details | Shows progress during large imports |

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
