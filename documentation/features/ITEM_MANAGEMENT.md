# Item Management Features

[< Back to Summary](./SUMMARY.md)

## Status: iOS 17/17 | macOS 17/17

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
| Multi-Select Items | ✅ | ✅ | Shared ViewModel + Platform UI |
| Move Items to Another List | ✅ | ✅ | Shared ViewModel + Platform Picker |
| Copy Items to Another List | ✅ | ✅ | Shared ViewModel + Platform Picker |
| Bulk Delete | ✅ | ✅ | Shared ViewModel + Platform UI |
| Undo Complete (5 sec) | ✅ | ✅ | Shared ViewModel + macOS MacUndoBanner |
| Undo Delete (5 sec) | ✅ | ✅ | Shared ViewModel + macOS MacDeleteUndoBanner |
| Smart Suggestions | ✅ | ✅ | Shared Service |

---

## Gaps (macOS)

*No remaining gaps - full feature parity achieved!*

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
- Undo banners with material background (MacUndoBanner, MacDeleteUndoBanner)
- Selection mode with checkmark button
- Ellipsis menu for bulk actions (Move, Copy, Delete)
- MacDestinationListPickerSheet for destination selection

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
- `ListAllMac/Views/Components/MacDestinationListPickerSheet.swift` - Move/Copy destination picker
