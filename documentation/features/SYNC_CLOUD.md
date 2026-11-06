# Sync & Cloud Features

[< Back to Summary](./SUMMARY.md)

## Status: iOS 10/10 | iPad 9/9 | macOS 9/9 | watchOS 3/5

*Count = ✅ / applicable rows (N/A excluded).*

---

## Important Note

> iCloud sync is **mandatory and built-in** via NSPersistentCloudKitContainer on iOS/iPadOS and macOS (Release builds).
> There is no toggle to disable sync - all data automatically syncs across devices when signed into iCloud.
> The macOS Settings "Sync" tab shows read-only sync status information.
> **watchOS does not use CloudKit** (`CoreDataManager.swift:73`, `80-82`: plain `NSPersistentContainer`); the watch
> gets its data from the paired iPhone over WatchConnectivity.

---

## Feature Matrix

| Feature | iOS | iPad | macOS | watchOS | Implementation |
|---------|:---:|:----:|:-----:|:-------:|----------------|
| iCloud Sync (CloudKit) | ✅ | ✅ | ✅ | ❌ | NSPersistentCloudKitContainer; disabled on watchOS (`CoreDataManager.swift:80-82`) |
| Multi-Device Sync | ✅ | ✅ | ✅ | ⚠️ | Shared Service; watch only via its paired iPhone |
| Sync Status Display | ✅ | ✅ | ✅ | ✅ | Platform UI; watch "syncing from iPhone" pill (`WatchListsView.swift:35-55`) |
| Live Sync Status Indicator (animated sync button) | ✅ | ✅ | ✅ | N/A | iOS `MainView.swift:49-79` (shared toolbar, used by iPad); macOS `MacMainView.swift:91-108` |
| Sync Error Banner (iCloud export failure) | ✅ | ✅ | ✅ | N/A | `CloudKitService.shouldShowSyncErrorBanner` (`CloudKitService.swift:21`); iOS `SyncErrorBanner.swift`, `MainView.swift:465-475` (iPad overlay `MainView.swift:757-759`); macOS `MacSyncErrorBanner.swift`, `MacMainView.swift:222-231` |
| Manual Sync Button | ✅ | ✅ | ✅ | ✅ | Platform UI; watch pull-to-refresh + "Sync with iPhone" button (`WatchEmptyStateView.swift:37-48`) |
| Conflict Resolution | ✅ | ✅ | ✅ | N/A | Shared Service |
| Offline Queue | ✅ | ✅ | ✅ | N/A | Shared Service |
| Apple Watch Sync | ✅ | N/A | N/A | ✅ | WatchConnectivity (iPhone only; iPads cannot pair a watch) |
| Handoff (iOS/macOS) | ✅ | ✅ | ✅ | N/A | Shared Service |

---

## Gaps

- watchOS: no direct iCloud sync; lists only update while the paired iPhone sends them.

---

## Implementation Files

**Shared**:
- `Services/CloudKitService.swift` - Sync logic, sync error banner state
- `Services/HandoffService.swift` - Handoff
- `Models/CoreData/CoreDataManager.swift` - NSPersistentCloudKitContainer

**iOS + watchOS**:
- `Services/WatchConnectivityService.swift` - Watch sync. The iPhone sends its lists when the session activates,
  when the watch app is installed, and when the watch requests them (watch launch, pull-to-refresh,
  empty-state "Sync with iPhone" button). See ARCHITECTURE.md "Watch Initial Sync".

**iOS / iPad**:
- `Views/Components/SyncErrorBanner.swift`

**macOS**:
- `ListAllMac/Views/MacSettingsView.swift` - Sync status display (read-only)
- `ListAllMac/Views/Components/MacSyncErrorBanner.swift`
