---
title: macOS SwiftUI Memory Management Patterns
date: 2026-01-06
severity: MEDIUM
category: macos
tags: [memory, retain-cycles, swiftui, structs, weak-references, testing]
symptoms:
  - Confusion about [self] vs [weak self] in SwiftUI views
  - False positive memory leak tests for singletons
  - Uncertainty about what can leak
root_cause: Misunderstanding that SwiftUI views are structs (value types) not classes
solution: Focus memory leak testing on class-based objects (ViewModels, services); understand structs cannot create retain cycles
files_affected:
  - ListAllMac/Views/MacMainView.swift
  - ListAllMacTests/ListAllMacTests.swift
related:
  - macos-performance-optimization.md
---

## SwiftUI Structs Cannot Create Retain Cycles

SwiftUI views are structs (value types). Using `[self]` in closures is correct:
```swift
// CORRECT for SwiftUI structs
Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [self] _ in
    dataManager.loadData()  // Captures copy of self - no retain cycle
}
```

**Do NOT use `[weak self]` in SwiftUI structs** - it won't compile because structs are value types.

## What Can Actually Leak

| Component Type | Can Leak? | Watch For |
|---------------|-----------|-----------|
| SwiftUI View (struct) | No | - |
| ObservableObject (class) | Yes | Closures, NotificationCenter, Timers |
| Service singletons | No* | *Intentionally retained |
| NSObject subclasses | Yes | Delegate patterns, event monitors |

## Good Patterns in Codebase

ViewModels properly clean up:
```swift
deinit {
    NotificationCenter.default.removeObserver(self)
    archiveNotificationTimer?.invalidate()
}

// Timer in ViewModel uses [weak self]
Timer.scheduledTimer(...) { [weak self] _ in
    self?.hideArchiveNotification()
}
```

## Memory Leak Testing Limitations

**Unit tests CAN detect:**
- Basic object deallocation via weak reference tracking
- Closure capture patterns
- NotificationCenter observer cleanup

**Unit tests CANNOT detect:**
- Runtime-only leaks from navigation patterns
- SwiftUI view lifecycle issues (views are structs)
- Core Data context retention issues
- Timing-dependent async leaks

Use Instruments Memory Graph Debugger for comprehensive testing.

## Singleton Testing Anti-Pattern

**DON'T test singletons for deallocation:**
```swift
// ALWAYS FAILS - singletons are intentionally retained
func testServiceDeallocates() {
    weak var weak = ImageService.shared  // Never nil!
}
```

Singletons not to test: `DataManager.shared`, `CoreDataManager.shared`, `ImageService.shared`, etc.

## ViewModel Deallocation Test Pattern

```swift
func testViewModelDeallocates() {
    weak var weakViewModel: SomeViewModel?

    autoreleasepool {
        let viewModel = SomeViewModel()
        weakViewModel = viewModel
    }

    RunLoop.current.run(until: Date().addingTimeInterval(0.1))
    XCTAssertNil(weakViewModel, "ViewModel should deallocate")
}
```
