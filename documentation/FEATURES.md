# ListAll Features Reference

This document provides a comprehensive, LLM-friendly feature inventory for the ListAll application across all platforms (iOS, watchOS, macOS). Use this document for future multiplatform development decisions.

---

## Feature Parity Matrix

### Legend
- **iOS**: iPhone/iPad implementation
- **macOS**: Mac implementation
- **Shared**: Uses shared code (ViewModels/Services)
- **Platform-Specific**: Uses platform-native implementation

---

## 1. List Management Features

| Feature | iOS | macOS | Implementation |
|---------|-----|-------|----------------|
| Create List | Yes | Yes | Shared ViewModel |
| Edit List Name | Yes | Yes | Shared ViewModel |
| Delete List | Yes | Yes | Shared ViewModel |
| Archive List | Yes | Yes | Shared ViewModel |
| Restore Archived List | Yes | Yes | Shared ViewModel |
| Permanently Delete Archived | Yes | Yes | Shared ViewModel |
| Duplicate List | Yes | Yes | Shared ViewModel |
| Reorder Lists (drag-drop) | Yes | Yes | Platform UI |
| Multi-Select Lists | Yes | **MISSING** | iOS only |
| Bulk Archive/Delete | Yes | **MISSING** | iOS only |
| Sample List Templates | Yes | Yes | Shared Service |
| Active/Archived Toggle | Yes | Yes | Platform UI |
| List Item Count Display | Yes | Yes | Platform UI |

### List Management - iOS-Specific
```
- Swipe-to-archive gesture
- Swipe actions (Share, Duplicate, Edit)
- Pull-to-refresh
- Selection mode with checkboxes
- Bulk operations toolbar
```

### List Management - macOS-Specific
```
- Right-click context menu
- Keyboard navigation (arrow keys, Enter, Delete)
- Sidebar navigation pattern
- Menu bar commands (Cmd+Shift+N, Cmd+Delete)
```

---

## 2. Item Management Features

| Feature | iOS | macOS | Implementation |
|---------|-----|-------|----------------|
| Create Item | Yes | Yes | Shared ViewModel |
| Edit Item | Yes | Yes | Shared ViewModel |
| Delete Item | Yes | Yes | Shared ViewModel |
| Toggle Completion | Yes | Yes | Shared ViewModel |
| Item Title | Yes | Yes | Shared Model |
| Item Description | Yes | Yes | Shared Model |
| Item Quantity | Yes | Yes | Shared Model |
| Item Images (up to 10) | Yes | Yes | Shared Service |
| Duplicate Item | Yes | Yes | Shared ViewModel |
| Reorder Items (drag-drop) | Yes | Yes | Platform UI |
| Multi-Select Items | Yes | **MISSING** | iOS only |
| Move Items to Another List | Yes | **MISSING** | iOS only |
| Copy Items to Another List | Yes | **MISSING** | iOS only |
| Bulk Delete | Yes | **MISSING** | iOS only |
| Undo Complete (5 sec) | Yes | **MISSING** | iOS only |
| Undo Delete (5 sec) | Yes | **MISSING** | iOS only |
| Smart Suggestions | Yes | Yes | Shared Service |

### Item Management - iOS-Specific
```
- Swipe-to-delete gesture
- Swipe actions menu
- Tap to toggle completion
- Strikethrough animation
- Scale/opacity effects on completion
- Haptic feedback
- Selection checkboxes
- Move/Copy destination picker
```

### Item Management - macOS-Specific
```
- Double-click to edit
- Context menu (Edit, Toggle, Delete)
- Keyboard shortcuts (Space, Return, Delete, C)
- Hover action buttons
- Quick Look preview (Space key)
```

---

## 3. Filter, Sort & Search

| Feature | iOS | macOS | Implementation |
|---------|-----|-------|----------------|
| Sort by Order Number | Yes | Yes | Shared ViewModel |
| Sort by Title (A-Z/Z-A) | Yes | Yes | Shared ViewModel |
| Sort by Created Date | Yes | Yes | Shared ViewModel |
| Sort by Modified Date | Yes | Yes | Shared ViewModel |
| Sort by Quantity | Yes | Yes | Shared ViewModel |
| Sort Direction Toggle | Yes | Yes | Shared ViewModel |
| Filter: All Items | Yes | Yes | Shared ViewModel |
| Filter: Active Only | Yes | Yes | Shared ViewModel |
| Filter: Completed Only | Yes | Yes | Shared ViewModel |
| Filter: Has Description | Yes | Yes | Shared ViewModel |
| Filter: Has Images | Yes | **PARTIAL** | Shared ViewModel |
| Search (title + description) | Yes | Yes | Shared ViewModel |
| Persistent Preferences | Yes | Yes | Shared Repository |
| Active Filter Indicator | Yes | Yes | Platform UI |
| Drag-to-Reorder Indicator | Yes | Yes | Platform UI |

---

## 4. Image Features

| Feature | iOS | macOS | Implementation |
|---------|-----|-------|----------------|
| Add Images to Items | Yes | Yes | Platform-Specific |
| View Image Thumbnails | Yes | Yes | Shared Service |
| View Full-Screen Images | Yes | Yes | Platform-Specific |
| Delete Images | Yes | Yes | Shared Service |
| Reorder Images | Yes | Yes | Shared Service |
| Image Compression | Yes | Yes | Shared Service |
| Thumbnail Caching | Yes | Yes | Shared Service |
| Multi-Image Support (10 max) | Yes | Yes | Shared Model |
| Image Validation | Yes | Yes | Shared Service |
| Pinch-to-Zoom | Yes | **N/A** | iOS only |
| Quick Look Preview | **N/A** | Yes | macOS only |
| Drag-Drop Images | **N/A** | Yes | macOS only |
| Paste Images (Cmd+V) | **N/A** | Yes | macOS only |
| Multi-Select Images | **N/A** | Yes | macOS only |

### Image Features - iOS-Specific
```
- Camera capture (UIImagePickerController)
- Photo library picker (PHPickerViewController)
- Camera permission handling
- Pinch-to-zoom in viewer
- Double-tap zoom
- Swipe between images
```

### Image Features - macOS-Specific
```
- File picker for images
- Drag-and-drop from Finder
- Clipboard paste (Cmd+V)
- Quick Look panel (Space)
- Thumbnail size slider
- Multi-select with Cmd+click/Shift+click
- Copy to clipboard (Cmd+C)
```

---

## 5. Import/Export Features

| Feature | iOS | macOS | Implementation |
|---------|-----|-------|----------------|
| Export to JSON | Yes | Yes | Shared Service |
| Export to CSV | Yes | Yes | Shared Service |
| Export to Plain Text | Yes | Yes | Shared Service |
| Copy to Clipboard | Yes | Yes | Platform-Specific |
| Export to File | Yes | Yes | Platform-Specific |
| Import from JSON | Yes | Yes | Shared Service |
| Import from Plain Text | Yes | Yes | Shared Service |
| Import Preview | Yes | **MISSING** | iOS only |
| Import Strategy: Merge | Yes | Yes | Shared Service |
| Import Strategy: Replace | Yes | Yes | Shared Service |
| Import Strategy: Append | Yes | Yes | Shared Service |
| Import Progress | Yes | **MISSING** | iOS only |
| Export Options UI | Yes | Yes | Platform UI |
| Include Archived Lists | Yes | Yes | Shared Service |
| Include Images (base64) | Yes | Yes | Shared Service |

### Export - Platform Differences
```
iOS: UIActivityViewController (share sheet)
macOS: NSSavePanel + NSSharingServicePicker
```

---

## 6. Sharing Features

| Feature | iOS | macOS | Implementation |
|---------|-----|-------|----------------|
| Share List as Text | Yes | Yes | Shared Service |
| Share List as JSON | Yes | Yes | Shared Service |
| Share All Data | Yes | Yes | Shared Service |
| Copy to Clipboard | Yes | Yes | Platform-Specific |
| Format Picker UI | Yes | Yes | Platform UI |
| Options (crossed out, desc, qty, dates, images) | Yes | Yes | Shared Service |

### Sharing - Platform Differences
```
iOS: UIActivityViewController
macOS: NSSharingServicePicker with native services
```

---

## 7. Sync & Cloud Features

| Feature | iOS | macOS | Implementation |
|---------|-----|-------|----------------|
| iCloud Sync (CloudKit) | Yes | Yes | Shared Service |
| Multi-Device Sync | Yes | Yes | Shared Service |
| Sync Status Display | Yes | Yes | Platform UI |
| Manual Sync Button | Yes | Yes | Platform UI |
| Conflict Resolution | Yes | Yes | Shared Service |
| Offline Queue | Yes | Yes | Shared Service |
| Apple Watch Sync | Yes | **N/A** | iOS only |
| Handoff (iOS/macOS) | Yes | Yes | Shared Service |

---

## 8. Settings & Preferences

| Feature | iOS | macOS | Implementation |
|---------|-----|-------|----------------|
| App Language Selection | Yes | **MISSING** | iOS only |
| Default Sort Order | Yes | Yes | Shared Repository |
| Add Button Position | Yes | **N/A** | iOS only |
| Haptic Feedback Toggle | Yes | **N/A** | iOS only |
| Feature Tips Tracking | Yes | **MISSING** | iOS only |
| Reset Tips Button | Yes | **MISSING** | iOS only |
| Biometric Auth Toggle | Yes | **PARTIAL** | Platform-Specific |
| Auth Timeout Duration | Yes | **MISSING** | iOS only |
| Export Data Button | Yes | Yes | Platform UI |
| Import Data Button | Yes | Yes | Platform UI |
| App Version Display | Yes | Yes | Platform UI |

### Settings - iOS-Specific
```
- Add button position (left/right)
- Haptic feedback toggle
- Full biometric options (Face ID, Touch ID, Passcode)
- Auth timeout selection (immediate to 1 hour)
- Feature tips management
- Language picker with restart alert
```

### Settings - macOS-Specific
```
- Preferences window (Cmd+,)
- Tab-based layout (General, Sync, Data, About)
- Touch ID support only
- Website link
```

---

## 9. User Interface & Navigation

| Feature | iOS | macOS | Implementation |
|---------|-----|-------|----------------|
| Tab Bar Navigation | Yes | **N/A** | iOS only |
| NavigationSplitView | **N/A** | Yes | macOS only |
| Sidebar | **N/A** | Yes | macOS only |
| Pull-to-Refresh | Yes | **N/A** | iOS only |
| Swipe Actions | Yes | **N/A** | iOS only |
| Context Menus | Yes | Yes | Platform UI |
| Sheet Presentations | Yes | Yes | Platform-Specific |
| Alerts/Confirmations | Yes | Yes | Platform UI |
| Empty State Views | Yes | Yes | Platform UI |
| Loading Indicators | Yes | Yes | Platform UI |
| Haptic Feedback | Yes | **N/A** | iOS only |
| Keyboard Navigation | **PARTIAL** | Yes | macOS only |
| Menu Bar Commands | **N/A** | Yes | macOS only |
| Keyboard Shortcuts | **N/A** | Yes | macOS only |

---

## 10. macOS-Only Features

These features are available on macOS but not iOS:

| Feature | Description |
|---------|-------------|
| Menu Commands | File/Edit/Lists/View/Help menus |
| Keyboard Shortcuts | Cmd+N, Cmd+Shift+N, Cmd+R, Cmd+F, etc. |
| Services Menu | Add to ListAll from any app |
| Quick Look | Space key to preview images |
| Sidebar Navigation | Three-column layout |
| Focus States | Arrow key navigation |
| NSSharingServicePicker | Native macOS sharing |
| Multi-Window | Standard macOS window management |

---

## 11. iOS-Only Features

These features are available on iOS but not macOS:

| Feature | Description |
|---------|-------------|
| Swipe Actions | Swipe gestures on lists/items |
| Pull-to-Refresh | Drag down to refresh |
| Haptic Feedback | Tactile responses |
| Camera Capture | Direct camera access |
| Photo Library Picker | Native photo picker |
| Tab Bar | Bottom tab navigation |
| Apple Watch Sync | WatchConnectivity |
| Touch ID/Face ID/Passcode | Full biometric options |
| Auth Timeout | Multiple timeout options |
| Tooltip System | Contextual help tooltips |
| Feature Tips | Progressive feature discovery |

---

## 12. Accessibility Features

| Feature | iOS | macOS | Implementation |
|---------|-----|-------|----------------|
| VoiceOver Labels | Yes | Yes | Platform UI |
| VoiceOver Hints | Yes | Yes | Platform UI |
| VoiceOver Values | **PARTIAL** | Yes | Platform UI |
| VoiceOver Traits | **PARTIAL** | Yes | Platform UI |
| Keyboard Navigation | **PARTIAL** | Yes | macOS-focused |
| Dynamic Type | Yes | **N/A** | iOS only |
| Reduce Motion | Yes | **PARTIAL** | Platform UI |
| High Contrast | Yes | Yes | Platform UI |
| Dark Mode | Yes | Yes | Shared Assets |

---

## 13. Smart Suggestions (SuggestionService)

| Feature | iOS | macOS | Implementation |
|---------|-----|-------|----------------|
| Title Matching | Yes | Yes | Shared Service |
| Fuzzy Matching | Yes | Yes | Shared Service |
| Frequency Scoring | Yes | Yes | Shared Service |
| Recency Scoring | Yes | Yes | Shared Service |
| Combined Scoring | Yes | Yes | Shared Service |
| Cache (5 min TTL) | Yes | Yes | Shared Service |
| Cross-List Search | Yes | Yes | Shared Service |
| Exclude Current Item | Yes | Yes | Shared Service |
| Recent Items List | Yes | Yes | Shared Service |
| Suggestion UI | Yes | Yes | Platform UI |
| Collapse/Expand Toggle | Yes | Yes | Platform UI |
| Score Indicators | Yes | Yes | Platform UI |
| Hot Item Indicator | Yes | Yes | Platform UI |

---

## 14. Data Models (Shared)

All platforms share these Core Data models:

### List
```swift
- id: UUID
- name: String (max 100 chars)
- orderNumber: Int32
- isArchived: Bool
- createdAt: Date
- modifiedAt: Date
- items: [Item]
```

### Item
```swift
- id: UUID
- listId: UUID
- title: String (max 200 chars)
- itemDescription: String? (max 50KB)
- quantity: Int32 (min 1)
- isCrossedOut: Bool
- orderNumber: Int32
- createdAt: Date
- modifiedAt: Date
- images: [ItemImage]
```

### ItemImage
```swift
- id: UUID
- itemId: UUID
- imageData: Data (max 5MB, compressed)
- orderNumber: Int32
- createdAt: Date
```

### UserData
```swift
- userID: String
- lastSyncDate: Date?
- preferencesJSON: String
```

---

## 15. Feature Gap Summary

### HIGH Priority Gaps (macOS needs these)

1. **Multi-Select Mode for Lists** - iOS has selection mode with bulk actions
2. **Multi-Select Mode for Items** - iOS has selection mode for items
3. **Move Items Between Lists** - iOS has destination picker
4. **Copy Items Between Lists** - iOS has destination picker
5. **Undo Complete** - iOS has 5-second undo for toggled items
6. **Undo Delete** - iOS has 5-second undo for deleted items
7. **Import Preview Dialog** - iOS shows preview before import
8. **Import Progress UI** - iOS shows detailed progress

### MEDIUM Priority Gaps (macOS would benefit)

9. **Language Selection** - iOS has language picker
10. **Auth Timeout Options** - iOS has multiple timeout choices
11. **Feature Tips System** - iOS has contextual tooltips
12. **Filter: Has Images** - macOS filter implementation partial

### LOW Priority Gaps (iOS-specific patterns)

13. **Pull-to-Refresh** - macOS uses manual refresh
14. **Swipe Actions** - macOS uses context menus
15. **Haptic Feedback** - No Mac equivalent
16. **Tab Bar Navigation** - macOS uses sidebar

### macOS-Only Features (iOS would benefit)

17. **Keyboard Navigation** - Enhanced for desktop
18. **Quick Look** - Space to preview images
19. **Services Menu** - System-wide text capture
20. **Menu Bar Commands** - Full keyboard shortcuts

---

## Version History

| Version | Date | Changes |
|---------|------|---------|
| 1.0 | 2026-01-06 | Initial comprehensive feature inventory |

---

## Usage Notes for LLMs

When implementing new features:

1. **Check this matrix first** to understand platform parity
2. **Prioritize HIGH priority gaps** for better cross-platform experience
3. **Use shared ViewModels/Services** when possible (DRY principle)
4. **Create platform-specific UI** only when necessary
5. **Update this document** after implementing new features

When asked about features:

1. **Reference the feature tables** for quick answers
2. **Check "Implementation" column** to understand code location
3. **Note "Platform-Specific" items** require separate implementations
4. **Review gap summary** for feature parity discussions
