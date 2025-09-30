# ListAll App - Development Tasks

## Phase Organization
**Note**: Phases are organized as sequential numbered phases for better task management and clear progression tracking.

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

## Phase 17: Image Library Integration
- ❌ Implement photo library access
- ❌ Add image compression and optimization

## Phase 18: Image Display and Storage
- ❌ Create thumbnail generation system
- ❌ Implement image display in item details

## Phase 19: Basic Export
- ❌ Implement ExportService for data export
- ❌ Create JSON export format
- ❌ Add CSV export format
- ❌ Create ExportView UI

## Phase 20: Advanced Export
- ❌ Implement plain text export
- ❌ Add export options and customization
- ❌ Implement clipboard export functionality

## Phase 21: Basic Import
- ❌ Implement ImportService for data import
- ❌ Add JSON import functionality
- ❌ Create import validation and error handling

## Phase 22: Advanced Import
- ❌ Implement conflict resolution for imports
- ❌ Add import preview functionality
- ❌ Create import progress indicators

## Phase 23: Sharing Features
- ❌ Implement SharingService for list sharing
- ❌ Add system share sheet integration
- ❌ Create custom share formats
- ❌ Implement URL scheme for deep linking
- ❌ Add share preview functionality
- ❌ Create share validation and error handling

## Phase 24: Basic Settings
- ❌ Create SettingsView for app preferences
- ❌ Implement export preferences

## Phase 25: Advanced Settings
- ❌ Add sync settings and status
- ❌ Create about and help sections
- ❌ Add privacy and data management options

## Phase 26: Search and Filtering
- ❌ Implement global search functionality
- ❌ Add search filters and sorting options
- ❌ Create bulk operations for items

## Phase 27: Templates and Accessibility
- ❌ Implement list templates and categories
- ❌ Add keyboard shortcuts and accessibility
- ❌ Create onboarding flow for new users

## Phase 28: Performance Basics
- ❌ Implement lazy loading for large lists
- ❌ Add pagination for very large datasets
- ❌ Optimize image loading and caching

## Phase 29: Advanced Performance
- ❌ Implement memory management strategies
- ❌ Add performance monitoring and analytics
- ❌ Create database optimization routines

## Phase 30: CloudKit Capability Setup (Pre-Release Requirement)
- ❌ **Enable CloudKit capability in project settings** (requires paid Apple Developer account - $99/year)
- ❌ **Test CloudKit integration with multiple devices** (requires physical devices with iCloud accounts)
- ❌ **Implement data validation for CloudKit sync** (optional enhancement)

### CloudKit Capability Details:
- **Current Status**: CloudKit integration code is complete and ready
- **Blocking Issue**: Free Apple ID cannot add iCloud capability to Xcode project
- **Required Action**: Upgrade to paid Apple Developer Program ($99/year)
- **Alternative**: Continue development without CloudKit sync (app works locally only)
- **Impact**: Without CloudKit capability, sync features will show "offline" status
- **Timing**: Complete this before Phase 30 (Polish and Release) when preparing for App Store

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
- ✅ ServicesTests: 100% passing (1/1 tests) - Fixed by removing deprecated resetSharedSingletons() calls  
- ✅ ModelTests: 100% passing (24/24 tests) - Fixed by adding @Suite(.serialized) for test isolation
- ✅ ViewModelsTests: 100% passing (46/46 tests) - Fixed by adding @Suite(.serialized) + async timing fix + Phase 8 show/hide tests
- 🎯 **OVERALL UNIT TESTS: 100% PASSING (101/101 tests)** - COMPLETE SUCCESS!
- ✅ Test Infrastructure: Complete with TestHelpers for isolation (createTestMainViewModel, createTestItemViewModel, etc.)
- ✅ Major Fix Applied: Removed all deprecated resetSharedSingletons() calls and updated to use new isolated test infrastructure

## Phase 31: Polish and Release
- ❌ Implement app icon and launch screen
- ❌ Add haptic feedback for interactions
- ❌ Create smooth animations and transitions
- ❌ Implement dark mode support
- ❌ Add localization support
- ❌ Create App Store assets and metadata
- ❌ Prepare for TestFlight and App Store submission

## Phase 32: Documentation
- ❌ Create user documentation and help
- ❌ Add inline code documentation
- ❌ Create API documentation for services
- ❌ Add troubleshooting guides
- ❌ Create developer documentation
- ❌ Update README with setup instructions

## Phase 33: Future Platform Support
- ❌ Design watchOS app architecture
- ❌ Plan macOS app adaptation
- ❌ Research Android app requirements
- ❌ Create shared data models for multi-platform
- ❌ Design cross-platform synchronization
- ❌ Plan platform-specific UI adaptations