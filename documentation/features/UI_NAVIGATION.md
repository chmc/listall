# UI & Navigation Features

[< Back to Summary](./SUMMARY.md)

## Status: iOS 14/14 | macOS 10/14

---

## Feature Matrix

| Feature | iOS | macOS | Implementation |
|---------|:---:|:-----:|----------------|
| Tab Bar Navigation | ✅ | N/A | iOS only |
| NavigationSplitView | N/A | ✅ | macOS only |
| Sidebar | N/A | ✅ | macOS only |
| Pull-to-Refresh | ✅ | N/A | iOS only |
| Swipe Actions | ✅ | N/A | iOS only |
| Context Menus | ✅ | ✅ | Platform UI |
| Sheet Presentations | ✅ | ✅ | Platform-Specific |
| Alerts/Confirmations | ✅ | ✅ | Platform UI |
| Empty State Views | ✅ | ✅ | Platform UI |
| Loading Indicators | ✅ | ✅ | Platform UI |
| Haptic Feedback | ✅ | N/A | iOS only |
| Keyboard Navigation | ⚠️ | ✅ | macOS-focused |
| Menu Bar Commands | N/A | ✅ | macOS only |
| Keyboard Shortcuts | N/A | ✅ | macOS only |

---

## Platform Patterns

### iOS Patterns
- Tab Bar (bottom navigation)
- Pull-to-refresh
- Swipe gestures
- Haptic feedback
- Touch-first interactions

### macOS Patterns
- NavigationSplitView (three-column)
- Sidebar with lists
- Menu bar commands
- Keyboard shortcuts
- Focus states
- Multi-window support

---

## macOS Keyboard Shortcuts

| Shortcut | Action |
|----------|--------|
| Cmd+N | New Item |
| Cmd+Shift+N | New List |
| Cmd+R | Refresh |
| Cmd+F | Search |
| Cmd+Delete | Archive List |
| Cmd+D | Duplicate |
| Space | Quick Look |
| Return | Edit Item |
| Delete | Delete Item |

---

## Implementation Files

**iOS**:
- `Views/MainView.swift` - Tab bar
- `Views/ListView.swift` - Swipe actions

**macOS**:
- `ListAllMac/Views/MacMainView.swift` - NavigationSplitView
- `ListAllMac/Commands/AppCommands.swift` - Menu commands
