---
title: SwiftUI List Drag-Drop with Watch Sync Multi-Bug
date: 2025-12-15
severity: HIGH
category: swiftui
tags: [drag-drop, reordering, watch-sync, foreach, animation-cache]
symptoms:
  - Dragging a list causes a DIFFERENT list to move
  - Data logs show correct order but UI displays wrong order
  - Watch receives OLD order after each drag (one step behind)
  - Item drag-drop works, only list drag-drop is broken
root_cause: Four separate bugs combining - wrong algorithm, cache staleness, ForEach animation cache, sync ping-pong
solution: Use remove+insert pattern, refresh cache after update, force ForEach rebuild with .id() trigger, ignore stale sync data
files_affected:
  - ListAll/ListAll/ViewModels/MainViewModel.swift
  - ListAll/ListAll/Views/MainView.swift
  - ListAll/ListAll/Services/DataRepository.swift
related: [macos-item-drag-drop-regression.md]
---

## The Four Bugs

### Bug 1: Wrong Reordering Algorithm

**Problem**: Used `Array.move(fromOffsets:toOffset:)` which has different semantics than working items implementation.

**Fix**: Use proven remove+insert pattern via `DataRepository.reorderLists()`.

### Bug 2: Cache Staleness After Core Data Update

**Problem**: After updating Core Data, `dataManager.lists` cache still had OLD array order.

**Why**: `updateList()` updated orderNumber properties at OLD array positions without reordering the array.

**Fix**: Add `dataManager.loadData()` after reordering to refresh cache from Core Data.

### Bug 3: SwiftUI ForEach Animation Cache

**Problem**: Even with correct data, SwiftUI ForEach kept items in DRAGGED visual positions.

**Why**: SwiftUI's animation system caches item positions during drag; updating @Published array doesn't break this cache.

**Fix**: Use counter trigger with `.id()`:

```swift
// MainViewModel.swift
@Published var listsReorderTrigger: Int = 0

func moveList(...) {
    // ... reordering logic ...
    listsReorderTrigger += 1  // Force SwiftUI rebuild
}

// MainView.swift
List { ... }
    .id(viewModel.listsReorderTrigger)  // Break ForEach animation cache
```

### Bug 4: Watch Sync Ping-Pong

**Problem**: After iOS reorder, Watch showed PREVIOUS order.

**Why**: When iOS sent new order, Watch (with old order) sent data BACK. This incoming sync was deferred during drag, then re-posted 1 second later with STALE data.

**Fix**: IGNORE stale Watch data completely during drag (don't defer and re-post):

```swift
if isDragOperationInProgress {
    print("Watch sync received during drag - IGNORING stale data")
    return  // Don't re-post stale data
}
```

## Key Insights

- **One bug can hide another**: Each fix revealed the next bug
- **Logs can lie about UI**: Data logs showed correct order, but SwiftUI rendered wrong
- **ForEach caches positions**: Updating data doesn't automatically update drag visuals
- **Sync ping-pong**: Deferring stale data causes "one sync behind" loops
- **Working reference exists**: Compare with working implementations in same codebase

## Prevention Checklist

- [ ] Use standard remove+insert pattern, not Array.move()
- [ ] Refresh cache from data store AFTER modifying data store
- [ ] Force SwiftUI ForEach rebuild after reordering (use .id() with trigger)
- [ ] Don't defer and re-post stale sync data - ignore it instead
- [ ] Compare with working implementations in same codebase
- [ ] Test with actual device, not just logs
