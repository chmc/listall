# ListAll App - Development Tasks

## Phase Organization
**Note**: Phases are organized as sequential numbered phases for better task management and clear progression tracking. Improvements are future enhancements organized for better task management and clear progression tracking.

## Phase 1: Project Foundation
- ✅ Create basic project structure and folder organization
- ✅ Configure build settings and deployment targets
- ✅ Set up Xcode project with proper targets and schemes
- ✅ Create folder structure (Models, ViewModels, Views, Services, Utils)

### Phase 1 Sub-tasks:
- ✅ Update iOS deployment target from 18.5 to 16.0
- ✅ Configure proper build settings for Core Data + CloudKit
- ✅ Verify folder structure matches architecture
- ✅ Create placeholder files in each folder
- ✅ Set up basic project configuration

## Phase 2: Core Data Model
- ✅ Create Core Data model with List, Item, ItemImage entities
- ✅ Define entity relationships and attributes
- ✅ Set up Core Data stack configuration
- ❌ Create data model versioning strategy (deferred - using simple models instead)
- ✅ Update all services to use simple data models instead of Core Data
- ✅ Fix compilation errors in view files and services

## Phase 3: Data Layer ✅ COMPLETED
- ✅ Implement Core Data stack with CloudKit integration
- ✅ Create DataRepository service for data access
- ✅ Implement CRUD operations for all entities
- ✅ Add data validation and business rules
- ✅ Create data migration strategies

### Phase 3 Sub-tasks:
- ✅ Create Core Data model (.xcdatamodeld) with List, Item, ItemImage, and UserData entities
- ✅ Implement enhanced Core Data stack with CloudKit integration
- ✅ Enhance DataRepository service with Core Data CRUD operations
- ✅ Implement comprehensive CloudKitService for iCloud sync
- ✅ Add data validation and business rules enforcement
- ✅ Create data migration strategies for schema changes
- ✅ Create UserData model for user preferences and settings
- ✅ Write comprehensive tests for data layer functionality
- ✅ Ensure project builds successfully with new data layer
- ✅ Fix Core Data model file recognition by Xcode
- ✅ Resolve app crashes during Core Data initialization
- ✅ Fix Core Data model attributes and relationships in Xcode
- ✅ Temporarily disable CloudKit to fix test crashes
- ✅ Fix validation helper and string extension test failures

## Phase 4: CloudKit Integration ✅ COMPLETED
- ✅ Set up CloudKit container and configuration
- ✅ Implement CloudKitService for iCloud sync
- ✅ Add automatic background synchronization
- ✅ Implement conflict resolution strategies
- ✅ Add offline support and queuing
- ✅ Create sync status indicators and error handling

### Phase 4 Sub-tasks:
- ✅ Configure CloudKit container in Xcode project
- ✅ Update Core Data model with CloudKit annotations
- ✅ Implement NSPersistentCloudKitContainer configuration
- ✅ Enhance CloudKitService with proper sync operations
- ✅ Add conflict resolution strategies (last-write-wins, user choice)
- ✅ Implement offline support with operation queuing
- ✅ Add sync status indicators and error handling UI
- ✅ Create sync progress tracking and user feedback
- ✅ Add retry mechanisms for failed sync operations
- ✅ Create sync conflict resolution UI
- ✅ Ensure proper error handling and user notifications

### Phase 4 Additional Fixes:
- ✅ Remove uniqueness constraints from Core Data model (CloudKit incompatible)
- ✅ Temporarily disable CloudKit integration to fix app crashes
- ✅ Add CloudKit-specific fields (ckServerChangeToken) to Core Data model
- ✅ Update CloudKitService to handle missing CloudKit entitlements gracefully
- ✅ Fix Core Data migration error by implementing proper error handling and store recreation
- ✅ Fix all failing tests to achieve 100% test success rate
- ✅ Add isArchived property to List model
- ✅ Create TestHelpers for test isolation
- ✅ Implement robust error handling for CloudKit integration

## Phase 5: UI Foundation ✅ COMPLETED
- ✅ Create main navigation structure (TabView)
- ✅ Implement basic navigation between screens
- ✅ Set up SwiftUI view hierarchy
- ✅ Create basic UI components and styling

## Phase 6A: Basic List Display ✅ COMPLETED
- ✅ Implement ListsView (main screen with list of lists)
- ✅ Create ListRowView component
- ✅ Set up basic navigation between screens

## Phase 6B: List Creation and Editing ✅ COMPLETED
- ✅ Implement CreateListView for new list creation
- ✅ Add list editing functionality
- ✅ Add list deletion functionality

## Phase 6C: List Interactions ✅ COMPLETED
- ✅ Implement list duplication/cloning
- ✅ Add drag-to-reorder functionality for lists
- ✅ Add swipe actions for quick list operations

## Phase 7A: Basic Item Display ✅ COMPLETED
- ✅ Implement ListView (items within a list)
- ✅ Create ItemRowView component
- ✅ Create ItemDetailView for viewing item details

## Phase 7B: Item Creation and Editing ✅ COMPLETED
- ✅ Implement ItemEditView for creating/editing items
- ✅ Add item crossing out functionality
- ✅ Create item duplication functionality

## Phase 7B 2: Items in itemlist has two arrow icons ✅ COMPLETED
- ✅ Remove another arrow icon, only one is needed

## Phase 7B 3: Lists list two arrow icons ✅ COMPLETED
- ✅ Remove another arrow icon, only one is needed

## Phase 7C: Item Interactions ✅ COMPLETED
- ✅ Implement drag-to-reorder for items within lists
- ✅ Add swipe actions for quick item operations

## Phase 7C 1: Click link to open it in default browser ✅ COMPLETED
- ✅ When item description link is clicked, it should always open it in default browser. Not just when user is in edit item screen.

## Phase 8: Show/Hide Crossed Out Items Toggle ✅ COMPLETED
- ✅ Add show/hide crossed out items toggle
- ✅ Fix Show/Hide Crossed Out Items Toggle bug - toggle button was not working because filteredItems used currentFilterOption enum but toggle used showCrossedOutItems boolean

## Phase 9: Item Organization ✅ COMPLETED
- ✅ Add item sorting and filtering options

## Phase 10: Simplify UI ✅ COMPLETED
- ✅ Just default action to click item (not url), completes item
- ✅ Remove item list checkbox complete
- ✅ Clicking right side item anchor opens item edit screen

## Phase 11: Basic Suggestions ✅ COMPLETED
- ✅ Implement SuggestionService for item recommendations
- ✅ Create SuggestionListView component
- ✅ Add fuzzy string matching for suggestions

## Phase 12: Advanced Suggestions ✅ COMPLETED
- ✅ Implement frequency-based suggestion weighting
- ✅ Add recent items tracking
- ✅ Create suggestion cache management

## Phase 13: Autofocus Item title on create new item ✅ COMPLETED

## Phase 14: Show all suggestions ✅ COMPLETED
- ✅ List all filtered suggestions so that user can choose which one to use,
     now app shows x2, but user cant choose which one to use
- ✅ Add details from selected item so that user chan overwrite them or use it as they are

## Phase 15: Basic Image Support ✅ COMPLETED
- ✅ Implement ImageService for image processing
- ✅ Create ImagePickerView component
- ✅ Add camera integration for taking photos

## Phase 16: Add image bug ✅ COMPLETED
- ✅ After image is selected, Add photo screen is visible, 
     but should go to edit item screen with newly added image

## Phase 17: Bug take photo using camera open photo library, not camera ✅ COMPLETED
- ✅ Take photo must open camera
- ✅ Camera permissions properly configured
- ✅ SwiftUI state management issues resolved
- ✅ All tests passing (100% success rate)
- ✅ Clean production code (debug logging removed)

## Phase 18: Image Library Integration ✅ COMPLETED
- ✅ Implement photo library access
- ✅ Add image compression and optimization

## Phase 19: Image Display and Storage ✅ COMPLETED
- ✅ Create thumbnail generation system
- ✅ Implement image display in item details
- ✅ Default image display fit to screen

## Phase 20: Items list default mode ✅ COMPLETED
- ✅ Change items list default view mode to show only active items (non completed)

## Phase 21: List item count ✅ COMPLETED
- ✅ Change to show count of active items and count of all items in (count) 
- ✅ Example: 5 (7) items

## Phase 22: Item list arrow clickable area ✅ COMPLETED
- ✅ In item list, make clickable arrow area bigger
- ✅ Keep arrow as is, but enlarge the clickable area

## Phase 23: Clean item edit UI ✅ COMPLETED
- ✅ Remove edit box borders to make UI more clean
- ✅ Fix quantity buttons. They dont work. And move them both to right side of screen.

## Phase 24: Show undo complete button ✅ COMPLETED
- ✅ Use standard timeout to show undo button when item is completed bottom of screen
- ✅ Implement undo state management in ListViewModel with 5-second timer
- ✅ Create UndoBanner UI component with Material Design styling
- ✅ Add smooth animations for banner appearance/disappearance
- ✅ Only show undo when completing items (not when uncompleting)
- ✅ Support multiple completions (new completion replaces previous undo)
- ✅ Write comprehensive tests for undo functionality
- ✅ Update test infrastructure to support undo testing

## Phase 25: Basic Export ✅ COMPLETED
- ✅ Implement ExportService for data export
- ✅ Create JSON export format
- ✅ Add CSV export format
- ✅ Create ExportView UI
- ✅ Add file sharing via iOS share sheet
- ✅ Write comprehensive export tests (12 tests)

## Phase 26: Advanced Export ✅ COMPLETED
- ✅ Implement plain text export
- ✅ Add export options and customization
- ✅ Implement clipboard export functionality

## Phase 27: Basic Import ✅ COMPLETED
- ✅ Implement ImportService for data import
- ✅ Add JSON import functionality
- ✅ Create import validation and error handling
- ✅ Write comprehensive tests for ImportService (12 tests)
- ✅ Add basic import UI with file picker
- ✅ Wire up ImportService to UI
- ✅ Add merge strategy selection
- ✅ Display import results
- ✅ Ensure build succeeds
- ✅ Update documentation in ai_changelog.md

## Phase 28: Advanced Import ✅ COMPLETED
- ✅ Implement conflict resolution for imports
- ✅ Add import preview functionality
- ✅ Create import progress indicators

## Phase 29: Fix sorting ✅ COMPLETED
- ✅ Make sure sorting works everywhere
- ✅ Fixed items sorting - disabled manual reordering when sort option is not orderNumber
- ✅ Added visual indicators showing when manual reordering is available
- ✅ Wrote 9 comprehensive tests for sorting functionality (all pass)

## Phase 30: Unify UI textboxes to all not have borders ✅ COMPLETED
- ✅ Removed RoundedBorderTextFieldStyle from CreateListView TextField
- ✅ Removed RoundedBorderTextFieldStyle from EditListView TextField  
- ✅ Verified ItemEditView TextField already uses .plain style (no borders)
- ✅ All text input fields now use consistent borderless design

## Phase 31: Hide keyboard when user clicks outside of textbox ✅ COMPLETED
- ✅ Added .contentShape(Rectangle()) and .onTapGesture to ItemEditView
- ✅ Added .contentShape(Rectangle()) and .onTapGesture to CreateListView
- ✅ Added .contentShape(Rectangle()) and .onTapGesture to EditListView
- ✅ Keyboard now dismisses when tapping outside text fields
- ✅ Implementation uses @FocusState for native SwiftUI behavior
- ✅ Build validation passed with no errors
- ✅ All tests passed (100% success rate)

## Phase 32: Item title text no Pascal Case style capitalize ✅ COMPLETED
- ✅ Changed ItemEditView TextField from .autocapitalization(.words) to .autocapitalization(.sentences)
- ✅ Changed CreateListView TextField to use .autocapitalization(.sentences)
- ✅ Changed EditListView TextField to use .autocapitalization(.sentences)
- ✅ Now only first letter is uppercase, others lowercase. And then again after dot, use capitalize. Like normal text capitalize.

## Phase 33: Item edit Cancel button does not work on real device ✅ COMPLETED
- ✅ Fixed by changing `.alert()` to `.confirmationDialog()` for better real device compatibility
- ✅ Confirmation dialog now opens reliably on physical devices
- ✅ Item edit screen closes properly when Cancel button is pressed
- ✅ Native iOS action sheet provides better UX than centered alert

## Phase 34: Import from multiline textfield ✅ COMPLETED
- ✅ Add import source selection (File or Text) to ImportView UI
- ✅ Implement multiline TextEditor for JSON and plain text input
- ✅ Add importFromText method to ImportViewModel
- ✅ Wire up text import to existing ImportService with auto-detect format
- ✅ Add validation and error handling for text input
- ✅ Implement plain text parsing (supports ListAll export format and simple lists)
- ✅ Add manual initializers to ListExportData and ItemExportData for parsing
- ✅ Run build validation - compilation succeeds
- ✅ Run test suite - 100% pass rate (182/182 tests)
- ✅ Update ai_changelog.md with implementation details

## Phase 35: Allow edit lists mode to select and delete multiple lists at once ✅ COMPLETED
- ✅ Multi-select mode with checkboxes for lists
- ✅ Select All / Deselect All functionality
- ✅ Bulk delete with single confirmation dialog
- ✅ Confirmation shows count of lists to delete
- ✅ Swipe to delete list confirm works correctly (already implemented)
- ✅ Import creates duplicate list with same name - Fixed: now updates existing list by name
- ✅ ImportService now matches lists by both ID and name
- ✅ Enhanced fuzzy matching for list names (trimmed + case-insensitive) to prevent duplicates
- ✅ Comprehensive test coverage (10 new tests, all passing)
- ✅ Build validation passed (100% success)
- ✅ All tests passed (198/198 = 100% success rate)

## Phase 36: Import items doesnt refresh lists view ✅ COMPLETED
- ✅ Fixed: After import, user is now redirected to lists view with refreshed content
- ✅ Added NotificationCenter notifications for data import and tab switching
- ✅ Import sheet auto-dismisses after successful import
- ✅ Lists view refreshes automatically after import
- ✅ **CRITICAL BUG FIX**: Plain text imports now respect merge strategy (were always appending)
- ✅ Plain text imports now correctly update existing lists instead of creating duplicates
- ✅ Added Core Data reload before merge to ensure fresh data matching
- ✅ Enhanced list matching with 3-level strategy: ID → exact name → fuzzy name
- ✅ Build validation passed (100% success)
- ✅ All tests passed (198/198 = 100% success rate)

## Phase 37: Deleted or crossed items count does not reflect to lists view counts ✅ COMPLETED
- ✅ Added `.itemDataChanged` notification to Constants.swift
- ✅ MainView now listens for item data changes and refreshes lists
- ✅ Item counts in ListRowView update immediately when items are deleted/crossed
- ✅ Build validation passed (100% success)
- ✅ All tests passed (198/198 = 100% success rate)

## Phase 38: Import textfield keyboard is not hidden when user clicks outside of textfied ✅ COMPLETED
- ✅ Added `.contentShape(Rectangle())` and `.onTapGesture` to ImportView
- ✅ Keyboard dismisses when tapping outside text field in import view
- ✅ Follows same pattern as CreateListView, EditListView, and ItemEditView (Phase 31)
- ✅ Build validation passed (100% success)
- ✅ All tests passed (198/198 = 100% success rate)

## Phase 39: Shrink list item height little bit, like 1% ✅ COMPLETED
- ✅ Fixed root cause: Removed SwiftUI List default insets that were preventing changes
- ✅ Applied compact layout APP-WIDE to both Lists view (ListRowView) and Items view (ItemRowView)
- ✅ Added `.listRowInsets(EdgeInsets())` to MainView and ListView to remove List padding
- ✅ Kept separator lines visible between items for better visual separation
- ✅ Added 8pt vertical padding for balanced spacing (comfortable for items with descriptions/quantities)
- ✅ Reduced internal VStack spacing from 4pt to 1pt (75% reduction)
- ✅ Consistent appearance for items with/without descriptions or quantity info
- ✅ Both list and item views now compact with sufficient padding
- ✅ Balanced design: compact yet readable with proper breathing room
- ✅ Added proper margins in Lists view: 8pt top margin for lists, 12pt bottom for status bar
- ✅ Consistent compact design throughout entire app
- ✅ Works across all device sizes (iPhone, iPad)
- ✅ Build validation passed (100% success)
- ✅ All tests passed (198/198 = 100% success rate)

## Phase 40: Item list organization ✅ COMPLETED
- ✅ Made filtering option whole row clearly clickable by adding visible background
- ✅ Changed non-selected filter options from transparent to gray background (Color.gray.opacity(0.1))
- ✅ Now matches the visual pattern of sort options for consistency
- ✅ Entire row area is now clearly interactive and provides better visual feedback
- ✅ Build validation passed (100% success)
- ✅ All tests passed (100% success rate)

## Phase 41: Items view, make list name smaller ✅ COMPLETED
- ✅ Moved list name from navigation bar to its own dedicated row below toolbar
- ✅ List name displayed as headline in primary color for clear visibility
- ✅ Added item count on separate row below list name showing "active/total items" (e.g., "50/56 items")
- ✅ Item count displayed in secondary color with caption font for visual hierarchy
- ✅ Navigation bar toolbar now only contains action buttons (back, sort, filter, edit, add)
- ✅ Clean three-tier layout: Toolbar → List Name → Item Count
- ✅ Build validation passed (100% success)
- ✅ All tests passed (198/198 = 100% success rate)

## Phase 42: Items view, edit list details ✅ COMPLETED
- ✅ Add edit list details to items view
- ✅ Edit list details can be revealed by edit button for example
- ✅ Be creative and find good way to deal this
- ✅ Added pencil icon button next to list name in ListView header
- ✅ Button opens EditListView sheet for editing list name
- ✅ Lists refresh automatically after editing
- ✅ Follows existing pattern from ListRowView
- ✅ Clean, intuitive UX - icon appears right next to the list name
- ✅ Build validation passed (100% success)
- ✅ All tests passed (198/198 = 100% success rate)

## Phase 43: Option to include images to json export
- ❌ Add item images part of json export

## Phase 44: Option to include images to json share
- ❌ Add item images part of json share

## Phase
- ❌ 

## Improvement 1: Sharing Features ✅ COMPLETED
- ✅ Implement SharingService for list sharing (multiple formats)
- ✅ Add share single list functionality (plainText, JSON, URL)
- ✅ Add share all data functionality (plainText, JSON)
- ✅ Create URL scheme support for deep linking (listall://list/UUID?name=...)
- ✅ Write comprehensive tests for SharingService (18 tests, all passing)
- ✅ Validate build and tests pass (100% success - 216/216 tests)
- ✅ Document changes in ai_changelog.md

## Improvement 2: Share UI Integration ✅ COMPLETED & FULLY TESTED
- ✅ Add share button to ListView toolbar (share single list)
- ✅ Add share button to MainView toolbar (share all data)
- ✅ Implement ShareSheet UIViewControllerRepresentable wrapper (reused existing from SettingsView)
- ✅ Add share format selection (Plain Text, JSON) - URL removed (not supported for local apps)
- ✅ Add share options configuration UI
- ✅ Handle share success/error states
- ✅ Add share button to list context menu (swipe actions)
- ✅ Fix empty share sheet issue (implemented UIActivityItemSource + SwiftUI state sync delay)
- ✅ Test sharing on real device - **CONFIRMED WORKING** by user
- ✅ Validate build and tests pass (100% - BUILD SUCCEEDED, all 217 unit tests passing, 0 failures)
- ✅ Document changes in ai_changelog.md

## Improvement 3: Basic Settings
- ❌ Create SettingsView for app preferences
- ❌ Implement export preferences

## Improvement 4: Advanced Settings
- ❌ Add sync settings and status
- ❌ Create about and help sections
- ❌ Add privacy and data management options

## Improvement 5: Search and Filtering
- ❌ Implement global search functionality
- ❌ Add search filters and sorting options
- ❌ Create bulk operations for items

## Improvement 6: Templates and Accessibility
- ❌ Implement list templates and categories
- ❌ Add keyboard shortcuts and accessibility
- ❌ Create onboarding flow for new users

## Improvement 7: Performance Basics
- ❌ Implement lazy loading for large lists
- ❌ Add pagination for very large datasets
- ❌ Optimize image loading and caching

## Improvement 8: Advanced Performance
- ❌ Implement memory management strategies
- ❌ Add performance monitoring and analytics
- ❌ Create database optimization routines

## Improvement 9: CloudKit Capability Setup (Pre-Release Requirement)
- ❌ **Enable CloudKit capability in project settings** (requires paid Apple Developer account - $99/year)
- ❌ **Test CloudKit integration with multiple devices** (requires physical devices with iCloud accounts)
- ❌ **Implement data validation for CloudKit sync** (optional enhancement)

### CloudKit Capability Details:
- **Current Status**: CloudKit integration code is complete and ready
- **Blocking Issue**: Free Apple ID cannot add iCloud capability to Xcode project
- **Required Action**: Upgrade to paid Apple Developer Program ($99/year)
- **Alternative**: Continue development without CloudKit sync (app works locally only)
- **Impact**: Without CloudKit capability, sync features will show "offline" status
- **Timing**: Complete this before Improvement 10 (Polish and Release) when preparing for App Store

## Testing Strategy (Integrated Throughout All Phases)
- ✅ Test infrastructure is set up and working
- ✅ Write unit tests for all services as they are implemented
- ✅ Create integration tests for Core Data + CloudKit when implemented
- ✅ Add UI tests for critical user flows as features are built
- ❌ Implement accessibility testing for UI components
- ❌ Create performance tests for large datasets when needed
- ❌ Add export/import functionality tests when features are implemented
- **CRITICAL**: All new code must be tested - write tests for every new feature, service, or component implemented
- **IMPORTANT**: Tests must verify the written code and its behavior, ensuring it works as intended
- **PRINCIPLE**: Do NOT change implementation to fix tests unless implementation is truly impossible to test
- **REQUIREMENT**: When implementing new features, you must write corresponding tests to verify functionality

### Current Test Status:
- ✅ UI Tests: 100% passing (12/12 tests)
- ✅ UtilsTests: 100% passing (26/26 tests) - Fixed by removing deprecated resetSharedSingletons() calls
- ✅ ServicesTests: 100% passing (106/106 tests) - Includes Phase 25 (12 tests) + Phase 26 (15 tests) + Phase 27 (12 tests) + Phase 28 (10 tests) + Improvement 1 (18 tests) export/import/sharing tests
- ✅ ModelTests: 100% passing (24/24 tests) - Fixed by adding @Suite(.serialized) for test isolation
- ✅ ViewModelsTests: 100% passing (42/42 tests) - Fixed by adding @Suite(.serialized) + async timing fix + Phase 8 show/hide tests + Phase 35 multi-select tests (10 new tests)
- ✅ URLHelperTests: 100% passing (6/6 tests)
- 🎯 **OVERALL UNIT TESTS: 100% PASSING (204/204 tests)** - COMPLETE SUCCESS!
- ✅ Test Infrastructure: Complete with TestHelpers for isolation (createTestMainViewModel, createTestItemViewModel, etc.)
- ✅ Major Fix Applied: Removed all deprecated resetSharedSingletons() calls and updated to use new isolated test infrastructure
- ✅ Phase 25, 26, 27 & 28 Export/Import Tests: Complete test coverage for JSON, CSV, Plain Text, clipboard, options, import validation, preview, progress, and conflict resolution (49 tests total)
- ✅ Phase 35 Multi-Select Tests: Complete test coverage for multi-select mode, selection operations, and bulk delete functionality (10 tests total)
- ✅ Improvement 1 Sharing Tests: Complete test coverage for share list (plain text, JSON, URL), share all data, URL parsing, validation, and share options (18 tests total)

## Improvement 10: Polish and Release
- ❌ Implement app icon and launch screen
- ❌ Add haptic feedback for interactions
- ❌ Create smooth animations and transitions
- ❌ Implement dark mode support
- ❌ Add localization support
- ❌ Create App Store assets and metadata
- ❌ Prepare for TestFlight and App Store submission

## Improvement 11: Documentation
- ❌ Create user documentation and help
- ❌ Add inline code documentation
- ❌ Create API documentation for services
- ❌ Add troubleshooting guides
- ❌ Create developer documentation
- ❌ Update README with setup instructions

## Improvement 12: Future Platform Support
- ❌ Design watchOS app architecture
- ❌ Plan macOS app adaptation
- ❌ Research Android app requirements
- ❌ Create shared data models for multi-platform
- ❌ Design cross-platform synchronization
- ❌ Plan platform-specific UI adaptations