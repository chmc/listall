# Sync & Cloud Features

[< Back to Summary](./SUMMARY.md)

## Status: iOS 8/8 | macOS 7/8

---

## Important Note

> iCloud sync is **mandatory and built-in** via NSPersistentCloudKitContainer.
> There is no toggle to disable sync - all data automatically syncs across devices when signed into iCloud.

---

## Feature Matrix

| Feature | iOS | macOS | Implementation |
|---------|:---:|:-----:|----------------|
| iCloud Sync (CloudKit) | ✅ | ✅ | NSPersistentCloudKitContainer |
| Multi-Device Sync | ✅ | ✅ | Shared Service |
| Sync Status Display | ✅ | ✅ | Platform UI |
| Manual Sync Button | ✅ | ✅ | Platform UI |
| Conflict Resolution | ✅ | ✅ | Shared Service |
| Offline Queue | ✅ | ✅ | Shared Service |
| Apple Watch Sync | ✅ | N/A | iOS only (WatchConnectivity) |
| Handoff (iOS/macOS) | ✅ | ✅ | Shared Service |

---

## Bug

| Issue | Location | Fix |
|-------|----------|-----|
| Remove iCloud Sync toggle | MacSettingsView.swift:80-98 | Delete SyncSettingsTab |

The toggle is misleading - sync is always on.

---

## Implementation Files

**Shared**:
- `Services/CloudKitService.swift` - Sync logic
- `Services/HandoffService.swift` - Handoff
- `Models/CoreData/CoreDataManager.swift` - NSPersistentCloudKitContainer

**iOS**:
- `Services/WatchConnectivityService.swift` - Watch sync
