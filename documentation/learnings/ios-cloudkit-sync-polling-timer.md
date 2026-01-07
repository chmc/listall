# iOS CloudKit Sync Polling Timer

## Date: 2026-01-07

## Problem
iOS app was not receiving macOS changes automatically. Changes made on macOS only appeared on iOS after app restart.

## Root Cause
iOS lacked the same polling timer fallback that macOS has. CloudKit push notifications on iOS can be unreliable when the app is frontmost and active, meaning changes from other devices may not trigger UI updates.

## Initial (Wrong) Implementation

Using `Timer.scheduledTimer` with `[self]` capture in a SwiftUI View struct:

```swift
// BAD - Causes crashes!
@State private var syncPollingTimer: Timer?

private func startSyncPolling() {
    syncPollingTimer = Timer.scheduledTimer(withTimeInterval: 30.0, repeats: true) { [self] _ in
        // This captures a COPY of the struct, causing crashes
        viewModel.loadLists()
    }
}
```

### Why This Crashes
- SwiftUI Views are **structs** (value types), not classes (reference types)
- `[self]` in a closure captures a **copy** of the struct at that moment
- When the timer fires, it operates on a stale copy with invalid references
- This leads to "ListAll quit unexpectedly" crashes

## Correct Implementation

Use `Timer.publish` with `.onReceive` - the proper SwiftUI pattern:

```swift
// GOOD - SwiftUI-native timer pattern
@State private var isSyncPollingActive = false
private let syncPollingTimer = Timer.publish(every: 30.0, on: .main, in: .common).autoconnect()

var body: some View {
    // ... view content ...
    .onReceive(syncPollingTimer) { _ in
        guard isSyncPollingActive else { return }

        let viewContext = CoreDataManager.shared.viewContext
        viewContext.performAndWait {
            viewContext.refreshAllObjects()
        }
        viewModel.loadLists()
    }
    .onChange(of: scenePhase) { newPhase in
        if newPhase == .active {
            isSyncPollingActive = true
        } else {
            isSyncPollingActive = false
        }
    }
}
```

### Why This Works
- `Timer.publish` returns a Combine publisher that integrates with SwiftUI lifecycle
- `.onReceive` subscribes to the timer in a way managed by SwiftUI
- No closure capture issues - SwiftUI handles the view identity properly
- The `isSyncPollingActive` flag controls when polling happens without needing manual start/stop

## Key Learnings

1. **Never use `Timer.scheduledTimer` with `[self]` capture in SwiftUI Views** - structs don't work like classes for closure captures

2. **Use `Timer.publish` + `.onReceive` for timers in SwiftUI** - this is the native pattern that integrates with the view lifecycle

3. **Control timer behavior with state flags** - instead of starting/stopping timers manually, use a flag that `.onReceive` checks

4. **Import Combine** when using `Timer.publish`:
   ```swift
   import Combine
   ```

5. **Match macOS sync patterns on iOS** - both platforms should have polling timer fallback for CloudKit sync reliability

## Files Modified

- `ListAll/ListAll/Views/MainView.swift`
  - Added `import Combine`
  - Replaced `@State private var syncPollingTimer: Timer?` with `@State private var isSyncPollingActive = false`
  - Added `private let syncPollingTimer = Timer.publish(every: 30.0, on: .main, in: .common).autoconnect()`
  - Added `.onReceive(syncPollingTimer)` modifier
  - Removed manual `startSyncPolling()` and `stopSyncPolling()` functions
  - Updated `scenePhase` handler to set `isSyncPollingActive` flag

## References

- Apple Documentation: Combine framework `Timer.publish`
- SwiftUI lifecycle and view identity
- Previous learning: `cloudkit-sync-enhanced-reliability.md` (macOS polling pattern)
