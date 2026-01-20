---
title: iOS CloudKit Real-Time Sync Threading Bug
date: 2025-12-15
severity: CRITICAL
category: cloudkit
tags: [threading, swiftui, notifications, background-threads, viewcontext]
symptoms:
  - iOS not receiving CloudKit changes in real-time
  - Changes only sync when iOS app closed and reopened
  - Console shows "Publishing changes from background threads is not allowed"
  - Console shows "Updating ObservedObject from background threads"
  - Data received but UI not refreshing
root_cause: viewContext.perform {} inside DispatchQueue.main.async re-dispatches to background queue, causing @Published updates to be silently ignored
solution: Remove viewContext.perform wrapper, add main thread guards to @objc handlers, enable observers on iOS
files_affected:
  - ListAll/ListAll/Models/CoreData/CoreDataManager.swift
  - ListAll/ListAll/Views/MainView.swift
  - ListAll/ListAll/ViewModels/ListViewModel.swift
  - ListAll/ListAll/ViewModels/MainViewModel.swift
related:
  - cloudkit-push-notification-config.md
  - macos-cloudkit-sync-race-condition.md
---

## The Bug

```swift
// BROKEN:
DispatchQueue.main.async {
    self.viewContext.perform {  // Re-dispatches to background!
        self.viewContext.refreshAllObjects()
    }
    NotificationCenter.default.post(...)  // Now on background thread!
}
```

`viewContext.perform {}` schedules on viewContext's queue (background), causing @Published updates to be silently ignored by SwiftUI.

## Fixes Applied

### 1. Remove viewContext.perform wrapper (CoreDataManager)
```swift
// FIXED:
DispatchQueue.main.async {
    self.viewContext.refreshAllObjects()  // Direct call on main thread
    NotificationCenter.default.post(...)
}
```

### 2. Add main thread guards to @objc handlers (MainViewModel)
```swift
@objc private func handleCoreDataRemoteChange(_ notification: Notification) {
    guard Thread.isMainThread else {
        DispatchQueue.main.async { [weak self] in
            self?.handleCoreDataRemoteChange(notification)
        }
        return
    }
    loadLists()
}
```

**Critical**: @MainActor does NOT protect @objc selectors.

### 3. Enable NSManagedObjectContextDidSave observer for iOS
Changed from `#if os(macOS)` to `#if os(iOS) || os(macOS)`.

### 4. Add UI notification observers
- MainView.swift: `.onReceive` for `.coreDataRemoteChange`
- ListViewModel.swift: Observer with `handleRemoteChange` selector

## Why macOS Worked But iOS Didn't

| Mechanism | macOS | iOS (Before) |
|-----------|-------|--------------|
| NSManagedObjectContextDidSave observer | Yes | No |
| refreshAllObjects() on import | Yes | No |
| Sync polling timer (30s) | Yes | No |
| coreDataRemoteChange observer in Views | Yes | No |

macOS had multiple fallback mechanisms; iOS relied solely on unreliable notifications.

## Key Insight

`NSPersistentStoreRemoteChange` is unreliable when foregrounded. CloudKit imports on background context; observing `NSManagedObjectContextDidSave` on ALL contexts catches these.

## Prevention Rules

1. Never nest viewContext.perform inside DispatchQueue.main.async
2. Always guard @objc handlers for main thread
3. Use multiple sync detection mechanisms (don't rely on one)
4. Observe background context saves for CloudKit imports
5. Test on real devices (simulator timing differs)
