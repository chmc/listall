---
title: macOS Settings iCloud Sync Toggle Bug
date: 2026-01-07
severity: HIGH
category: macos
tags: [settings, icloud, cloudkit, ui-bug, misleading-ui]
symptoms:
  - Toggle claims to control iCloud sync but has no effect
  - Users believe they can disable sync when they cannot
  - AppStorage value never read by Core Data stack
root_cause: NSPersistentCloudKitContainer sync is mandatory/automatic; toggle was cosmetic only
solution: Replace fake toggle with read-only sync status display
files_affected:
  - ListAllMac/Views/MacSettingsView.swift
related: [macos-toolbar-sync-indicator.md, macos-cloudkit-sync-analysis.md, macos-settings-window-resizable.md]
---

## Problem

`MacSettingsView.swift` had misleading "Enable iCloud Sync" toggle:
1. Stored value in UserDefaults (`@AppStorage("iCloudSyncEnabled")`)
2. Never actually controlled sync behavior
3. Misled users into thinking they could disable iCloud sync

## Root Cause

iCloud sync via `NSPersistentCloudKitContainer` is **mandatory and automatic**. The toggle value was never read by Core Data stack.

## Solution

Replace toggle with read-only status:

**Before (problematic):**
```swift
private struct SyncSettingsTab: View {
    @AppStorage("iCloudSyncEnabled") private var iCloudSyncEnabled = true

    var body: some View {
        Form {
            Toggle("Enable iCloud Sync", isOn: $iCloudSyncEnabled)
        }
    }
}
```

**After (fixed):**
```swift
private struct SyncSettingsTab: View {
    var body: some View {
        Form {
            HStack {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.green)
                Text("iCloud Sync: Enabled")
                    .fontWeight(.medium)
            }
            Text("Your lists automatically sync across all your Apple devices...")
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
}
```

## Lesson Learned

When implementing settings UIs:
1. Verify toggles actually control the claimed feature
2. For mandatory features, use read-only status displays
3. Check what the underlying service supports before adding UI controls
