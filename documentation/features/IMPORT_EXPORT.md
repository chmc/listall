# Import/Export Features

[< Back to Summary](./SUMMARY.md)

## Status: iOS 15/15 | iPad 15/15 | macOS 14/15 | watchOS N/A

*Count = ✅ / applicable rows (N/A excluded). The watch app has no import/export.*

---

## Feature Matrix

| Feature | iOS | iPad | macOS | watchOS | Implementation |
|---------|:---:|:----:|:-----:|:-------:|----------------|
| Export to JSON | ✅ | ✅ | ✅ | N/A | Shared Service |
| Export to CSV | ✅ | ✅ | ⚠️ | N/A | iOS `SettingsView.swift:412-417`; macOS "Export All Lists" sheet offers only JSON / Plain Text (`MacMainView.swift:3817-3820`), CSV only when sharing one list (see SHARING.md) |
| Export to Plain Text | ✅ | ✅ | ✅ | N/A | Shared Service |
| Copy to Clipboard | ✅ | ✅ | ✅ | N/A | Platform-Specific |
| Export to File | ✅ | ✅ | ✅ | N/A | Platform-Specific |
| Import from JSON | ✅ | ✅ | ✅ | N/A | Shared Service |
| Import from Plain Text | ✅ | ✅ | ✅ | N/A | Shared Service |
| Import Preview | ✅ | ✅ | ✅ | N/A | Platform-Specific UI |
| Import Strategy: Merge | ✅ | ✅ | ✅ | N/A | Shared Service |
| Import Strategy: Replace | ✅ | ✅ | ✅ | N/A | Shared Service |
| Import Strategy: Append | ✅ | ✅ | ✅ | N/A | Shared Service |
| Import Progress | ✅ | ✅ | ✅ | N/A | Platform-Specific UI |
| Export Options UI | ✅ | ✅ | ✅ | N/A | Platform UI |
| Include Archived Lists | ✅ | ✅ | ✅ | N/A | Shared Service |
| Include Images (base64) | ✅ | ✅ | ✅ | N/A | Shared Service |

---

## Gaps

- macOS: the "Export All Lists" sheet has no CSV option, although `SharingService.shareAllData(format: .csv)` supports it (`SharingService.swift:339-343`).

---

## Platform Differences

```
iOS / iPad: UIActivityViewController (share sheet)
macOS: NSSavePanel + NSSharingServicePicker
```

---

## Implementation Files

**Shared**:
- `Services/ExportService.swift` - Export logic
- `Services/ImportService.swift` - Import logic
- `ViewModels/ExportViewModel.swift`
- `ViewModels/ImportViewModel.swift`

**iOS / iPad**:
- `Views/SettingsView.swift` - ExportView / ImportView sheets

**macOS**:
- `ListAllMac/Views/MacMainView.swift` - Export sheets (`MacExportAllListsSheet`)
- `ListAllMac/Views/MacSettingsView.swift` - Import integration
- `ListAllMac/Views/Components/MacImportPreviewSheet.swift` - Import preview UI
- `ListAllMac/Views/Components/MacImportProgressView.swift` - Import progress UI
