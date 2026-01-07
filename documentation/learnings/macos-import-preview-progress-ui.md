# macOS Import Preview and Progress UI Implementation

## Problem

macOS needed feature parity with iOS for import functionality, specifically:
1. Import Preview Dialog - shows summary before importing
2. Import Progress UI - shows progress during import operations

## Solution

Created two new macOS-specific UI components that integrate with the shared ImportViewModel.

### Components Created

1. **MacImportPreviewSheet.swift** (`/ListAllMac/Views/Components/`)
   - GroupBox-based layout for macOS styling
   - Summary section showing lists/items to create/update with icons
   - Conflicts section showing up to 5 conflicts with "and more" indicator
   - Strategy info section showing selected merge strategy
   - Confirm Import and Cancel buttons
   - Uses native AppKit sheet presentation via MacNativeSheetPresenter

2. **MacImportProgressView.swift** (`/ListAllMac/Views/Components/`)
   - Linear ProgressView with percentage display
   - Current operation text with truncation
   - Lists and items processed counts with monospaced digits
   - Simple variant (MacImportProgressSimpleView) for indeterminate progress

### Integration

Updated **MacSettingsView.swift** DataSettingsTab:
- Added @StateObject ImportViewModel for state management
- Uses SwiftUI .fileImporter for file selection
- Presents MacImportPreviewSheet via MacNativeSheetPresenter
- Displays progress and status messages during import

## Key Implementation Details

### Native Sheet Presentation

Used MacNativeSheetPresenter for reliable sheet presentation on macOS (see `macos-native-sheet-presentation.md` learning). SwiftUI's .sheet() has RunLoop mode issues on macOS that cause sheets to only appear after app deactivation.

```swift
MacNativeSheetPresenter.shared.presentSheet(
    MacImportPreviewSheet(preview: preview, viewModel: viewModel),
    onCancel: { /* handle cancel */ }
)
```

### Shared ViewModel Pattern

The ImportViewModel is shared between iOS and macOS. Only the UI layer is platform-specific:

```swift
// macOS
@StateObject private var importViewModel = ImportViewModel()

// Uses same ViewModel methods as iOS:
// - viewModel.showPreviewForFile(url)
// - viewModel.confirmImport()
// - viewModel.cancelPreview()
// - viewModel.importProgress
// - viewModel.isImporting
```

### Progress Display

Progress shows both detailed and simple variants:

```swift
if let progress = importViewModel.importProgress {
    MacImportProgressView(progress: progress)  // Detailed
} else {
    MacImportProgressSimpleView()  // Indeterminate
}
```

## Testing

Created MacImportUIComponentsTests with 19 tests covering:
- ImportPreview model validation
- ImportProgress calculation at various stages
- ConflictDetail types
- ImportViewModel strategy options and state
- Documentation test

## Files Changed

**Created:**
- `/ListAllMac/Views/Components/MacImportPreviewSheet.swift`
- `/ListAllMac/Views/Components/MacImportProgressView.swift`

**Modified:**
- `/ListAllMac/Views/MacSettingsView.swift` - Added import integration
- `/ListAllMacTests/ListAllMacTests.swift` - Added MacImportUIComponentsTests

**Documentation:**
- `/documentation/TODO.md` - Marked features as IMPLEMENTED
- `/documentation/features/SUMMARY.md` - Updated status
- `/documentation/features/IMPORT_EXPORT.md` - Updated feature matrix

## Accessibility

Both components include:
- `.accessibilityAddTraits(.isHeader)` for section headers
- `.accessibilityLabel()` for combined elements
- `.accessibilityHidden(true)` for decorative icons
- `.accessibilityHint()` for actionable buttons
- Keyboard shortcuts: ESC for cancel, Return for confirm

## Related

- `macos-native-sheet-presentation.md` - Native AppKit sheet pattern used
- ImportViewModel in `/ListAll/ViewModels/ImportViewModel.swift`
- ImportService in `/ListAll/Services/ImportService.swift`
