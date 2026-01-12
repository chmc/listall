# macOS Integration Architecture for ListAll

**Document Status:** Task 11.6 Research Phase
**Date:** January 6, 2026
**Purpose:** Map integration points for final integration testing

---

## 1. Overview

This document maps the integration architecture of the ListAll macOS app, identifying all integration points between components that need testing for Task 11.6.

### High-Level Architecture Diagram

```
+------------------------------------------------------------------+
|                          CloudKit (iCloud)                        |
|                  iCloud.io.github.chmc.ListAll                    |
+------------------------------------------------------------------+
                               ^
                               | NSPersistentCloudKitContainer
                               | .coreDataRemoteChange notifications
                               v
+------------------------------------------------------------------+
|                   App Groups Shared Storage                       |
|                group.io.github.chmc.ListAll                       |
|                                                                    |
|  +----------------------------------------------------------+    |
|  |              Core Data SQLite Database                    |    |
|  |           (ListAll-Debug.sqlite / ListAll.sqlite)         |    |
|  +----------------------------------------------------------+    |
+------------------------------------------------------------------+
                               ^
                               | CoreDataManager.shared
                               v
+------------------------------------------------------------------+
|                        DataManager.shared                         |
|                     (@Published lists: [List])                    |
|                                                                    |
|  - loadData() - fetch from Core Data                             |
|  - saveData() - persist to Core Data                             |
|  - CRUD operations for Lists and Items                           |
+------------------------------------------------------------------+
                               ^
                               | DataRepository / Direct access
                               v
+------------------------------------------------------------------+
|                          ViewModels                               |
|                                                                    |
|  MainViewModel (@MainActor)                                       |
|  - @Published lists: [List]                                       |
|  - @Published archivedLists: [List]                              |
|  - loadLists(), addList(), moveList()                            |
|  - Edit mode tracking (isDragging, isEditModeActive)             |
|                                                                    |
|  ListViewModel                                                    |
|  - @Published items: [Item]                                       |
|  - loadItems(), createItem(), toggleItemCrossedOut()             |
|  - Filtering and sorting                                         |
+------------------------------------------------------------------+
                               ^
                               | @EnvironmentObject / @StateObject
                               v
+------------------------------------------------------------------+
|                      macOS Views (SwiftUI)                        |
|                                                                    |
|  MacMainView (NavigationSplitView)                               |
|  - MacSidebarView (list selection)                               |
|  - MacListDetailView (item management)                           |
|  - Sheet presentations (create/edit)                             |
+------------------------------------------------------------------+
                               ^
                               | NotificationCenter.default.post()
                               v
+------------------------------------------------------------------+
|                      AppCommands.swift                            |
|                    (macOS Menu Commands)                          |
|                                                                    |
|  Cmd+Shift+N -> "CreateNewList" notification                     |
|  Cmd+N       -> "CreateNewItem" notification                     |
|  Cmd+Delete  -> "ArchiveSelectedList" notification               |
|  Cmd+R       -> "RefreshData" notification                       |
|  Cmd+Shift+A -> "ToggleArchivedLists" notification               |
|  etc.                                                            |
+------------------------------------------------------------------+
```

---

## 2. Data Flow Integration Points

### 2.1 Views -> ViewModels Integration

**File:** `/Users/aleksi/source/listall/ListAll/ListAllMac/Views/MacMainView.swift`

| View Component | ViewModel | Connection Method | Data Flow |
|---------------|-----------|-------------------|-----------|
| MacMainView | DataManager | @EnvironmentObject | Bidirectional |
| MacSidebarView | DataManager | @EnvironmentObject | Read + Observe |
| MacListDetailView | ListViewModel | @StateObject | Bidirectional |

**Critical Integration Points:**

1. **DataManager Injection:**
   ```swift
   MacMainView()
       .environmentObject(dataManager)
       .environment(\.managedObjectContext, CoreDataManager.shared.viewContext)
   ```

2. **MacSidebarView observes DataManager directly:**
   ```swift
   // CRITICAL: Observe dataManager directly instead of receiving array by value
   // Passing [List] by value breaks SwiftUI observation chain on macOS
   @EnvironmentObject var dataManager: DataManager
   ```

3. **MacListDetailView creates its own ViewModel:**
   ```swift
   @StateObject private var viewModel: ListViewModel
   init(list: List, onEditItem: @escaping (Item) -> Void) {
       _viewModel = StateObject(wrappedValue: ListViewModel(list: list))
   }
   ```

### 2.2 ViewModels -> Services Integration

**File:** `/Users/aleksi/source/listall/ListAll/ListAll/ViewModels/MainViewModel.swift`

| ViewModel | Service | Method | Purpose |
|-----------|---------|--------|---------|
| MainViewModel | DataManager | loadData() | Fetch lists from Core Data |
| MainViewModel | DataRepository | reorderLists() | Handle drag-drop reordering |
| ListViewModel | DataManager | getItems(forListId:) | Fetch items |
| ListViewModel | DataRepository | createItem(), deleteItem() | CRUD operations |

**Critical Data Flow Pattern:**
```
User Action (drag list)
    -> MainViewModel.moveList()
        -> DataRepository.reorderLists()
            -> DataManager.updateList() x N
            -> DataManager.loadData() // Refresh cache
        -> MainViewModel.lists = updated
    -> SwiftUI re-renders
```

### 2.3 Services -> Core Data Integration

**File:** `/Users/aleksi/source/listall/ListAll/ListAll/Models/CoreData/CoreDataManager.swift`

| Service | Core Data Operation | Trigger |
|---------|---------------------|---------|
| DataManager.loadData() | NSFetchRequest<ListEntity> | Manual or notification |
| DataManager.saveData() | context.save() | After CRUD operations |
| DataManager.addList() | Create ListEntity | User creates list |
| CoreDataManager | NSPersistentStoreRemoteChange | CloudKit sync |

**Entity Relationships:**
```
ListEntity (1) <-->> (many) ItemEntity <-->> (many) ItemImageEntity
```

---

## 3. Notification-Based Integration

### 3.1 Menu Command Notifications

**File:** `/Users/aleksi/source/listall/ListAll/ListAllMac/Commands/AppCommands.swift`

| Menu Command | Notification Name | Handler Location |
|--------------|-------------------|------------------|
| New List (Cmd+Shift+N) | "CreateNewList" | MacMainView |
| New Item (Cmd+N) | "CreateNewItem" | MacListDetailView |
| Archive List (Cmd+Delete) | "ArchiveSelectedList" | MacMainView |
| Duplicate List (Cmd+D) | "DuplicateSelectedList" | MacMainView |
| Share List (Cmd+Shift+S) | "ShareSelectedList" | MacMainView |
| Export All (Cmd+Shift+E) | "ExportAllLists" | MacMainView |
| Toggle Archived (Cmd+Shift+A) | "ToggleArchivedLists" | MacMainView |
| Refresh (Cmd+R) | "RefreshData" | MacMainView |

**Example Integration Test Scenario:**
```
1. Press Cmd+Shift+N
2. Verify: showingCreateListSheet = true
3. Enter list name and save
4. Verify: New list appears in sidebar
```

### 3.2 CloudKit Sync Notifications

**File:** `/Users/aleksi/source/listall/ListAll/ListAll/Models/CoreData/CoreDataManager.swift`

| Notification | Posted By | Observed By | Action |
|--------------|-----------|-------------|--------|
| .NSPersistentStoreRemoteChange | Core Data/CloudKit | CoreDataManager | Refresh context |
| .coreDataRemoteChange | CoreDataManager | DataManager, ViewModels | Reload data |
| NSPersistentCloudKitContainer.eventChangedNotification | CloudKit | CoreDataManager | Log sync status |

**CloudKit Sync Flow:**
```
CloudKit receives remote change
    -> .NSPersistentStoreRemoteChange posted
    -> CoreDataManager.handlePersistentStoreRemoteChange()
        -> Debounce (500ms)
        -> viewContext.refreshAllObjects()
        -> Post .coreDataRemoteChange
            -> DataManager.handleRemoteChange()
                -> loadData()
            -> MainViewModel.handleCoreDataRemoteChange()
                -> loadLists()
            -> ListViewModel.handleRemoteChange()
                -> loadItems()
```

### 3.3 Edit State Protection Notifications

**File:** `/Users/aleksi/source/listall/ListAll/ListAllMac/Views/MacMainView.swift`

| Notification | Purpose |
|--------------|---------|
| "ItemEditingStarted" | Block sync during editing |
| "ItemEditingEnded" | Resume sync after editing |

**Critical for Testing:** Sync must NOT corrupt state during sheet presentation.

---

## 4. Cross-Platform Integration Points

### 4.1 App Groups Data Sharing (iOS <-> macOS)

**Configuration:**
- Group Identifier: `group.io.github.chmc.ListAll`
- Shared Resource: Core Data SQLite database
- Database Files:
  - Debug: `ListAll-Debug.sqlite` (CloudKit Development environment)
  - Release: `ListAll.sqlite` (CloudKit Production environment)

**File:** `/Users/aleksi/source/listall/ListAll/ListAll/Models/CoreData/CoreDataManager.swift`

```swift
// App Groups container URL configuration
let appGroupID = "group.io.github.chmc.ListAll"
if let containerURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupID) {
    let storeURL = containerURL.appendingPathComponent(databaseFileName)
    storeDescription.url = storeURL
}
```

### 4.2 CloudKit Sync (Device <-> Device)

**Container:** `iCloud.io.github.chmc.ListAll`

**Platform-Specific Behavior:**
- **macOS Debug:** CloudKit DISABLED (unsigned builds lack entitlements)
- **macOS Release:** CloudKit ENABLED
- **iOS Debug/Release:** CloudKit ENABLED

```swift
#if os(macOS) && DEBUG
container = NSPersistentContainer(name: "ListAll")
#else
container = NSPersistentCloudKitContainer(name: "ListAll")
#endif
```

### 4.3 Handoff Integration (iOS <-> macOS)

**File:** `/Users/aleksi/source/listall/ListAll/ListAll/Services/HandoffService.swift`

| Activity Type | UserInfo Keys | Navigation Target |
|--------------|---------------|-------------------|
| io.github.chmc.ListAll.browsing-lists | - | MainLists |
| io.github.chmc.ListAll.viewing-list | listId, listName | Specific list |
| io.github.chmc.ListAll.viewing-item | itemId, listId, itemTitle | Specific item |

**Handoff Flow:**
```
iOS: User views list
    -> HandoffService.startViewingListActivity(list:)
    -> NSUserActivity advertised via Bluetooth/WiFi

macOS: User clicks Handoff icon in Dock
    -> .onContinueUserActivity() triggers
    -> HandoffService.extractNavigationTarget()
    -> Post "HandoffNavigateToList" notification
    -> MacMainView selects list
```

---

## 5. Sheet Presentation Integration

### 5.1 Native AppKit Sheet Presenter

**File:** `/Users/aleksi/source/listall/ListAll/ListAllMac/Views/Components/MacNativeSheetPresenter.swift`

**Problem Solved:** SwiftUI sheets have RunLoop mode issues on macOS - they only present after app deactivation.

**Integration Pattern:**
```swift
// In MacMainView.swift
MacNativeSheetPresenter.shared.presentSheet(
    MacEditItemSheet(item: item, onSave: {...}, onCancel: {...}),
    onCancel: cancelAction
) {
    // Completion handler
    dataManager.loadData()
}
```

### 5.2 Sheet State Flow

```
User double-clicks item row
    -> MacItemRowView.onDoubleClick()
    -> MacListDetailView.onEditItem callback
    -> MacMainView.onEditItem handler
        -> isEditingAnyItem = true
        -> MacNativeSheetPresenter.presentSheet()
    -> User edits and saves
        -> dataManager.updateItem()
        -> MacNativeSheetPresenter.dismissSheet()
        -> isEditingAnyItem = false
        -> dataManager.loadData()
```

---

## 6. Export/Import Integration

### 6.1 Export Service Integration

**File:** `/Users/aleksi/source/listall/ListAll/ListAll/Services/ExportService.swift`

| Export Format | Method | Output |
|--------------|--------|--------|
| JSON | exportToJSON() | Data |
| CSV | exportToCSV() | String |
| Plain Text | exportToPlainText() | String |

**Integration Points:**
1. DataRepository -> ExportService (getAllLists, getItems)
2. ExportService -> NSPasteboard (copyToClipboard)
3. ExportService -> FileManager (exportToFile)

### 6.2 Share Integration

**File:** `/Users/aleksi/source/listall/ListAll/ListAllMac/Views/Components/MacShareFormatPickerView.swift`

```
User clicks Share button
    -> MacShareFormatPickerView presented
    -> User selects format
    -> SharingService.share(format:list:)
    -> NSSavePanel for file export OR NSPasteboard for clipboard
```

---

## 7. UI Test Integration Points

### 7.1 Test Data Service

**File:** `/Users/aleksi/source/listall/ListAll/ListAll/Services/UITestDataService.swift`

| Launch Argument | Effect |
|-----------------|--------|
| UITEST_MODE | Enable test mode |
| SKIP_TEST_DATA | Don't populate test data |
| DISABLE_TOOLTIPS | Disable tooltip hints |
| FORCE_LIGHT_MODE | Force light appearance |

**Test Database Isolation:**
```swift
if isUITest {
    let storeURL = documentsURL.appendingPathComponent("ListAll-UITests.sqlite")
    storeDescription.url = storeURL
}
```

### 7.2 Accessibility Identifiers for Testing

| View Element | Accessibility Identifier |
|-------------|-------------------------|
| Sidebar | "ListsSidebar" |
| List row | "SidebarListCell_\(list.name)" |
| Add List button | "AddListButton" |
| Add Item button | "AddItemButton" |
| Item row | "ItemRow_\(item.title)" |
| Search field | "ListSearchField" |
| Filter/Sort button | "FilterSortButton" |

---

## 8. Integration Test Requirements

Based on this architecture analysis, the following integration tests are needed:

### 8.1 Data Layer Integration Tests

| Test ID | Description | Components |
|---------|-------------|------------|
| DL-1 | List CRUD operations persist to Core Data | DataManager <-> CoreDataManager |
| DL-2 | Item CRUD operations persist correctly | DataManager <-> CoreDataManager |
| DL-3 | Drag-drop reorder updates orderNumber | DataRepository <-> DataManager |
| DL-4 | Data loads correctly after app restart | CoreDataManager persistence |

### 8.2 CloudKit Sync Integration Tests

| Test ID | Description | Components |
|---------|-------------|------------|
| CK-1 | Remote changes trigger UI refresh | CoreDataManager -> DataManager -> Views |
| CK-2 | Local changes don't trigger false remote sync | CoreDataManager.isLocalSave |
| CK-3 | Edit mode blocks sync interruption | isEditingAnyItem protection |
| CK-4 | Sync debouncing prevents rapid reloads | 500ms debounce timer |

### 8.3 Menu Command Integration Tests

| Test ID | Description | Components |
|---------|-------------|------------|
| MC-1 | Cmd+Shift+N opens create list sheet | AppCommands -> MacMainView |
| MC-2 | Cmd+N opens create item sheet | AppCommands -> MacListDetailView |
| MC-3 | Cmd+R refreshes data | AppCommands -> DataManager |
| MC-4 | Cmd+Shift+A toggles archived view | AppCommands -> MacMainView |

### 8.4 Sheet Presentation Integration Tests

| Test ID | Description | Components |
|---------|-------------|------------|
| SP-1 | Edit sheet presents immediately on double-click | MacNativeSheetPresenter |
| SP-2 | Edit sheet saves changes correctly | Sheet -> DataManager |
| SP-3 | Cancel dismisses without saving | Sheet state management |
| SP-4 | ESC key dismisses sheet | SheetHostingController |

### 8.5 Cross-Platform Integration Tests

| Test ID | Description | Components |
|---------|-------------|------------|
| CP-1 | Handoff advertises current activity | HandoffService |
| CP-2 | Incoming Handoff navigates correctly | NSUserActivity handling |
| CP-3 | App Groups container accessible | FileManager + App Groups |

### 8.6 Export/Import Integration Tests

| Test ID | Description | Components |
|---------|-------------|------------|
| EI-1 | JSON export includes all data | ExportService <-> DataRepository |
| EI-2 | Copy to clipboard works | ExportService <-> NSPasteboard |
| EI-3 | File export creates valid file | ExportService <-> FileManager |

---

## 9. Known Integration Issues (From Learnings)

### 9.1 SwiftUI NavigationSplitView Animation Bug

**Source:** `/Users/aleksi/source/listall/documentation/learnings/macos-native-sheet-presentation.md`

**Problem:** NavigationSplitView breaks SwiftUI's animation system, causing sheets to queue but not present.

**Solution:** Use NavigationStack with explicit animation path inside NavigationSplitView.

### 9.2 CloudKit Sync During Drag Operations

**Source:** `/Users/aleksi/source/listall/documentation/learnings/swiftui-list-drag-drop-ordering.md`

**Problem:** CloudKit sync during drag-drop can corrupt list order.

**Solution:** Block sync when `isDragging` or `isEditModeActive` is true.

### 9.3 @Published Updates from Background Thread

**Problem:** @objc selectors called by NotificationCenter may run on background thread.

**Solution:** Always guard with `Thread.isMainThread` check:
```swift
guard Thread.isMainThread else {
    DispatchQueue.main.async { [weak self] in
        self?.handleRemoteChange(notification)
    }
    return
}
```

---

## 10. Summary

### Key Integration Boundaries

1. **CoreDataManager <-> DataManager:** Core Data fetch/persist operations
2. **DataManager <-> ViewModels:** @Published observation chain
3. **ViewModels <-> Views:** @EnvironmentObject/@StateObject binding
4. **AppCommands <-> Views:** NotificationCenter.default communication
5. **CloudKit <-> CoreDataManager:** Remote change notifications
6. **HandoffService <-> App:** NSUserActivity management

### Critical Test Focus Areas

1. **Data consistency** across all layers
2. **Notification delivery** and handling
3. **Thread safety** for @Published updates
4. **Edit state protection** during sync
5. **Sheet presentation** reliability
6. **Cross-platform** data sharing

### Files to Monitor in Integration Tests

- `/Users/aleksi/source/listall/ListAll/ListAll/Models/CoreData/CoreDataManager.swift`
- `/Users/aleksi/source/listall/ListAll/ListAllMac/Views/MacMainView.swift`
- `/Users/aleksi/source/listall/ListAll/ListAll/ViewModels/MainViewModel.swift`
- `/Users/aleksi/source/listall/ListAll/ListAllMac/Commands/AppCommands.swift`
- `/Users/aleksi/source/listall/ListAll/ListAll/Services/HandoffService.swift`
- `/Users/aleksi/source/listall/ListAll/ListAll/Services/ExportService.swift`
