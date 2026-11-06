# UI & Navigation Features

[< Back to Summary](./SUMMARY.md)

## Status: iOS 10/11 | iPad 13/14 | macOS 10/10 | watchOS 5/5

*Count = ✅ / applicable rows (N/A excluded). Platform-specific navigation patterns are N/A elsewhere.*

---

## Feature Matrix

| Feature | iOS | iPad | macOS | watchOS | Implementation |
|---------|:---:|:----:|:-----:|:-------:|----------------|
| Bottom Toolbar (Lists / Settings) | ✅ | N/A | N/A | N/A | `CustomBottomToolbar`, iPhone only (`MainView.swift:482-496`); iPad uses a sidebar Settings row |
| NavigationStack | ✅ | N/A | N/A | ✅ | iPhone `MainView.swift:765`; watch `WatchListsView.swift:9` |
| NavigationSplitView (two-column) | N/A | ✅ | ✅ | N/A | iPad `MainView.swift:730-760` (selected by `horizontalSizeClass == .regular`, `MainView.swift:45-47`, `503-506`) |
| Sidebar | N/A | ✅ | ✅ | N/A | iPad `sidebarContent` `MainView.swift:187` |
| Settings in Detail Column | N/A | ✅ | N/A | N/A | `MainView.swift:242-249`, `271-272` |
| Add Item Toolbar Button | N/A | ✅ | N/A | N/A | `ListView.swift:325-335` (iPhone uses the floating button) |
| Pull-to-Refresh | ✅ | ✅ | N/A | ✅ | `.refreshable` `MainView.swift:141`, `261`; watch `WatchPullToRefreshView.swift` |
| Swipe Actions | ✅ | ✅ | N/A | N/A | `ListRowView.swift:168-195`, `ItemRowView.swift:160-184` |
| Context Menus | ✅ | ✅ | ✅ | N/A | `ListRowView.swift:152-165`, `ItemRowView.swift:141-157` |
| Sheet Presentations | ✅ | ✅ | ✅ | N/A | Platform-Specific |
| Alerts/Confirmations | ✅ | ✅ | ✅ | N/A | Platform UI |
| Empty State Views | ✅ | ✅ | ✅ | ✅ | Platform UI; watch `WatchEmptyStateView.swift`, `WatchListView.swift:147-163` |
| Loading Indicators | ✅ | ✅ | ✅ | ✅ | Platform UI; watch `WatchLoadingView.swift` |
| Haptic Feedback | ✅ | N/A | N/A | ✅ | iOS `HapticManager`; watch `WatchHapticManager.swift` (iPads have no haptic hardware) |
| Keyboard Navigation | ⚠️ | ⚠️ | ✅ | N/A | macOS-focused |
| Menu Bar Commands | N/A | N/A | ✅ | N/A | macOS only |
| Keyboard Shortcuts | N/A | ✅ | ✅ | N/A | iPad: 4 shortcuts (table below) |
| Pointer / Trackpad Hover Effects | N/A | ✅ | N/A | N/A | `.hoverEffect` in `ListRowView.swift:150`, `ItemRowView.swift:140`, `MainView.swift:319`, `ListView.swift:644`, `SettingsView.swift:164` |

---

## Platform Patterns

### iPhone Patterns
- Custom bottom toolbar (Lists / Settings)
- NavigationStack push navigation
- Pull-to-refresh
- Swipe gestures
- Long-press context menus
- Haptic feedback
- Touch-first interactions

### iPad Patterns
- NavigationSplitView: lists in the sidebar, list or Settings in the detail column
- Add Item toolbar button
- Hardware-keyboard shortcuts
- Pointer hover effects (`.highlight` on buttons, `.lift` on rows)

### macOS Patterns
- NavigationSplitView (three-column)
- Sidebar with lists
- Menu bar commands
- Keyboard shortcuts
- Focus states
- Multi-window support

### watchOS Patterns
- NavigationStack: lists → items
- Custom pull-to-refresh, "syncing from iPhone" indicator
- Haptics for toggle, filter change and refresh

---

## iPad Keyboard Shortcuts

| Shortcut | Action | Code |
|----------|--------|------|
| Cmd+N | New List | `MainView.swift:435` |
| Cmd+Shift+N | New Item | `ListView.swift:334`, `647` |
| Cmd+R | Sync / Refresh | `MainView.swift:351` |
| Cmd+Shift+A | Toggle Archived Lists | `MainView.swift:320` |

## macOS Keyboard Shortcuts

| Shortcut | Action |
|----------|--------|
| Cmd+N | New Item |
| Cmd+Shift+N | New List |
| Cmd+Option+Space | Quick Entry |
| Cmd+R | Refresh |
| Cmd+F | Search |
| Cmd+1 | Filter: All Items |
| Cmd+2 | Filter: Active Only |
| Cmd+3 | Filter: Completed Only |
| Cmd+Delete | Archive List |
| Cmd+D | Duplicate |
| Space | Quick Look |
| Return | Edit Item |
| Delete | Delete Item |

---

## Implementation Files

**iOS / iPad**:
- `Views/MainView.swift` - `iPhoneBody` (NavigationStack + bottom toolbar), `iPadBody` (NavigationSplitView)
- `Views/ListView.swift` - Item list, iPad toolbar button
- `Views/Components/ListRowView.swift`, `ItemRowView.swift` - Swipe actions, context menus

**macOS**:
- `ListAllMac/Views/MacMainView.swift` - NavigationSplitView
- `ListAllMac/Commands/AppCommands.swift` - Menu commands

**watchOS**:
- `ListAllWatch Watch App/Views/WatchListsView.swift`, `WatchListView.swift`
- `ListAllWatch Watch App/Views/Components/WatchPullToRefreshView.swift`
