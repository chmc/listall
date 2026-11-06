# ListAll Feature Status

> Quick scan for feature parity. Details in linked category files.

## Status Legend
- ✅ Done | ⚠️ Partial | ❌ Missing | N/A Not applicable

---

## Platform Overview

| Platform | Status | Target | Done |
|----------|:------:|--------|:----:|
| iOS (iPhone) | ✅ Live | `ListAll` (compact width: NavigationStack + bottom toolbar) | 128/140 |
| iPad | ✅ Live | `ListAll` (regular width: NavigationSplitView, keyboard shortcuts, hover effects) | 129/143 |
| macOS | ✅ Live | `ListAllMac` | 131/138 |
| watchOS | ✅ Live | `ListAllWatch Watch App` (companion: browse lists, check off items, filter) | 22/30 |

Counts are ✅ / applicable rows (N/A excluded); ⚠️ and ❌ count as not done.

> **Note**: iPhone, iPad and macOS cover the full list/item feature set. Remaining gaps are mostly accessibility
> (no Reduce Motion support anywhere, few VoiceOver values/traits on iOS) and a few platform-specific options
> (see "Open Gaps"). The watch app is a deliberately small companion; most rows are N/A there.

---

## Feature Categories

| Category | iOS | iPad | macOS | watchOS | Gap rows* | Details |
|----------|:---:|:----:|:-----:|:-------:|:---:|---------|
| [List Management](#list-management) | 14/16 | 14/16 | 16/16 | 1/2 | 3 | [LIST_MANAGEMENT.md](./LIST_MANAGEMENT.md) |
| [Item Management](#item-management) | 19/19 | 19/19 | 17/18 | 4/5 | 2 | [ITEM_MANAGEMENT.md](./ITEM_MANAGEMENT.md) |
| [Filter/Sort/Search](#filtersortsearch) | 16/16 | 16/16 | 16/16 | 5/6 | 1 | [FILTER_SORT.md](./FILTER_SORT.md) |
| Images | 11/11 | 11/11 | 13/15 | N/A | 2 | [IMAGES.md](./IMAGES.md) |
| [Import/Export](#importexport) | 15/15 | 15/15 | 14/15 | N/A | 1 | [IMPORT_EXPORT.md](./IMPORT_EXPORT.md) |
| Sharing | 6/7 | 6/7 | 7/7 | N/A | 1 | [SHARING.md](./SHARING.md) |
| Sync/Cloud | 10/10 | 9/9 | 9/9 | 3/5 | 2 | [SYNC_CLOUD.md](./SYNC_CLOUD.md) |
| [Settings](#settings) | 12/13 | 11/14 | 10/11 | N/A | 3 | [SETTINGS.md](./SETTINGS.md) |
| UI/Navigation | 10/11 | 13/14 | 10/10 | 5/5 | 1 | [UI_NAVIGATION.md](./UI_NAVIGATION.md) |
| Accessibility | 2/9 | 2/9 | 6/8 | 4/7 | 7 | [ACCESSIBILITY.md](./ACCESSIBILITY.md) |
| Smart Suggestions | 13/13 | 13/13 | 13/13 | N/A | 0 | [SUGGESTIONS.md](./SUGGESTIONS.md) |

*Gap rows = feature rows with ❌ or ⚠️ on at least one platform (N/A excluded)

---

## Open Gaps

| Feature | Category | iOS | iPad | macOS | watchOS |
|---------|----------|:---:|:----:|:-----:|:-------:|
| Default Sort Order setting has no effect (value never read) | Settings | ⚠️ | ⚠️ | ⚠️ | N/A |
| Add Button Position setting has no effect on iPad | Settings | ✅ | ⚠️ | N/A | N/A |
| Bulk permanent delete of active lists | List Management | ❌ | ❌ | ✅ | N/A |
| Template picker in New List sheet | List Management | ❌ | ❌ | ✅ | N/A |
| Share single list as CSV | Sharing | ❌ | ❌ | ✅ | N/A |
| CSV in "Export All Lists" | Import/Export | ✅ | ✅ | ⚠️ | N/A |
| 10-images-per-item limit (enforced + shown) | Images | ✅ | ✅ | ❌ | N/A |
| Reduce Motion support | Accessibility | ❌ | ❌ | ❌ | ❌ |
| VoiceOver values | Accessibility | ❌ | ❌ | ✅ | ❌ |
| iCloud sync on the watch (CloudKit disabled) | Sync/Cloud | ✅ | ✅ | ✅ | ❌ |
| Create items / lists on the watch | Item / List Management | ✅ | ✅ | ✅ | ❌ |

## Added Since 2026-01-20

| Feature | Platforms | Category |
|---------|-----------|----------|
| NavigationSplitView two-column layout, Settings in detail column, Add Item toolbar button | iPad | UI/Navigation, Settings |
| Keyboard shortcuts (Cmd+N, Cmd+Shift+N, Cmd+R, Cmd+Shift+A) and pointer hover effects | iPad | UI/Navigation |
| List and item context menus | iOS, iPad | UI/Navigation, Item Management |
| Leading swipe actions Edit / Duplicate on items | iOS, iPad | Item Management |
| Animated live sync status indicator | iOS, iPad | Sync/Cloud |
| Sync error banner when iCloud export fails | iOS, iPad, macOS | Sync/Cloud |
| Default sort order picker (stored only, see Open Gaps) | iOS, iPad | Settings |
| Reset button in sort/filter view | iOS, iPad | Filter/Sort |
| Explicit 10-image limit UI | iOS, iPad | Images |
| Template picker in New List sheet, Duplicate in item context menu, Cmd+D duplicate list | macOS | List / Item Management |
| CSV format when sharing a list, bulk delete for active lists | macOS | Sharing, List Management |
| Collapsible image section with thumbnails in the edit sheet | macOS | Images |
| Creator info in About | iOS, iPad, macOS | Settings |
| Finnish feature tip translations | iOS, iPad, macOS | Settings |
| iPhone sends lists to the watch on launch, install and request; "Sync with iPhone" button | iOS, watchOS | Sync/Cloud |

### Completed Gaps (Historical, macOS)

| # | Feature | Category | Status |
|---|---------|----------|:------:|
| 1 | Restore Archived List UI | List Management | ✅ |
| 2 | Archived Lists Read-Only | List Management | ✅ |
| 3 | Multi-Select Lists | List Management | ✅ |
| 4 | Bulk Archive/Delete | List Management | ✅ |
| 5 | Multi-Select Items | Item Management | ✅ |
| 6 | Move Items Between Lists | Item Management | ✅ |
| 7 | Copy Items Between Lists | Item Management | ✅ |
| 8 | Bulk Delete Items | Item Management | ✅ |
| 9 | Undo Complete (5 sec) | Item Management | ✅ |
| 10 | Undo Delete (5 sec) | Item Management | ✅ |
| 11 | Import Preview | Import/Export | ✅ |
| 12 | Import Progress UI | Import/Export | ✅ |
| 13 | Filter: Has Images | Filter/Sort | ✅ |
| 14 | Feature Tips System | Settings | ✅ |

The completed 2026-01 verification plan is archived at [`../archive/FEATURE_PARITY.md`](../archive/FEATURE_PARITY.md).

---

## Quick Reference

### List Management
| Feature | iOS | iPad | macOS | watchOS |
|---------|:---:|:----:|:-----:|:-------:|
| Create/Edit/Delete List | ✅ | ✅ | ✅ | ❌ (view only) |
| Archive List | ✅ | ✅ | ✅ | N/A |
| Restore Archived List | ✅ | ✅ | ✅ | N/A |
| Archived Lists Read-Only | ✅ | ✅ | ✅ | N/A |
| Duplicate List | ✅ | ✅ | ✅ | N/A |
| Reorder Lists | ✅ | ✅ | ✅ | N/A |
| Multi-Select Lists | ✅ | ✅ | ✅ | N/A |
| Bulk Archive | ✅ | ✅ | ✅ | N/A |
| Bulk Permanent Delete | ❌ | ❌ | ✅ | N/A |

### Item Management
| Feature | iOS | iPad | macOS | watchOS |
|---------|:---:|:----:|:-----:|:-------:|
| Create/Edit/Delete Item | ✅ | ✅ | ✅ | ❌ (view only) |
| Toggle Completion | ✅ | ✅ | ✅ | ✅ |
| Item Images (up to 10) | ✅ | ✅ | ⚠️ | N/A |
| Duplicate Item | ✅ | ✅ | ✅ | N/A |
| Reorder Items | ✅ | ✅ | ✅ | N/A |
| Multi-Select Items | ✅ | ✅ | ✅ | N/A |
| Move/Copy to Other List | ✅ | ✅ | ✅ | N/A |
| Undo Complete/Delete | ✅ | ✅ | ✅ | N/A |

### Filter/Sort/Search
| Feature | iOS | iPad | macOS | watchOS |
|---------|:---:|:----:|:-----:|:-------:|
| Sort (5 options) | ✅ | ✅ | ✅ | N/A (iPhone order) |
| Filter (5 options) | ✅ | ✅ | ✅ | ⚠️ (3 of 4 applicable) |
| Search | ✅ | ✅ | ✅ | N/A |
| Reset / Clear Filters | ✅ | ✅ | ✅ | N/A |

### Import/Export
| Feature | iOS | iPad | macOS | watchOS |
|---------|:---:|:----:|:-----:|:-------:|
| Export JSON/CSV/Text | ✅ | ✅ | ⚠️ (no CSV in Export All) | N/A |
| Import JSON/Text | ✅ | ✅ | ✅ | N/A |
| Import Preview | ✅ | ✅ | ✅ | N/A |
| Import Progress | ✅ | ✅ | ✅ | N/A |

### Settings
| Feature | iOS | iPad | macOS | watchOS |
|---------|:---:|:----:|:-----:|:-------:|
| Default Sort Order | ⚠️ | ⚠️ | ⚠️ | N/A |
| Biometric Auth | ✅ | ✅ | ✅ | N/A |
| Language Selection | ✅ | ✅ | ✅ | N/A (follows iPhone) |
| Auth Timeout | ✅ | ✅ | ✅ | N/A |

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
| Models | 100% | Core Data entities (CloudKit disabled on watchOS) |
| Services | 95% | ImageService has platform code |
| ViewModels | 80% | WatchConnectivity iOS/watchOS only; watch has its own view models |
| Views | 0% | Platform-specific UI; iPhone and iPad share views with size-class branches |

---

*Last updated: 2026-11-06*
