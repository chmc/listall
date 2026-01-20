# List Management Features

[< Back to Summary](./SUMMARY.md)

## Status: iOS 14/14 | macOS 12/14

---

## Feature Matrix

| Feature | iOS | macOS | Implementation |
|---------|:---:|:-----:|----------------|
| Create List | ✅ | ✅ | Shared ViewModel |
| Edit List Name | ✅ | ✅ | Shared ViewModel |
| Delete List | ✅ | ✅ | Shared ViewModel |
| Archive List | ✅ | ✅ | Shared ViewModel |
| Restore Archived List | ✅ | ⚠️ | Backend exists, macOS UI missing |
| Permanently Delete Archived | ✅ | ✅ | Shared ViewModel |
| Duplicate List | ✅ | ✅ | Shared ViewModel |
| Reorder Lists (drag-drop) | ✅ | ✅ | Platform UI |
| Multi-Select Lists | ✅ | ✅ | Platform UI |
| Bulk Archive/Delete | ✅ | ✅ | Platform UI |
| Sample List Templates | ✅ | ✅ | Shared Service |
| Active/Archived Toggle | ✅ | ✅ | Platform UI |
| List Item Count Display | ✅ | ✅ | Platform UI |
| Archived Lists Read-Only | ✅ | ❌ | iOS: ArchivedListView, macOS: missing |

---

## Gaps (macOS)

| Gap | Priority | Issue |
|-----|:--------:|-------|
| Restore Archived List UI | CRITICAL | No restore button in context menu or toolbar |
| Archived Lists Read-Only | CRITICAL | Archived lists are fully editable (should be read-only) |

**Details**:
- **Restore**: Backend `restoreList(withId:)` exists in CoreDataManager but macOS has no UI to invoke it
- **Read-Only**: iOS uses dedicated `ArchivedListView` with `ArchivedItemRowView` (no editing). macOS uses same view for both active and archived lists, allowing full editing.

---

## iOS-Specific Patterns
- Swipe-to-archive gesture
- Swipe actions (Share, Duplicate, Edit)
- Pull-to-refresh
- Selection mode with checkboxes
- Bulk operations toolbar

## macOS-Specific Patterns
- Right-click context menu
- Keyboard navigation (arrow keys, Enter, Delete)
- Sidebar navigation pattern
- Menu bar commands (Cmd+Shift+N, Cmd+Delete)
- Selection mode with pencil button, checkboxes, and ellipsis menu
- Keyboard shortcuts: Escape (exit selection), Cmd+A (select all), Space (toggle selection)

---

## Implementation Files

**Shared**:
- `ViewModels/MainViewModel.swift` - List CRUD operations
- `Services/DataRepository.swift` - Persistence layer
- `Services/SampleDataService.swift` - Templates

**iOS**:
- `Views/MainView.swift` - List display
- `Views/Components/ListRowView.swift` - Row with swipe actions

**macOS**:
- `ListAllMac/Views/MacMainView.swift` - Sidebar with lists
