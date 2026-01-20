---
title: macOS Quick Entry Window Implementation
date: 2026-01-15
severity: MEDIUM
category: macos
tags: [swiftui, window, quick-entry, keyboard-shortcut, dependency-injection, nsvisualeffect]
symptoms: [no way to quickly add items without app switching, power users need rapid entry]
root_cause: Missing Things 3-style Quick Entry feature for rapid item creation
solution: Created floating Quick Entry window with Cmd+Option+Space shortcut
files_affected: [ListAllMac/Views/QuickEntryView.swift, ListAllMac/ListAllMacApp.swift, ListAllMac/Commands/AppCommands.swift]
related: [macos-keyboard-reordering.md, macos-global-cmdf-search.md, macos-native-sheet-presentation.md]
---

## Problem

No way to quickly add items from anywhere in macOS without switching to the app. Power users expect Things 3-style Quick Entry.

## Solution

### Architecture

1. **QuickEntryViewModel** - ObservableObject for state
2. **QuickEntryView** - Minimal floating window
3. **Window Scene** - Hidden title bar, content-sized
4. **Menu Command** - Cmd+Option+Space shortcut

### ViewModel with Dependency Injection

```swift
final class QuickEntryViewModel: ObservableObject {
    private let dataManager: any DataManaging

    init(dataManager: any DataManaging = DataManager.shared) {
        self.dataManager = dataManager
        loadLists()
        selectDefaultList()
    }
}
```

Enables production use with default and test use with injected mock.

### Window Configuration

```swift
Window("Quick Entry", id: "quickEntry") {
    QuickEntryView()
}
.windowStyle(.hiddenTitleBar)
.windowResizability(.contentSize)
.defaultPosition(.center)
```

### Visual Effect Background (Frosted Glass)

```swift
struct VisualEffectBackground: NSViewRepresentable {
    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = .hudWindow
        view.blendingMode = .behindWindow
        view.state = .active
        return view
    }
}
```

### Order Number Assignment

```swift
let existingItems = dataManager.getItems(forListId: listId)
let maxOrderNumber = existingItems.map { $0.orderNumber }.max() ?? -1
newItem.orderNumber = maxOrderNumber + 1
```

New items always appear at end of list.

### Keyboard Handling

- **Enter**: Saves item and dismisses (`.onSubmit` + button shortcut)
- **Escape**: Dismisses without saving (`.onExitCommand`)

## Note on Global Shortcuts

Current implementation uses menu command (Cmd+Option+Space) that works when:
- App is in foreground
- App is in dock (can be activated via shortcut)

Future enhancement: Register global hotkey using `CGEvent` API with accessibility permissions.

## Test Coverage

30 tests: view/ViewModel existence, item creation, validation, trimming, list selection, canSave state, clear() behavior, window config, keyboard shortcuts, rapid entry, order numbers.
