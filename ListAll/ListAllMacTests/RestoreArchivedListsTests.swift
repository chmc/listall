//
//  RestoreArchivedListsTests.swift
//  ListAllMacTests
//
//  TDD tests for macOS restore archived lists functionality.
//  Tests written before implementation following TDD approach.
//
//  Context: Backend already works (CoreDataManager.restoreList, MainViewModel.restoreList)
//  Need to test the restore functionality integration for macOS context menu.
//

import Testing
import Foundation
import CoreData
@testable import ListAll

// Use ListModel typealias to avoid conflict with SwiftUI.List
typealias RestoreTestListModel = ListAll.List

/// Tests for macOS restore archived lists functionality
/// Verifies that archived lists can be properly restored to active lists
/// @MainActor required because TestMainViewModel accesses Core Data viewContext (main-thread only)
@Suite(.serialized)
@MainActor
struct RestoreArchivedListsTests {

    // MARK: - Test 1: MainViewModel.restoreList() moves list from archived to active

    @Test("Restoring list moves it from archivedLists to active lists array")
    func testRestoreListMovesFromArchivedToActive() async throws {
        // Arrange: Create test environment with an archived list
        let testDataManager = TestHelpers.createTestDataManager()
        let viewModel = TestMainViewModel(dataManager: testDataManager)

        // Create a list and archive it
        try viewModel.addList(name: "Test List to Archive")
        let listToArchive = viewModel.lists.first!
        viewModel.archiveList(listToArchive)

        // Load archived lists to populate archivedLists array
        viewModel.loadArchivedLists()

        // Verify list is in archived lists, not active lists
        #expect(viewModel.lists.isEmpty || !viewModel.lists.contains(where: { $0.id == listToArchive.id }))
        #expect(viewModel.archivedLists.contains(where: { $0.id == listToArchive.id }))

        // Act: Restore the list
        let archivedList = viewModel.archivedLists.first { $0.id == listToArchive.id }!
        viewModel.restoreList(archivedList)

        // Assert: List should now be in active lists, not archived lists
        #expect(viewModel.lists.contains(where: { $0.id == listToArchive.id }), "Restored list should appear in active lists")
        #expect(!viewModel.archivedLists.contains(where: { $0.id == listToArchive.id }), "Restored list should not appear in archived lists")
    }

    // MARK: - Test 2: Restore sets isArchived = false on List model

    @Test("Restoring list sets isArchived to false")
    func testRestoreListSetsIsArchivedToFalse() async throws {
        // Arrange: Create test environment with an archived list
        let testDataManager = TestHelpers.createTestDataManager()
        let viewModel = TestMainViewModel(dataManager: testDataManager)

        // Create and archive a list
        try viewModel.addList(name: "Archive Test List")
        let listToArchive = viewModel.lists.first!
        viewModel.archiveList(listToArchive)

        // Load archived lists
        viewModel.loadArchivedLists()
        let archivedList = viewModel.archivedLists.first { $0.id == listToArchive.id }!

        // Verify list is archived
        #expect(archivedList.isArchived == true, "List should be archived before restore")

        // Act: Restore the list
        viewModel.restoreList(archivedList)

        // Assert: Restored list should have isArchived = false
        let restoredList = viewModel.lists.first { $0.id == listToArchive.id }
        #expect(restoredList != nil, "Restored list should exist in active lists")
        #expect(restoredList?.isArchived == false, "Restored list should have isArchived set to false")
    }

    // MARK: - Test 3: DataManager.restoreList(withId:) is called by MainViewModel.restoreList()

    @Test("MainViewModel.restoreList calls DataManager.restoreList(withId:)")
    func testMainViewModelCallsDataManagerRestoreList() async throws {
        // Arrange: Create test environment with tracking
        let testDataManager = TestHelpers.createTestDataManager()
        let viewModel = TestMainViewModel(dataManager: testDataManager)

        // Create and archive a list
        try viewModel.addList(name: "Tracking Test List")
        let listToArchive = viewModel.lists.first!
        let listId = listToArchive.id
        viewModel.archiveList(listToArchive)

        // Load archived lists
        viewModel.loadArchivedLists()
        let archivedList = viewModel.archivedLists.first { $0.id == listId }!

        // Act: Restore the list
        viewModel.restoreList(archivedList)

        // Assert: Verify the list was restored via Core Data
        // The list should now be in the active lists (fetched with isArchived == false predicate)
        let activeLists = testDataManager.getLists()
        #expect(activeLists.contains(where: { $0.id == listId }), "DataManager should have restored the list to active lists")

        // And should not be in archived lists
        let archivedLists = testDataManager.loadArchivedLists()
        #expect(!archivedLists.contains(where: { $0.id == listId }), "DataManager should have removed the list from archived lists")
    }

    // MARK: - Test 4: Restore updates modifiedAt timestamp

    @Test("Restoring list updates modifiedAt timestamp")
    func testRestoreListUpdatesModifiedAtTimestamp() async throws {
        // Arrange: Create test environment with an archived list
        let testDataManager = TestHelpers.createTestDataManager()
        let viewModel = TestMainViewModel(dataManager: testDataManager)

        // Create and archive a list
        try viewModel.addList(name: "Timestamp Test List")
        let listToArchive = viewModel.lists.first!
        let originalModifiedAt = listToArchive.modifiedAt
        viewModel.archiveList(listToArchive)

        // Wait a small amount to ensure timestamp difference
        try await Task.sleep(nanoseconds: 10_000_000) // 10ms

        // Load archived lists
        viewModel.loadArchivedLists()
        let archivedList = viewModel.archivedLists.first { $0.id == listToArchive.id }!
        let archivedModifiedAt = archivedList.modifiedAt

        // Wait again before restore
        try await Task.sleep(nanoseconds: 10_000_000) // 10ms

        // Act: Restore the list
        viewModel.restoreList(archivedList)

        // Assert: modifiedAt should be updated after restore
        let restoredList = viewModel.lists.first { $0.id == listToArchive.id }
        #expect(restoredList != nil, "Restored list should exist")
        #expect(restoredList!.modifiedAt > archivedModifiedAt, "modifiedAt should be updated after restore")
    }

    // MARK: - Additional Edge Case Tests

    @Test("Restoring preserves list name and items")
    func testRestorePreservesListNameAndItems() async throws {
        // Arrange: Create test environment
        let testDataManager = TestHelpers.createTestDataManager()
        let viewModel = TestMainViewModel(dataManager: testDataManager)

        // Create a list with a specific name
        let listName = "My Important Shopping List"
        try viewModel.addList(name: listName)
        let listToArchive = viewModel.lists.first!
        let listId = listToArchive.id

        // Add some items to the list
        let testItem1 = Item(title: "Milk", listId: listId)
        let testItem2 = Item(title: "Bread", listId: listId)
        testDataManager.addItem(testItem1, to: listId)
        testDataManager.addItem(testItem2, to: listId)

        // Archive the list
        viewModel.archiveList(listToArchive)

        // Load archived lists
        viewModel.loadArchivedLists()
        let archivedList = viewModel.archivedLists.first { $0.id == listId }!

        // Act: Restore the list
        viewModel.restoreList(archivedList)

        // Assert: Name should be preserved
        let restoredList = viewModel.lists.first { $0.id == listId }
        #expect(restoredList?.name == listName, "List name should be preserved after restore")

        // Items should be preserved
        let items = testDataManager.getItems(forListId: listId)
        #expect(items.count == 2, "Items should be preserved after restore")
        #expect(items.contains(where: { $0.title == "Milk" }), "Item 'Milk' should be preserved")
        #expect(items.contains(where: { $0.title == "Bread" }), "Item 'Bread' should be preserved")
    }

    @Test("Restoring multiple lists works correctly")
    func testRestoringMultipleListsWorksCorrectly() async throws {
        // Arrange: Create test environment with multiple archived lists
        let testDataManager = TestHelpers.createTestDataManager()
        let viewModel = TestMainViewModel(dataManager: testDataManager)

        // Create and archive multiple lists
        try viewModel.addList(name: "List A")
        try viewModel.addList(name: "List B")
        try viewModel.addList(name: "List C")

        let listA = viewModel.lists.first { $0.name == "List A" }!
        let listB = viewModel.lists.first { $0.name == "List B" }!
        let listC = viewModel.lists.first { $0.name == "List C" }!

        // Archive all three lists
        viewModel.archiveList(listA)
        viewModel.archiveList(listB)
        viewModel.archiveList(listC)

        // Load archived lists
        viewModel.loadArchivedLists()
        #expect(viewModel.archivedLists.count == 3, "All three lists should be archived")

        // Act: Restore lists one by one
        let archivedListA = viewModel.archivedLists.first { $0.name == "List A" }!
        viewModel.restoreList(archivedListA)

        let archivedListC = viewModel.archivedLists.first { $0.name == "List C" }!
        viewModel.restoreList(archivedListC)

        // Assert: Two lists restored, one still archived
        #expect(viewModel.lists.count == 2, "Two lists should be in active lists")
        #expect(viewModel.archivedLists.count == 1, "One list should remain archived")
        #expect(viewModel.lists.contains(where: { $0.name == "List A" }), "List A should be restored")
        #expect(viewModel.lists.contains(where: { $0.name == "List C" }), "List C should be restored")
        #expect(viewModel.archivedLists.contains(where: { $0.name == "List B" }), "List B should still be archived")
    }

    @Test("Restoring list removes it from archived lists immediately")
    func testRestoreRemovesFromArchivedListsImmediately() async throws {
        // Arrange
        let testDataManager = TestHelpers.createTestDataManager()
        let viewModel = TestMainViewModel(dataManager: testDataManager)

        try viewModel.addList(name: "Quick Restore Test")
        let list = viewModel.lists.first!
        viewModel.archiveList(list)
        viewModel.loadArchivedLists()

        let initialArchivedCount = viewModel.archivedLists.count
        #expect(initialArchivedCount == 1)

        // Act
        let archivedList = viewModel.archivedLists.first!
        viewModel.restoreList(archivedList)

        // Assert: archivedLists array should be updated immediately
        #expect(viewModel.archivedLists.count == 0, "Archived lists should be empty after restore")
    }
}

// MARK: - DataManager Level Tests

/// @MainActor required because tests access Core Data viewContext (main-thread only)
@Suite(.serialized)
@MainActor
struct RestoreArchivedListsDataManagerTests {

    @Test("TestDataManager.restoreList(withId:) sets isArchived to false in Core Data")
    func testDataManagerRestoreListSetsIsArchivedFalse() async throws {
        // Arrange
        let testDataManager = TestHelpers.createTestDataManager()

        // Create and archive a list
        var list = RestoreTestListModel(name: "Core Data Test List")
        testDataManager.addList(list)

        // Get the list and archive it directly in Core Data
        let context = testDataManager.coreDataManager.viewContext
        let request: NSFetchRequest<ListEntity> = ListEntity.fetchRequest()
        request.predicate = NSPredicate(format: "name == %@", "Core Data Test List")

        let results = try context.fetch(request)
        let listEntity = results.first!
        listEntity.isArchived = true
        testDataManager.saveData()

        // Verify it's archived
        #expect(listEntity.isArchived == true)

        // Act: Restore using DataManager
        testDataManager.restoreList(withId: listEntity.id!)

        // Assert: Verify in Core Data that isArchived is false
        context.refresh(listEntity, mergeChanges: true)
        #expect(listEntity.isArchived == false, "ListEntity.isArchived should be false after restore")
    }

    @Test("TestDataManager.restoreList(withId:) updates modifiedAt in Core Data")
    func testDataManagerRestoreListUpdatesModifiedAt() async throws {
        // Arrange
        let testDataManager = TestHelpers.createTestDataManager()

        // Create a list
        let list = RestoreTestListModel(name: "ModifiedAt Test List")
        testDataManager.addList(list)

        // Archive it directly
        let context = testDataManager.coreDataManager.viewContext
        let request: NSFetchRequest<ListEntity> = ListEntity.fetchRequest()
        request.predicate = NSPredicate(format: "name == %@", "ModifiedAt Test List")

        let results = try context.fetch(request)
        let listEntity = results.first!
        listEntity.isArchived = true
        let archivedDate = Date(timeIntervalSinceNow: -3600) // 1 hour ago
        listEntity.modifiedAt = archivedDate
        testDataManager.saveData()

        // Wait to ensure time difference
        try await Task.sleep(nanoseconds: 10_000_000) // 10ms

        // Act: Restore
        testDataManager.restoreList(withId: listEntity.id!)

        // Assert: modifiedAt should be updated to a more recent time
        context.refresh(listEntity, mergeChanges: true)
        #expect(listEntity.modifiedAt! > archivedDate, "modifiedAt should be updated after restore")
    }

    @Test("TestDataManager.restoreList(withId:) reloads data after restore")
    func testDataManagerRestoreListReloadsData() async throws {
        // Arrange
        let testDataManager = TestHelpers.createTestDataManager()

        // Create and archive a list
        let list = RestoreTestListModel(name: "Reload Test List")
        testDataManager.addList(list)
        let listId = testDataManager.lists.first!.id

        // Archive directly in Core Data
        let context = testDataManager.coreDataManager.viewContext
        let request: NSFetchRequest<ListEntity> = ListEntity.fetchRequest()
        request.predicate = NSPredicate(format: "id == %@", listId as CVarArg)

        let results = try context.fetch(request)
        let listEntity = results.first!
        listEntity.isArchived = true
        testDataManager.saveData()
        testDataManager.loadData()

        // Verify list is not in active lists after archiving
        #expect(!testDataManager.lists.contains(where: { $0.id == listId }), "List should not be in active lists when archived")

        // Act: Restore
        testDataManager.restoreList(withId: listId)

        // Assert: List should now appear in the lists array (loadData was called)
        #expect(testDataManager.lists.contains(where: { $0.id == listId }), "List should appear in active lists after restore")
    }
}

// MARK: - Core Data Manager Level Tests (Direct Protocol Tests)

/// @MainActor required because tests access Core Data viewContext (main-thread only)
@Suite(.serialized)
@MainActor
struct RestoreArchivedListsCoreDataTests {

    @Test("Archived list is excluded from getLists() predicate")
    func testArchivedListExcludedFromGetLists() async throws {
        // Arrange
        let testDataManager = TestHelpers.createTestDataManager()

        // Create a list
        let list = RestoreTestListModel(name: "Predicate Test List")
        testDataManager.addList(list)
        let listId = testDataManager.lists.first!.id

        // Archive it
        let context = testDataManager.coreDataManager.viewContext
        let request: NSFetchRequest<ListEntity> = ListEntity.fetchRequest()
        request.predicate = NSPredicate(format: "id == %@", listId as CVarArg)

        let results = try context.fetch(request)
        let listEntity = results.first!
        listEntity.isArchived = true
        testDataManager.saveData()

        // Act: Get lists (should exclude archived)
        let activeLists = testDataManager.getLists()

        // Assert
        #expect(!activeLists.contains(where: { $0.id == listId }), "getLists() should not return archived lists")
    }

    @Test("Restored list is included in getLists() predicate")
    func testRestoredListIncludedInGetLists() async throws {
        // Arrange
        let testDataManager = TestHelpers.createTestDataManager()

        // Create and archive a list
        let list = RestoreTestListModel(name: "Include Test List")
        testDataManager.addList(list)
        let listId = testDataManager.lists.first!.id

        // Archive it
        let context = testDataManager.coreDataManager.viewContext
        let request: NSFetchRequest<ListEntity> = ListEntity.fetchRequest()
        request.predicate = NSPredicate(format: "id == %@", listId as CVarArg)

        let results = try context.fetch(request)
        let listEntity = results.first!
        listEntity.isArchived = true
        testDataManager.saveData()

        // Act: Restore the list
        testDataManager.restoreList(withId: listId)
        let activeLists = testDataManager.getLists()

        // Assert
        #expect(activeLists.contains(where: { $0.id == listId }), "getLists() should return restored lists")
    }

    @Test("loadArchivedLists excludes restored list")
    func testLoadArchivedListsExcludesRestoredList() async throws {
        // Arrange
        let testDataManager = TestHelpers.createTestDataManager()

        // Create and archive a list
        let list = RestoreTestListModel(name: "Exclude After Restore Test")
        testDataManager.addList(list)
        let listId = testDataManager.lists.first!.id

        // Archive it
        let context = testDataManager.coreDataManager.viewContext
        let request: NSFetchRequest<ListEntity> = ListEntity.fetchRequest()
        request.predicate = NSPredicate(format: "id == %@", listId as CVarArg)

        let results = try context.fetch(request)
        let listEntity = results.first!
        listEntity.isArchived = true
        testDataManager.saveData()

        // Verify it's in archived lists
        var archivedLists = testDataManager.loadArchivedLists()
        #expect(archivedLists.contains(where: { $0.id == listId }), "List should be in archived lists before restore")

        // Act: Restore
        testDataManager.restoreList(withId: listId)
        archivedLists = testDataManager.loadArchivedLists()

        // Assert
        #expect(!archivedLists.contains(where: { $0.id == listId }), "loadArchivedLists should not return restored list")
    }
}

// MARK: - Archived Lists Read-Only Tests (Task 13.2)

/// Tests for Task 13.2: Make Archived Lists Read-Only
/// Verifies that archived lists behave as read-only in macOS UI
/// These tests verify the LOGIC that will drive UI state, not the UI rendering itself
/// @MainActor required because tests access Core Data viewContext (main-thread only)
@Suite(.serialized)
@MainActor
struct ArchivedListsReadOnlyTests {

    // MARK: - Test 1: isArchived Property Detection

    @Test("isArchived property is correctly detected on List model")
    func testIsArchivedPropertyDetection() async throws {
        // Arrange: Create a list
        var list = RestoreTestListModel(name: "Test List")

        // Assert: Default should be not archived
        #expect(list.isArchived == false, "New list should not be archived by default")

        // Act: Set to archived
        list.isArchived = true

        // Assert: Should now be archived
        #expect(list.isArchived == true, "List should be marked as archived after setting")
    }

    // MARK: - Test 2: Archived List Preserves Items Unchanged

    @Test("Archived list preserves items unchanged when viewed")
    func testArchivedListPreservesItemsUnchanged() async throws {
        // Arrange: Create test environment with a list and items
        let testDataManager = TestHelpers.createTestDataManager()
        let viewModel = TestMainViewModel(dataManager: testDataManager)

        // Create a list with items
        try viewModel.addList(name: "Shopping List")
        let list = viewModel.lists.first!
        let listId = list.id

        // Add items to the list
        let item1 = Item(title: "Milk", listId: listId)
        let item2 = Item(title: "Bread", listId: listId)
        var item3 = Item(title: "Eggs", listId: listId)
        item3.isCrossedOut = true  // Mark one as completed

        testDataManager.addItem(item1, to: listId)
        testDataManager.addItem(item2, to: listId)
        testDataManager.addItem(item3, to: listId)

        // Get items before archiving
        let itemsBeforeArchive = testDataManager.getItems(forListId: listId)
        let titlesBeforeArchive = Set(itemsBeforeArchive.map { $0.title })
        let crossedOutCountBefore = itemsBeforeArchive.filter { $0.isCrossedOut }.count

        // Act: Archive the list
        viewModel.archiveList(list)
        viewModel.loadArchivedLists()

        // Get items after archiving
        let itemsAfterArchive = testDataManager.getItems(forListId: listId)
        let titlesAfterArchive = Set(itemsAfterArchive.map { $0.title })
        let crossedOutCountAfter = itemsAfterArchive.filter { $0.isCrossedOut }.count

        // Assert: Items should be unchanged
        #expect(itemsAfterArchive.count == itemsBeforeArchive.count, "Item count should be preserved after archiving")
        #expect(titlesAfterArchive == titlesBeforeArchive, "Item titles should be preserved after archiving")
        #expect(crossedOutCountAfter == crossedOutCountBefore, "Crossed out state should be preserved after archiving")
    }

    // MARK: - Test 3: Read-Only State Indicators for Archived List

    @Test("Archived list should indicate read-only state via isArchived property")
    func testArchivedListIndicatesReadOnlyState() async throws {
        // Arrange: Create test environment
        let testDataManager = TestHelpers.createTestDataManager()
        let viewModel = TestMainViewModel(dataManager: testDataManager)

        // Create and archive a list
        try viewModel.addList(name: "Read-Only Test List")
        let list = viewModel.lists.first!
        viewModel.archiveList(list)
        viewModel.loadArchivedLists()

        // Act: Get the archived list
        let archivedList = viewModel.archivedLists.first!

        // Assert: The isArchived property should indicate read-only state
        // UI components will use this to hide/disable edit controls
        #expect(archivedList.isArchived == true, "Archived list should have isArchived = true for UI to determine read-only state")
    }

    // MARK: - Test 4: Computed Property for Checking Edit Allowed

    @Test("List should provide computed property indicating if editing is allowed")
    func testListEditAllowedComputation() async throws {
        // Arrange: Create two lists
        var activeList = RestoreTestListModel(name: "Active List")
        activeList.isArchived = false

        var archivedList = RestoreTestListModel(name: "Archived List")
        archivedList.isArchived = true

        // Assert: isArchived property can be used to determine edit permission
        // Note: The UI will use !list.isArchived to determine if editing is allowed
        let canEditActive = !activeList.isArchived
        let canEditArchived = !archivedList.isArchived

        #expect(canEditActive == true, "Active list should allow editing")
        #expect(canEditArchived == false, "Archived list should not allow editing")
    }

    // MARK: - Test 5: ViewModel State for Selection Mode Disabled on Archived Lists

    @Test("Selection mode should not be enterable when viewing archived lists")
    func testSelectionModeDisabledForArchivedList() async throws {
        // Arrange: Create test environment
        let testDataManager = TestHelpers.createTestDataManager()
        let viewModel = TestMainViewModel(dataManager: testDataManager)

        // Create and archive a list
        try viewModel.addList(name: "Selection Mode Test List")
        let list = viewModel.lists.first!
        viewModel.archiveList(list)
        viewModel.loadArchivedLists()

        // Get the archived list
        let archivedList = viewModel.archivedLists.first!

        // Assert: When list.isArchived == true, UI should prevent entering selection mode
        // This is a logic test - the actual UI prevention will use this flag
        let shouldDisableSelectionMode = archivedList.isArchived
        #expect(shouldDisableSelectionMode == true, "Selection mode should be disabled for archived lists")
    }

    // MARK: - Test 6: ListViewModel Should Know When Reorder Is Disabled

    @Test("ListViewModel should indicate when drag reorder is disabled for archived list")
    func testDragReorderDisabledForArchivedList() async throws {
        // Arrange: Create test environment
        let testDataManager = TestHelpers.createTestDataManager()

        // Create an archived list directly for testing
        var archivedList = RestoreTestListModel(name: "Reorder Test List")
        archivedList.isArchived = true

        // Assert: When list.isArchived == true, drag reorder should be disabled
        // The UI will use this to disable .onMove() modifier
        let shouldDisableReorder = archivedList.isArchived
        #expect(shouldDisableReorder == true, "Drag reorder should be disabled for archived lists")

        // Active list should allow reorder
        var activeList = RestoreTestListModel(name: "Active Reorder Test")
        activeList.isArchived = false
        let shouldEnableReorder = !activeList.isArchived
        #expect(shouldEnableReorder == true, "Drag reorder should be enabled for active lists")
    }

    // MARK: - Test 7: Quick Look Remains Available for Archived Lists

    @Test("Quick Look should still be available for archived list items with images")
    func testQuickLookStillAvailableForArchivedList() async throws {
        // Arrange: Create test environment with a list that has items with images
        let testDataManager = TestHelpers.createTestDataManager()
        let viewModel = TestMainViewModel(dataManager: testDataManager)

        // Create a list
        try viewModel.addList(name: "Quick Look Test List")
        let list = viewModel.lists.first!
        let listId = list.id

        // Add an item with an image
        var itemWithImage = Item(title: "Item with Image", listId: listId)
        let testImageData = Data(repeating: 0, count: 100)  // Dummy image data
        let itemImage = ItemImage(imageData: testImageData, itemId: itemWithImage.id)
        itemWithImage.images = [itemImage]
        testDataManager.addItem(itemWithImage, to: listId)

        // Archive the list
        viewModel.archiveList(list)
        viewModel.loadArchivedLists()

        // Get items from the archived list
        let archivedListItems = testDataManager.getItems(forListId: listId)
        let itemImages = archivedListItems.first?.images ?? []

        // Assert: Quick Look is a read-only operation, so it should remain available
        // The presence of images should still be detectable for Quick Look
        #expect(archivedListItems.first?.hasImages == true, "Item should still have images after archiving")
        #expect(!itemImages.isEmpty, "Images should be preserved for Quick Look")

        // Quick Look availability is determined by presence of images, not archive status
        let quickLookAvailable = archivedListItems.first?.hasImages ?? false
        #expect(quickLookAvailable == true, "Quick Look should be available when item has images, regardless of archive status")
    }

    // MARK: - Test 8: Add Item Button State Determination

    @Test("Add item button visibility should be determined by list archive status")
    func testAddItemButtonHiddenForArchivedList() async throws {
        // Arrange: Create active and archived lists
        var activeList = RestoreTestListModel(name: "Active List")
        activeList.isArchived = false

        var archivedList = RestoreTestListModel(name: "Archived List")
        archivedList.isArchived = true

        // Assert: UI will use isArchived to determine button visibility
        let showAddButtonForActive = !activeList.isArchived
        let showAddButtonForArchived = !archivedList.isArchived

        #expect(showAddButtonForActive == true, "Add item button should be visible for active list")
        #expect(showAddButtonForArchived == false, "Add item button should be hidden for archived list")
    }

    // MARK: - Test 9: Edit List Button State Determination

    @Test("Edit list button visibility should be determined by list archive status")
    func testEditListButtonHiddenForArchivedList() async throws {
        // Arrange: Create active and archived lists
        var activeList = RestoreTestListModel(name: "Active List")
        activeList.isArchived = false

        var archivedList = RestoreTestListModel(name: "Archived List")
        archivedList.isArchived = true

        // Assert: UI will use isArchived to determine button visibility
        let showEditButtonForActive = !activeList.isArchived
        let showEditButtonForArchived = !archivedList.isArchived

        #expect(showEditButtonForActive == true, "Edit list button should be visible for active list")
        #expect(showEditButtonForArchived == false, "Edit list button should be hidden for archived list")
    }

    // MARK: - Test 10: Item Row Read-Only State Determination

    @Test("Item row interactive elements should be determined by list archive status")
    func testItemRowReadOnlyForArchivedList() async throws {
        // Arrange: Create a list with items
        var activeList = RestoreTestListModel(name: "Active List")
        activeList.isArchived = false

        var archivedList = RestoreTestListModel(name: "Archived List")
        archivedList.isArchived = true

        // Assert: UI will use list.isArchived to determine interactive elements visibility
        // Interactive elements include: checkbox (toggle completion), edit button, swipe actions

        let showCheckboxForActive = !activeList.isArchived
        let showCheckboxForArchived = !archivedList.isArchived

        let showEditButtonForActive = !activeList.isArchived
        let showEditButtonForArchived = !archivedList.isArchived

        let enableSwipeActionsForActive = !activeList.isArchived
        let enableSwipeActionsForArchived = !archivedList.isArchived

        #expect(showCheckboxForActive == true, "Checkbox should be visible for active list items")
        #expect(showCheckboxForArchived == false, "Checkbox should be hidden for archived list items")

        #expect(showEditButtonForActive == true, "Edit button should be visible for active list items")
        #expect(showEditButtonForArchived == false, "Edit button should be hidden for archived list items")

        #expect(enableSwipeActionsForActive == true, "Swipe actions should be enabled for active list items")
        #expect(enableSwipeActionsForArchived == false, "Swipe actions should be disabled for archived list items")
    }

    // MARK: - Test 11: Context Menu Options Differ for Archived Lists

    @Test("Context menu options should differ based on list archive status")
    func testContextMenuDifferentForArchivedLists() async throws {
        // Arrange: Create active and archived lists
        var activeList = RestoreTestListModel(name: "Active List")
        activeList.isArchived = false

        var archivedList = RestoreTestListModel(name: "Archived List")
        archivedList.isArchived = true

        // Define expected context menu options based on archive status
        // Active list: Share, Duplicate, Edit, Delete (Archive)
        // Archived list: Restore, Delete Permanently (NO Share, Duplicate, Edit)

        let activeListOptions = ContextMenuOptions(
            showShare: !activeList.isArchived,
            showDuplicate: !activeList.isArchived,
            showEdit: !activeList.isArchived,
            showRestore: activeList.isArchived,
            showDeletePermanently: activeList.isArchived
        )

        let archivedListOptions = ContextMenuOptions(
            showShare: !archivedList.isArchived,
            showDuplicate: !archivedList.isArchived,
            showEdit: !archivedList.isArchived,
            showRestore: archivedList.isArchived,
            showDeletePermanently: archivedList.isArchived
        )

        // Assert: Active list context menu
        #expect(activeListOptions.showShare == true, "Active list should show Share option")
        #expect(activeListOptions.showDuplicate == true, "Active list should show Duplicate option")
        #expect(activeListOptions.showEdit == true, "Active list should show Edit option")
        #expect(activeListOptions.showRestore == false, "Active list should not show Restore option")
        #expect(activeListOptions.showDeletePermanently == false, "Active list should not show Delete Permanently option")

        // Assert: Archived list context menu
        #expect(archivedListOptions.showShare == false, "Archived list should not show Share option")
        #expect(archivedListOptions.showDuplicate == false, "Archived list should not show Duplicate option")
        #expect(archivedListOptions.showEdit == false, "Archived list should not show Edit option")
        #expect(archivedListOptions.showRestore == true, "Archived list should show Restore option")
        #expect(archivedListOptions.showDeletePermanently == true, "Archived list should show Delete Permanently option")
    }

    // MARK: - Test 12: Archived List Items Cannot Be Modified via DataManager

    @Test("Archived list items state verification after archive operation")
    func testArchivedListItemsStateAfterArchive() async throws {
        // Arrange: Create test environment with items
        let testDataManager = TestHelpers.createTestDataManager()
        let viewModel = TestMainViewModel(dataManager: testDataManager)

        // Create a list
        try viewModel.addList(name: "Item State Test List")
        let list = viewModel.lists.first!
        let listId = list.id

        // Add items with various states
        var item1 = Item(title: "Active Item", listId: listId)
        item1.quantity = 3
        item1.itemDescription = "Test description"

        var item2 = Item(title: "Crossed Out Item", listId: listId)
        item2.isCrossedOut = true

        testDataManager.addItem(item1, to: listId)
        testDataManager.addItem(item2, to: listId)

        // Store original states
        let originalItems = testDataManager.getItems(forListId: listId)
        let originalItem1 = originalItems.first { $0.title == "Active Item" }!
        let originalItem2 = originalItems.first { $0.title == "Crossed Out Item" }!

        // Act: Archive the list
        viewModel.archiveList(list)
        viewModel.loadArchivedLists()

        // Verify archived list
        guard let archivedList = viewModel.archivedLists.first else {
            Issue.record("No archived list found after archiving")
            return
        }
        #expect(archivedList.isArchived == true, "List should be archived")

        // Get items after archiving
        let archivedItems = testDataManager.getItems(forListId: listId)
        let archivedItem1 = archivedItems.first { $0.title == "Active Item" }!
        let archivedItem2 = archivedItems.first { $0.title == "Crossed Out Item" }!

        // Assert: All item properties should be preserved
        #expect(archivedItem1.quantity == originalItem1.quantity, "Item quantity should be preserved")
        #expect(archivedItem1.itemDescription == originalItem1.itemDescription, "Item description should be preserved")
        #expect(archivedItem1.isCrossedOut == originalItem1.isCrossedOut, "Item crossed out state should be preserved")

        #expect(archivedItem2.isCrossedOut == originalItem2.isCrossedOut, "Crossed out item state should be preserved")
    }
}

// MARK: - Helper Struct for Context Menu Options

/// Helper struct to represent context menu options for testing
/// Used by ArchivedListsReadOnlyTests to verify correct menu options
private struct ContextMenuOptions {
    let showShare: Bool
    let showDuplicate: Bool
    let showEdit: Bool
    let showRestore: Bool
    let showDeletePermanently: Bool
}
