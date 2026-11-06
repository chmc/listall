# Item Management Features

[< Back to Summary](./SUMMARY.md)

## Status: iOS 19/19 | iPad 19/19 | macOS 17/18 | watchOS 4/5

*Count = ✅ / applicable rows (N/A excluded).*

---

## Feature Matrix

| Feature | iOS | iPad | macOS | watchOS | Implementation |
|---------|:---:|:----:|:-----:|:-------:|----------------|
| Create Item | ✅ | ✅ | ✅ | ❌ | Shared ViewModel; iPad also via toolbar button (`ListView.swift:325-335`) |
| Edit Item | ✅ | ✅ | ✅ | N/A | Shared ViewModel |
| Delete Item | ✅ | ✅ | ✅ | N/A | Shared ViewModel |
| Toggle Completion | ✅ | ✅ | ✅ | ✅ | Shared ViewModel; watch `WatchListView.swift:81-84` |
| Item Title | ✅ | ✅ | ✅ | ✅ | Shared Model; watch `WatchItemRowView.swift:24` |
| Item Description | ✅ | ✅ | ✅ | ✅ | Shared Model; watch shows it read-only (`WatchItemRowView.swift:38-42`) |
| Item Quantity | ✅ | ✅ | ✅ | ✅ | Shared Model; watch shows ×N (`WatchItemRowView.swift:30-33`) |
| Item Images (up to 10) | ✅ | ✅ | ⚠️ | N/A | See [IMAGES.md](./IMAGES.md): macOS has no per-item cap |
| Duplicate Item | ✅ | ✅ | ✅ | N/A | Shared ViewModel |
| Item Context Menu (Cross Out/Edit/Duplicate/Delete) | ✅ | ✅ | ✅ | N/A | iOS `ItemRowView.swift:141-157`; macOS Duplicate entry `MacMainView.swift:2698` |
| Leading Swipe: Edit / Duplicate | ✅ | ✅ | N/A | N/A | `ItemRowView.swift:160-175` (trailing swipe = Delete, `:177-184`) |
| Reorder Items (drag-drop) | ✅ | ✅ | ✅ | N/A | Platform UI |
| Multi-Select Items | ✅ | ✅ | ✅ | N/A | Shared ViewModel + Platform UI |
| Move Items to Another List | ✅ | ✅ | ✅ | N/A | Shared ViewModel + Platform Picker |
| Copy Items to Another List | ✅ | ✅ | ✅ | N/A | Shared ViewModel + Platform Picker |
| Bulk Delete | ✅ | ✅ | ✅ | N/A | Shared ViewModel + Platform UI |
| Undo Complete (5 sec) | ✅ | ✅ | ✅ | N/A | Shared ViewModel + macOS MacUndoBanner |
| Undo Delete (5 sec) | ✅ | ✅ | ✅ | N/A | Shared ViewModel + macOS MacDeleteUndoBanner |
| Smart Suggestions | ✅ | ✅ | ✅ | N/A | Shared Service |

---

## Gaps

- macOS: the 10-images-per-item limit is not enforced (see IMAGES.md).
- watchOS: cannot add items (e.g. by dictation); the watch only views and checks off items.

---

## iOS-Specific Patterns
- Swipe-to-delete gesture (trailing, full swipe)
- Leading swipe: Edit, Duplicate
- Long-press context menu: Cross Out / Mark Active, Edit, Duplicate, Delete
- Tap to toggle completion
- Strikethrough animation
- Scale/opacity effects on completion
- Haptic feedback
- Selection checkboxes
- Move/Copy destination picker

## iPad-Specific Patterns
- "Add Item" toolbar button replaces the floating add button in regular width (`ListView.swift:200`, `325-335`), Cmd+Shift+N
- Pointer hover effect on rows (`ItemRowView.swift:140`)

## macOS-Specific Patterns
- Double-click to edit
- Context menu (Edit, Toggle, Duplicate, Delete)
- Keyboard shortcuts (Space, Return, Delete, C)
- Hover action buttons
- Quick Look preview (Space key)
- Undo banners with material background (MacUndoBanner, MacDeleteUndoBanner)
- Selection mode with checkmark button
- Ellipsis menu for bulk actions (Move, Copy, Delete)
- MacDestinationListPickerSheet for destination selection

## watchOS Patterns
- Tap row to toggle completion with haptic and animation (`WatchListView.swift:81-84`)
- Active / completed / total counts above the list (`WatchListView.swift:102-144`)

---

## Implementation Files

**Shared**:
- `ViewModels/ListViewModel.swift` - Item CRUD
- `ViewModels/ItemViewModel.swift` - Item details
- `Services/DataRepository.swift` - Persistence

**iOS / iPad**:
- `Views/ListView.swift` - Item list
- `Views/Components/ItemRowView.swift` - Row with swipe actions and context menu
- `Views/Components/DestinationListPickerView.swift` - Move/Copy picker

**macOS**:
- `ListAllMac/Views/MacMainView.swift` - MacListDetailView, MacItemRowView
- `ListAllMac/Views/Components/MacDestinationListPickerSheet.swift` - Move/Copy destination picker

**watchOS**:
- `ListAllWatch Watch App/Views/WatchListView.swift`
- `ListAllWatch Watch App/Views/Components/WatchItemRowView.swift`
- `ListAllWatch Watch App/ViewModels/WatchListViewModel.swift`
