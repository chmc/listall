---
title: macOS Import Preview and Progress UI
date: 2026-01-15
severity: MEDIUM
category: macos
tags: [import, preview, progress, groupbox, native-sheet, accessibility]
symptoms: [macOS missing import preview dialog, No progress UI during import]
root_cause: macOS lacked platform-specific import UI components
solution: Create MacImportPreviewSheet and MacImportProgressView with native AppKit sheet presentation
files_affected: [ListAllMac/Views/Components/MacImportPreviewSheet.swift, ListAllMac/Views/Components/MacImportProgressView.swift, ListAllMac/Views/MacSettingsView.swift]
related: [macos-native-sheet-presentation.md]
---

## Problem

macOS needed import preview dialog and progress UI for feature parity with iOS.

## Solution

### MacImportPreviewSheet

- GroupBox-based layout for macOS styling
- Summary section: lists/items to create/update with icons
- Conflicts section: up to 5 conflicts with "and more" indicator
- Strategy info section: selected merge strategy
- Confirm Import and Cancel buttons
- Uses MacNativeSheetPresenter (see related learning)

### MacImportProgressView

- Linear ProgressView with percentage display
- Current operation text with truncation
- Lists and items processed counts with monospaced digits
- Simple variant (MacImportProgressSimpleView) for indeterminate progress

### Native Sheet Presentation

SwiftUI's `.sheet()` has RunLoop mode issues on macOS. Use MacNativeSheetPresenter:

```swift
MacNativeSheetPresenter.shared.presentSheet(
    MacImportPreviewSheet(preview: preview, viewModel: viewModel),
    onCancel: { /* handle cancel */ }
)
```

### Shared ViewModel Pattern

```swift
@StateObject private var importViewModel = ImportViewModel()

// Same methods as iOS:
// - viewModel.showPreviewForFile(url)
// - viewModel.confirmImport()
// - viewModel.cancelPreview()
```

### Progress Display

```swift
if let progress = importViewModel.importProgress {
    MacImportProgressView(progress: progress)  // Detailed
} else {
    MacImportProgressSimpleView()  // Indeterminate
}
```

## Accessibility

- `.accessibilityAddTraits(.isHeader)` for section headers
- `.accessibilityLabel()` for combined elements
- `.accessibilityHidden(true)` for decorative icons
- `.accessibilityHint()` for actionable buttons
- Keyboard shortcuts: ESC for cancel, Return for confirm
