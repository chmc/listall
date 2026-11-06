# List Management Features

[< Back to Summary](./SUMMARY.md)

## Status: iOS 14/16 | iPad 14/16 | macOS 16/16 | watchOS 1/2

*Count = ✅ / applicable rows (N/A excluded). iPad runs the iOS target (`ListAll/ListAll`) with size-class-specific layout; watchOS is `ListAll/ListAllWatch Watch App`.*

---

## Feature Matrix

| Feature | iOS | iPad | macOS | watchOS | Implementation |
|---------|:---:|:----:|:-----:|:-------:|----------------|
| Create List | ✅ | ✅ | ✅ | ❌ | Shared ViewModel (watch is read-only: lists come from iPhone) |
| Edit List Name | ✅ | ✅ | ✅ | N/A | Shared ViewModel |
| Delete List | ✅ | ✅ | ✅ | N/A | Shared ViewModel |
| Archive List | ✅ | ✅ | ✅ | N/A | Shared ViewModel |
| Restore Archived List | ✅ | ✅ | ✅ | N/A | Shared ViewModel + Platform UI |
| Permanently Delete Archived | ✅ | ✅ | ✅ | N/A | Shared ViewModel |
| Duplicate List | ✅ | ✅ | ✅ | N/A | Shared ViewModel; macOS Cmd+D handler `MacMainView.swift:308-310` |
| Reorder Lists (drag-drop) | ✅ | ✅ | ✅ | N/A | iPhone `MainView.swift:134`, iPad sidebar `MainView.swift:239` (`onMove`) |
| Multi-Select Lists | ✅ | ✅ | ✅ | N/A | Platform UI (iPad sidebar reuses `ListRowView`, `MainView.swift:225`) |
| Bulk Archive | ✅ | ✅ | ✅ | N/A | iOS "Delete Lists" menu item archives (`MainView.swift:411-414`, `702-708`) |
| Bulk Permanent Delete (active lists) | ❌ | ❌ | ✅ | N/A | macOS `MacMainView.swift:782-785`; iOS bulk "Delete Lists" archives instead |
| Sample List Templates (empty state) | ✅ | ✅ | ✅ | N/A | Shared `SampleDataService`; iOS `MainView.swift:105-108` |
| Template Picker in New List Sheet | ❌ | ❌ | ✅ | N/A | macOS `MacCreateListSheet` `MacMainView.swift:3680-3694`; iOS `CreateListView` has no templates |
| Active/Archived Toggle | ✅ | ✅ | ✅ | N/A | Platform UI; watch shows active lists only (`WatchMainViewModel.swift:219`) |
| List Item Count Display | ✅ | ✅ | ✅ | ✅ | Platform UI; watch `WatchListRowView.swift:16` |
| Archived Lists Read-Only | ✅ | ✅ | ✅ | N/A | Platform UI (read-only enforcement) |

---

## Gaps

- iOS/iPad: no permanent bulk delete of active lists (bulk action archives), no template picker in the Create List sheet.
- watchOS: cannot create lists (lists are created on iPhone and sent via WatchConnectivity).

---

## iOS-Specific Patterns
- Swipe-to-archive gesture
- Swipe actions (Share, Duplicate, Edit)
- Context menu (Edit, Share, Duplicate, Archive) - `ListRowView.swift:152-165`
- Pull-to-refresh
- Selection mode with checkboxes
- Bulk operations toolbar

## iPad-Specific Patterns
- Lists in the NavigationSplitView sidebar; selected list opens in the detail column (`ListRowView.swift:120-125`)
- Pointer hover effect on rows (`ListRowView.swift:150`)

## macOS-Specific Patterns
- Right-click context menu
- Keyboard navigation (arrow keys, Enter, Delete)
- Sidebar navigation pattern
- Menu bar commands (Cmd+Shift+N, Cmd+Delete, Cmd+D)
- Selection mode with pencil button, checkboxes, and ellipsis menu (Archive Lists / Delete Lists)
- Keyboard shortcuts: Escape (exit selection), Cmd+A (select all), Space (toggle selection)
- Template picker in New List sheet

## watchOS Patterns
- Read-only list browser (NavigationStack, `WatchListsView.swift:9`)

---

## Implementation Files

**Shared**:
- `ViewModels/MainViewModel.swift` - List CRUD operations
- `Services/DataRepository.swift` - Persistence layer
- `Services/SampleDataService.swift` - Templates

**iOS / iPad**:
- `Views/MainView.swift` - List display (iPhone `iPhoneBody`, iPad `iPadBody`)
- `Views/Components/ListRowView.swift` - Row with swipe actions and context menu

**macOS**:
- `ListAllMac/Views/MacMainView.swift` - Sidebar with lists, `MacCreateListSheet`

**watchOS**:
- `ListAllWatch Watch App/Views/WatchListsView.swift`
- `ListAllWatch Watch App/Views/Components/WatchListRowView.swift`
