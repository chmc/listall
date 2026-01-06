# macOS SwiftUI Memory Management Patterns

## Date: 2026-01-06

## Context
Implemented Task 11.5 Memory Leak Testing for ListAll macOS app. Analyzed the codebase for retain cycles and memory management issues, and created unit tests for memory leak detection.

## Key Findings

### 1. SwiftUI Structs Don't Create Retain Cycles

**Important:** SwiftUI views are structs (value types), not classes. The pattern `[self]` in a Timer closure within a struct is correct because:
- Structs are copied by value, not referenced
- When the timer closure captures `[self]`, it captures a copy of the struct's state at that moment
- No retain cycle is possible because there's no reference cycle

```swift
// CORRECT for SwiftUI structs:
Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [self] _ in
    // This captures a copy of self - no retain cycle
    dataManager.loadData()
}
```

**Mistake to Avoid:** Don't try to use `[weak self]` in SwiftUI structs - it won't compile because structs are value types, not reference types.

### 2. Actual Memory Leak Patterns to Watch For

In a SwiftUI/MVVM codebase, focus on **class-based objects** for memory leaks:

| Component Type | Can Leak? | Watch For |
|---------------|-----------|-----------|
| SwiftUI View (struct) | No | - |
| ObservableObject (class) | Yes | Closures, NotificationCenter, Timers |
| Service singletons | No* | *Intentionally retained |
| NSObject subclasses | Yes | Delegate patterns, event monitors |

### 3. Good Patterns Already in Codebase

The ListAll codebase follows best practices:

```swift
// ViewModels properly clean up in deinit
deinit {
    NotificationCenter.default.removeObserver(self)
    archiveNotificationTimer?.invalidate()
}

// Timer closures in ViewModels use [weak self]
Timer.scheduledTimer(...) { [weak self] _ in
    self?.hideArchiveNotification()
}
```

### 4. Testing Memory Leaks Limitations

**What unit tests CAN detect:**
- Basic object deallocation with weak reference tracking
- Closure capture patterns
- NotificationCenter observer cleanup

**What unit tests CANNOT detect:**
- Runtime-only leaks from specific navigation patterns
- SwiftUI view lifecycle issues (views are structs)
- Core Data context retention issues
- Timing-dependent async leaks

**Recommendation:** Use Instruments Memory Graph Debugger for comprehensive testing, supplement with unit tests for specific patterns.

### 5. Singleton Testing Anti-Pattern

**DON'T** test singletons for deallocation:
```swift
// This test will ALWAYS FAIL - singletons are intentionally retained
func testServiceDeallocates() {
    weak var weak = ImageService.shared
    // weak will NEVER be nil - false positive!
}
```

Singletons in this codebase that should NOT be tested for deallocation:
- `DataManager.shared`
- `CoreDataManager.shared`
- `ImageService.shared`
- `HandoffService.shared`
- Many others (~20+ services)

## Test Pattern Template

For ViewModels and other classes, use this pattern:

```swift
func testViewModelDeallocates() {
    weak var weakViewModel: SomeViewModel?

    autoreleasepool {
        let viewModel = SomeViewModel()
        weakViewModel = viewModel
        // Use viewModel...
    }

    // Run loop for async cleanup
    RunLoop.current.run(until: Date().addingTimeInterval(0.1))

    XCTAssertNil(weakViewModel, "ViewModel should deallocate")
}
```

## Files Modified
- `ListAllMac/Views/MacMainView.swift` - Added clarifying comment for `[self]` in timer
- `ListAllMacTests/ListAllMacTests.swift` - Added 24 memory leak tests

## Related Resources
- [Understanding Swift Memory Management](https://developer.apple.com/documentation/swift/managing-memory-automatically)
- [Diagnosing Memory Issues](https://developer.apple.com/documentation/xcode/diagnosing-memory-issues)
