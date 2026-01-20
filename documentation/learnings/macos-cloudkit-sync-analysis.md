---
title: macOS CloudKit Sync UI Update Analysis
date: 2025-12-07
severity: HIGH
category: cloudkit
tags: [coredata, swiftui, threading, race-condition, sync-debugging]
symptoms: [macOS UI only updates when switching away/back, changes visible after scenePhase.active]
root_cause: Multiple issues - isLocalSave race condition, notification posted before refresh, @Published update optimization skips changes
solution: Thread-safe flags, post notification after refresh completes, always reassign @Published arrays
files_affected: [ListAll/Models/CoreData/CoreDataManager.swift, ListAll/ViewModels/MainViewModel.swift]
related: [macos-realtime-sync-fix.md, ios-cloudkit-sync-polling-timer.md]
---

## Symptom

macOS receives CloudKit changes but UI only updates when user switches away and back (triggers `scenePhase == .active`).

## Root Causes Identified

### Issue A: isLocalSave Race Condition

```swift
// NOT thread-safe!
private var isLocalSave = false

// Main thread sets it
isLocalSave = true
try context.save()

// Background thread reads it - RACE!
if isLocalSave { return }  // Remote change incorrectly ignored
```

**Fix**: Use `@MainActor` or guard with `Thread.isMainThread`.

### Issue B: Notification Posted Before Refresh

```swift
// BAD - notification fires before data ready
viewContext.perform { viewContext.refreshAllObjects() }
NotificationCenter.default.post(name: .coreDataRemoteChange, ...)  // Immediate!

// GOOD - post AFTER refresh
viewContext.perform {
    viewContext.refreshAllObjects()
    DispatchQueue.main.async {
        NotificationCenter.default.post(name: .coreDataRemoteChange, ...)
    }
}
```

### Issue C: @Published Array Optimization Bug

```swift
// BAD - in-place mutation may not trigger @Published
if currentIds == newIds {
    for (i, list) in newLists.enumerated() {
        lists[i] = list  // SwiftUI might not detect this
    }
}

// GOOD - always reassign entire array
lists = newLists  // Always triggers @Published
```

### Issue D: Debounce Too Long

```swift
// 500ms feels sluggish
private let remoteChangeDebounceInterval: TimeInterval = 0.5

// 200ms more responsive
private let remoteChangeDebounceInterval: TimeInterval = 0.2
```

## Fix Priority

1. **Remove optimization** (Issue C) - most likely fix, easiest
2. **Post after refresh** (Issue B) - correct operation order
3. **Add debug logging** - essential for debugging
4. **Thread safety** (Issue A) - prevents race conditions
5. **Reduce debounce** (Issue D) - improves UX

## Testing

| Test | Steps | Expected |
|------|-------|----------|
| Remote appears | iOS adds list, macOS active | macOS shows list in 5s |
| Race condition | Rapid local + remote creates | All lists appear |
| Drag protected | Start drag, iOS reorders | macOS ignores during drag |
