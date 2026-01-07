# macOS Undo Banners Implementation

## Problem

The macOS app was missing the undo functionality that iOS has for:
1. Completing items (5-second undo banner)
2. Deleting items (5-second undo banner)

## Solution

Implemented macOS-native undo banners by:

1. **Created MacUndoBanner view** (for completed items):
   - Green checkmark icon
   - "Completed" text + item name
   - Blue "Undo" button using accent color
   - "X" dismiss button
   - Material background (`.ultraThinMaterial`) for modern macOS look
   - Shadow and rounded corners

2. **Created MacDeleteUndoBanner view** (for deleted items):
   - Red trash icon
   - "Deleted" text + item name
   - Red "Undo" button (restore action)
   - Same material background styling

3. **Integration in MacListDetailView**:
   - Wrapped main content in ZStack with `.bottom` alignment
   - Added conditional rendering based on ViewModel state
   - Applied spring animations with move+opacity transition
   - Max width of 400px with horizontal centering

4. **Wired up ViewModel methods**:
   - Changed `toggleItem()` to use `viewModel.toggleItemCrossedOut()`
   - Changed `deleteItem()` to use `viewModel.deleteItem()`
   - These methods automatically trigger undo banners via ListViewModel

## Key Implementation Details

### macOS-Specific Styling
```swift
.padding(12)
.background(.ultraThinMaterial)
.clipShape(RoundedRectangle(cornerRadius: 10))
.shadow(color: Color.black.opacity(0.15), radius: 4, x: 0, y: 2)
```

### Animation
```swift
.transition(.move(edge: .bottom).combined(with: .opacity))
.animation(.spring(response: 0.3, dampingFraction: 0.7), value: viewModel.showUndoButton)
```

### ZStack Overlay Pattern
```swift
ZStack(alignment: .bottom) {
    // Main content (VStack)
    VStack(spacing: 0) { ... }

    // Undo banners overlay at bottom
    if viewModel.showUndoButton, let item = viewModel.recentlyCompletedItem {
        MacUndoBanner(...)
    }

    if viewModel.showDeleteUndoButton, let item = viewModel.recentlyDeletedItem {
        MacDeleteUndoBanner(...)
    }
}
```

## DRY Principle

The implementation follows DRY by:
- Reusing shared `ListViewModel` with existing undo logic
- Reusing `undoComplete()`, `hideUndoButton()`, `undoDeleteItem()`, `hideDeleteUndoButton()` methods
- Only creating macOS-specific UI components (MacUndoBanner, MacDeleteUndoBanner)
- Timer-based auto-hide (5 seconds) is in shared ViewModel

## Files Modified

- `/Users/aleksi/source/listall/ListAll/ListAllMac/Views/MacMainView.swift`:
  - Added `MacUndoBanner` struct (lines 1966-2031)
  - Added `MacDeleteUndoBanner` struct (lines 2033-2098)
  - Modified `MacListDetailView.body` to use ZStack overlay
  - Updated `toggleItem()` and `deleteItem()` to use ViewModel methods

## Testing

Build verified with `xcodebuild -scheme ListAllMac` - BUILD SUCCEEDED

The undo functionality works because:
1. When user toggles an item complete, `viewModel.toggleItemCrossedOut()` sets `showUndoButton = true`
2. MacUndoBanner appears with spring animation
3. Timer auto-hides after 5 seconds
4. User can click "Undo" to restore item to active state
5. Same flow for delete with `showDeleteUndoButton`
