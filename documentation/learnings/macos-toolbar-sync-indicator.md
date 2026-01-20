---
title: macOS Toolbar Sync Status Indicator
date: 2026-01-15
severity: MEDIUM
category: macos
tags: [swiftui, toolbar, cloudkit, sync, animation, accessibility]
symptoms: [sync status hidden in sidebar footer, no visual feedback during sync, sync errors not visible]
root_cause: Sync status lacked prominent UI placement and visual feedback
solution: Added toolbar button with rotating animation, tooltips, error coloring, and click-to-sync
files_affected: [ListAll/Services/CloudKitService.swift, ListAllMac/Views/MacMainView.swift]
related: [macos-settings-sync-toggle-bug.md, macos-cloudkit-sync-analysis.md, macos-realtime-sync-fix.md]
---

## Problem

iCloud sync status was hidden in a small sidebar footer. Users had no visual indication of sync state or errors.

## Solution

Added prominent toolbar sync button with:
- Rotating animation during sync (macOS 15+ native, 14.x fallback)
- Tooltip showing last sync time or error
- Red color for errors
- Click-to-sync functionality

## Key Patterns

### macOS Version-Specific Symbol Effects

`.symbolEffect(.rotate)` requires macOS 15.0+. Use availability check with fallback:

```swift
@ViewBuilder
private var syncButtonImage: some View {
    if #available(macOS 15.0, *) {
        Image(systemName: "arrow.triangle.2.circlepath")
            .symbolEffect(.rotate, isActive: cloudKitService.isSyncing)
    } else {
        Image(systemName: "arrow.triangle.2.circlepath")
            .rotationEffect(.degrees(cloudKitService.isSyncing ? 360 : 0))
            .animation(
                cloudKitService.isSyncing
                    ? .linear(duration: 1.0).repeatForever(autoreverses: false)
                    : .default,
                value: cloudKitService.isSyncing
            )
    }
}
```

### Toolbar Placement in NavigationSplitView

Place toolbar modifier at NavigationSplitView level (not nested views) for main window visibility:

```swift
NavigationSplitView { ... }
.toolbar {
    ToolbarItem(placement: .automatic) {
        // Always visible in main toolbar
    }
}
```

### Singleton for Service Observation

```swift
class CloudKitService: ObservableObject {
    static let shared = CloudKitService()
    @Published var isSyncing = false
    @Published var syncError: String?
    @Published var lastSyncDate: Date?
}
```

### RelativeDateTimeFormatter for Timestamps

```swift
let formatter = RelativeDateTimeFormatter()
formatter.unitsStyle = .short
return "Last synced \(formatter.localizedString(for: lastSync, relativeTo: Date()))"
```

## Test Coverage

25 tests: icon existence, animation states, tooltip content, error coloring, click-to-sync, accessibility labels.
