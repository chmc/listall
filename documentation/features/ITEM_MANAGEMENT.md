# Item Management Features

[< Back to Summary](./SUMMARY.md)

## Status: iOS 17/17 | macOS 11/17

---

## Feature Matrix

| Feature | iOS | macOS | Implementation |
|---------|:---:|:-----:|----------------|
| Create Item | ✅ | ✅ | Shared ViewModel |
| Edit Item | ✅ | ✅ | Shared ViewModel |
| Delete Item | ✅ | ✅ | Shared ViewModel |
| Toggle Completion | ✅ | ✅ | Shared ViewModel |
| Item Title | ✅ | ✅ | Shared Model |
| Item Description | ✅ | ✅ | Shared Model |
| Item Quantity | ✅ | ✅ | Shared Model |
| Item Images (up to 10) | ✅ | ✅ | Shared Service |
| Duplicate Item | ✅ | ✅ | Shared ViewModel |
| Reorder Items (drag-drop) | ✅ | ✅ | Platform UI |
| Multi-Select Items | ✅ | ❌ | iOS only |
| Move Items to Another List | ✅ | ❌ | iOS only |
| Copy Items to Another List | ✅ | ❌ | iOS only |
| Bulk Delete | ✅ | ❌ | iOS only |
| Undo Complete (5 sec) | ✅ | ❌ | iOS only |
| Undo Delete (5 sec) | ✅ | ❌ | iOS only |
| Smart Suggestions | ✅ | ✅ | Shared Service |

---

## Gaps (macOS)

| Feature | Priority | iOS Implementation | Notes |
|---------|:--------:|-------------------|-------|
| Multi-Select Items | HIGH | Selection checkboxes | Need macOS selection mode |
| Move Items Between Lists | HIGH | DestinationListPickerView | Need macOS destination picker |
| Copy Items Between Lists | HIGH | DestinationListPickerView | Share with Move |
| Bulk Delete | HIGH | Bulk operations toolbar | Depends on multi-select |
| Undo Complete | HIGH | 5-second undo banner | Need macOS undo UI |
| Undo Delete | HIGH | 5-second undo banner | Need macOS undo UI |

---

## iOS-Specific Patterns
- Swipe-to-delete gesture
- Swipe actions menu
- Tap to toggle completion
- Strikethrough animation
- Scale/opacity effects on completion
- Haptic feedback
- Selection checkboxes
- Move/Copy destination picker

## macOS-Specific Patterns
- Double-click to edit
- Context menu (Edit, Toggle, Delete)
- Keyboard shortcuts (Space, Return, Delete, C)
- Hover action buttons
- Quick Look preview (Space key)

---

## Implementation Files

**Shared**:
- `ViewModels/ListViewModel.swift` - Item CRUD
- `ViewModels/ItemViewModel.swift` - Item details
- `Services/DataRepository.swift` - Persistence

**iOS**:
- `Views/ListView.swift` - Item list
- `Views/Components/ItemRowView.swift` - Row with swipe
- `Views/Components/DestinationListPickerView.swift` - Move/Copy picker

**macOS**:
- `ListAllMac/Views/MacMainView.swift` - MacListDetailView, MacItemRowView
