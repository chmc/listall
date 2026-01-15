# macOS Quick Entry Window Implementation

## Task Reference
Task 12.10: Add Quick Entry Window (MINOR)

## Problem Statement
No way to quickly add items from anywhere in macOS without switching to the app. Power users expect a Things 3-style Quick Entry feature that allows rapid item creation without context switching.

## Solution Implemented

### Architecture

1. **QuickEntryViewModel** - ObservableObject for state management:
   - `itemTitle: String` - The item title being entered
   - `selectedListId: UUID?` - The target list
   - `lists: [List]` - Available non-archived lists
   - `canSave: Bool` - Computed property for validation
   - `saveItem() -> Bool` - Creates and persists the item
   - `clear()` - Resets for another entry
   - `refresh()` - Reloads lists from DataManager

2. **QuickEntryView** - Minimal floating window design:
   - Header with title and close button
   - Text field for item title (focused on appear)
   - List picker with menu style
   - Add Item button with validation
   - Visual effect background for frosted glass

3. **Window Scene** in ListAllMacApp.swift:
   - `Window("Quick Entry", id: "quickEntry")`
   - `.windowStyle(.hiddenTitleBar)` - No title bar
   - `.windowResizability(.contentSize)` - Match content size
   - `.defaultPosition(.center)` - Center on screen

4. **Menu Command** in AppCommands.swift:
   - "Quick Entry" in File menu
   - Keyboard shortcut: Cmd+Option+Space
   - Opens window via `openWindow(id: "quickEntry")`

### Key Implementation Details

#### ViewModel with Dependency Injection
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

This pattern allows:
- Production use with default `DataManager.shared`
- Test use with injected `TestDataManager`

#### Title Validation and Trimming
```swift
func saveItem() -> Bool {
    let trimmedTitle = itemTitle.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmedTitle.isEmpty else { return false }
    guard let listId = selectedListId else { return false }
    // ... create item
}
```

#### Order Number Assignment
```swift
let existingItems = dataManager.getItems(forListId: listId)
let maxOrderNumber = existingItems.map { $0.orderNumber }.max() ?? -1
newItem.orderNumber = maxOrderNumber + 1
```

New items always get the next order number, appearing at the end of the list.

#### Visual Effect Background
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

This creates the macOS-native frosted glass appearance.

### Keyboard Handling

- **Enter**: Saves item and dismisses (via `.onSubmit` and button shortcut)
- **Escape**: Dismisses without saving (via `.onExitCommand`)

### Note on Global Shortcuts

Global keyboard shortcuts outside the app require accessibility permissions. The current implementation uses a menu command with `Cmd+Option+Space` that works when:
- The app is in the foreground
- The app is in the dock (can be activated via shortcut)

Future enhancement: Register a global hotkey using `CGEvent` API with accessibility permissions.

## Files Created
- `/Users/aleksi/source/listall/ListAll/ListAllMac/Views/QuickEntryView.swift`

## Files Modified
- `/Users/aleksi/source/listall/ListAll/ListAllMac/ListAllMacApp.swift` - Added Window scene
- `/Users/aleksi/source/listall/ListAll/ListAllMac/Commands/AppCommands.swift` - Added menu command

## Test Coverage
30 tests in `QuickEntryWindowTests`:
- View and ViewModel existence
- Item creation and validation
- Empty/whitespace title rejection
- Title trimming
- List selection and default selection
- canSave state tracking
- clear() reset behavior
- Window configuration
- Keyboard shortcuts
- Rapid item creation
- Order number assignment

## References
- Things 3 Quick Entry pattern
- Apple HIG: Floating windows
- SwiftUI Window scene documentation
- NSVisualEffectView documentation

## Date
January 15, 2026
