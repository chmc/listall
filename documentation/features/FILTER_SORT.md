# Filter, Sort & Search Features

[< Back to Summary](./SUMMARY.md)

## Status: iOS 15/15 | macOS 14/15

---

## Feature Matrix

| Feature | iOS | macOS | Implementation |
|---------|:---:|:-----:|----------------|
| Sort by Order Number | ✅ | ✅ | Shared ViewModel |
| Sort by Title (A-Z/Z-A) | ✅ | ✅ | Shared ViewModel |
| Sort by Created Date | ✅ | ✅ | Shared ViewModel |
| Sort by Modified Date | ✅ | ✅ | Shared ViewModel |
| Sort by Quantity | ✅ | ✅ | Shared ViewModel |
| Sort Direction Toggle | ✅ | ✅ | Shared ViewModel |
| Filter: All Items | ✅ | ✅ | Shared ViewModel |
| Filter: Active Only | ✅ | ✅ | Shared ViewModel |
| Filter: Completed Only | ✅ | ✅ | Shared ViewModel |
| Filter: Has Description | ✅ | ✅ | Shared ViewModel |
| Filter: Has Images | ✅ | ⚠️ | Shared ViewModel |
| Search (title + description) | ✅ | ✅ | Shared ViewModel |
| Persistent Preferences | ✅ | ✅ | Shared Repository |
| Active Filter Indicator | ✅ | ✅ | Platform UI |
| Drag-to-Reorder Indicator | ✅ | ✅ | Platform UI |

---

## Gaps (macOS)

| Feature | Priority | Status | Notes |
|---------|:--------:|:------:|-------|
| Filter: Has Images | MEDIUM | ⚠️ Partial | UI exists, logic incomplete |

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
- `ViewModels/ListViewModel.swift` - Filter/sort logic
- `Models/Item.swift` - Enums defined here
- `Services/DataRepository.swift` - Preference persistence

**iOS**:
- `Views/Components/ItemOrganizationView.swift` - Filter/sort UI

**macOS**:
- `ListAllMac/Views/Components/MacItemOrganizationView.swift` - Filter/sort popover
