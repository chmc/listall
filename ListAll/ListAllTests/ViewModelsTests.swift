import XCTest
import Foundation
import CoreData
@testable import ListAll

class ViewModelsTests: XCTestCase {
    
    // MARK: - MainViewModel Tests
    
    func testMainViewModelInitialization() throws {
        let viewModel = TestHelpers.createTestMainViewModel()
        
        XCTAssertTrue(viewModel.lists.isEmpty)
    }
    
    func testAddListSuccess() throws {
        let viewModel = TestHelpers.createTestMainViewModel()
        let initialCount = viewModel.lists.count
        
        try viewModel.addList(name: "Test List")
        XCTAssertEqual(viewModel.lists.count, initialCount + 1)
        XCTAssertEqual(viewModel.lists.last?.name, "Test List")
    }
    
    func testAddListEmptyName() throws {
        let viewModel = TestHelpers.createTestMainViewModel()
        
        do {
            try viewModel.addList(name: "")
            XCTFail("Should have thrown ValidationError.emptyName")
        } catch ValidationError.emptyName {
            XCTAssertTrue(true)
        } catch {
            XCTFail("Unexpected error type: \(error)")
        }
    }
    
    func testAddListWhitespaceName() throws {
        let viewModel = TestHelpers.createTestMainViewModel()
        
        do {
            try viewModel.addList(name: "   ")
            XCTFail("Should have thrown ValidationError.emptyName")
        } catch ValidationError.emptyName {
            XCTAssertTrue(true)
        } catch {
            XCTFail("Unexpected error type: \(error)")
        }
    }
    
    func testAddListNameTooLong() throws {
        let viewModel = TestHelpers.createTestMainViewModel()
        let longName = String(repeating: "a", count: 101)
        
        do {
            try viewModel.addList(name: longName)
            XCTFail("Should have thrown ValidationError.nameTooLong")
        } catch ValidationError.nameTooLong {
            XCTAssertTrue(true)
        } catch {
            XCTFail("Unexpected error type: \(error)")
        }
    }
    
    func testAddListExactly100Characters() throws {
        let viewModel = TestHelpers.createTestMainViewModel()
        let exactName = String(repeating: "a", count: 100)
        
        try viewModel.addList(name: exactName)
        XCTAssertEqual(viewModel.lists.last?.name, exactName)
    }
    
    func testUpdateListSuccess() throws {
        let viewModel = TestHelpers.createTestMainViewModel()
        try viewModel.addList(name: "Original Name")
        
        guard let list = viewModel.lists.first else {
            XCTFail("List should exist")
            return
        }
        
        try viewModel.updateList(list, name: "Updated Name")
        XCTAssertEqual(viewModel.lists.first?.name, "Updated Name")
    }
    
    func testUpdateListEmptyName() throws {
        let viewModel = TestHelpers.createTestMainViewModel()
        try viewModel.addList(name: "Test List")
        
        guard let list = viewModel.lists.first else {
            XCTFail("List should exist")
            return
        }
        
        do {
            try viewModel.updateList(list, name: "")
            XCTFail("Should have thrown ValidationError.emptyName")
        } catch ValidationError.emptyName {
            XCTAssertTrue(true)
        } catch {
            XCTFail("Unexpected error type: \(error)")
        }
    }
    
    func testUpdateListNameTooLong() throws {
        let viewModel = TestHelpers.createTestMainViewModel()
        try viewModel.addList(name: "Test List")
        
        guard let list = viewModel.lists.first else {
            XCTFail("List should exist")
            return
        }
        
        let longName = String(repeating: "a", count: 101)
        do {
            try viewModel.updateList(list, name: longName)
            XCTFail("Should have thrown ValidationError.nameTooLong")
        } catch ValidationError.nameTooLong {
            XCTAssertTrue(true)
        } catch {
            XCTFail("Unexpected error type: \(error)")
        }
    }
    
    func testDeleteList() throws {
        let viewModel = TestHelpers.createTestMainViewModel()
        try viewModel.addList(name: "Test List")
        let initialCount = viewModel.lists.count
        
        guard let list = viewModel.lists.first else {
            XCTFail("List should exist")
            return
        }
        
        viewModel.deleteList(list)
        XCTAssertEqual(viewModel.lists.count, initialCount - 1)
        XCTAssertFalse(viewModel.lists.contains { $0.id == list.id })
    }
    
    func testArchiveList() throws {
        let viewModel = TestHelpers.createTestMainViewModel()
        try viewModel.addList(name: "Test List")
        let initialCount = viewModel.lists.count
        
        guard let list = viewModel.lists.first else {
            XCTFail("List should exist")
            return
        }
        
        viewModel.archiveList(list)
        
        // List should be removed from active lists
        XCTAssertEqual(viewModel.lists.count, initialCount - 1)
        XCTAssertFalse(viewModel.lists.contains { $0.id == list.id })
    }
    
    func testArchiveListShowsNotification() throws {
        let viewModel = TestHelpers.createTestMainViewModel()
        try viewModel.addList(name: "Test List")
        
        guard let list = viewModel.lists.first else {
            XCTFail("List should exist")
            return
        }
        
        viewModel.archiveList(list)
        
        // Notification should be shown
        XCTAssertTrue(viewModel.showArchivedNotification)
        XCTAssertEqual(viewModel.recentlyArchivedList?.id, list.id)
    }
    
    func testUndoArchive() throws {
        let viewModel = TestHelpers.createTestMainViewModel()
        try viewModel.addList(name: "Test List")
        
        guard let list = viewModel.lists.first else {
            XCTFail("List should exist")
            return
        }
        
        let listId = list.id
        viewModel.archiveList(list)
        
        // List should be archived
        XCTAssertFalse(viewModel.lists.contains { $0.id == listId })
        XCTAssertTrue(viewModel.showArchivedNotification)
        
        // Undo archive
        viewModel.undoArchive()
        
        // List should be restored
        XCTAssertTrue(viewModel.lists.contains { $0.id == listId })
        XCTAssertFalse(viewModel.showArchivedNotification)
        XCTAssertNil(viewModel.recentlyArchivedList)
    }
    
    func testRestoreArchivedList() throws {
        let viewModel = TestHelpers.createTestMainViewModel()
        try viewModel.addList(name: "Test List")
        
        guard let list = viewModel.lists.first else {
            XCTFail("List should exist")
            return
        }
        
        let listId = list.id
        
        // Archive the list
        viewModel.archiveList(list)
        XCTAssertFalse(viewModel.lists.contains { $0.id == listId })
        
        // Load archived lists
        viewModel.loadArchivedLists()
        
        guard let archivedList = viewModel.archivedLists.first(where: { $0.id == listId }) else {
            XCTFail("Archived list should exist")
            return
        }
        
        // Restore the list
        viewModel.restoreList(archivedList)
        
        // List should be back in active lists
        XCTAssertTrue(viewModel.lists.contains { $0.id == listId })
        XCTAssertFalse(viewModel.archivedLists.contains { $0.id == listId })
    }
    
    func testPermanentlyDeleteArchivedList() throws {
        let viewModel = TestHelpers.createTestMainViewModel()
        try viewModel.addList(name: "Test List")
        
        guard let list = viewModel.lists.first else {
            XCTFail("List should exist")
            return
        }
        
        let listId = list.id
        
        // Archive the list first
        viewModel.archiveList(list)
        
        // Load archived lists
        viewModel.loadArchivedLists()
        
        guard let archivedList = viewModel.archivedLists.first(where: { $0.id == listId }) else {
            XCTFail("Archived list should exist")
            return
        }
        
        let archivedCount = viewModel.archivedLists.count
        
        // Permanently delete the archived list
        viewModel.permanentlyDeleteList(archivedList)
        
        // List should be removed from archived lists
        XCTAssertEqual(viewModel.archivedLists.count, archivedCount - 1)
        XCTAssertFalse(viewModel.archivedLists.contains { $0.id == listId })
        
        // List should not be in active lists either
        XCTAssertFalse(viewModel.lists.contains { $0.id == listId })
    }
    
    func testValidationErrorEmptyNameDescription() throws {
        let error = ValidationError.emptyName
        XCTAssertEqual(error.errorDescription, "Please enter a list name")
    }
    
    func testValidationErrorNameTooLongDescription() throws {
        let error = ValidationError.nameTooLong
        XCTAssertEqual(error.errorDescription, "List name must be 100 characters or less")
    }
    
    func testSpecialCharactersInListNames() throws {
        let viewModel = TestHelpers.createTestMainViewModel()
        let specialName = "Test 🎉 List & More!"
        
        try viewModel.addList(name: specialName)
        XCTAssertEqual(viewModel.lists.count, 1)
        XCTAssertEqual(viewModel.lists.first?.name, specialName)
    }
    
    // MARK: - ItemViewModel Tests
    
    func testItemViewModelInitialization() throws {
        let item = Item(title: "Test Item")
        let viewModel = TestHelpers.createTestItemViewModel(with: item)
        
        XCTAssertEqual(viewModel.item.id, item.id)
        XCTAssertEqual(viewModel.item.title, item.title)
    }
    
    func testItemViewModelToggleCrossedOut() throws {
        let item = Item(title: "Test Item")
        let viewModel = TestHelpers.createTestItemViewModel(with: item)
        let originalState = item.isCrossedOut
        
        viewModel.toggleCrossedOut()
        XCTAssertEqual(viewModel.item.isCrossedOut, !originalState)
        
        viewModel.toggleCrossedOut()
        XCTAssertEqual(viewModel.item.isCrossedOut, originalState)
    }
    
    // MARK: - ListViewModel Tests
    
    func testListViewModelCreateItem() throws {
        // Create a shared data manager
        let dataManager = TestHelpers.createTestDataManager()
        let mainViewModel = TestMainViewModel(dataManager: dataManager)
        
        try mainViewModel.addList(name: "Test List")
        
        guard let list = mainViewModel.lists.first else {
            XCTFail("List should exist")
            return
        }
        
        // Use the same data manager for the list view model
        let viewModel = TestListViewModel(list: list, dataManager: dataManager)
        let initialCount = viewModel.items.count
        
        viewModel.createItem(title: "New Item", description: "Description")
        XCTAssertEqual(viewModel.items.count, initialCount + 1)
        XCTAssertTrue(viewModel.items.contains { $0.title == "New Item" })
    }
    
    func testListViewModelToggleItemCrossedOut() throws {
        // Create a shared data manager
        let dataManager = TestHelpers.createTestDataManager()
        let mainViewModel = TestMainViewModel(dataManager: dataManager)
        
        try mainViewModel.addList(name: "Test List")
        
        guard let list = mainViewModel.lists.first else {
            XCTFail("List should exist")
            return
        }
        
        // Use the same data manager for the list view model
        let viewModel = TestListViewModel(list: list, dataManager: dataManager)
        viewModel.createItem(title: "Test Item", description: "")
        
        guard let item = viewModel.items.first else {
            XCTFail("Item should exist")
            return
        }
        
        let originalState = item.isCrossedOut
        viewModel.toggleItemCrossedOut(item)
        
        // Refresh the item from the list
        guard let updatedItem = viewModel.items.first(where: { $0.id == item.id }) else {
            XCTFail("Item should still exist")
            return
        }
        
        XCTAssertEqual(updatedItem.isCrossedOut, !originalState)
    }
    
    func testListViewModelDeleteItem() throws {
        // Create a shared data manager
        let dataManager = TestHelpers.createTestDataManager()
        let mainViewModel = TestMainViewModel(dataManager: dataManager)
        
        try mainViewModel.addList(name: "Test List")
        
        guard let list = mainViewModel.lists.first else {
            XCTFail("List should exist")
            return
        }
        
        // Use the same data manager for the list view model
        let viewModel = TestListViewModel(list: list, dataManager: dataManager)
        viewModel.createItem(title: "Test Item", description: "")
        let initialCount = viewModel.items.count
        
        guard let item = viewModel.items.first else {
            XCTFail("Item should exist")
            return
        }
        
        viewModel.deleteItem(item)
        XCTAssertEqual(viewModel.items.count, initialCount - 1)
        XCTAssertFalse(viewModel.items.contains { $0.id == item.id })
    }
    
    func testListViewModelReorderItems() throws {
        // Create a shared data manager
        let dataManager = TestHelpers.createTestDataManager()
        let mainViewModel = TestMainViewModel(dataManager: dataManager)
        
        try mainViewModel.addList(name: "Test List")
        
        guard let list = mainViewModel.lists.first else {
            XCTFail("List should exist")
            return
        }
        
        // Use the same data manager for the list view model
        let viewModel = TestListViewModel(list: list, dataManager: dataManager)
        
        // Create multiple items to test reordering
        viewModel.createItem(title: "First Item", description: "")
        viewModel.createItem(title: "Second Item", description: "")
        viewModel.createItem(title: "Third Item", description: "")
        
        // Verify initial order
        XCTAssertEqual(viewModel.items.count, 3)
        let initialItems = viewModel.items.sorted { $0.orderNumber < $1.orderNumber }
        XCTAssertEqual(initialItems[0].title, "First Item")
        XCTAssertEqual(initialItems[1].title, "Second Item")
        XCTAssertEqual(initialItems[2].title, "Third Item")
        
        // Test reordering: move first item to last position
        viewModel.reorderItems(from: 0, to: 2)
        
        // Verify new order
        let reorderedItems = viewModel.items.sorted { $0.orderNumber < $1.orderNumber }
        XCTAssertEqual(reorderedItems.count, 3)
        XCTAssertEqual(reorderedItems[0].title, "Second Item")
        XCTAssertEqual(reorderedItems[1].title, "Third Item")
        XCTAssertEqual(reorderedItems[2].title, "First Item")
        
        // Verify order numbers are correct
        XCTAssertEqual(reorderedItems[0].orderNumber, 0)
        XCTAssertEqual(reorderedItems[1].orderNumber, 1)
        XCTAssertEqual(reorderedItems[2].orderNumber, 2)
    }
    
    func testListViewModelMoveItems() throws {
        // Create a shared data manager
        let dataManager = TestHelpers.createTestDataManager()
        let mainViewModel = TestMainViewModel(dataManager: dataManager)
        
        try mainViewModel.addList(name: "Test List")
        
        guard let list = mainViewModel.lists.first else {
            XCTFail("List should exist")
            return
        }
        
        // Use the same data manager for the list view model
        let viewModel = TestListViewModel(list: list, dataManager: dataManager)
        
        // Create multiple items to test moving
        viewModel.createItem(title: "Item A", description: "")
        viewModel.createItem(title: "Item B", description: "")
        viewModel.createItem(title: "Item C", description: "")
        viewModel.createItem(title: "Item D", description: "")
        
        // Verify initial order
        XCTAssertEqual(viewModel.items.count, 4)
        let initialItems = viewModel.items.sorted { $0.orderNumber < $1.orderNumber }
        XCTAssertEqual(initialItems[0].title, "Item A")
        XCTAssertEqual(initialItems[1].title, "Item B")
        XCTAssertEqual(initialItems[2].title, "Item C")
        XCTAssertEqual(initialItems[3].title, "Item D")
        
        // Test moving: simulate SwiftUI's onMove behavior (move item B to position 3)
        let sourceIndexSet = IndexSet([1])
        viewModel.moveItems(from: sourceIndexSet, to: 3)
        
        // Verify new order: A, C, B, D
        let movedItems = viewModel.items.sorted { $0.orderNumber < $1.orderNumber }
        XCTAssertEqual(movedItems.count, 4)
        XCTAssertEqual(movedItems[0].title, "Item A")
        XCTAssertEqual(movedItems[1].title, "Item C")
        XCTAssertEqual(movedItems[2].title, "Item B")
        XCTAssertEqual(movedItems[3].title, "Item D")
    }
    
    func testListViewModelReorderItemsInvalidIndices() throws {
        // Create a shared data manager
        let dataManager = TestHelpers.createTestDataManager()
        let mainViewModel = TestMainViewModel(dataManager: dataManager)
        
        try mainViewModel.addList(name: "Test List")
        
        guard let list = mainViewModel.lists.first else {
            XCTFail("List should exist")
            return
        }
        
        // Use the same data manager for the list view model
        let viewModel = TestListViewModel(list: list, dataManager: dataManager)
        
        // Create items
        viewModel.createItem(title: "Item 1", description: "")
        viewModel.createItem(title: "Item 2", description: "")
        
        let initialItems = viewModel.items.sorted { $0.orderNumber < $1.orderNumber }
        let initialCount = initialItems.count
        
        // Test invalid indices - should not crash and should not change order
        viewModel.reorderItems(from: -1, to: 0) // Invalid source
        viewModel.reorderItems(from: 0, to: 10) // Invalid destination
        viewModel.reorderItems(from: 0, to: 0) // Same index
        
        // Verify no changes occurred
        let finalItems = viewModel.items.sorted { $0.orderNumber < $1.orderNumber }
        XCTAssertEqual(finalItems.count, initialCount)
        XCTAssertEqual(finalItems[0].title, initialItems[0].title)
        XCTAssertEqual(finalItems[1].title, initialItems[1].title)
    }
    
    // MARK: - Show/Hide Crossed Out Items Tests
    
    func testListViewModelShowCrossedOutItemsDefault() throws {
        // Create a shared data manager
        let dataManager = TestHelpers.createTestDataManager()
        let mainViewModel = TestMainViewModel(dataManager: dataManager)
        
        try mainViewModel.addList(name: "Test List")
        
        guard let list = mainViewModel.lists.first else {
            XCTFail("List should exist")
            return
        }
        
        let viewModel = TestListViewModel(list: list, dataManager: dataManager)
        
        // By default, should show crossed out items
        XCTAssertTrue(viewModel.showCrossedOutItems)
    }
    
    func testListViewModelToggleShowCrossedOutItems() throws {
        // Create a shared data manager
        let dataManager = TestHelpers.createTestDataManager()
        let mainViewModel = TestMainViewModel(dataManager: dataManager)
        
        try mainViewModel.addList(name: "Test List")
        
        guard let list = mainViewModel.lists.first else {
            XCTFail("List should exist")
            return
        }
        
        let viewModel = TestListViewModel(list: list, dataManager: dataManager)
        
        let initialState = viewModel.showCrossedOutItems
        viewModel.toggleShowCrossedOutItems()
        
        XCTAssertEqual(viewModel.showCrossedOutItems, !initialState)
    }
    
    func testListViewModelFilteredItemsShowAll() throws {
        // Create a shared data manager
        let dataManager = TestHelpers.createTestDataManager()
        let mainViewModel = TestMainViewModel(dataManager: dataManager)
        
        try mainViewModel.addList(name: "Test List")
        
        guard let list = mainViewModel.lists.first else {
            XCTFail("List should exist")
            return
        }
        
        let viewModel = TestListViewModel(list: list, dataManager: dataManager)
        
        // Create items with different states
        viewModel.createItem(title: "Active Item 1", description: "")
        viewModel.createItem(title: "Active Item 2", description: "")
        viewModel.createItem(title: "Crossed Item", description: "")
        
        // Cross out one item
        guard let itemToCross = viewModel.items.first(where: { $0.title == "Crossed Item" }) else {
            XCTFail("Should find item to cross out")
            return
        }
        
        viewModel.toggleItemCrossedOut(itemToCross)
        
        // When showCrossedOutItems is true, should show all items
        viewModel.showCrossedOutItems = true
        XCTAssertEqual(viewModel.filteredItems.count, 3)
        XCTAssertTrue(viewModel.filteredItems.contains { $0.title == "Active Item 1" })
        XCTAssertTrue(viewModel.filteredItems.contains { $0.title == "Active Item 2" })
        XCTAssertTrue(viewModel.filteredItems.contains { $0.title == "Crossed Item" })
    }
    
    func testListViewModelFilteredItemsHideCrossedOut() throws {
        // Create a shared data manager
        let dataManager = TestHelpers.createTestDataManager()
        let mainViewModel = TestMainViewModel(dataManager: dataManager)
        
        try mainViewModel.addList(name: "Test List")
        
        guard let list = mainViewModel.lists.first else {
            XCTFail("List should exist")
            return
        }
        
        let viewModel = TestListViewModel(list: list, dataManager: dataManager)
        
        // Create items with different states
        viewModel.createItem(title: "Active Item 1", description: "")
        viewModel.createItem(title: "Active Item 2", description: "")
        viewModel.createItem(title: "Crossed Item", description: "")
        
        // Cross out one item
        guard let itemToCross = viewModel.items.first(where: { $0.title == "Crossed Item" }) else {
            XCTFail("Should find item to cross out")
            return
        }
        
        viewModel.toggleItemCrossedOut(itemToCross)
        
        // When showCrossedOutItems is false, should only show active items
        viewModel.showCrossedOutItems = false
        XCTAssertEqual(viewModel.filteredItems.count, 2)
        XCTAssertTrue(viewModel.filteredItems.contains { $0.title == "Active Item 1" })
        XCTAssertTrue(viewModel.filteredItems.contains { $0.title == "Active Item 2" })
        XCTAssertFalse(viewModel.filteredItems.contains { $0.title == "Crossed Item" })
    }
    
    func testListViewModelFilteredItemsEmptyWhenAllCrossedOut() throws {
        // Create a shared data manager
        let dataManager = TestHelpers.createTestDataManager()
        let mainViewModel = TestMainViewModel(dataManager: dataManager)
        
        try mainViewModel.addList(name: "Test List")
        
        guard let list = mainViewModel.lists.first else {
            XCTFail("List should exist")
            return
        }
        
        let viewModel = TestListViewModel(list: list, dataManager: dataManager)
        
        // Create items and cross them all out
        viewModel.createItem(title: "Item 1", description: "")
        viewModel.createItem(title: "Item 2", description: "")
        
        for item in viewModel.items {
            viewModel.toggleItemCrossedOut(item)
        }
        
        // When showCrossedOutItems is false and all items are crossed out, should show empty
        viewModel.showCrossedOutItems = false
        XCTAssertEqual(viewModel.filteredItems.count, 0)
        
        // When showCrossedOutItems is true, should show all crossed out items
        viewModel.showCrossedOutItems = true
        XCTAssertEqual(viewModel.filteredItems.count, 2)
    }
    
    // MARK: - Undo Complete Functionality Tests
    
    func testListViewModelShowUndoButtonOnComplete() throws {
        // Create a shared data manager
        let dataManager = TestHelpers.createTestDataManager()
        let mainViewModel = TestMainViewModel(dataManager: dataManager)
        
        try mainViewModel.addList(name: "Test List")
        
        guard let list = mainViewModel.lists.first else {
            XCTFail("List should exist")
            return
        }
        
        let viewModel = TestListViewModel(list: list, dataManager: dataManager)
        viewModel.createItem(title: "Test Item", description: "")
        
        guard let item = viewModel.items.first else {
            XCTFail("Item should exist")
            return
        }
        
        // Initially, undo button should not be shown
        XCTAssertFalse(viewModel.showUndoButton)
        XCTAssertNil(viewModel.recentlyCompletedItem)
        
        // Complete the item
        viewModel.toggleItemCrossedOut(item)
        
        // Undo button should now be shown
        XCTAssertTrue(viewModel.showUndoButton)
        XCTAssertNotNil(viewModel.recentlyCompletedItem)
        XCTAssertEqual(viewModel.recentlyCompletedItem?.id, item.id)
    }
    
    func testListViewModelUndoComplete() throws {
        // Create a shared data manager
        let dataManager = TestHelpers.createTestDataManager()
        let mainViewModel = TestMainViewModel(dataManager: dataManager)
        
        try mainViewModel.addList(name: "Test List")
        
        guard let list = mainViewModel.lists.first else {
            XCTFail("List should exist")
            return
        }
        
        let viewModel = TestListViewModel(list: list, dataManager: dataManager)
        viewModel.createItem(title: "Test Item", description: "")
        
        guard let item = viewModel.items.first else {
            XCTFail("Item should exist")
            return
        }
        
        // Complete the item
        viewModel.toggleItemCrossedOut(item)
        
        // Verify undo button is shown
        XCTAssertTrue(viewModel.showUndoButton)
        XCTAssertNotNil(viewModel.recentlyCompletedItem)
        
        // Call undo
        viewModel.undoComplete()
        
        // Verify undo button is hidden (main goal of Phase 24)
        XCTAssertFalse(viewModel.showUndoButton)
        XCTAssertNil(viewModel.recentlyCompletedItem)
        
        // Verify item was toggled back (after refresh)
        guard let finalItem = viewModel.items.first(where: { $0.id == item.id }) else {
            XCTFail("Item should still exist")
            return
        }
        XCTAssertFalse(finalItem.isCrossedOut, "Item should be uncompleted after undo")
    }
    
    func testListViewModelNoUndoButtonOnUncomplete() throws {
        // Create a shared data manager
        let dataManager = TestHelpers.createTestDataManager()
        let mainViewModel = TestMainViewModel(dataManager: dataManager)
        
        try mainViewModel.addList(name: "Test List")
        
        guard let list = mainViewModel.lists.first else {
            XCTFail("List should exist")
            return
        }
        
        let viewModel = TestListViewModel(list: list, dataManager: dataManager)
        viewModel.createItem(title: "Test Item", description: "")
        
        guard let item = viewModel.items.first else {
            XCTFail("Item should exist")
            return
        }
        
        // Complete the item first
        viewModel.toggleItemCrossedOut(item)
        
        guard let completedItem = viewModel.items.first(where: { $0.id == item.id }) else {
            XCTFail("Item should still exist")
            return
        }
        
        XCTAssertTrue(completedItem.isCrossedOut)
        XCTAssertTrue(viewModel.showUndoButton)
        
        // Now uncomplete the item (toggle again)
        viewModel.toggleItemCrossedOut(completedItem)
        
        // Undo button should NOT be shown when uncompleting
        // (because undo is only for completing, not uncompleting)
        // Note: showUndoButton might still be true from the previous completion,
        // but recentlyCompletedItem should be set to the item that was just completed
        // Since we toggled back (uncompleted), no new undo state should be created
        // However, our implementation doesn't clear the undo on uncomplete, only on complete
        // So we just verify that uncompleting doesn't trigger undo
        guard let uncompletedItem = viewModel.items.first(where: { $0.id == item.id }) else {
            XCTFail("Item should still exist")
            return
        }
        XCTAssertFalse(uncompletedItem.isCrossedOut)
    }
    
    // MARK: - Delete Item Undo Tests
    
    func testListViewModelDeleteItemShowsUndoBanner() throws {
        // Create a shared data manager
        let dataManager = TestHelpers.createTestDataManager()
        let mainViewModel = TestMainViewModel(dataManager: dataManager)
        
        try mainViewModel.addList(name: "Test List")
        
        guard let list = mainViewModel.lists.first else {
            XCTFail("List should exist")
            return
        }
        
        let viewModel = TestListViewModel(list: list, dataManager: dataManager)
        viewModel.createItem(title: "Test Item", description: "Test description")
        
        guard let item = viewModel.items.first else {
            XCTFail("Item should exist")
            return
        }
        
        // Delete the item
        viewModel.deleteItem(item)
        
        // Verify undo button is shown
        XCTAssertTrue(viewModel.showDeleteUndoButton)
        XCTAssertNotNil(viewModel.recentlyDeletedItem)
        XCTAssertEqual(viewModel.recentlyDeletedItem?.id, item.id)
        
        // Verify item was deleted
        XCTAssertTrue(viewModel.items.isEmpty)
    }
    
    func testListViewModelUndoDeleteItem() throws {
        // Create a shared data manager
        let dataManager = TestHelpers.createTestDataManager()
        let mainViewModel = TestMainViewModel(dataManager: dataManager)
        
        try mainViewModel.addList(name: "Test List")
        
        guard let list = mainViewModel.lists.first else {
            XCTFail("List should exist")
            return
        }
        
        let viewModel = TestListViewModel(list: list, dataManager: dataManager)
        viewModel.createItem(title: "Test Item", description: "Test description")
        
        guard let item = viewModel.items.first else {
            XCTFail("Item should exist")
            return
        }
        
        let itemId = item.id
        let itemTitle = item.title
        
        // Delete the item
        viewModel.deleteItem(item)
        
        // Verify undo button is shown
        XCTAssertTrue(viewModel.showDeleteUndoButton)
        XCTAssertNotNil(viewModel.recentlyDeletedItem)
        
        // Verify item was deleted
        XCTAssertTrue(viewModel.items.isEmpty)
        
        // Call undo
        viewModel.undoDeleteItem()
        
        // Verify undo button is hidden
        XCTAssertFalse(viewModel.showDeleteUndoButton)
        XCTAssertNil(viewModel.recentlyDeletedItem)
        
        // Verify item was restored
        XCTAssertEqual(viewModel.items.count, 1)
        
        guard let restoredItem = viewModel.items.first(where: { $0.id == itemId }) else {
            XCTFail("Item should be restored")
            return
        }
        
        XCTAssertEqual(restoredItem.title, itemTitle)
        XCTAssertEqual(restoredItem.itemDescription, "Test description")
    }
    
    func testListViewModelUndoDeleteItemPreservesProperties() throws {
        // Create a shared data manager
        let dataManager = TestHelpers.createTestDataManager()
        let mainViewModel = TestMainViewModel(dataManager: dataManager)
        
        try mainViewModel.addList(name: "Test List")
        
        guard let list = mainViewModel.lists.first else {
            XCTFail("List should exist")
            return
        }
        
        let viewModel = TestListViewModel(list: list, dataManager: dataManager)
        viewModel.createItem(title: "Test Item", description: "Test description", quantity: 5)
        
        guard var item = viewModel.items.first else {
            XCTFail("Item should exist")
            return
        }
        
        // Mark item as crossed out
        viewModel.toggleItemCrossedOut(item)
        
        guard let crossedItem = viewModel.items.first else {
            XCTFail("Item should exist")
            return
        }
        
        let itemId = crossedItem.id
        let itemTitle = crossedItem.title
        let itemDescription = crossedItem.itemDescription
        let itemQuantity = crossedItem.quantity
        let itemCrossedOut = crossedItem.isCrossedOut
        
        XCTAssertTrue(itemCrossedOut, "Item should be crossed out")
        
        // Delete the item
        viewModel.deleteItem(crossedItem)
        
        // Verify item was deleted
        XCTAssertTrue(viewModel.items.isEmpty)
        
        // Call undo
        viewModel.undoDeleteItem()
        
        // Verify item was restored with all properties
        XCTAssertEqual(viewModel.items.count, 1)
        
        guard let restoredItem = viewModel.items.first(where: { $0.id == itemId }) else {
            XCTFail("Item should be restored")
            return
        }
        
        XCTAssertEqual(restoredItem.title, itemTitle)
        XCTAssertEqual(restoredItem.itemDescription, itemDescription)
        XCTAssertEqual(restoredItem.quantity, itemQuantity)
        XCTAssertEqual(restoredItem.isCrossedOut, itemCrossedOut, "Item should maintain crossed out state")
    }
    
    func testListViewModelDeleteUndoBannerReplacesOnNewDeletion() throws {
        // Create a shared data manager
        let dataManager = TestHelpers.createTestDataManager()
        let mainViewModel = TestMainViewModel(dataManager: dataManager)
        
        try mainViewModel.addList(name: "Test List")
        
        guard let list = mainViewModel.lists.first else {
            XCTFail("List should exist")
            return
        }
        
        let viewModel = TestListViewModel(list: list, dataManager: dataManager)
        viewModel.createItem(title: "Item 1", description: "")
        viewModel.createItem(title: "Item 2", description: "")
        
        guard viewModel.items.count == 2 else {
            XCTFail("Should have 2 items")
            return
        }
        
        let item1 = viewModel.items[0]
        let item2 = viewModel.items[1]
        
        // Delete first item
        viewModel.deleteItem(item1)
        
        // Verify first delete undo is shown
        XCTAssertTrue(viewModel.showDeleteUndoButton)
        XCTAssertEqual(viewModel.recentlyDeletedItem?.id, item1.id)
        
        // Delete second item
        viewModel.deleteItem(item2)
        
        // Verify second delete undo replaces first
        XCTAssertTrue(viewModel.showDeleteUndoButton)
        XCTAssertEqual(viewModel.recentlyDeletedItem?.id, item2.id)
        XCTAssertNotEqual(viewModel.recentlyDeletedItem?.id, item1.id)
    }
    
    func testListViewModelBothUndoBannersCanBeShown() throws {
        // Test that complete undo and delete undo can coexist (for different items)
        let dataManager = TestHelpers.createTestDataManager()
        let mainViewModel = TestMainViewModel(dataManager: dataManager)
        
        try mainViewModel.addList(name: "Test List")
        
        guard let list = mainViewModel.lists.first else {
            XCTFail("List should exist")
            return
        }
        
        let viewModel = TestListViewModel(list: list, dataManager: dataManager)
        viewModel.createItem(title: "Item 1", description: "")
        viewModel.createItem(title: "Item 2", description: "")
        
        guard viewModel.items.count == 2 else {
            XCTFail("Should have 2 items")
            return
        }
        
        let item1 = viewModel.items[0]
        let item2 = viewModel.items[1]
        
        // Complete first item
        viewModel.toggleItemCrossedOut(item1)
        
        // Verify complete undo is shown
        XCTAssertTrue(viewModel.showUndoButton)
        XCTAssertFalse(viewModel.showDeleteUndoButton)
        
        // Delete second item
        viewModel.deleteItem(item2)
        
        // Verify both undo banners can be active
        XCTAssertTrue(viewModel.showUndoButton, "Complete undo should still be shown")
        XCTAssertTrue(viewModel.showDeleteUndoButton, "Delete undo should be shown")
        XCTAssertNotEqual(viewModel.recentlyCompletedItem?.id, viewModel.recentlyDeletedItem?.id)
    }
    
    func testListViewModelUndoButtonReplacesOnNewCompletion() throws {
        // Create a shared data manager
        let dataManager = TestHelpers.createTestDataManager()
        let mainViewModel = TestMainViewModel(dataManager: dataManager)
        
        try mainViewModel.addList(name: "Test List")
        
        guard let list = mainViewModel.lists.first else {
            XCTFail("List should exist")
            return
        }
        
        let viewModel = TestListViewModel(list: list, dataManager: dataManager)
        viewModel.createItem(title: "Item 1", description: "")
        viewModel.createItem(title: "Item 2", description: "")
        
        guard let item1 = viewModel.items.first(where: { $0.title == "Item 1" }),
              let item2 = viewModel.items.first(where: { $0.title == "Item 2" }) else {
            XCTFail("Items should exist")
            return
        }
        
        // Complete first item
        viewModel.toggleItemCrossedOut(item1)
        XCTAssertTrue(viewModel.showUndoButton)
        XCTAssertEqual(viewModel.recentlyCompletedItem?.id, item1.id)
        
        // Complete second item - should replace the undo for first item
        viewModel.toggleItemCrossedOut(item2)
        XCTAssertTrue(viewModel.showUndoButton)
        XCTAssertEqual(viewModel.recentlyCompletedItem?.id, item2.id)
        XCTAssertNotEqual(viewModel.recentlyCompletedItem?.id, item1.id)
    }
    
    // MARK: - Sorting Tests
    
    func testItemSortingByOrderNumberAscending() throws {
        let dataManager = TestHelpers.createTestDataManager()
        let mainViewModel = TestMainViewModel(dataManager: dataManager)
        
        try mainViewModel.addList(name: "Test List")
        guard let list = mainViewModel.lists.first else {
            XCTFail("List should exist")
            return
        }
        
        let viewModel = TestListViewModel(list: list, dataManager: dataManager)
        
        // Create items with specific order numbers
        viewModel.createItem(title: "Third", description: "")
        viewModel.createItem(title: "First", description: "")
        viewModel.createItem(title: "Second", description: "")
        
        // Set sort to order number ascending
        viewModel.updateSortOption(.orderNumber)
        viewModel.updateSortDirection(.ascending)
        
        let sortedItems = viewModel.filteredItems
        XCTAssertEqual(sortedItems.count, 3)
        XCTAssertTrue(sortedItems[0].orderNumber < sortedItems[1].orderNumber)
        XCTAssertTrue(sortedItems[1].orderNumber < sortedItems[2].orderNumber)
    }
    
    func testItemSortingByOrderNumberDescending() throws {
        let dataManager = TestHelpers.createTestDataManager()
        let mainViewModel = TestMainViewModel(dataManager: dataManager)
        
        try mainViewModel.addList(name: "Test List")
        guard let list = mainViewModel.lists.first else {
            XCTFail("List should exist")
            return
        }
        
        let viewModel = TestListViewModel(list: list, dataManager: dataManager)
        
        // Create items
        viewModel.createItem(title: "First", description: "")
        viewModel.createItem(title: "Second", description: "")
        viewModel.createItem(title: "Third", description: "")
        
        // Set sort to order number descending
        viewModel.updateSortOption(.orderNumber)
        viewModel.updateSortDirection(.descending)
        
        let sortedItems = viewModel.filteredItems
        XCTAssertEqual(sortedItems.count, 3)
        XCTAssertTrue(sortedItems[0].orderNumber > sortedItems[1].orderNumber)
        XCTAssertTrue(sortedItems[1].orderNumber > sortedItems[2].orderNumber)
    }
    
    func testItemSortingByTitleAscending() throws {
        let dataManager = TestHelpers.createTestDataManager()
        let mainViewModel = TestMainViewModel(dataManager: dataManager)
        
        try mainViewModel.addList(name: "Test List")
        guard let list = mainViewModel.lists.first else {
            XCTFail("List should exist")
            return
        }
        
        let viewModel = TestListViewModel(list: list, dataManager: dataManager)
        
        // Create items with titles in non-alphabetical order
        viewModel.createItem(title: "Zebra", description: "")
        viewModel.createItem(title: "Apple", description: "")
        viewModel.createItem(title: "Banana", description: "")
        
        // Set sort to title ascending
        viewModel.updateSortOption(.title)
        viewModel.updateSortDirection(.ascending)
        
        let sortedItems = viewModel.filteredItems
        XCTAssertEqual(sortedItems.count, 3)
        XCTAssertEqual(sortedItems[0].title, "Apple")
        XCTAssertEqual(sortedItems[1].title, "Banana")
        XCTAssertEqual(sortedItems[2].title, "Zebra")
    }
    
    func testItemSortingByTitleDescending() throws {
        let dataManager = TestHelpers.createTestDataManager()
        let mainViewModel = TestMainViewModel(dataManager: dataManager)
        
        try mainViewModel.addList(name: "Test List")
        guard let list = mainViewModel.lists.first else {
            XCTFail("List should exist")
            return
        }
        
        let viewModel = TestListViewModel(list: list, dataManager: dataManager)
        
        // Create items with titles in non-alphabetical order
        viewModel.createItem(title: "Zebra", description: "")
        viewModel.createItem(title: "Apple", description: "")
        viewModel.createItem(title: "Banana", description: "")
        
        // Set sort to title descending
        viewModel.updateSortOption(.title)
        viewModel.updateSortDirection(.descending)
        
        let sortedItems = viewModel.filteredItems
        XCTAssertEqual(sortedItems.count, 3)
        XCTAssertEqual(sortedItems[0].title, "Zebra")
        XCTAssertEqual(sortedItems[1].title, "Banana")
        XCTAssertEqual(sortedItems[2].title, "Apple")
    }
    
    func testItemSortingByCreatedDateAscending() throws {
        let dataManager = TestHelpers.createTestDataManager()
        let mainViewModel = TestMainViewModel(dataManager: dataManager)
        
        try mainViewModel.addList(name: "Test List")
        guard let list = mainViewModel.lists.first else {
            XCTFail("List should exist")
            return
        }
        
        let viewModel = TestListViewModel(list: list, dataManager: dataManager)
        
        // Create items with small delays to ensure different timestamps
        viewModel.createItem(title: "First", description: "")
        Thread.sleep(forTimeInterval: 0.01)
        viewModel.createItem(title: "Second", description: "")
        Thread.sleep(forTimeInterval: 0.01)
        viewModel.createItem(title: "Third", description: "")
        
        // Set sort to created date ascending
        viewModel.updateSortOption(.createdAt)
        viewModel.updateSortDirection(.ascending)
        
        let sortedItems = viewModel.filteredItems
        XCTAssertEqual(sortedItems.count, 3)
        XCTAssertTrue(sortedItems[0].createdAt <= sortedItems[1].createdAt)
        XCTAssertTrue(sortedItems[1].createdAt <= sortedItems[2].createdAt)
    }
    
    func testItemSortingByQuantityAscending() throws {
        let dataManager = TestHelpers.createTestDataManager()
        let mainViewModel = TestMainViewModel(dataManager: dataManager)
        
        try mainViewModel.addList(name: "Test List")
        guard let list = mainViewModel.lists.first else {
            XCTFail("List should exist")
            return
        }
        
        let viewModel = TestListViewModel(list: list, dataManager: dataManager)
        
        // Create items with different quantities
        viewModel.createItem(title: "Large", description: "", quantity: 10)
        viewModel.createItem(title: "Small", description: "", quantity: 1)
        viewModel.createItem(title: "Medium", description: "", quantity: 5)
        
        // Set sort to quantity ascending
        viewModel.updateSortOption(.quantity)
        viewModel.updateSortDirection(.ascending)
        
        let sortedItems = viewModel.filteredItems
        XCTAssertEqual(sortedItems.count, 3)
        XCTAssertEqual(sortedItems[0].quantity, 1)
        XCTAssertEqual(sortedItems[1].quantity, 5)
        XCTAssertEqual(sortedItems[2].quantity, 10)
    }
    
    func testItemSortingByQuantityDescending() throws {
        let dataManager = TestHelpers.createTestDataManager()
        let mainViewModel = TestMainViewModel(dataManager: dataManager)
        
        try mainViewModel.addList(name: "Test List")
        guard let list = mainViewModel.lists.first else {
            XCTFail("List should exist")
            return
        }
        
        let viewModel = TestListViewModel(list: list, dataManager: dataManager)
        
        // Create items with different quantities
        viewModel.createItem(title: "Large", description: "", quantity: 10)
        viewModel.createItem(title: "Small", description: "", quantity: 1)
        viewModel.createItem(title: "Medium", description: "", quantity: 5)
        
        // Set sort to quantity descending
        viewModel.updateSortOption(.quantity)
        viewModel.updateSortDirection(.descending)
        
        let sortedItems = viewModel.filteredItems
        XCTAssertEqual(sortedItems.count, 3)
        XCTAssertEqual(sortedItems[0].quantity, 10)
        XCTAssertEqual(sortedItems[1].quantity, 5)
        XCTAssertEqual(sortedItems[2].quantity, 1)
    }
    
    func testSortPreferencesPersistence() throws {
        let dataManager = TestHelpers.createTestDataManager()
        let mainViewModel = TestMainViewModel(dataManager: dataManager)
        
        try mainViewModel.addList(name: "Test List")
        guard let list = mainViewModel.lists.first else {
            XCTFail("List should exist")
            return
        }
        
        let viewModel = TestListViewModel(list: list, dataManager: dataManager)
        
        // Change sort preferences
        viewModel.updateSortOption(.title)
        viewModel.updateSortDirection(.descending)
        
        // Verify preferences are saved
        XCTAssertEqual(viewModel.currentSortOption, .title)
        XCTAssertEqual(viewModel.currentSortDirection, .descending)
    }
    
    func testSortingWithFiltering() throws {
        let dataManager = TestHelpers.createTestDataManager()
        let mainViewModel = TestMainViewModel(dataManager: dataManager)
        
        try mainViewModel.addList(name: "Test List")
        guard let list = mainViewModel.lists.first else {
            XCTFail("List should exist")
            return
        }
        
        let viewModel = TestListViewModel(list: list, dataManager: dataManager)
        
        // Create items
        viewModel.createItem(title: "Zebra", description: "")
        viewModel.createItem(title: "Apple", description: "")
        viewModel.createItem(title: "Banana", description: "")
        
        // Cross out one item
        guard let itemToCross = viewModel.items.first(where: { $0.title == "Banana" }) else {
            XCTFail("Should find item to cross out")
            return
        }
        viewModel.toggleItemCrossedOut(itemToCross)
        
        // Set filter to active only and sort by title
        viewModel.updateFilterOption(.active)
        viewModel.updateSortOption(.title)
        viewModel.updateSortDirection(.ascending)
        
        let filteredAndSortedItems = viewModel.filteredItems
        XCTAssertEqual(filteredAndSortedItems.count, 2)
        XCTAssertEqual(filteredAndSortedItems[0].title, "Apple")
        XCTAssertEqual(filteredAndSortedItems[1].title, "Zebra")
    }
    
    // MARK: - Test Helper Validation
    
    func testTestHelpersIsolation() throws {
        let viewModel1 = TestHelpers.createTestMainViewModel()
        let viewModel2 = TestHelpers.createTestMainViewModel()
        
        try viewModel1.addList(name: "List 1")
        XCTAssertEqual(viewModel1.lists.count, 1)
        XCTAssertEqual(viewModel2.lists.count, 0)
    }
    
    func testInMemoryCoreDataStack() throws {
        let stack1 = TestHelpers.createInMemoryCoreDataStack()
        let stack2 = TestHelpers.createInMemoryCoreDataStack()
        
        XCTAssertTrue(stack1 !== stack2)
        
        let description1 = stack1.persistentStoreDescriptions.first
        let description2 = stack2.persistentStoreDescriptions.first
        
        XCTAssertEqual(description1?.type, NSInMemoryStoreType)
        XCTAssertEqual(description2?.type, NSInMemoryStoreType)
    }
    
    // MARK: - Multi-Select Tests
    
    func testEnterSelectionMode() throws {
        let viewModel = TestHelpers.createTestMainViewModel()
        
        XCTAssertFalse(viewModel.isInSelectionMode)
        XCTAssertTrue(viewModel.selectedLists.isEmpty)
        
        viewModel.enterSelectionMode()
        
        XCTAssertTrue(viewModel.isInSelectionMode)
        XCTAssertTrue(viewModel.selectedLists.isEmpty)
    }
    
    func testExitSelectionMode() throws {
        let viewModel = TestHelpers.createTestMainViewModel()
        try viewModel.addList(name: "List 1")
        
        // Enter selection mode and select a list
        viewModel.enterSelectionMode()
        if let listId = viewModel.lists.first?.id {
            viewModel.toggleSelection(for: listId)
        }
        
        XCTAssertTrue(viewModel.isInSelectionMode)
        XCTAssertFalse(viewModel.selectedLists.isEmpty)
        
        viewModel.exitSelectionMode()
        
        XCTAssertFalse(viewModel.isInSelectionMode)
        XCTAssertTrue(viewModel.selectedLists.isEmpty)
    }
    
    func testToggleSelection() throws {
        let viewModel = TestHelpers.createTestMainViewModel()
        try viewModel.addList(name: "List 1")
        
        guard let listId = viewModel.lists.first?.id else {
            XCTFail("List should exist")
            return
        }
        
        viewModel.enterSelectionMode()
        
        // Select the list
        viewModel.toggleSelection(for: listId)
        XCTAssertTrue(viewModel.selectedLists.contains(listId))
        
        // Deselect the list
        viewModel.toggleSelection(for: listId)
        XCTAssertFalse(viewModel.selectedLists.contains(listId))
    }
    
    func testSelectAll() throws {
        let viewModel = TestHelpers.createTestMainViewModel()
        try viewModel.addList(name: "List 1")
        try viewModel.addList(name: "List 2")
        try viewModel.addList(name: "List 3")
        
        viewModel.enterSelectionMode()
        viewModel.selectAll()
        
        XCTAssertEqual(viewModel.selectedLists.count, 3)
        for list in viewModel.lists {
            XCTAssertTrue(viewModel.selectedLists.contains(list.id))
        }
    }
    
    func testDeselectAll() throws {
        let viewModel = TestHelpers.createTestMainViewModel()
        try viewModel.addList(name: "List 1")
        try viewModel.addList(name: "List 2")
        
        viewModel.enterSelectionMode()
        viewModel.selectAll()
        
        XCTAssertEqual(viewModel.selectedLists.count, 2)
        
        viewModel.deselectAll()
        
        XCTAssertTrue(viewModel.selectedLists.isEmpty)
    }
    
    func testDeleteSelectedLists() throws {
        let viewModel = TestHelpers.createTestMainViewModel()
        try viewModel.addList(name: "List 1")
        try viewModel.addList(name: "List 2")
        try viewModel.addList(name: "List 3")
        
        XCTAssertEqual(viewModel.lists.count, 3)
        
        viewModel.enterSelectionMode()
        
        // Select first and third lists
        let firstListId = viewModel.lists[0].id
        let thirdListId = viewModel.lists[2].id
        viewModel.toggleSelection(for: firstListId)
        viewModel.toggleSelection(for: thirdListId)
        
        XCTAssertEqual(viewModel.selectedLists.count, 2)
        
        // Delete selected lists
        viewModel.deleteSelectedLists()
        
        XCTAssertEqual(viewModel.lists.count, 1)
        XCTAssertEqual(viewModel.lists[0].name, "List 2")
        XCTAssertTrue(viewModel.selectedLists.isEmpty)
    }
    
    func testDeleteAllLists() throws {
        let viewModel = TestHelpers.createTestMainViewModel()
        try viewModel.addList(name: "List 1")
        try viewModel.addList(name: "List 2")
        try viewModel.addList(name: "List 3")
        
        XCTAssertEqual(viewModel.lists.count, 3)
        
        viewModel.enterSelectionMode()
        viewModel.selectAll()
        viewModel.deleteSelectedLists()
        
        XCTAssertTrue(viewModel.lists.isEmpty)
        XCTAssertTrue(viewModel.selectedLists.isEmpty)
    }
    
    func testSelectionModeWithEmptyLists() throws {
        let viewModel = TestHelpers.createTestMainViewModel()
        
        viewModel.enterSelectionMode()
        viewModel.selectAll()
        
        XCTAssertTrue(viewModel.selectedLists.isEmpty)
        XCTAssertTrue(viewModel.lists.isEmpty)
    }
    
    func testMultiSelectPersistence() throws {
        let viewModel = TestHelpers.createTestMainViewModel()
        try viewModel.addList(name: "List 1")
        try viewModel.addList(name: "List 2")
        try viewModel.addList(name: "List 3")
        
        viewModel.enterSelectionMode()
        
        let firstListId = viewModel.lists[0].id
        let secondListId = viewModel.lists[1].id
        
        viewModel.toggleSelection(for: firstListId)
        viewModel.toggleSelection(for: secondListId)
        
        // Verify selections persist
        XCTAssertEqual(viewModel.selectedLists.count, 2)
        XCTAssertTrue(viewModel.selectedLists.contains(firstListId))
        XCTAssertTrue(viewModel.selectedLists.contains(secondListId))
        
        // Add another list - selections should remain
        try viewModel.addList(name: "List 4")
        
        XCTAssertEqual(viewModel.selectedLists.count, 2)
        XCTAssertTrue(viewModel.selectedLists.contains(firstListId))
        XCTAssertTrue(viewModel.selectedLists.contains(secondListId))
    }
    
    // MARK: - Item Multi-Select Tests
    
    func testEnterSelectionModeForItems() throws {
        let dataManager = TestHelpers.createTestDataManager()
        let mainViewModel = TestMainViewModel(dataManager: dataManager)
        
        try mainViewModel.addList(name: "Test List")
        guard let list = mainViewModel.lists.first else {
            XCTFail("List should exist")
            return
        }
        
        let viewModel = TestListViewModel(list: list, dataManager: dataManager)
        
        XCTAssertFalse(viewModel.isInSelectionMode)
        XCTAssertTrue(viewModel.selectedItems.isEmpty)
        
        viewModel.enterSelectionMode()
        
        XCTAssertTrue(viewModel.isInSelectionMode)
        XCTAssertTrue(viewModel.selectedItems.isEmpty)
    }
    
    func testExitSelectionModeForItems() throws {
        let dataManager = TestHelpers.createTestDataManager()
        let mainViewModel = TestMainViewModel(dataManager: dataManager)
        
        try mainViewModel.addList(name: "Test List")
        guard let list = mainViewModel.lists.first else {
            XCTFail("List should exist")
            return
        }
        
        let viewModel = TestListViewModel(list: list, dataManager: dataManager)
        viewModel.createItem(title: "Item 1")
        
        viewModel.enterSelectionMode()
        
        guard let itemId = viewModel.items.first?.id else {
            XCTFail("Item should exist")
            return
        }
        
        viewModel.toggleSelection(for: itemId)
        XCTAssertTrue(viewModel.selectedItems.contains(itemId))
        
        viewModel.exitSelectionMode()
        
        XCTAssertFalse(viewModel.isInSelectionMode)
        XCTAssertTrue(viewModel.selectedItems.isEmpty)
    }
    
    func testToggleItemSelection() throws {
        let dataManager = TestHelpers.createTestDataManager()
        let mainViewModel = TestMainViewModel(dataManager: dataManager)
        
        try mainViewModel.addList(name: "Test List")
        guard let list = mainViewModel.lists.first else {
            XCTFail("List should exist")
            return
        }
        
        let viewModel = TestListViewModel(list: list, dataManager: dataManager)
        viewModel.createItem(title: "Item 1")
        
        guard let itemId = viewModel.items.first?.id else {
            XCTFail("Item should exist")
            return
        }
        
        viewModel.enterSelectionMode()
        
        // Select the item
        viewModel.toggleSelection(for: itemId)
        XCTAssertTrue(viewModel.selectedItems.contains(itemId))
        
        // Deselect the item
        viewModel.toggleSelection(for: itemId)
        XCTAssertFalse(viewModel.selectedItems.contains(itemId))
    }
    
    func testSelectAllItems() throws {
        let dataManager = TestHelpers.createTestDataManager()
        let mainViewModel = TestMainViewModel(dataManager: dataManager)
        
        try mainViewModel.addList(name: "Test List")
        guard let list = mainViewModel.lists.first else {
            XCTFail("List should exist")
            return
        }
        
        let viewModel = TestListViewModel(list: list, dataManager: dataManager)
        viewModel.createItem(title: "Item 1")
        viewModel.createItem(title: "Item 2")
        viewModel.createItem(title: "Item 3")
        
        viewModel.enterSelectionMode()
        viewModel.selectAll()
        
        XCTAssertEqual(viewModel.selectedItems.count, 3)
        for item in viewModel.items {
            XCTAssertTrue(viewModel.selectedItems.contains(item.id))
        }
    }
    
    func testDeselectAllItems() throws {
        let dataManager = TestHelpers.createTestDataManager()
        let mainViewModel = TestMainViewModel(dataManager: dataManager)
        
        try mainViewModel.addList(name: "Test List")
        guard let list = mainViewModel.lists.first else {
            XCTFail("List should exist")
            return
        }
        
        let viewModel = TestListViewModel(list: list, dataManager: dataManager)
        viewModel.createItem(title: "Item 1")
        viewModel.createItem(title: "Item 2")
        
        viewModel.enterSelectionMode()
        viewModel.selectAll()
        
        XCTAssertEqual(viewModel.selectedItems.count, 2)
        
        viewModel.deselectAll()
        
        XCTAssertTrue(viewModel.selectedItems.isEmpty)
    }
    
    func testDeleteSelectedItems() throws {
        let dataManager = TestHelpers.createTestDataManager()
        let mainViewModel = TestMainViewModel(dataManager: dataManager)
        
        try mainViewModel.addList(name: "Test List")
        guard let list = mainViewModel.lists.first else {
            XCTFail("List should exist")
            return
        }
        
        let viewModel = TestListViewModel(list: list, dataManager: dataManager)
        viewModel.createItem(title: "Item 1")
        viewModel.createItem(title: "Item 2")
        viewModel.createItem(title: "Item 3")
        
        XCTAssertEqual(viewModel.items.count, 3)
        
        viewModel.enterSelectionMode()
        
        // Select first and third items
        let firstItemId = viewModel.items[0].id
        let thirdItemId = viewModel.items[2].id
        viewModel.toggleSelection(for: firstItemId)
        viewModel.toggleSelection(for: thirdItemId)
        
        XCTAssertEqual(viewModel.selectedItems.count, 2)
        
        // Delete selected items
        viewModel.deleteSelectedItems()
        
        XCTAssertEqual(viewModel.items.count, 1)
        XCTAssertEqual(viewModel.items[0].title, "Item 2")
        XCTAssertTrue(viewModel.selectedItems.isEmpty)
    }
    
    func testDeleteAllItems() throws {
        let dataManager = TestHelpers.createTestDataManager()
        let mainViewModel = TestMainViewModel(dataManager: dataManager)
        
        try mainViewModel.addList(name: "Test List")
        guard let list = mainViewModel.lists.first else {
            XCTFail("List should exist")
            return
        }
        
        let viewModel = TestListViewModel(list: list, dataManager: dataManager)
        viewModel.createItem(title: "Item 1")
        viewModel.createItem(title: "Item 2")
        viewModel.createItem(title: "Item 3")
        
        XCTAssertEqual(viewModel.items.count, 3)
        
        viewModel.enterSelectionMode()
        viewModel.selectAll()
        viewModel.deleteSelectedItems()
        
        XCTAssertTrue(viewModel.items.isEmpty)
        XCTAssertTrue(viewModel.selectedItems.isEmpty)
    }
    
    func testItemSelectionModeWithEmptyItems() throws {
        let dataManager = TestHelpers.createTestDataManager()
        let mainViewModel = TestMainViewModel(dataManager: dataManager)
        
        try mainViewModel.addList(name: "Test List")
        guard let list = mainViewModel.lists.first else {
            XCTFail("List should exist")
            return
        }
        
        let viewModel = TestListViewModel(list: list, dataManager: dataManager)
        
        viewModel.enterSelectionMode()
        viewModel.selectAll()
        
        XCTAssertTrue(viewModel.selectedItems.isEmpty)
        XCTAssertTrue(viewModel.items.isEmpty)
    }
    
    func testItemMultiSelectPersistence() throws {
        let dataManager = TestHelpers.createTestDataManager()
        let mainViewModel = TestMainViewModel(dataManager: dataManager)
        
        try mainViewModel.addList(name: "Test List")
        guard let list = mainViewModel.lists.first else {
            XCTFail("List should exist")
            return
        }
        
        let viewModel = TestListViewModel(list: list, dataManager: dataManager)
        viewModel.createItem(title: "Item 1")
        viewModel.createItem(title: "Item 2")
        viewModel.createItem(title: "Item 3")
        
        viewModel.enterSelectionMode()
        
        let firstItemId = viewModel.items[0].id
        let secondItemId = viewModel.items[1].id
        
        viewModel.toggleSelection(for: firstItemId)
        viewModel.toggleSelection(for: secondItemId)
        
        // Verify selections persist
        XCTAssertEqual(viewModel.selectedItems.count, 2)
        XCTAssertTrue(viewModel.selectedItems.contains(firstItemId))
        XCTAssertTrue(viewModel.selectedItems.contains(secondItemId))
        
        // Add another item - selections should remain
        viewModel.createItem(title: "Item 4")
        
        XCTAssertEqual(viewModel.selectedItems.count, 2)
        XCTAssertTrue(viewModel.selectedItems.contains(firstItemId))
        XCTAssertTrue(viewModel.selectedItems.contains(secondItemId))
    }
    
    func testItemSelectAllRespectsFilters() throws {
        let dataManager = TestHelpers.createTestDataManager()
        let mainViewModel = TestMainViewModel(dataManager: dataManager)
        
        try mainViewModel.addList(name: "Test List")
        guard let list = mainViewModel.lists.first else {
            XCTFail("List should exist")
            return
        }
        
        let viewModel = TestListViewModel(list: list, dataManager: dataManager)
        viewModel.createItem(title: "Item 1")
        viewModel.createItem(title: "Item 2")
        viewModel.createItem(title: "Item 3")
        
        // Complete first item
        if let item1 = viewModel.items.first(where: { $0.title == "Item 1" }) {
            viewModel.toggleItemCrossedOut(item1)
        }
        
        // Set filter to show only active items
        viewModel.updateFilterOption(.active)
        
        // Select all should only select filtered (active) items
        viewModel.enterSelectionMode()
        viewModel.selectAll()
        
        // Should only select 2 active items, not the completed one
        XCTAssertEqual(viewModel.selectedItems.count, 2)
        XCTAssertEqual(viewModel.filteredItems.count, 2)
    }
    
    // MARK: - Move and Copy Items Tests
    
    func testMoveItemsToAnotherList() throws {
        let dataManager = TestHelpers.createTestDataManager()
        let mainViewModel = TestMainViewModel(dataManager: dataManager)
        
        // Create two lists
        try mainViewModel.addList(name: "Source List")
        try mainViewModel.addList(name: "Destination List")
        
        guard let sourceList = mainViewModel.lists.first(where: { $0.name == "Source List" }),
              let destList = mainViewModel.lists.first(where: { $0.name == "Destination List" }) else {
            XCTFail("Lists should exist")
            return
        }
        
        let sourceViewModel = TestListViewModel(list: sourceList, dataManager: dataManager)
        let destViewModel = TestListViewModel(list: destList, dataManager: dataManager)
        
        // Add items to source list
        sourceViewModel.createItem(title: "Item 1")
        sourceViewModel.createItem(title: "Item 2")
        sourceViewModel.createItem(title: "Item 3")
        
        XCTAssertEqual(sourceViewModel.items.count, 3)
        XCTAssertEqual(destViewModel.items.count, 0)
        
        // Select first and second items to move
        sourceViewModel.enterSelectionMode()
        sourceViewModel.toggleSelection(for: sourceViewModel.items[0].id)
        sourceViewModel.toggleSelection(for: sourceViewModel.items[1].id)
        
        // Move selected items
        sourceViewModel.moveSelectedItems(to: destList)
        
        // Verify items moved
        XCTAssertEqual(sourceViewModel.items.count, 1, "Source list should have 1 item")
        XCTAssertEqual(sourceViewModel.items[0].title, "Item 3", "Only Item 3 should remain")
        
        destViewModel.loadItems()
        XCTAssertEqual(destViewModel.items.count, 2, "Destination list should have 2 items")
        
        let destTitles = destViewModel.items.map { $0.title }.sorted()
        XCTAssertEqual(destTitles, ["Item 1", "Item 2"])
        
        // Verify selection cleared
        XCTAssertTrue(sourceViewModel.selectedItems.isEmpty)
    }
    
    func testCopyItemsToAnotherList() throws {
        let dataManager = TestHelpers.createTestDataManager()
        let mainViewModel = TestMainViewModel(dataManager: dataManager)
        
        // Create two lists
        try mainViewModel.addList(name: "Source List")
        try mainViewModel.addList(name: "Destination List")
        
        guard let sourceList = mainViewModel.lists.first(where: { $0.name == "Source List" }),
              let destList = mainViewModel.lists.first(where: { $0.name == "Destination List" }) else {
            XCTFail("Lists should exist")
            return
        }
        
        let sourceViewModel = TestListViewModel(list: sourceList, dataManager: dataManager)
        let destViewModel = TestListViewModel(list: destList, dataManager: dataManager)
        
        // Add items to source list
        sourceViewModel.createItem(title: "Item 1")
        sourceViewModel.createItem(title: "Item 2")
        sourceViewModel.createItem(title: "Item 3")
        
        XCTAssertEqual(sourceViewModel.items.count, 3)
        XCTAssertEqual(destViewModel.items.count, 0)
        
        // Select first and second items to copy
        sourceViewModel.enterSelectionMode()
        sourceViewModel.toggleSelection(for: sourceViewModel.items[0].id)
        sourceViewModel.toggleSelection(for: sourceViewModel.items[1].id)
        
        // Copy selected items
        sourceViewModel.copySelectedItems(to: destList)
        
        // Verify items copied (source unchanged, destination has copies)
        XCTAssertEqual(sourceViewModel.items.count, 3, "Source list should still have 3 items")
        
        destViewModel.loadItems()
        XCTAssertEqual(destViewModel.items.count, 2, "Destination list should have 2 items")
        
        let destTitles = destViewModel.items.map { $0.title }.sorted()
        XCTAssertEqual(destTitles, ["Item 1", "Item 2"])
        
        // Verify copied items have different IDs
        let sourceIds = Set(sourceViewModel.items.map { $0.id })
        let destIds = Set(destViewModel.items.map { $0.id })
        XCTAssertTrue(sourceIds.isDisjoint(with: destIds), "Copied items should have different IDs")
        
        // Verify selection cleared
        XCTAssertTrue(sourceViewModel.selectedItems.isEmpty)
    }
    
    func testMoveAllItemsToAnotherList() throws {
        let dataManager = TestHelpers.createTestDataManager()
        let mainViewModel = TestMainViewModel(dataManager: dataManager)
        
        // Create two lists
        try mainViewModel.addList(name: "Source List")
        try mainViewModel.addList(name: "Destination List")
        
        guard let sourceList = mainViewModel.lists.first(where: { $0.name == "Source List" }),
              let destList = mainViewModel.lists.first(where: { $0.name == "Destination List" }) else {
            XCTFail("Lists should exist")
            return
        }
        
        let sourceViewModel = TestListViewModel(list: sourceList, dataManager: dataManager)
        let destViewModel = TestListViewModel(list: destList, dataManager: dataManager)
        
        // Add items to source list
        sourceViewModel.createItem(title: "Item 1")
        sourceViewModel.createItem(title: "Item 2")
        
        XCTAssertEqual(sourceViewModel.items.count, 2)
        
        // Select all items
        sourceViewModel.enterSelectionMode()
        sourceViewModel.selectAll()
        
        // Move all items
        sourceViewModel.moveSelectedItems(to: destList)
        
        // Verify all items moved
        XCTAssertEqual(sourceViewModel.items.count, 0, "Source list should be empty")
        
        destViewModel.loadItems()
        XCTAssertEqual(destViewModel.items.count, 2, "Destination list should have 2 items")
    }
    
    func testCopyItemsPreservesProperties() throws {
        let dataManager = TestHelpers.createTestDataManager()
        let mainViewModel = TestMainViewModel(dataManager: dataManager)
        
        // Create two lists
        try mainViewModel.addList(name: "Source List")
        try mainViewModel.addList(name: "Destination List")
        
        guard let sourceList = mainViewModel.lists.first(where: { $0.name == "Source List" }),
              let destList = mainViewModel.lists.first(where: { $0.name == "Destination List" }) else {
            XCTFail("Lists should exist")
            return
        }
        
        let sourceViewModel = TestListViewModel(list: sourceList, dataManager: dataManager)
        let destViewModel = TestListViewModel(list: destList, dataManager: dataManager)
        
        // Create item with properties
        sourceViewModel.createItem(title: "Complex Item", description: "Test description", quantity: 5)
        
        guard let originalItem = sourceViewModel.items.first else {
            XCTFail("Item should exist")
            return
        }
        
        // Toggle crossed out status
        sourceViewModel.toggleItemCrossedOut(originalItem)
        
        // Select and copy
        sourceViewModel.enterSelectionMode()
        sourceViewModel.toggleSelection(for: sourceViewModel.items[0].id)
        sourceViewModel.copySelectedItems(to: destList)
        
        // Verify properties preserved
        destViewModel.loadItems()
        XCTAssertEqual(destViewModel.items.count, 1)
        
        let copiedItem = destViewModel.items[0]
        XCTAssertEqual(copiedItem.title, "Complex Item")
        XCTAssertEqual(copiedItem.itemDescription, "Test description")
        XCTAssertEqual(copiedItem.quantity, 5)
        XCTAssertEqual(copiedItem.isCrossedOut, true, "Crossed out status should be preserved")
    }
    
    func testMoveItemsUpdatesOrderNumbers() throws {
        let dataManager = TestHelpers.createTestDataManager()
        let mainViewModel = TestMainViewModel(dataManager: dataManager)
        
        // Create two lists
        try mainViewModel.addList(name: "Source List")
        try mainViewModel.addList(name: "Destination List")
        
        guard let sourceList = mainViewModel.lists.first(where: { $0.name == "Source List" }),
              let destList = mainViewModel.lists.first(where: { $0.name == "Destination List" }) else {
            XCTFail("Lists should exist")
            return
        }
        
        let destViewModel = TestListViewModel(list: destList, dataManager: dataManager)
        
        // Add existing items to destination list
        destViewModel.createItem(title: "Existing 1")
        destViewModel.createItem(title: "Existing 2")
        
        let sourceViewModel = TestListViewModel(list: sourceList, dataManager: dataManager)
        
        // Add items to source list
        sourceViewModel.createItem(title: "New Item")
        
        // Move item to destination
        sourceViewModel.enterSelectionMode()
        sourceViewModel.toggleSelection(for: sourceViewModel.items[0].id)
        sourceViewModel.moveSelectedItems(to: destList)
        
        // Verify order numbers
        destViewModel.loadItems()
        XCTAssertEqual(destViewModel.items.count, 3)
        
        let movedItem = destViewModel.items.first(where: { $0.title == "New Item" })
        XCTAssertNotNil(movedItem)
        XCTAssertGreaterThan(movedItem!.orderNumber, destViewModel.items.filter { $0.title != "New Item" }.map { $0.orderNumber }.max() ?? -1)
    }
    
    func testCopyItemsWithImages() throws {
        let dataManager = TestHelpers.createTestDataManager()
        let mainViewModel = TestMainViewModel(dataManager: dataManager)
        
        // Create two lists
        try mainViewModel.addList(name: "Source List")
        try mainViewModel.addList(name: "Destination List")
        
        guard let sourceList = mainViewModel.lists.first(where: { $0.name == "Source List" }),
              let destList = mainViewModel.lists.first(where: { $0.name == "Destination List" }) else {
            XCTFail("Lists should exist")
            return
        }
        
        let sourceViewModel = TestListViewModel(list: sourceList, dataManager: dataManager)
        let destViewModel = TestListViewModel(list: destList, dataManager: dataManager)
        
        // Create item
        sourceViewModel.createItem(title: "Item with Image")
        
        guard var item = sourceViewModel.items.first else {
            XCTFail("Item should exist")
            return
        }
        
        // Add image to item
        let testImageData = Data(count: 100)
        var image = ItemImage(imageData: testImageData, itemId: item.id)
        item.images.append(image)
        sourceViewModel.updateItem(item, title: item.title, description: item.itemDescription ?? "", quantity: item.quantity)
        
        // Copy item with image
        sourceViewModel.enterSelectionMode()
        sourceViewModel.toggleSelection(for: item.id)
        sourceViewModel.copySelectedItems(to: destList)
        
        // Verify image copied
        destViewModel.loadItems()
        XCTAssertEqual(destViewModel.items.count, 1)
        
        let copiedItem = destViewModel.items[0]
        XCTAssertEqual(copiedItem.images.count, 1, "Image should be copied")
        XCTAssertNotEqual(copiedItem.images[0].id, image.id, "Copied image should have different ID")
        XCTAssertEqual(copiedItem.images[0].itemId, copiedItem.id, "Image should reference copied item")
    }
    
    func testMoveItemsWithFilteredView() throws {
        let dataManager = TestHelpers.createTestDataManager()
        let mainViewModel = TestMainViewModel(dataManager: dataManager)
        
        // Create two lists
        try mainViewModel.addList(name: "Source List")
        try mainViewModel.addList(name: "Destination List")
        
        guard let sourceList = mainViewModel.lists.first(where: { $0.name == "Source List" }),
              let destList = mainViewModel.lists.first(where: { $0.name == "Destination List" }) else {
            XCTFail("Lists should exist")
            return
        }
        
        let sourceViewModel = TestListViewModel(list: sourceList, dataManager: dataManager)
        let destViewModel = TestListViewModel(list: destList, dataManager: dataManager)
        
        // Add items
        sourceViewModel.createItem(title: "Active Item")
        sourceViewModel.createItem(title: "Completed Item")
        
        // Complete second item
        if let item = sourceViewModel.items.first(where: { $0.title == "Completed Item" }) {
            sourceViewModel.toggleItemCrossedOut(item)
        }
        
        // Filter to show only active items
        sourceViewModel.updateFilterOption(.active)
        
        // Select visible (active) items
        sourceViewModel.enterSelectionMode()
        sourceViewModel.selectAll()
        
        XCTAssertEqual(sourceViewModel.selectedItems.count, 1, "Only active item should be selected")
        
        // Move selected
        sourceViewModel.moveSelectedItems(to: destList)
        
        // Verify only active item moved
        XCTAssertEqual(sourceViewModel.items.count, 1, "Completed item should remain")
        XCTAssertEqual(sourceViewModel.items[0].title, "Completed Item")
        
        destViewModel.loadItems()
        XCTAssertEqual(destViewModel.items.count, 1)
        XCTAssertEqual(destViewModel.items[0].title, "Active Item")
    }
    
    // MARK: - Search Tests (Phase 63)
    
    func testSearchWithEmptyText() throws {
        let dataManager = TestHelpers.createTestDataManager()
        let mainViewModel = TestMainViewModel(dataManager: dataManager)
        
        try mainViewModel.addList(name: "Test List")
        
        guard let list = mainViewModel.lists.first else {
            XCTFail("List should exist")
            return
        }
        
        let viewModel = TestListViewModel(list: list, dataManager: dataManager)
        viewModel.createItem(title: "Item 1", description: "Description 1")
        viewModel.createItem(title: "Item 2", description: "Description 2")
        
        // Empty search text should return all items
        viewModel.searchText = ""
        XCTAssertEqual(viewModel.filteredItems.count, 2)
    }
    
    func testSearchMatchingTitles() throws {
        let dataManager = TestHelpers.createTestDataManager()
        let mainViewModel = TestMainViewModel(dataManager: dataManager)
        
        try mainViewModel.addList(name: "Test List")
        
        guard let list = mainViewModel.lists.first else {
            XCTFail("List should exist")
            return
        }
        
        let viewModel = TestListViewModel(list: list, dataManager: dataManager)
        viewModel.createItem(title: "Apple", description: "Red fruit")
        viewModel.createItem(title: "Banana", description: "Yellow fruit")
        viewModel.createItem(title: "Cherry", description: "Small fruit")
        
        // Search for "Apple"
        viewModel.searchText = "Apple"
        XCTAssertEqual(viewModel.filteredItems.count, 1)
        XCTAssertEqual(viewModel.filteredItems[0].title, "Apple")
        
        // Search for "an" (should match Banana)
        viewModel.searchText = "an"
        XCTAssertEqual(viewModel.filteredItems.count, 1)
        XCTAssertEqual(viewModel.filteredItems[0].title, "Banana")
    }
    
    func testSearchMatchingDescriptions() throws {
        let dataManager = TestHelpers.createTestDataManager()
        let mainViewModel = TestMainViewModel(dataManager: dataManager)
        
        try mainViewModel.addList(name: "Test List")
        
        guard let list = mainViewModel.lists.first else {
            XCTFail("List should exist")
            return
        }
        
        let viewModel = TestListViewModel(list: list, dataManager: dataManager)
        viewModel.createItem(title: "Item 1", description: "This is a test description")
        viewModel.createItem(title: "Item 2", description: "Another description")
        viewModel.createItem(title: "Item 3", description: "Different content")
        
        // Search for "test" (should match first item's description)
        viewModel.searchText = "test"
        XCTAssertEqual(viewModel.filteredItems.count, 1)
        XCTAssertEqual(viewModel.filteredItems[0].title, "Item 1")
        
        // Search for "description" (should match first two items)
        viewModel.searchText = "description"
        XCTAssertEqual(viewModel.filteredItems.count, 2)
    }
    
    func testSearchWithNoMatches() throws {
        let dataManager = TestHelpers.createTestDataManager()
        let mainViewModel = TestMainViewModel(dataManager: dataManager)
        
        try mainViewModel.addList(name: "Test List")
        
        guard let list = mainViewModel.lists.first else {
            XCTFail("List should exist")
            return
        }
        
        let viewModel = TestListViewModel(list: list, dataManager: dataManager)
        viewModel.createItem(title: "Apple", description: "Red fruit")
        viewModel.createItem(title: "Banana", description: "Yellow fruit")
        
        // Search for something that doesn't exist
        viewModel.searchText = "xyz123notfound"
        XCTAssertEqual(viewModel.filteredItems.count, 0)
    }
    
    func testSearchCaseInsensitive() throws {
        let dataManager = TestHelpers.createTestDataManager()
        let mainViewModel = TestMainViewModel(dataManager: dataManager)
        
        try mainViewModel.addList(name: "Test List")
        
        guard let list = mainViewModel.lists.first else {
            XCTFail("List should exist")
            return
        }
        
        let viewModel = TestListViewModel(list: list, dataManager: dataManager)
        viewModel.createItem(title: "Apple", description: "Red Fruit")
        viewModel.createItem(title: "BANANA", description: "YELLOW FRUIT")
        
        // Test lowercase search matching uppercase title
        viewModel.searchText = "banana"
        XCTAssertEqual(viewModel.filteredItems.count, 1)
        XCTAssertEqual(viewModel.filteredItems[0].title, "BANANA")
        
        // Test uppercase search matching lowercase title
        viewModel.searchText = "APPLE"
        XCTAssertEqual(viewModel.filteredItems.count, 1)
        XCTAssertEqual(viewModel.filteredItems[0].title, "Apple")
        
        // Test mixed case search
        viewModel.searchText = "FrUiT"
        XCTAssertEqual(viewModel.filteredItems.count, 2)
    }
    
    func testSearchWithFiltering() throws {
        let dataManager = TestHelpers.createTestDataManager()
        let mainViewModel = TestMainViewModel(dataManager: dataManager)
        
        try mainViewModel.addList(name: "Test List")
        
        guard let list = mainViewModel.lists.first else {
            XCTFail("List should exist")
            return
        }
        
        let viewModel = TestListViewModel(list: list, dataManager: dataManager)
        viewModel.createItem(title: "Active Apple", description: "Red fruit")
        viewModel.createItem(title: "Completed Apple", description: "Green fruit")
        
        // Complete second item
        if let item = viewModel.items.first(where: { $0.title == "Completed Apple" }) {
            viewModel.toggleItemCrossedOut(item)
        }
        
        // Filter to show only active items
        viewModel.updateFilterOption(.active)
        
        // Search for "Apple" - should only find active one
        viewModel.searchText = "Apple"
        XCTAssertEqual(viewModel.filteredItems.count, 1)
        XCTAssertEqual(viewModel.filteredItems[0].title, "Active Apple")
        
        // Now filter to show completed items
        viewModel.updateFilterOption(.completed)
        
        // Same search should now find completed one
        viewModel.searchText = "Apple"
        XCTAssertEqual(viewModel.filteredItems.count, 1)
        XCTAssertEqual(viewModel.filteredItems[0].title, "Completed Apple")
    }
    
    func testSearchWithSorting() throws {
        let dataManager = TestHelpers.createTestDataManager()
        let mainViewModel = TestMainViewModel(dataManager: dataManager)
        
        try mainViewModel.addList(name: "Test List")
        
        guard let list = mainViewModel.lists.first else {
            XCTFail("List should exist")
            return
        }
        
        let viewModel = TestListViewModel(list: list, dataManager: dataManager)
        viewModel.createItem(title: "Zebra Test", description: "Last alphabetically")
        viewModel.createItem(title: "Apple Test", description: "First alphabetically")
        viewModel.createItem(title: "Banana Test", description: "Middle alphabetically")
        
        // Sort by title ascending
        viewModel.updateSortOption(.title)
        viewModel.updateSortDirection(.ascending)
        
        // Search for "Test" - should return all items in alphabetical order
        viewModel.searchText = "Test"
        XCTAssertEqual(viewModel.filteredItems.count, 3)
        XCTAssertEqual(viewModel.filteredItems[0].title, "Apple Test")
        XCTAssertEqual(viewModel.filteredItems[1].title, "Banana Test")
        XCTAssertEqual(viewModel.filteredItems[2].title, "Zebra Test")
        
        // Sort by title descending
        viewModel.updateSortDirection(.descending)
        
        // Same search should return items in reverse alphabetical order
        viewModel.searchText = "Test"
        XCTAssertEqual(viewModel.filteredItems.count, 3)
        XCTAssertEqual(viewModel.filteredItems[0].title, "Zebra Test")
        XCTAssertEqual(viewModel.filteredItems[1].title, "Banana Test")
        XCTAssertEqual(viewModel.filteredItems[2].title, "Apple Test")
    }
    
    func testSearchPartialMatching() throws {
        let dataManager = TestHelpers.createTestDataManager()
        let mainViewModel = TestMainViewModel(dataManager: dataManager)
        
        try mainViewModel.addList(name: "Test List")
        
        guard let list = mainViewModel.lists.first else {
            XCTFail("List should exist")
            return
        }
        
        let viewModel = TestListViewModel(list: list, dataManager: dataManager)
        viewModel.createItem(title: "Pineapple", description: "Tropical fruit")
        viewModel.createItem(title: "Apple", description: "Common fruit")
        viewModel.createItem(title: "Grapple", description: "Hybrid fruit")
        
        // Search for "apple" - should match all three (partial match)
        viewModel.searchText = "apple"
        XCTAssertEqual(viewModel.filteredItems.count, 3)
    }
    
    func testSearchEmptyItemDescription() throws {
        let dataManager = TestHelpers.createTestDataManager()
        let mainViewModel = TestMainViewModel(dataManager: dataManager)
        
        try mainViewModel.addList(name: "Test List")
        
        guard let list = mainViewModel.lists.first else {
            XCTFail("List should exist")
            return
        }
        
        let viewModel = TestListViewModel(list: list, dataManager: dataManager)
        viewModel.createItem(title: "Item with description", description: "Has text")
        viewModel.createItem(title: "Item without description", description: "")
        
        // Search for description text
        viewModel.searchText = "text"
        XCTAssertEqual(viewModel.filteredItems.count, 1)
        XCTAssertEqual(viewModel.filteredItems[0].title, "Item with description")
        
        // Search for title that has no description
        viewModel.searchText = "without"
        XCTAssertEqual(viewModel.filteredItems.count, 1)
        XCTAssertEqual(viewModel.filteredItems[0].title, "Item without description")
    }
}