# macOS Keyboard Reordering Implementation

## Date
January 15, 2026

## Task
Task 12.11: Add Keyboard Reordering

## Problem
Items in the ListAll macOS app could only be reordered via drag-and-drop. Users with motor disabilities or keyboard-first workflows could not reorder items without using a mouse.

## Solution

### 1. ListViewModel Methods

Added three new members to `ListViewModel.swift`:

```swift
// Computed property to check if keyboard reordering is available
var canReorderWithKeyboard: Bool {
    return currentSortOption == .orderNumber
}

// Move item up one position
func moveItemUp(_ id: UUID) {
    guard canReorderWithKeyboard else { return }
    guard let currentIndex = items.firstIndex(where: { $0.id == id }) else { return }
    guard currentIndex > 0 else { return }
    let destinationIndex = currentIndex - 1
    reorderItems(from: currentIndex, to: destinationIndex)
}

// Move item down one position
func moveItemDown(_ id: UUID) {
    guard canReorderWithKeyboard else { return }
    guard let currentIndex = items.firstIndex(where: { $0.id == id }) else { return }
    guard currentIndex < items.count - 1 else { return }
    let destinationIndex = currentIndex + 1
    reorderItems(from: currentIndex, to: destinationIndex)
}
```

### 2. SwiftUI Keyboard Handlers (Critical Learning)

**IMPORTANT**: SwiftUI `.onKeyPress` with arrow keys does NOT support a `modifiers:` parameter like character-based key press handlers.

**Wrong approach** (causes compilation error):
```swift
// This does NOT work for arrow keys!
.onKeyPress(.upArrow, modifiers: [.command, .option]) {
    // ...
}
```

**Correct approach**:
```swift
.onKeyPress(keys: [.upArrow]) { keyPress in
    // Check modifiers inside the closure
    guard keyPress.modifiers.contains(.command),
          keyPress.modifiers.contains(.option) else {
        return .ignored
    }
    // Handle the key press
    return .handled
}
```

### 3. Constraints

- Only works when sorted by "Order" (orderNumber)
- Disabled when sorted by title, date, quantity, etc.
- Visual feedback happens automatically via SwiftUI List animation

## Files Modified

1. `/Users/aleksi/source/listall/ListAll/ListAll/ViewModels/ListViewModel.swift`
   - Added `canReorderWithKeyboard` computed property
   - Added `moveItemUp(_ id: UUID)` method
   - Added `moveItemDown(_ id: UUID)` method

2. `/Users/aleksi/source/listall/ListAll/ListAllMac/Views/MacMainView.swift`
   - Added `.onKeyPress(keys: [.upArrow])` handler (lines ~1555-1566)
   - Added `.onKeyPress(keys: [.downArrow])` handler (lines ~1567-1577)

3. `/Users/aleksi/source/listall/ListAll/ListAllMacTests/TestHelpers.swift`
   - Added matching methods to TestListViewModel for test isolation

4. `/Users/aleksi/source/listall/ListAll/ListAllMacTests/ListAllMacTests.swift`
   - Added KeyboardReorderingTests class with 16 tests

## Test Coverage

16 tests covering:
- Move item up from middle position
- Move item up from first position (should do nothing)
- Move item up with invalid ID
- Move item down from middle position
- Move item down from last position (should do nothing)
- Move item down with invalid ID
- canReorderWithKeyboard only true with orderNumber sort
- Move ignored when not sorted by order
- Edge cases: single item, empty list
- Sequential moves up/down

## Key Insight

When testing with Core Data in Swift tests, the list entity must exist in the data manager BEFORE creating items. The test helper `createViewModelWithItems(itemCount:)` demonstrates the correct setup:

```swift
private func createViewModelWithItems(itemCount: Int) -> TestListViewModel {
    let testDataManager = TestHelpers.createTestDataManager()
    // First add the list to the data manager
    let testList = ListModel(name: "Test List")
    testDataManager.addList(testList)  // <-- CRITICAL: list must exist first!

    let viewModel = TestListViewModel(list: testList, dataManager: testDataManager)

    for i in 0..<itemCount {
        viewModel.createItem(title: "Item \(i)")
    }
    return viewModel
}
```

## Accessibility Benefits

This feature improves accessibility by:
- Allowing keyboard-only users to reorder items
- Supporting VoiceOver users who cannot use drag-and-drop
- Following macOS accessibility best practices (WCAG 2.1 Guideline 2.1.1)
