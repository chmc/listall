# macOS Settings: iCloud Sync Toggle Bug Fix

## Date: 2026-01-07

## Problem

The `MacSettingsView.swift` had a misleading "Enable iCloud Sync" toggle that:
1. Stored a value in UserDefaults (`@AppStorage("iCloudSyncEnabled")`)
2. Never actually controlled sync behavior
3. Misled users into thinking they could disable iCloud sync

## Root Cause

iCloud sync via `NSPersistentCloudKitContainer` is **mandatory and automatic**. The toggle value was never read by the Core Data stack, making it purely cosmetic and deceptive.

## Solution

Replaced the toggle with read-only sync status information:
- Shows "iCloud Sync: Enabled" with green checkmark
- Explains that sync is automatic across all Apple devices
- Removed the `@AppStorage("iCloudSyncEnabled")` property

## Code Changes

**Before (problematic):**
```swift
private struct SyncSettingsTab: View {
    @AppStorage("iCloudSyncEnabled") private var iCloudSyncEnabled = true

    var body: some View {
        Form {
            Section {
                Toggle("Enable iCloud Sync", isOn: $iCloudSyncEnabled)
                // ... misleading toggle
            }
        }
    }
}
```

**After (fixed):**
```swift
private struct SyncSettingsTab: View {
    var body: some View {
        Form {
            Section {
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
}
```

## Additional Features Added

While fixing the bug, also added missing Settings features:

1. **Language Selection** in General tab
   - Uses `LocalizationManager.AppLanguage.allCases`
   - Shows flag emoji + native name
   - Shows restart alert after change

2. **Security tab** with Auth Timeout Options
   - Uses `MacBiometricAuthService.shared` for Touch ID detection
   - Toggle for "Require Touch ID"
   - Picker with `Constants.AuthTimeoutDuration.allCases`

## Lesson Learned

When implementing settings UIs:
1. Verify that toggles actually control the feature they claim to
2. For mandatory features, use read-only status displays instead of fake toggles
3. Always check what the underlying service actually supports before adding UI controls
