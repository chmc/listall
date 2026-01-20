---
title: macOS Archived Lists Empty View Fix
date: 2026-01-19
severity: CRITICAL
category: macos
tags: [coredata, swiftui, archived-lists, published-property, data-loading]
symptoms: [archived lists view shows empty, header visible but no lists appear]
root_cause: displayedLists filtered dataManager.lists for archived items, but loadData() predicate excludes archived
solution: Added separate @Published archivedLists property with dedicated loadArchivedData() method
files_affected: [ListAll/Models/CoreData/CoreDataManager.swift, ListAllMac/Views/MacMainView.swift, ListAllMacTests/TestHelpers.swift]
related: [macos-restore-archived-lists.md, macos-archived-lists-read-only.md]
---

## Problem

Archived lists view showed empty even when archived lists existed.

## Root Cause

`displayedLists` filtered `dataManager.lists` for archived items:

```swift
// BUG: dataManager.lists NEVER contains archived lists!
return dataManager.lists.filter { $0.isArchived }  // Always empty
```

**Why:** `loadData()` uses predicate `"isArchived == NO OR isArchived == nil"` - it never loads archived lists into the `lists` property.

## iOS vs macOS Pattern Difference

| Aspect | iOS (Working) | macOS (Broken) |
|--------|---------------|----------------|
| Data source | `MainViewModel.archivedLists` | `dataManager.lists.filter { $0.isArchived }` |
| Load method | Calls `loadArchivedLists()` | Filters from cached (excluded) lists |

## Solution

### 1. Added @Published archivedLists

```swift
class DataManager: ObservableObject {
    @Published var lists: [List] = []
    @Published var archivedLists: [List] = []  // NEW
}
```

### 2. Added loadArchivedData()

```swift
func loadArchivedData() {
    let fetched = loadArchivedLists()
    DispatchQueue.main.async {
        self.objectWillChange.send()
        self.archivedLists = fetched
    }
}
```

### 3. Updated displayedLists

```swift
private var displayedLists: [List] {
    if showingArchivedLists {
        return dataManager.archivedLists  // Use cached property
    } else {
        return dataManager.lists.filter { !$0.isArchived }
            .sorted { $0.orderNumber < $1.orderNumber }
    }
}
```

### 4. Trigger on Toggle

```swift
.onChange(of: showingArchivedLists) { _, newValue in
    if newValue {
        dataManager.loadArchivedData()
    }
}
```

### 5. Refresh After Mutations

Updated `deleteList()`, `restoreList()`, `permanentlyDeleteList()` to call `loadArchivedData()`.

## Key Learnings

1. **Separate data sources need separate loading**: Different predicates require separate properties
2. **SwiftUI observation requires @Published**: Filtering a `@Published` array does not create new observable - need dedicated property
3. **Consistency across platforms**: Align data layer patterns (iOS had this right)
4. **Cache invalidation**: All mutation methods must refresh relevant caches

## Test Coverage

11 tests: property existence, initial state, loading, active/archived separation, restore updates, permanent delete, sort order, multiple operations, item preservation, cascade delete, empty state.
