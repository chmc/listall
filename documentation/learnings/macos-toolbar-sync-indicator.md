# Learning: macOS Toolbar Sync Status Indicator

**Date**: January 15, 2026
**Task**: 12.6 - Add Sync Status Indicator in Toolbar
**Platform**: macOS 14.0+

## Problem

The iCloud sync status was hidden in a small footer at the bottom of the sidebar. Users had no visual indication when sync was happening or if there were errors, making it difficult to understand the current sync state.

## Solution

Added a prominent sync status indicator button in the main toolbar with:
1. Rotating animation during sync
2. Tooltip showing last sync time or error message
3. Red color indicator for sync errors
4. Click-to-sync functionality

## Key Learnings

### 1. macOS Version-Specific Symbol Effects

The `.symbolEffect(.rotate)` modifier requires macOS 15.0+. For apps targeting macOS 14.0, you need a fallback:

```swift
@ViewBuilder
private var syncButtonImage: some View {
    if #available(macOS 15.0, *) {
        // Native SF Symbol animation on macOS 15+
        Image(systemName: "arrow.triangle.2.circlepath")
            .symbolEffect(.rotate, isActive: cloudKitService.isSyncing)
    } else {
        // Fallback for macOS 14: use rotationEffect with animation
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

### 2. Shared Singleton for Service Observation

To observe CloudKitService state from views, a shared singleton is needed:

```swift
class CloudKitService: ObservableObject {
    static let shared = CloudKitService()

    @Published var isSyncing = false
    @Published var syncError: String?
    @Published var lastSyncDate: Date?
    // ...
}
```

Then in the view:
```swift
@ObservedObject private var cloudKitService = CloudKitService.shared
```

### 3. Toolbar Placement in NavigationSplitView

When adding toolbar items to a NavigationSplitView-based app with multiple sub-views, place the toolbar modifier at the NavigationSplitView level (not inside nested views) for the button to appear in the main window toolbar:

```swift
NavigationSplitView { ... }
.frame(minWidth: 800, minHeight: 600)
.toolbar {
    ToolbarItem(placement: .automatic) {
        // Sync button here is always visible in main toolbar
    }
}
```

### 4. RelativeDateTimeFormatter for User-Friendly Timestamps

Use `RelativeDateTimeFormatter` for human-readable "X minutes ago" style timestamps:

```swift
private var syncTooltipText: String {
    if cloudKitService.isSyncing {
        return "Syncing with iCloud..."
    } else if let error = cloudKitService.syncError {
        return "Sync error: \(error) - Click to retry"
    } else if let lastSync = coreDataManager.lastSyncDate {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .short
        return "Last synced \(formatter.localizedString(for: lastSync, relativeTo: Date())) - Click to sync"
    } else {
        return "Click to sync with iCloud"
    }
}
```

### 5. Accessibility for Dynamic States

When button labels change based on state, use computed accessibility labels:

```swift
.accessibilityLabel(cloudKitService.isSyncing ? "Syncing with iCloud" : "Sync with iCloud")
```

## Files Modified

- `/Users/aleksi/source/listall/ListAll/ListAll/Services/CloudKitService.swift`
  - Added `static let shared = CloudKitService()` singleton

- `/Users/aleksi/source/listall/ListAll/ListAllMac/Views/MacMainView.swift`
  - Added `@ObservedObject private var cloudKitService = CloudKitService.shared`
  - Added `syncButtonImage` computed property with availability check
  - Added `syncTooltipText` computed property
  - Added toolbar sync indicator button

## Test Coverage

25 tests in `SyncStatusIndicatorTests` verify:
- Sync icon exists with correct accessibility identifier
- Correct system image used
- Animation activates/deactivates based on sync state
- Tooltip shows last sync time, syncing state, and errors
- Red indicator for error state
- Click triggers manual sync
- Button disabled during sync
- Accessibility labels for all states

## Best Practices Applied

1. **Progressive Enhancement**: Modern API with fallback for older OS
2. **Accessibility First**: Proper labels and identifiers
3. **Visual Feedback**: Animation during sync, color for errors
4. **User Control**: Click to trigger manual sync
5. **Informative Tooltips**: Context-aware tooltip text
