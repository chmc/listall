# Filter, Sort & Search Features

[< Back to Summary](./SUMMARY.md)

## Status: iOS 16/16 | iPad 16/16 | macOS 16/16 | watchOS 5/6

*Count = ✅ / applicable rows (N/A excluded).*

---

## Feature Matrix

| Feature | iOS | iPad | macOS | watchOS | Implementation |
|---------|:---:|:----:|:-----:|:-------:|----------------|
| Sort by Order Number | ✅ | ✅ | ✅ | N/A | Shared ViewModel; watch keeps the iPhone's display order (`WatchListViewModel.swift:125-128`) |
| Sort by Title (A-Z/Z-A) | ✅ | ✅ | ✅ | N/A | Shared ViewModel |
| Sort by Created Date | ✅ | ✅ | ✅ | N/A | Shared ViewModel |
| Sort by Modified Date | ✅ | ✅ | ✅ | N/A | Shared ViewModel |
| Sort by Quantity | ✅ | ✅ | ✅ | N/A | Shared ViewModel |
| Sort Direction Toggle | ✅ | ✅ | ✅ | N/A | Shared ViewModel |
| Filter: All Items | ✅ | ✅ | ✅ | ✅ | Shared ViewModel; watch `WatchFilterPicker.swift:25-27` |
| Filter: Active Only | ✅ | ✅ | ✅ | ✅ | Shared ViewModel; watch `WatchFilterPicker.swift:25-27` |
| Filter: Completed Only | ✅ | ✅ | ✅ | ✅ | Shared ViewModel; watch `WatchFilterPicker.swift:25-27` |
| Filter: Has Description | ✅ | ✅ | ✅ | ❌ | Watch view model supports it (`WatchListViewModel.swift:170`) but the picker only offers All/Active/Completed |
| Filter: Has Images | ✅ | ✅ | ✅ | N/A | Watch shows no images |
| Search (title + description) | ✅ | ✅ | ✅ | N/A | Shared ViewModel |
| Persistent Preferences | ✅ | ✅ | ✅ | ✅ | Shared Repository; watch per-list filter in UserDefaults (`WatchListViewModel.swift:177-197`) |
| Active Filter Indicator | ✅ | ✅ | ✅ | ✅ | Platform UI; watch picker shows selection + per-filter empty state (`WatchListView.swift:167-222`) |
| Drag-to-Reorder Indicator | ✅ | ✅ | ✅ | N/A | Platform UI |
| Reset / Clear All Filters | ✅ | ✅ | ✅ | N/A | iOS Reset button `ItemOrganizationView.swift:178-182`; macOS `MacMainView.swift:1709-1718` (Cmd+Shift+Delete) |

---

## Gaps

- watchOS: "Has Description" filter not offered in the picker.

---

## Enums (Shared)

```swift
enum ItemSortOption: String, Codable, CaseIterable {
    case orderNumber, title, createdAt, modifiedAt, quantity
}

enum ItemFilterOption: String, Codable, CaseIterable {
    case all, active, completed, hasDescription, hasImages
}

enum SortDirection: String, Codable {
    case ascending, descending
}
```

---

## Implementation Files

**Shared**:
- `ViewModels/ListViewModel.swift` - Filter/sort logic, `clearAllFilters()`
- `Models/Item.swift` - Enums defined here
- `Services/DataRepository.swift` - Preference persistence

**iOS / iPad**:
- `Views/Components/ItemOrganizationView.swift` - Filter/sort UI with Reset button

**macOS**:
- `ListAllMac/Views/Components/MacItemOrganizationView.swift` - Filter/sort popover

**watchOS**:
- `ListAllWatch Watch App/Views/Components/WatchFilterPicker.swift`
- `ListAllWatch Watch App/ViewModels/WatchListViewModel.swift`
