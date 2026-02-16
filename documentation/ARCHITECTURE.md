# ListAll App - Architecture

## Executive Summary

ListAll is a multi-platform list management app built with SwiftUI for iOS, watchOS, and macOS. The architecture follows MVVM with Repository Pattern, using Core Data with NSPersistentCloudKitContainer for persistence and sync. Code sharing (~85%) is achieved via Xcode target membership with conditional compilation for platform-specific behavior.

---

## Tech Stack

### iOS (Primary Platform)
- **Language:** Swift 5.9+
- **UI Framework:** SwiftUI
- **Data Persistence:** Core Data + CloudKit (NSPersistentCloudKitContainer)
- **State Management:** @StateObject, @ObservableObject, @Published
- **Image Processing:** PhotosUI, UIImagePickerController
- **Minimum iOS Version:** iOS 16.0
- **App Groups:** `group.io.github.chmc.ListAll`
- **Bundle ID:** `io.github.chmc.ListAll`

### watchOS (Companion App)
- **Language:** Swift 5.9+
- **UI Framework:** SwiftUI
- **Data Persistence:** Shared Core Data via App Groups
- **Communication:** WatchConnectivity for iOS sync
- **Minimum watchOS Version:** watchOS 9.0
- **Bundle ID:** `io.github.chmc.ListAll.watchkitapp`

### macOS (Desktop App)
- **Language:** Swift 5.9+
- **UI Framework:** SwiftUI + AppKit integration
- **Data Persistence:** Core Data + CloudKit (Release builds)
- **Features:** NavigationSplitView, keyboard shortcuts, Services menu
- **Minimum macOS Version:** macOS 14.0 (Sonoma)
- **Bundle ID:** `io.github.chmc.ListAllMac`

---

## Xcode Project Structure

### Targets (9 total)

| Target | Platform | Type | Min Version |
|--------|----------|------|-------------|
| ListAll | iOS | App | iOS 16.0 |
| ListAllTests | iOS | Unit Tests | iOS 16.0 |
| ListAllUITests | iOS | UI Tests | iOS 16.0 |
| ListAllWatch Watch App | watchOS | App | watchOS 9.0 |
| ListAllWatch Watch AppTests | watchOS | Unit Tests | watchOS 9.0 |
| ListAllWatch Watch AppUITests | watchOS | UI Tests | watchOS 9.0 |
| ListAllMac | macOS | App | macOS 14.0 |
| ListAllMacTests | macOS | Unit Tests | macOS 14.0 |
| ListAllMacUITests | macOS | UI Tests | macOS 14.0 |

### Entry Points

| Platform | File | Key Features |
|----------|------|--------------|
| iOS | `ListAllApp.swift` | UIApplicationDelegateAdaptor, Handoff, UI test setup |
| watchOS | `ListAllWatchApp.swift` | WatchLocalizationManager, App Groups language sync |
| macOS | `ListAllMacApp.swift` | NSApplicationDelegateAdaptor, Settings scene, Services provider |

---

## Architecture Patterns

### MVVM (Model-View-ViewModel)
```
View Layer (SwiftUI)
    │
    ▼
ViewModel Layer (@ObservableObject)
    │
    ▼
Repository Layer (DataRepository)
    │
    ▼
Data Manager Layer (DataManager)
    │
    ▼
Core Data Layer (CoreDataManager)
    │
    ▼
Persistence (SQLite + CloudKit)
```

### Repository Pattern
- **DataRepository:** Orchestration, validation, Watch sync coordination
- **DataManager:** CRUD operations, in-memory cache, list management
- **CoreDataManager:** Core Data stack, CloudKit integration, remote notifications

### Protocol-Based Dependency Injection

*Note: Simplified examples. See actual protocol files for complete signatures.*

```swift
protocol CoreDataManaging: AnyObject {
    var viewContext: NSManagedObjectContext { get }
    var backgroundContext: NSManagedObjectContext { get }
    var lastSyncDate: Date? { get }
    func save()
    func forceRefresh()
    func triggerCloudKitSync()
    func checkCloudKitStatus() async -> CKAccountStatus
    // ... additional methods
}

protocol DataManaging: AnyObject, ObservableObject {
    var lists: [List] { get }
    func loadData()
    func addList(_ list: List)
    func updateList(_ list: List)
    func deleteList(withId id: UUID)
    // ... ~24 total methods/properties
}

protocol CloudSyncProviding: AnyObject, ObservableObject {
    var isSyncing: Bool { get }
    var lastSyncDate: Date? { get }
    func sync() async
    func checkAccountStatus() async -> CKAccountStatus
}
```

---

## Folder Structure

### iOS Target (`ListAll/ListAll/`)

```
ListAll/ListAll/
├── ListAllApp.swift              # App entry point
├── ContentView.swift             # Root content view
├── Localizable.xcstrings         # Localization strings
├── ListAll.entitlements          # iOS entitlements
│
├── Models/                       # [SHARED via target membership]
│   ├── Item.swift                # Item domain model
│   ├── List.swift                # List domain model
│   ├── ItemImage.swift           # Image attachment model
│   ├── UserData.swift            # User preferences
│   ├── Item+Transferable.swift   # Drag-drop support
│   ├── List+Transferable.swift   # Drag-drop support
│   └── CoreData/
│       ├── CoreDataManager.swift # Core Data stack (~1400 lines)
│       ├── ListAll.xcdatamodeld  # Core Data schema
│       ├── ListEntity+Extensions.swift
│       ├── ItemEntity+Extensions.swift
│       ├── ItemImageEntity+Extensions.swift
│       └── UserDataEntity+Extensions.swift
│
├── ViewModels/                   # [SHARED via target membership]
│   ├── MainViewModel.swift       # Main app state
│   ├── ListViewModel.swift       # Single list management
│   ├── ItemViewModel.swift       # Item operations
│   ├── ExportViewModel.swift     # Export functionality
│   └── ImportViewModel.swift     # Import functionality
│
├── Services/                     # [Mostly SHARED]
│   ├── DataRepository.swift      # Repository abstraction
│   ├── CloudKitService.swift     # CloudKit sync
│   ├── WatchConnectivityService.swift # iOS-Watch sync
│   ├── ImageService.swift        # Image processing
│   ├── ExportService.swift       # CSV/JSON export
│   ├── ImportService.swift       # Data import
│   ├── SharingService.swift      # List sharing
│   ├── SuggestionService.swift   # Smart suggestions
│   ├── HandoffService.swift      # Continuity handoff
│   ├── BiometricAuthService.swift # Face ID/Touch ID [iOS only]
│   ├── DataMigrationService.swift
│   ├── SampleDataService.swift
│   └── UITestDataService.swift
│
├── Views/                        # [iOS ONLY]
│   ├── MainView.swift            # Primary list view
│   ├── ListView.swift            # Single list with items
│   ├── ItemDetailView.swift      # Item viewing
│   ├── ItemEditView.swift        # Item editing
│   ├── CreateListView.swift      # New list creation
│   ├── EditListView.swift        # List editing
│   ├── ArchivedListView.swift    # Archived lists
│   ├── SettingsView.swift        # Settings
│   └── Components/               # 13+ reusable components
│       ├── ItemRowView.swift
│       ├── ListRowView.swift
│       ├── EmptyStateView.swift
│       ├── ImagePickerView.swift
│       └── ...
│
├── Protocols/                    # [SHARED]
│   ├── DataManaging.swift
│   ├── CoreDataManaging.swift
│   └── CloudSyncProviding.swift
│
├── Utils/                        # [Mostly SHARED]
│   ├── Constants.swift
│   ├── Theme.swift
│   ├── HapticManager.swift
│   ├── LocalizationManager.swift
│   ├── TooltipManager.swift      # [iOS only]
│   ├── ActivityItemSource.swift  # [iOS only]
│   ├── Helpers/
│   │   ├── URLHelper.swift
│   │   └── ValidationHelper.swift
│   └── Extensions/
│       ├── Date+Extensions.swift
│       └── String+Extensions.swift
│
└── Resources/
    └── Assets.xcassets
```

### macOS Target (`ListAll/ListAllMac/`)

```
ListAll/ListAllMac/
├── ListAllMacApp.swift           # macOS app entry point
├── ListAllMac.entitlements       # Release entitlements
├── ListAllMac.Debug.entitlements # Debug entitlements (no CloudKit)
│
├── Views/
│   ├── MacMainView.swift         # NavigationSplitView (~108KB)
│   ├── MacSettingsView.swift     # macOS settings pane
│   └── Components/               # 14+ macOS-specific components
│       ├── MacEmptyStateView.swift
│       ├── MacImageGalleryView.swift
│       ├── MacQuickLookView.swift
│       ├── MacSuggestionListView.swift
│       └── ...
│
├── Services/
│   ├── MacBiometricAuthService.swift
│   └── ServicesProvider.swift    # macOS Services menu
│
├── Commands/
│   └── AppCommands.swift         # Menu commands
│
├── Utils/
│   └── MacTooltipManager.swift
│
└── Resources/
    └── Assets.xcassets
```

### watchOS Target (`ListAll/ListAllWatch Watch App/`)

```
ListAll/ListAllWatch Watch App/
├── ListAllWatchApp.swift         # Watch app entry point
├── ContentView.swift             # Root view
├── ListAllWatch Watch App.entitlements
│
├── Views/
│   ├── WatchListsView.swift      # Lists overview
│   └── WatchListView.swift       # Single list view
│
├── Components/                   # 6 watch components
│   ├── WatchEmptyStateView.swift
│   ├── WatchFilterPicker.swift
│   ├── WatchItemRowView.swift
│   ├── WatchListRowView.swift
│   ├── WatchLoadingView.swift
│   └── WatchPullToRefreshView.swift
│
├── ViewModels/
│   ├── WatchMainViewModel.swift
│   └── WatchListViewModel.swift
│
├── Services/
│   └── WatchUITestDataService.swift
│
├── Utils/                        # 6 watch utilities
│   ├── WatchHapticManager.swift
│   ├── WatchAnimationManager.swift
│   ├── WatchPerformanceManager.swift
│   ├── WatchLocalizedString.swift
│   ├── LocalizedText.swift
│   └── WatchScreenshotConfiguration.swift
│
└── Resources/
    └── Assets.xcassets
```

---

## Code Sharing Strategy

### Xcode Target Membership (Not Symbolic Links)

Files are shared by checking multiple targets in Xcode's File Inspector. The project uses `PBXFileSystemSynchronizedBuildFileExceptionSet` for managing shared files.

### Files Shared Across Platforms

| Category | Files Shared | Notes |
|----------|--------------|-------|
| **Models** | All Core Data models, domain models | 100% shared |
| **Services** | DataRepository, CloudKit, ImageService, etc. | ~95% shared |
| **ViewModels** | Main, List, Item, Export, Import | ~80% shared |
| **Protocols** | All 3 protocols | 100% shared |
| **Utils** | Constants, Theme, Extensions | ~70% shared |

### Platform-Specific Code via Conditional Compilation

```swift
#if os(iOS)
import PhotosUI
// iOS-specific code
#elseif os(macOS)
import AppKit
// macOS-specific code
#elseif os(watchOS)
import WatchKit
// watchOS-specific code
#endif
```

### Platform-Specific Exclusions

**iOS Only:**
- BiometricAuthService (Face ID/Touch ID)
- TooltipManager, ActivityItemSource
- All iOS Views and Components

**macOS Only:**
- MacBiometricAuthService
- ServicesProvider (Services menu)
- MacTooltipManager
- All macOS Views and Components

**watchOS Only:**
- WatchHapticManager
- WatchAnimationManager
- WatchPerformanceManager
- All watchOS Views and Components

---

## Data Architecture

### Core Data Model

```
UserDataEntity (1)
    │
    └──< ListEntity (many)
              │
              ├── id: UUID
              ├── name: String
              ├── orderNumber: Int32
              ├── isArchived: Bool
              ├── createdAt: Date
              ├── modifiedAt: Date
              ├── ckServerChangeToken: Binary?
              │
              └──< ItemEntity (many)
                        │
                        ├── id: UUID
                        ├── title: String
                        ├── itemDescription: String?
                        ├── quantity: Int32
                        ├── orderNumber: Int32
                        ├── isCrossedOut: Bool
                        ├── createdAt: Date
                        ├── modifiedAt: Date
                        ├── ckServerChangeToken: Binary?
                        │
                        └──< ItemImageEntity (many)
                                  │
                                  ├── id: UUID
                                  ├── imageData: Binary
                                  ├── orderNumber: Int32
                                  ├── createdAt: Date
                                  └── ckServerChangeToken: Binary?
```

### CoreDataManager Container Selection

```swift
// Platform and build-specific container selection
#if os(watchOS)
container = NSPersistentContainer(name: "ListAll")  // CloudKit disabled
#elseif os(macOS) && DEBUG
container = NSPersistentContainer(name: "ListAll")  // Unsigned builds lack entitlements
#else
container = NSPersistentCloudKitContainer(name: "ListAll")  // iOS + macOS Release
#endif
```

### CloudKit Integration

- **Container ID:** `iCloud.io.github.chmc.ListAll`
- **Sync:** Automatic via NSPersistentCloudKitContainer
- **Conflict Resolution:** `NSMergeByPropertyObjectTrumpMergePolicy` (local wins on property conflicts)
- **Notifications:** Remote change notifications with 500ms debouncing

### App Groups Configuration

**Group Identifier:** `group.io.github.chmc.ListAll`

**Shared Resources:**
- Core Data SQLite database (`ListAll.sqlite` or `ListAll-Debug.sqlite`)
- UserDefaults for shared preferences
- Immediate data sharing between iOS, watchOS, and macOS

**Store Location Logic:**
```swift
if let containerURL = FileManager.default.containerURL(
    forSecurityApplicationGroupIdentifier: "group.io.github.chmc.ListAll") {
    #if DEBUG
    storeDescription.url = containerURL.appendingPathComponent("ListAll-Debug.sqlite")
    #else
    storeDescription.url = containerURL.appendingPathComponent("ListAll.sqlite")
    #endif
}
```

---

## Data Flow Patterns

### User Creates Item on iOS

```
User taps "Add Item"
    ↓
CreateItemView → ListViewModel.addItem()
    ↓
DataRepository.createItem()
    ├── Duplicate detection (same title + metadata → uncross instead)
    ↓
DataManager.addItem()
    ↓
CoreDataManager.save()
    ↓
Core Data writes to SQLite (App Groups)
    ├── CloudKitService syncs to iCloud
    └── WatchConnectivityService.sendListsData() → watchOS
```

### CloudKit Sync from Another Device

```
iCloud Server pushes change
    ↓
NSPersistentCloudKitContainer imports
    ↓
CoreDataManager.handleCloudKitEvent()
    ├── Check endDate != nil (event completed)
    ├── viewContext.refreshAllObjects()
    └── Post .coreDataRemoteChange notification
    ↓
MainViewModel observes notification
    ↓
loadLists() → @Published lists updates
    ↓
SwiftUI re-renders
```

### Watch Connectivity Sync

```
watchOS changes data
    ↓
WatchConnectivityService.sendListsData()
    ├── Convert to lightweight ListSyncData (no images)
    ├── Encode to JSON (<256KB limit)
    └── session.transferUserInfo() (reliable, queued)
    ↓
iOS WatchConnectivityService receives
    ↓
Post "WatchConnectivityListsDataReceived" notification
    ↓
MainViewModel.handleWatchListsData()
    ├── Check: isDragOperationInProgress? (ignore if yes)
    ├── Compare modifiedAt timestamps
    └── Update only if received is newer
```

---

## State Management

### @Published vs Computed Properties

```swift
// Storage (mutable, triggers SwiftUI updates)
@Published var lists: [List] = []
@Published var showingArchivedLists = false

// Display (derived, always recalculated)
var displayedLists: [List] {
    let source = showingArchivedLists ? archivedLists : lists
    return source.sorted { $0.orderNumber < $1.orderNumber }
}
```

### Drag-Drop State Protection

```swift
// Prevent sync during drag operations
private var isDragging = false
private var isEditModeActive = false

private var isDragOperationInProgress: Bool {
    isDragging || isEditModeActive
}

// Force SwiftUI ForEach rebuild after reorder
@Published var listsReorderTrigger: Int = 0

func moveList(from source: IndexSet, to destination: Int) {
    // ... perform reordering ...
    listsReorderTrigger += 1  // Break ForEach animation cache
}

// In View:
List { ... }.id(viewModel.listsReorderTrigger)
```

---

## Testing Architecture

### Test Targets (6 total)

| Target | Files | Coverage Focus |
|--------|-------|----------------|
| ListAllTests | 19 files | Models, ViewModels, Services, CloudKit, Sync |
| ListAllUITests | 4 files | Screenshots, User flows |
| ListAllMacTests | 15 files | Models, Accessibility, Performance, Screenshots |
| ListAllMacUITests | 16 files | Keyboard navigation, Screenshots |
| ListAllWatch Watch AppTests | 8 files | ViewModels, Localization, Animations |
| ListAllWatch Watch AppUITests | 3 files | Screenshots |

### Test Isolation Pattern

```swift
class TestHelpers {
    static func createInMemoryCoreDataStack() -> NSPersistentContainer {
        let container = NSPersistentContainer(name: "ListAll")
        let description = NSPersistentStoreDescription()
        description.type = NSInMemoryStoreType
        description.url = URL(fileURLWithPath: "/dev/null")
        container.persistentStoreDescriptions = [description]
        // ...
    }
}
```

### Test Double Hierarchy

1. `TestCoreDataManager` - In-memory Core Data (implements `CoreDataManaging`)
2. `TestDataManager` - Isolated data manager (implements `DataManaging`)
3. `TestDataRepository` - Repository with isolated storage
4. `TestMainViewModel` / `TestListViewModel` / `TestItemViewModel`

### UI Test Data Service

```swift
class UITestDataService {
    static var isUITesting: Bool {
        ProcessInfo.processInfo.arguments.contains("UITEST_MODE")
    }
}

// Launch arguments:
// - UITEST_MODE - Enable UI test mode
// - UITEST_SCREENSHOT_MODE - Enable screenshot capture
// - DISABLE_TOOLTIPS - Disable tooltips during screenshots
// - SKIP_TEST_DATA - Skip test data population (for empty state)
// - FORCE_LIGHT_MODE - Force light appearance
// - UITEST_FORCE_PORTRAIT - Force portrait on iPhone (iPad allows landscape for split view)
```

---

## CI/CD Pipeline

### GitHub Actions Workflows

| Workflow | Trigger | Purpose |
|----------|---------|---------|
| `ci.yml` | Push/PR to main | Build + test all platforms in parallel |
| `release.yml` | Manual/tag | Version bump, TestFlight upload |
| `publish-to-appstore.yml` | Manual | Upload screenshots/metadata to ASC |
| `validate-macos-screenshots.yml` | Screenshot changes | Validate dimensions |

### CI Pipeline Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                     CI Pipeline (ci.yml)                     │
├─────────────────────────────────────────────────────────────┤
│                                                              │
│  ┌───────────────┐  ┌───────────────┐  ┌───────────────┐   │
│  │ iOS Build &   │  │ watchOS Build │  │ macOS Build & │   │
│  │ Test (25min)  │  │ & Test (25min)│  │ Test (20min)  │   │
│  └───────────────┘  └───────────────┘  └───────────────┘   │
│          │                  │                  │            │
│          └──────────────────┼──────────────────┘            │
│                             ▼                               │
│                   ┌─────────────────┐                       │
│                   │   CI Summary    │                       │
│                   │ (ubuntu-latest) │                       │
│                   └─────────────────┘                       │
└─────────────────────────────────────────────────────────────┘
```

### Fastlane Configuration

- **`Fastfile`:** Build, test, screenshot, release lanes
- **`Matchfile`:** Code signing certificate management
- **`Snapfile`:** iOS/iPad screenshot configuration
- **`WatchSnapfile`:** watchOS screenshot configuration

### Key Fastlane Lanes

| Lane | Purpose |
|------|---------|
| `beta` | Build iOS/watchOS → TestFlight |
| `beta_macos` | Build macOS → TestFlight |
| `test` | Run unit tests |
| `screenshots` | Generate App Store screenshots |
| `release` | Upload to App Store Connect |

---

## Security & Privacy

### Data Protection
- **iCloud Encryption:** All data encrypted in transit and at rest
- **Local Encryption:** Data stored in App Groups container
- **No Third-Party Services:** All data stays within Apple ecosystem

### Privacy Features
- **No Analytics:** No user tracking or analytics
- **Local Processing:** Smart suggestions processed locally
- **User Control:** Full control over data export and deletion

### Entitlements

**iOS (`ListAll.entitlements`):**
- App Groups: `group.io.github.chmc.ListAll`
- iCloud: CloudKit with `iCloud.io.github.chmc.ListAll`

**macOS (`ListAllMac.entitlements`):**
- Same as iOS, plus:
- App Sandbox: enabled
- Network Client: enabled

**macOS Debug (`ListAllMac.Debug.entitlements`):**
- No App Groups or iCloud (avoids permission dialogs on unsigned builds)
- Only sandbox and network permissions

---

## Known Architectural Decisions

### CloudKit Disabled on watchOS
CloudKit is disabled on watchOS due to portal configuration complexity. watchOS syncs via WatchConnectivity with iOS instead.

### macOS Debug Without CloudKit
Unsigned macOS Debug builds lack proper entitlements for CloudKit. This allows development without code signing while still testing other features.

### Drag-Drop Sync Protection
During drag-and-drop operations, all sync from other devices is ignored (not deferred) to prevent visual corruption and stale data overwrites.

### ListEntity.toList() Direct Fetch
The `ListEntity.toList()` method fetches items via direct NSFetchRequest instead of relationship traversal due to CloudKit timing issues where items may not be fully imported when accessed via relationship.

### Duplicate Cleanup on Startup
DataManager performs duplicate list/item removal on startup. This mitigates prior sync issues and ensures data consistency.

---

## File Statistics

*Note: Counts are approximate and may vary as the codebase evolves.*

| Component | Count | Notes |
|-----------|-------|-------|
| iOS Views | ~22 files | 8 main views + 14 components |
| iOS Models | ~13 files | CoreData + domain + transferable |
| iOS Services | 13 files | Cloud, auth, export, import, sync |
| iOS ViewModels | 5 files | Core state management |
| macOS Views | ~16 files | 2 main + 14 components (in Views/Components/) |
| watchOS Views | ~8 files | 2 main + 6 components |
| Total Test Files | 63 files | Across 6 test targets |
| Documentation | 100+ files | Guides, features, learnings |
| CI/CD Workflows | 5 files | Complete automation |
| Shell Scripts | 12 files | ~4,600 lines total |
| Fastlane Config | 7 files | Screenshots + deployment |

---

## References

### Documentation
- `/documentation/learnings/` - 90+ learning documents
- `/documentation/features/` - Feature specifications
- `/documentation/guides/` - Platform guides

### Key Learning Documents
- `macos-item-drag-drop-regression.md` - Drag-drop on macOS
- `cloudkit-sync-trigger-mechanism.md` - CloudKit sync patterns
- `ios-cloudkit-sync-polling-timer.md` - Timer patterns in SwiftUI
- `cloudkit-sync-enhanced-reliability.md` - Sync reliability improvements
- `swiftui-list-drag-drop-ordering.md` - SwiftUI ForEach cache issues

### External References
- Apple WWDC23: The SwiftUI cookbook for focus
- Apple TN3163: Understanding NSPersistentCloudKitContainer Synchronization
- Apple TN3164: Debugging NSPersistentCloudKitContainer Synchronization
