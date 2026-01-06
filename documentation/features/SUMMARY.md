# ListAll Feature Status

> Quick scan for feature parity. Details in linked category files.

## Status Legend
- ✅ Done | ⚠️ Partial | ❌ Missing | N/A Not applicable

---

## Platform Overview

| Platform | Status | Core | Advanced |
|----------|:------:|:----:|:--------:|
| iOS | ✅ Live | 100% | 100% |
| macOS | ⚠️ Dev | 85% | 60% |

---

## Feature Categories

| Category | iOS | macOS | Gap | Details |
|----------|:---:|:-----:|:---:|---------|
| [List Management](#list-management) | 13/13 | 11/13 | 2 | [LIST_MANAGEMENT.md](./LIST_MANAGEMENT.md) |
| [Item Management](#item-management) | 17/17 | 11/17 | 6 | [ITEM_MANAGEMENT.md](./ITEM_MANAGEMENT.md) |
| [Filter/Sort/Search](#filter-sort-search) | 15/15 | 14/15 | 1 | [FILTER_SORT.md](./FILTER_SORT.md) |
| [Images](#images) | 14/14 | 13/14 | 1 | [IMAGES.md](./IMAGES.md) |
| [Import/Export](#import-export) | 15/15 | 13/15 | 2 | [IMPORT_EXPORT.md](./IMPORT_EXPORT.md) |
| [Sharing](#sharing) | 6/6 | 6/6 | 0 | [SHARING.md](./SHARING.md) |
| [Sync/Cloud](#sync-cloud) | 8/8 | 7/8 | 1 | [SYNC_CLOUD.md](./SYNC_CLOUD.md) |
| [Settings](#settings) | 11/11 | 5/11 | 6 | [SETTINGS.md](./SETTINGS.md) |
| [UI/Navigation](#ui-navigation) | 14/14 | 10/14 | 4 | [UI_NAVIGATION.md](./UI_NAVIGATION.md) |
| [Accessibility](#accessibility) | 9/9 | 7/9 | 2 | [ACCESSIBILITY.md](./ACCESSIBILITY.md) |
| [Smart Suggestions](#smart-suggestions) | 13/13 | 13/13 | 0 | [SUGGESTIONS.md](./SUGGESTIONS.md) |

---

## HIGH Priority Gaps (macOS)

| # | Feature | Category | Status |
|---|---------|----------|:------:|
| 1 | Multi-Select Lists | List Management | ❌ |
| 2 | Bulk Archive/Delete | List Management | ❌ |
| 3 | Multi-Select Items | Item Management | ❌ |
| 4 | Move Items Between Lists | Item Management | ❌ |
| 5 | Copy Items Between Lists | Item Management | ❌ |
| 6 | Bulk Delete Items | Item Management | ❌ |
| 7 | Undo Complete (5 sec) | Item Management | ❌ |
| 8 | Undo Delete (5 sec) | Item Management | ❌ |
| 9 | Import Preview | Import/Export | ❌ |
| 10 | Import Progress UI | Import/Export | ❌ |

---

## MEDIUM Priority Gaps (macOS)

| # | Feature | Category | Status |
|---|---------|----------|:------:|
| 11 | Filter: Has Images | Filter/Sort | ⚠️ |
| 12 | Language Selection | Settings | ❌ |
| 13 | Auth Timeout Options | Settings | ❌ |
| 14 | Feature Tips System | Settings | ❌ |
| 15 | Biometric Auth (full) | Settings | ⚠️ |

---

## BUGS

| Issue | Platform | Location |
|-------|----------|----------|
| Remove iCloud Sync toggle | macOS | MacSettingsView.swift:80-98 |

> iCloud sync is mandatory via NSPersistentCloudKitContainer - toggle is misleading.

---

## Quick Reference

### List Management
| Feature | iOS | macOS |
|---------|:---:|:-----:|
| Create/Edit/Delete List | ✅ | ✅ |
| Archive/Restore List | ✅ | ✅ |
| Duplicate List | ✅ | ✅ |
| Reorder Lists | ✅ | ✅ |
| Multi-Select Lists | ✅ | ❌ |
| Bulk Archive/Delete | ✅ | ❌ |

### Item Management
| Feature | iOS | macOS |
|---------|:---:|:-----:|
| Create/Edit/Delete Item | ✅ | ✅ |
| Toggle Completion | ✅ | ✅ |
| Item Images (up to 10) | ✅ | ✅ |
| Duplicate Item | ✅ | ✅ |
| Reorder Items | ✅ | ✅ |
| Multi-Select Items | ✅ | ❌ |
| Move/Copy to Other List | ✅ | ❌ |
| Undo Complete/Delete | ✅ | ❌ |

### Filter/Sort/Search
| Feature | iOS | macOS |
|---------|:---:|:-----:|
| Sort (5 options) | ✅ | ✅ |
| Filter (5 options) | ✅ | ⚠️ |
| Search | ✅ | ✅ |

### Import/Export
| Feature | iOS | macOS |
|---------|:---:|:-----:|
| Export JSON/CSV/Text | ✅ | ✅ |
| Import JSON/Text | ✅ | ✅ |
| Import Preview | ✅ | ❌ |
| Import Progress | ✅ | ❌ |

### Settings
| Feature | iOS | macOS |
|---------|:---:|:-----:|
| Default Sort Order | ✅ | ✅ |
| Biometric Auth | ✅ | ⚠️ |
| Language Selection | ✅ | ❌ |
| Auth Timeout | ✅ | ❌ |

---

## Data Models (Shared 100%)

```
List: id, name, orderNumber, isArchived, createdAt, modifiedAt, items[]
Item: id, listId, title, description, quantity, isCrossedOut, orderNumber, images[]
ItemImage: id, itemId, imageData, orderNumber, createdAt
UserData: userID, lastSyncDate, preferencesJSON
```

---

## Architecture

| Layer | Shared % | Notes |
|-------|:--------:|-------|
| Models | 100% | Core Data entities |
| Services | 95% | ImageService has platform code |
| ViewModels | 80% | WatchConnectivity iOS-only |
| Views | 0% | Platform-specific UI |

---

*Last updated: 2026-01-06*
