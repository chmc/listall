---
title: SwiftUI Timer Pattern for CloudKit Polling
date: 2026-01-07
severity: CRITICAL
category: cloudkit
tags: [swiftui, timer, combine, cloudkit-sync, polling, crash-fix]
symptoms: [app crashes on timer fire, "ListAll quit unexpectedly", stale data in UI]
root_cause: Using Timer.scheduledTimer with [self] capture in SwiftUI View struct causes crash
solution: Use Timer.publish with .onReceive modifier - the native SwiftUI timer pattern
files_affected: [ListAll/Views/MainView.swift]
related: [macos-cloudkit-sync-analysis.md, macos-realtime-sync-fix.md]
---

## The Problem

iOS wasn't receiving macOS CloudKit changes automatically - only after app restart.

## WRONG Pattern (Causes Crashes)

```swift
// BAD - SwiftUI Views are STRUCTS, not classes!
@State private var syncPollingTimer: Timer?

private func startSyncPolling() {
    syncPollingTimer = Timer.scheduledTimer(withTimeInterval: 30.0, repeats: true) { [self] _ in
        // [self] captures a COPY of the struct - becomes stale, causes crash
        viewModel.loadLists()
    }
}
```

**Why it crashes**: SwiftUI Views are value types. `[self]` captures a copy at creation time. When timer fires, the copy has invalid references.

## CORRECT Pattern

```swift
import Combine

struct MainView: View {
    @State private var isSyncPollingActive = false
    private let syncPollingTimer = Timer.publish(every: 30.0, on: .main, in: .common).autoconnect()

    var body: some View {
        // ... view content ...
        .onReceive(syncPollingTimer) { _ in
            guard isSyncPollingActive else { return }
            viewContext.performAndWait { viewContext.refreshAllObjects() }
            viewModel.loadLists()
        }
        .onChange(of: scenePhase) { newPhase in
            isSyncPollingActive = (newPhase == .active)
        }
    }
}
```

## Key Rules

| Rule | Reason |
|------|--------|
| Never `Timer.scheduledTimer` with `[self]` in View | Struct copy becomes stale |
| Use `Timer.publish` + `.onReceive` | SwiftUI manages lifecycle |
| Control with state flag | No manual start/stop needed |
| Import Combine | Required for Timer.publish |

## Requirements

- `import Combine` at top of file
- State flag controls polling (not timer start/stop)
- Both iOS and macOS should have polling fallback for reliability
