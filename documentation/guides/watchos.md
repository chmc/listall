# ListAll - watchOS Companion App Architecture

## Overview

The watchOS companion app for ListAll provides quick access to lists and items directly from the Apple Watch. The app focuses on essential features for on-the-go list management: viewing lists, checking items, and marking items as complete.

## Target Audience

Users who want to:
- Quickly check their shopping lists while shopping
- Mark items as complete without pulling out their phone
- View their todo lists on their wrist
- Keep lists synced between iPhone and Apple Watch

## Core Features (MVP)

### 1. Lists View
- Display all active (non-archived) lists
- Show list name and item counts (active/completed)
- Navigate to list detail view
- Pull-to-refresh for manual sync

### 2. List Detail View
- Display all items in a list
- Show item title and completion status
- Display quantity if > 1
- Tap item to toggle completion
- Visual styling for completed items (strikethrough, reduced opacity)

### 3. Item Filtering
- Filter items by status:
  - **All Items**: Show all items
  - **Active Only**: Show non-completed items
  - **Completed Only**: Show crossed-out items
- Persist filter preference per list
- Update counts based on active filter

### 4. Data Synchronization
- Real-time sync via CloudKit
- Changes on iOS appear on watchOS
- Changes on watchOS appear on iOS
- Offline support with automatic sync when online

## Technical Architecture

### Platform Requirements
- **watchOS Version**: 9.0+ (for optimal SwiftUI support)
- **Xcode Version**: 15.0+
- **Swift Version**: 5.9+

### Project Structure

```
ListAll (iOS)
├── Models/              [SHARED with watchOS]
│   ├── List.swift
│   ├── Item.swift
│   ├── ItemImage.swift
│   └── UserData.swift
├── CoreData/            [SHARED with watchOS]
│   ├── ListAll.xcdatamodeld
│   ├── CoreDataManager.swift
│   ├── ListEntity+Extensions.swift
│   ├── ItemEntity+Extensions.swift
│   └── UserDataEntity+Extensions.swift
├── Services/            [SHARED with watchOS]
│   ├── DataRepository.swift
│   └── CloudKitService.swift
├── ViewModels/          [SHARED with watchOS - selected]
│   ├── MainViewModel.swift
│   └── ListViewModel.swift
└── Views/               [iOS-specific]

ListAll Watch App
├── Views/               [watchOS-specific]
│   ├── WatchListsView.swift
│   ├── WatchListRowView.swift
│   ├── WatchListView.swift
│   ├── WatchItemRowView.swift
│   └── Components/
│       ├── WatchEmptyStateView.swift
│       └── WatchFilterPickerView.swift
├── ViewModels/          [watchOS-specific if needed]
│   └── WatchListViewModel.swift (optional, may reuse iOS version)
├── Utils/               [watchOS-specific]
│   ├── WatchTheme.swift
│   └── WatchConstants.swift
└── Resources/
    └── Assets.xcassets
```

## Data Layer

### Shared Components

The watchOS app shares the core data layer with iOS:

1. **Data Models**: All Swift model structs (List, Item, ItemImage, UserData)
2. **Core Data Stack**: CoreDataManager and entity extensions
3. **CloudKit Service**: CloudKitService for synchronization
4. **Data Repository**: DataRepository for CRUD operations

### Data Synchronization Strategy

**Primary Sync Method**: CloudKit + NSPersistentCloudKitContainer

- Both iOS and watchOS apps use the same CloudKit container
- NSPersistentCloudKitContainer handles automatic sync
- Changes are pushed to CloudKit immediately (when online)
- Changes are pulled from CloudKit automatically
- Conflict resolution: Last-write-wins based on modifiedAt timestamp

**Sync Flow**:
```
1. User makes change on watchOS
   ↓
2. Core Data saves change locally
   ↓
3. NSPersistentCloudKitContainer uploads to CloudKit
   ↓
4. CloudKit notifies iOS app of change
   ↓
5. iOS app downloads and merges change
```

**Alternative/Complementary**: WatchConnectivity Framework (Optional)

- Direct communication between iOS and watchOS
- Useful for immediate updates when both devices are paired
- Can be added in Phase 42 (Advanced Features)

### Core Data Configuration

**Shared Container**: Both apps access the same Core Data container through App Groups

```swift
// App Group identifier
let appGroupIdentifier = "group.com.yourcompany.listall"

// Core Data container URL
container.persistentStoreDescriptions.first?.url = 
    FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupIdentifier)?
        .appendingPathComponent("ListAll.sqlite")
```

**CloudKit Configuration**:
- Same CloudKit container for both targets
- Same iCloud capabilities
- Shared custom CloudKit zone

## UI/UX Design Principles

### watchOS-Specific Considerations

1. **Screen Size**: Design for small screens (38mm - 49mm)
2. **Glanceable**: Information should be quickly readable
3. **Simple Navigation**: Maximum 2-3 levels deep
4. **Tap Targets**: Large enough for finger interaction
5. **Digital Crown**: Support scrolling with Digital Crown
6. **Dark Mode**: Optimize for always-on display

### Design Patterns

**Color Scheme**:
- Use watchOS system colors for consistency
- Primary: System blue for accents
- Success: System green for completion
- Text: White/gray on dark background

**Typography**:
- Title: .headline (bold, 17pt)
- List names: .body (regular, 17pt)
- Item titles: .body (regular, 17pt)
- Metadata: .caption (regular, 13pt)

**Spacing**:
- List rows: 8-12pt padding
- Sections: 16pt spacing
- Edge padding: 16pt horizontal

## View Hierarchy

### 1. WatchListsView (Root View)

**Purpose**: Display all lists

**Components**:
- Navigation title: "Lists"
- List of WatchListRowView items
- Pull-to-refresh gesture
- Empty state view (if no lists)

**Data Source**: MainViewModel (shared from iOS)

**Layout**:
```
┌─────────────────────┐
│      Lists          │
├─────────────────────┤
│ 🛒 Groceries        │
│    5 active, 2 done │
├─────────────────────┤
│ ✓ Todo              │
│    3 active, 7 done │
├─────────────────────┤
│ 📋 Shopping List    │
│    0 active, 10 done│
└─────────────────────┘
```

### 2. WatchListView (List Detail View)

**Purpose**: Display items in a list

**Components**:
- Navigation title: List name
- Filter picker (All/Active/Completed)
- Item count summary
- List of WatchItemRowView items
- Empty state view (if no items)

**Data Source**: ListViewModel (shared or watchOS-specific)

**Layout**:
```
┌─────────────────────┐
│    Groceries    [⚙] │
├─────────────────────┤
│ [All▼] 5/7 items    │
├─────────────────────┤
│ ○ Milk (2x)         │
├─────────────────────┤
│ ✓ Bread             │
├─────────────────────┤
│ ○ Eggs              │
├─────────────────────┤
│ ○ Cheese            │
└─────────────────────┘
```

### 3. WatchItemRowView (Item Row Component)

**Purpose**: Display individual item

**Components**:
- Completion indicator (circle or checkmark)
- Item title
- Quantity (if > 1)
- Tap gesture to toggle completion

**Visual States**:
- Active: White text, empty circle
- Completed: Gray text with strikethrough, filled checkmark

## User Interactions

### Navigation
- **Tap list row**: Navigate to list detail view
- **Swipe back**: Return to lists view
- **Digital Crown**: Scroll through lists/items

### Item Actions
- **Tap item**: Toggle completion status
- **Force Touch** (optional): Show item menu (future)

### Sync Actions
- **Pull down**: Trigger manual sync
- **Automatic**: Background sync every 15 minutes

## Performance Optimization

### Loading Strategy
- Load all lists on app launch (typically small dataset)
- Load items for specific list when opened
- Lazy loading for very large lists (>100 items)

### Memory Management
- Don't load ItemImage data on watchOS (not displayed)
- Keep only active list's items in memory
- Release memory when navigating away from list

### Battery Optimization
- Minimize CloudKit sync frequency
- Use efficient Core Data fetch requests
- Avoid unnecessary UI updates
- Cache filter preferences locally

## Error Handling

### Sync Errors
- Show alert: "Sync Failed - Tap to Retry"
- Retry button triggers manual sync
- Changes still saved locally

### Network Errors
- Graceful offline mode
- Queue changes for later sync
- Show "Offline" indicator

### Data Errors
- Log errors for debugging
- Show user-friendly error messages
- Provide recovery options (retry, cancel)

## Testing Strategy

### Unit Tests
- Test shared ViewModels work on watchOS
- Test Core Data operations on watchOS
- Test filter logic
- Test data synchronization

### Integration Tests
- Test CloudKit sync between iOS and watchOS
- Test offline scenarios
- Test conflict resolution
- Test large dataset handling

### UI Tests
- Test navigation flows
- Test item completion toggle
- Test filter switching
- Test pull-to-refresh

### Device Testing
- Test on all Apple Watch sizes (38mm - 49mm)
- Test on actual hardware (battery, performance)
- Test with poor network conditions
- Test with large datasets (100+ items)

## Implementation Phases

### Phase 68: Foundation (Week 1)
- Create watchOS target
- Configure build settings
- Share data models and Core Data stack
- Verify sync works on watchOS

### Phase 69: Lists View (Week 1-2)
- Implement WatchListsView
- Create WatchListRowView
- Add navigation to list detail
- Test with sample data

### Phase 70: List Detail View (Week 2)
- Implement WatchListView
- Create WatchItemRowView
- Add item completion toggle
- Test sync with iOS

### Phase 71: Item Filtering (Week 2-3)
- Add filter picker UI
- Implement filter logic
- Persist filter preferences
- Test all filter combinations

### Phase 72: Data Synchronization (Week 3)
- Configure CloudKit for watchOS
- Test bidirectional sync
- Add sync status indicators
- Handle offline scenarios

### Phase 73: Polish & Testing (Week 3-4)
- Add app icon
- Implement haptic feedback
- Add animations
- Test on all devices
- Fix bugs and polish UI

### Phase 74: Advanced Features (Optional, Week 4+)
- Watch complications
- Siri shortcuts
- Item creation
- Swipe actions

### Phase 75: Documentation & Deployment (Week 4+)
- Complete documentation
- Create App Store assets
- TestFlight testing
- Submit to App Store

## Known Limitations

### MVP Limitations
1. **No item creation**: Can only view and complete items (create on iOS)
2. **No item editing**: Can't edit title, description, or quantity
3. **No list management**: Can't create, edit, or delete lists
4. **No images**: ItemImage data not displayed on watchOS
5. **No reordering**: Can't reorder lists or items
6. **No search**: No search functionality (small screen)

### Technical Limitations
1. **Screen size**: Limited UI complexity due to small screen
2. **Battery**: Frequent sync can drain battery
3. **Performance**: Large datasets (>200 items) may be slow
4. **Network**: Requires internet for sync (offline mode has limitations)

### Future Enhancements (Phase 74)
- Voice input for item creation (Siri/dictation)
- Smart notifications for list reminders
- Complications for quick access
- Watch face widgets
- WatchConnectivity for instant sync
- Item detail view with description

## Dependencies

### Frameworks
- SwiftUI (UI framework)
- WatchKit (watchOS platform)
- CoreData (data persistence)
- CloudKit (synchronization)
- Combine (reactive updates)

### Capabilities Required
- iCloud (for CloudKit)
- App Groups (for shared container)
- Background Modes (for sync)

## Configuration Checklist

### Xcode Project Setup
- [ ] Create watchOS App target
- [ ] Configure bundle identifiers (e.g., com.yourcompany.listall.watchkitapp)
- [ ] Add App Groups capability to both iOS and watchOS targets
- [ ] Configure iCloud and CloudKit capabilities
- [ ] Share data models with watchOS target
- [ ] Share Core Data model with watchOS target
- [ ] Share services with watchOS target
- [ ] Configure proper target membership
- [ ] Set minimum watchOS version (9.0+)
- [ ] Configure build settings

### CloudKit Configuration
- [ ] Verify CloudKit container is accessible from watchOS
- [ ] Ensure custom zone is shared
- [ ] Test CloudKit operations on watchOS
- [ ] Verify conflict resolution works

### Code Sharing Configuration
- [ ] Add models to watchOS target membership
- [ ] Add Core Data files to watchOS target membership
- [ ] Add services to watchOS target membership
- [ ] Add ViewModels to watchOS target membership (selected)
- [ ] Use conditional compilation if needed (#if os(watchOS))

## Security & Privacy

### Data Protection
- All data encrypted in CloudKit
- Local Core Data encrypted by iOS/watchOS
- No third-party services or analytics
- Data stays within Apple ecosystem

### Permissions
- No camera or photo access needed on watchOS
- No location access needed
- Only iCloud access required

## Deployment

### App Store Submission
- watchOS app is bundled with iOS app
- Single App Store listing
- Watch app automatically installs when iPhone app is installed
- Requires both iOS and watchOS screenshots

### Version Management
- iOS and watchOS versions should match
- Coordinate releases for both platforms
- Test compatibility between versions

## Support & Troubleshooting

### Common Issues

**Issue**: Lists not appearing on Watch
- **Solution**: Ensure both devices are signed into same iCloud account
- **Solution**: Verify iCloud sync is enabled on iPhone
- **Solution**: Trigger manual sync with pull-to-refresh

**Issue**: Changes not syncing between devices
- **Solution**: Check internet connection on both devices
- **Solution**: Verify CloudKit container is configured correctly
- **Solution**: Check iCloud storage is not full

**Issue**: App crashes on launch
- **Solution**: Verify Core Data model is properly shared
- **Solution**: Check App Groups are configured correctly
- **Solution**: Review crash logs in Xcode

**Issue**: Poor performance with large lists
- **Solution**: Implement pagination for lists >100 items
- **Solution**: Optimize Core Data fetch requests
- **Solution**: Consider archiving old completed items

## Resources

### Apple Documentation
- [watchOS App Programming Guide](https://developer.apple.com/watchos/)
- [Core Data and CloudKit](https://developer.apple.com/documentation/coredata/mirroring_a_core_data_store_with_cloudkit)
- [App Groups](https://developer.apple.com/documentation/security/app_sandbox/app_groups)
- [WatchKit Framework](https://developer.apple.com/documentation/watchkit)

### Sample Code
- Apple's "Sharing Core Data with CloudKit" sample
- watchOS tutorial projects on Apple Developer

### Design Resources
- [Human Interface Guidelines - watchOS](https://developer.apple.com/design/human-interface-guidelines/watchos)
- watchOS app icons and assets templates

## Changelog

### Version 1.0 (Planned)
- Initial watchOS companion app release
- Lists view with item counts
- List detail view with item completion
- Item filtering (all/active/completed)
- CloudKit synchronization with iOS
- Pull-to-refresh for manual sync

### Future Versions
- Watch complications
- Siri integration
- Item creation with voice input
- Enhanced offline support
- Performance optimizations

