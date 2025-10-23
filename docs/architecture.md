# ListAll App - Architecture

## Tech Stack

### iOS (Primary Platform)
- **Language:** Swift 5.9+
- **UI Framework:** SwiftUI
- **Data Persistence:** Core Data + CloudKit (ready for activation)
- **State Management:** @StateObject, @ObservableObject
- **Networking:** URLSession
- **Image Processing:** PhotosUI, UIImagePickerController
- **Minimum iOS Version:** iOS 16.0
- **App Groups:** `group.io.github.chmc.ListAll` for data sharing

### watchOS (Companion App) ✅ ACTIVE
- **Language:** Swift 5.9+
- **UI Framework:** SwiftUI
- **Data Persistence:** Shared Core Data via App Groups + CloudKit (ready for activation)
- **State Management:** @StateObject, @ObservableObject
- **Minimum watchOS Version:** watchOS 9.0
- **App Groups:** `group.io.github.chmc.ListAll` (shared with iOS)
- **Current Status:** Foundation complete, UI in development
- **Core Features:** 
  - View lists (placeholder UI)
  - Shared Core Data store with iOS
  - CloudKit sync infrastructure ready
  - Data changes sync via App Groups

### Future Platforms
- **macOS:** SwiftUI + AppKit (Future consideration)
- **Android:** Kotlin + Jetpack Compose (Long-term consideration)

## Architecture Patterns

### MVVM (Model-View-ViewModel)
- **Models:** Core Data entities (List, Item, UserData)
- **Views:** SwiftUI views for UI components
- **ViewModels:** ObservableObject classes managing business logic
- **Services:** Data persistence, cloud sync, export/import

### Repository Pattern
- **DataRepository:** Abstracts data access layer
- **CloudKitRepository:** Handles iCloud synchronization
- **ExportRepository:** Manages data export/import functionality

## Folder Structure

### iOS Target (Primary App)
```
ListAll/ListAll/
├── Models/ [SHARED with watchOS]
│   ├── Item.swift
│   ├── ItemImage.swift
│   ├── List.swift
│   ├── UserData.swift
│   └── CoreData/ [SHARED with watchOS]
│       ├── ListAllModel.xcdatamodeld
│       └── CoreDataManager.swift
├── ViewModels/ [SHARED with watchOS]
│   ├── ListViewModel.swift
│   ├── ItemViewModel.swift
│   ├── MainViewModel.swift
│   ├── ExportViewModel.swift
│   └── ImportViewModel.swift
├── Views/ [iOS ONLY]
│   ├── MainView.swift
│   ├── ListView.swift
│   ├── ItemDetailView.swift
│   ├── ItemEditView.swift
│   ├── CreateListView.swift
│   ├── EditListView.swift
│   ├── ArchivedListView.swift
│   ├── SettingsView.swift
│   └── Components/
│       ├── ItemRowView.swift
│       ├── ListRowView.swift
│       ├── ImagePickerView.swift
│       ├── SearchBar.swift
│       └── [14 other iOS components]
├── Services/ [SHARED with watchOS]
│   ├── DataRepository.swift
│   ├── CloudKitService.swift
│   ├── ImageService.swift
│   ├── ExportService.swift
│   ├── ImportService.swift
│   ├── SharingService.swift
│   ├── SuggestionService.swift
│   ├── DataMigrationService.swift
│   ├── BiometricAuthService.swift [iOS ONLY]
│   └── SampleDataService.swift
├── Utils/ [SHARED with watchOS]
│   ├── Extensions/
│   │   ├── Color+Extensions.swift
│   │   └── Date+Extensions.swift
│   ├── Helpers/
│   │   ├── URLHelper.swift
│   │   └── ValidationHelper.swift
│   ├── Constants.swift
│   ├── Theme.swift
│   ├── HapticManager.swift
│   ├── TooltipManager.swift [iOS ONLY]
│   └── ActivityItemSource.swift [iOS ONLY]
└── Resources/
    ├── Assets.xcassets
    └── ListAll.entitlements

### watchOS Target (Companion App)
```
ListAll/ListAllWatch Watch App/
├── Shared/ [Symbolic links to iOS shared files]
│   ├── Models/ -> ../../ListAll/Models/
│   └── Services/ -> ../../ListAll/Services/
├── ContentView.swift [watchOS ONLY - Placeholder]
├── ListAllWatchApp.swift [watchOS ONLY - App entry]
├── Assets.xcassets [watchOS ONLY]
└── ListAllWatch Watch App.entitlements

### Shared Folder (For Future Use)
```
ListAll/Shared/
├── Models/
└── Services/
```
Note: Currently using direct file sharing via Xcode target membership instead of Shared folder

## Data Architecture

### Core Data Model
- **List Entity:**
  - id: UUID
  - name: String
  - orderNumber: Int32
  - createdAt: Date
  - modifiedAt: Date
  - items: Relationship to Item (one-to-many)

- **Item Entity:**
  - id: UUID
  - title: String
  - itemDescription: String
  - quantity: Int32
  - orderNumber: Int32
  - isCrossedOut: Bool
  - createdAt: Date
  - modifiedAt: Date
  - list: Relationship to List (many-to-one)
  - images: Relationship to ItemImage (one-to-many)

- **ItemImage Entity:**
  - id: UUID
  - imageData: Data
  - orderNumber: Int32
  - item: Relationship to Item (many-to-one)

### CloudKit Integration (Infrastructure Ready)
- **Private Database:** User's personal data
- **Custom Zones:** For better conflict resolution
- **Automatic Sync:** Background synchronization
- **Conflict Resolution:** Last-write-wins with timestamp comparison
- **Container ID:** `iCloud.io.github.chmc.ListAll`
- **Current Status:** Infrastructure implemented, requires paid Apple Developer account to activate
- **Cross-Platform Sync:** Both iOS and watchOS use same CloudKit container for seamless data sync

### App Groups Configuration ✅ ACTIVE
**Purpose:** Share Core Data store between iOS and watchOS apps

**Group Identifier:** `group.io.github.chmc.ListAll`

**Shared Resources:**
- Core Data SQLite database
- UserDefaults for shared preferences
- File storage for shared resources

**Implementation:**
1. **Entitlements Configuration:**
   - iOS: `ListAll/ListAll.entitlements`
   - watchOS: `ListAllWatch Watch App/ListAllWatch Watch App.entitlements`
   - Both include App Groups entitlement with same identifier

2. **Core Data Integration:**
   ```swift
   // CoreDataManager.swift
   let containerURL = FileManager.default
       .containerURL(forSecurityApplicationGroupIdentifier: "group.io.github.chmc.ListAll")!
       .appendingPathComponent("ListAll.sqlite")
   ```

3. **Data Migration:**
   - Automatic migration from iOS-only storage to App Groups
   - Handled by DataMigrationService.swift
   - Preserves all existing user data

**Benefits:**
- ✅ Instant data sharing between iOS and watchOS
- ✅ No network required for local sync
- ✅ Both apps see same data immediately
- ✅ CloudKit syncs shared data across devices

## Multi-Platform Architecture (iOS + watchOS)

### Architecture Diagram

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                          iCloud (CloudKit Container)                         │
│                      iCloud.io.github.chmc.ListAll                          │
│                    [Infrastructure Ready - Not Active]                       │
└─────────────────────────────────────────────────────────────────────────────┘
                                      ▲
                                      │
                    ┌─────────────────┴─────────────────┐
                    │   CloudKit Sync (Future)          │
                    │   NSPersistentCloudKitContainer   │
                    └─────────────────┬─────────────────┘
                                      │
                                      ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│                         App Groups Shared Storage                            │
│                      group.io.github.chmc.ListAll                           │
│                                                                              │
│  ┌────────────────────────────────────────────────────────────────────┐   │
│  │                    Core Data SQLite Database                        │   │
│  │                         ListAll.sqlite                              │   │
│  │                                                                     │   │
│  │   ┌─────────────┐  ┌─────────────┐  ┌──────────────┐             │   │
│  │   │   List      │  │    Item     │  │  ItemImage   │             │   │
│  │   │  Entity     │──│   Entity    │──│   Entity     │             │   │
│  │   └─────────────┘  └─────────────┘  └──────────────┘             │   │
│  │                                                                     │   │
│  └────────────────────────────────────────────────────────────────────┘   │
│                                                                              │
│  ┌────────────────────────────────────────────────────────────────────┐   │
│  │                      Shared UserDefaults                            │   │
│  └────────────────────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────────────────────┘
                    ▲                                   ▲
                    │                                   │
         ┌──────────┴──────────┐           ┌──────────┴──────────┐
         │   iOS App (Primary)  │           │  watchOS App (Watch) │
         │                      │           │                      │
         │  ┌────────────────┐ │           │  ┌────────────────┐ │
         │  │   UI Layer     │ │           │  │   UI Layer     │ │
         │  │   (SwiftUI)    │ │           │  │   (SwiftUI)    │ │
         │  │  - MainView    │ │           │  │  - ContentView │ │
         │  │  - ListView    │ │           │  │   (Placeholder)│ │
         │  │  - ItemDetail  │ │           │  │                │ │
         │  │  - Settings    │ │           │  └────────────────┘ │
         │  │  - Components  │ │           │                      │
         │  └────────────────┘ │           │  ┌────────────────┐ │
         │         │            │           │  │   ViewModels   │ │
         │         ▼            │           │  │    [SHARED]    │ │
         │  ┌────────────────┐ │           │  │  - MainVM      │ │
         │  │   ViewModels   │ │           │  │  - ListVM      │ │
         │  │    [SHARED]    │◄├───────────┤──│  - ItemVM      │ │
         │  │  - MainVM      │ │           │  └────────────────┘ │
         │  │  - ListVM      │ │           │         │            │
         │  │  - ItemVM      │ │           │         ▼            │
         │  │  - ExportVM    │ │           │  ┌────────────────┐ │
         │  │  - ImportVM    │ │           │  │   Services     │ │
         │  └────────────────┘ │           │  │    [SHARED]    │ │
         │         │            │           │  │  - DataRepo    │ │
         │         ▼            │           │  │  - CloudKit    │ │
         │  ┌────────────────┐ │           │  │  - ImageSvc    │ │
         │  │   Services     │◄├───────────┤──│  - SampleData  │ │
         │  │    [SHARED]    │ │           │  └────────────────┘ │
         │  │  - DataRepo    │ │           │         │            │
         │  │  - CloudKit    │ │           │         ▼            │
         │  │  - ImageSvc    │ │           │  ┌────────────────┐ │
         │  │  - ExportSvc   │ │           │  │     Models     │ │
         │  │  - ImportSvc   │ │           │  │    [SHARED]    │ │
         │  │  - SharingSvc  │ │           │  │  - List        │ │
         │  │  - BiometricAuth│ │          │  │  - Item        │ │
         │  │  - SampleData  │ │           │  │  - ItemImage   │ │
         │  └────────────────┘ │           │  │  - UserData    │ │
         │         │            │           │  │  - CoreData    │ │
         │         ▼            │           │  └────────────────┘ │
         │  ┌────────────────┐ │           │                      │
         │  │     Models     │◄├───────────┤──────────────────────┤
         │  │    [SHARED]    │ │           │                      │
         │  │  - List        │ │           └──────────────────────┘
         │  │  - Item        │ │              iPhone Apple Watch
         │  │  - ItemImage   │ │                  Series 4+
         │  │  - UserData    │ │              watchOS 9.0+
         │  │  - CoreData    │ │
         │  └────────────────┘ │
         │                      │
         └──────────────────────┘
           iPhone/iPad
           iOS 16.0+
```

### Shared Components Strategy

**Philosophy:** Share business logic and data layer, keep UI platform-specific

#### ✅ Shared Across Platforms
1. **Data Models** (100% shared)
   - `List.swift` - List entity
   - `Item.swift` - Item entity
   - `ItemImage.swift` - Image entity
   - `UserData.swift` - User preferences
   - `CoreDataManager.swift` - Core Data stack
   - `ListAllModel.xcdatamodeld` - Core Data schema

2. **Services** (95% shared)
   - `DataRepository.swift` - Data access layer
   - `CloudKitService.swift` - Cloud sync
   - `ImageService.swift` - Image management
   - `ExportService.swift` - Data export
   - `ImportService.swift` - Data import
   - `SharingService.swift` - List sharing
   - `SuggestionService.swift` - Smart suggestions
   - `DataMigrationService.swift` - Data migration
   - `SampleDataService.swift` - Sample data
   - ❌ `BiometricAuthService.swift` - iOS only (Face ID/Touch ID)

3. **ViewModels** (80% shared)
   - `MainViewModel.swift` - Main app logic
   - `ListViewModel.swift` - List management
   - `ItemViewModel.swift` - Item operations
   - `ExportViewModel.swift` - Export functionality
   - `ImportViewModel.swift` - Import functionality

4. **Utilities** (70% shared)
   - `Constants.swift` - App constants
   - `Theme.swift` - Color/typography definitions
   - `HapticManager.swift` - Haptic feedback
   - `Color+Extensions.swift` - Color utilities
   - `Date+Extensions.swift` - Date utilities
   - `URLHelper.swift` - URL handling
   - `ValidationHelper.swift` - Input validation
   - ❌ `TooltipManager.swift` - iOS only
   - ❌ `ActivityItemSource.swift` - iOS only (sharing)

#### ❌ Platform-Specific Components

**iOS Only:**
- All Views/* - iPhone/iPad optimized UI
- All Components/* - Large screen components
- BiometricAuthService - Face ID/Touch ID
- TooltipManager - iPad tooltip system
- ActivityItemSource - iOS sharing
- Image display and editing
- Complex navigation flows
- Settings and preferences UI

**watchOS Only:**
- `ContentView.swift` - Watch UI (placeholder)
- `ListAllWatchApp.swift` - Watch app entry
- Watch complications (Phase 74)
- Digital Crown integration (Phase 70)
- Watch-specific haptics
- Simplified navigation

### Data Flow Architecture

**User Makes Change on iOS:**
```
User Interaction
    ↓
iOS SwiftUI View
    ↓
ViewModel (Shared)
    ↓
DataRepository (Shared)
    ↓
CoreDataManager (Shared)
    ↓
Core Data Store (App Groups)
    ↓
[watchOS reads same store immediately]
    ↓
[CloudKit syncs to other devices - when active]
```

**User Makes Change on watchOS:**
```
User Interaction (tap to complete item)
    ↓
watchOS SwiftUI View
    ↓
ViewModel (Shared)
    ↓
DataRepository (Shared)
    ↓
CoreDataManager (Shared)
    ↓
Core Data Store (App Groups)
    ↓
[iOS reads same store immediately]
    ↓
[CloudKit syncs to other devices - when active]
```

### File Sharing Implementation

**Method:** Xcode Target Membership (not symbolic links)

**How It Works:**
1. Files in `ListAll/ListAll/Models/`, `Services/`, `ViewModels/`, `Utils/`
2. Select file in Xcode
3. Check both "ListAll" and "ListAllWatch Watch App" in Target Membership
4. File compiles into both app binaries
5. No code changes needed - same Swift code works on both platforms

**Benefits:**
- ✅ No symbolic link maintenance
- ✅ Xcode handles compilation
- ✅ Clean project structure
- ✅ Easy to add/remove shared files
- ✅ Type-safe sharing (compile-time checks)

**Limitations:**
- Files must be compatible with both iOS and watchOS
- Platform-specific code needs `#if os(iOS)` / `#if os(watchOS)` guards
- Both targets must be kept in sync

### Platform Detection

When platform-specific code is needed:

```swift
#if os(iOS)
// iOS-only code
import PhotosUI
#elseif os(watchOS)
// watchOS-only code
import WatchKit
#endif
```

### Testing Strategy Per Platform

**iOS Tests:** 100% of shared code + iOS-specific code
- All unit tests run on iOS
- UI tests for iOS interface

**watchOS Tests:** Subset of shared code
- Core functionality tests
- Watch-specific UI tests (Phase 73)
- Sync tests between platforms

## Testing Strategy

### Unit Tests (iOS + watchOS)
- **Model Tests:** Core Data entity validation
- **ViewModel Tests:** Business logic and state management
- **Service Tests:** Data persistence and cloud sync
- **Utility Tests:** Helper functions and extensions
- **App Groups Tests:** ✅ Data sharing between platforms
  - `AppGroupsTests.swift` - 5 tests validating App Groups configuration
  - Container path verification
  - Data persistence across app restarts
  - CoreDataManager initialization with App Groups
- **CloudKit Tests:** ✅ Sync infrastructure validation
  - `CloudKitTests.swift` - 18 tests covering CloudKit service
  - Account status handling
  - Offline operation queuing
  - Integration with Core Data and App Groups
  - watchOS platform compatibility

**Current Test Results (Phase 68):**
- ✅ iOS Unit Tests: 100% pass rate
- ✅ App Groups Tests: 5/5 passed
- ✅ CloudKit Tests: 18/18 passed
- ✅ watchOS Build: Successful (0 errors, 0 warnings)
- ⏳ watchOS UI Tests: Pending (Phase 73)

### Integration Tests
- **Core Data + CloudKit:** Data synchronization (infrastructure ready)
- **Export/Import:** Data integrity across operations
- **Sharing:** List sharing functionality
- **Cross-Platform Data:** iOS ↔ watchOS via App Groups ✅

### UI Tests
- **iOS UI Tests:**
  - User flows and complete journeys
  - Accessibility and VoiceOver features
  - Performance with large datasets
- **watchOS UI Tests:** (Planned for Phase 73)
  - Watch-specific navigation
  - Item completion gestures
  - Filter switching
  - Digital Crown scrolling

## Performance Considerations

### Data Loading
- **Lazy Loading:** Load items on demand for large lists
- **Pagination:** Implement pagination for very large datasets
- **Caching:** Cache frequently accessed data

### Image Handling
- **Compression:** Compress images before storage
- **Thumbnails:** Generate thumbnails for list views
- **Memory Management:** Proper cleanup of image data

### Cloud Sync
- **Batch Operations:** Group changes for efficient sync
- **Conflict Resolution:** Handle concurrent edits gracefully
- **Offline Support:** Queue changes when offline

## Security & Privacy

### Data Protection
- **iCloud Encryption:** All data encrypted in transit and at rest
- **Local Encryption:** Sensitive data encrypted locally
- **No Third-Party Services:** All data stays within Apple ecosystem

### Privacy Features
- **No Analytics:** No user tracking or analytics
- **Local Processing:** All smart suggestions processed locally
- **User Control:** Full control over data export and deletion

## Scalability Considerations

### Multi-Platform Architecture ✅ IMPLEMENTED
- **Shared Models:** ✅ 100% shared across iOS and watchOS
- **Platform-Specific Views:** ✅ iOS has full UI, watchOS has placeholder
- **Service Abstraction:** ✅ 95% shared, platform-agnostic business logic
- **Data Synchronization:** ✅ App Groups for instant local sync, CloudKit ready for cloud sync
- **Code Reuse:** ✅ ~85% of codebase shared between platforms

**Benefits Achieved:**
- Reduced development time for watchOS (leveraged existing code)
- Guaranteed consistency across platforms (same data layer)
- Easy to add new platforms (macOS, etc.)
- Single source of truth for business logic

### Current Platform Support
- ✅ **iOS 16.0+:** Full-featured list management app
- ✅ **watchOS 9.0+:** Foundation complete, UI in development (Phases 69-73)
- ⏳ **macOS:** Future consideration (could reuse ~80% of code)
- ⏳ **iPadOS:** Works via iOS target, could optimize UI further

### Future Enhancements
- **Phase 69-73:** Complete watchOS UI
  - Lists view, item detail, filtering, polish
- **Phase 74:** watchOS advanced features
  - Complications, Siri shortcuts, item creation
- **CloudKit Activation:** When paid developer account available
  - Device-to-device sync across iPhone/iPad/Mac/Watch
- **Collaborative Lists:** Real-time collaboration features
- **Advanced Export:** More export formats and options
- **Smart Features:** AI-powered list suggestions and organization
- **Integration:** Third-party app integrations (calendar, reminders)
- **macOS App:** Native Mac app with same data layer

## Known Limitations (Phase 68)

### watchOS Current Limitations
- ✅ watchOS target builds and runs successfully
- ✅ Core Data and App Groups fully functional
- ⏳ UI is placeholder (ContentView) - real UI in Phases 69-73
- ⏳ No item creation on watch yet (Phase 74)
- ⏳ No complications yet (Phase 74)
- ❌ Images not displayed on watchOS (by design - small screen)

### CloudKit Limitations
- Infrastructure 100% implemented and tested
- Requires paid Apple Developer account to activate
- Currently using local storage only (works perfectly)
- All code ready - just need to uncomment entitlements

### Testing Limitations
- UI tests are slow (can take minutes)
- CloudKit testing limited without paid account
- Device-to-device sync testing requires actual hardware

## Version History

### Phase 68 (October 2025) - watchOS Foundation ✅
- Created watchOS companion app target
- Implemented App Groups for data sharing
- Shared 85% of codebase with iOS
- Added CloudKit infrastructure (ready for activation)
- Comprehensive testing (23 tests, 100% pass rate)
- Complete documentation

**Status:** Foundation complete, ready for UI development (Phase 69)
