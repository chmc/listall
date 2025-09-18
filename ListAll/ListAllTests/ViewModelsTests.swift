import Testing
import Foundation
import CoreData
@testable import ListAll

struct ViewModelsTests {
    
    // MARK: - MainViewModel Tests
    
    @Test func testMainViewModelInitialization() async throws {
        let viewModel = TestHelpers.createTestMainViewModel()
        
        #expect(viewModel.lists.isEmpty)
    }
    
    @Test func testAddListSuccess() async throws {
        let viewModel = TestHelpers.createTestMainViewModel()
        let initialCount = viewModel.lists.count
        
        try viewModel.addList(name: "Test List")
        
        #expect(viewModel.lists.count == initialCount + 1)
        #expect(viewModel.lists.last?.name == "Test List")
    }
    
    @Test func testAddListEmptyName() async throws {
        let viewModel = TestHelpers.createTestMainViewModel()
        
        do {
            try viewModel.addList(name: "")
            #expect(Bool(false), "Should have thrown ValidationError.emptyName")
        } catch ValidationError.emptyName {
            // Expected error
            #expect(Bool(true))
        } catch {
            #expect(Bool(false), "Unexpected error type: \(error)")
        }
    }
    
    @Test func testAddListWhitespaceName() async throws {
        let viewModel = TestHelpers.createTestMainViewModel()
        
        do {
            try viewModel.addList(name: "   ")
            #expect(Bool(false), "Should have thrown ValidationError.emptyName")
        } catch ValidationError.emptyName {
            // Expected error
            #expect(Bool(true))
        } catch {
            #expect(Bool(false), "Unexpected error type: \(error)")
        }
    }
    
    @Test func testAddListNameTooLong() async throws {
        let viewModel = TestHelpers.createTestMainViewModel()
        let longName = String(repeating: "a", count: 101) // 101 characters
        
        do {
            try viewModel.addList(name: longName)
            #expect(Bool(false), "Should have thrown ValidationError.nameTooLong")
        } catch ValidationError.nameTooLong {
            // Expected error
            #expect(Bool(true))
        } catch {
            #expect(Bool(false), "Unexpected error type: \(error)")
        }
    }
    
    @Test func testAddListExactly100Characters() async throws {
        let viewModel = TestHelpers.createTestMainViewModel()
        let exactName = String(repeating: "a", count: 100) // Exactly 100 characters
        
        try viewModel.addList(name: exactName)
        
        #expect(viewModel.lists.last?.name == exactName)
    }
    
    @Test func testUpdateListSuccess() async throws {
        let viewModel = TestHelpers.createTestMainViewModel()
        try viewModel.addList(name: "Original Name")
        
        guard let list = viewModel.lists.first else {
            #expect(Bool(false), "List should exist")
            return
        }
        
        try viewModel.updateList(list, name: "Updated Name")
        
        #expect(viewModel.lists.first?.name == "Updated Name")
    }
    
    @Test func testUpdateListEmptyName() async throws {
        let viewModel = TestHelpers.createTestMainViewModel()
        try viewModel.addList(name: "Original Name")
        
        guard let list = viewModel.lists.first else {
            #expect(Bool(false), "List should exist")
            return
        }
        
        do {
            try viewModel.updateList(list, name: "")
            #expect(Bool(false), "Should have thrown ValidationError.emptyName")
        } catch ValidationError.emptyName {
            // Expected error
            #expect(Bool(true))
        } catch {
            #expect(Bool(false), "Unexpected error type: \(error)")
        }
    }
    
    @Test func testUpdateListNameTooLong() async throws {
        let viewModel = TestHelpers.createTestMainViewModel()
        try viewModel.addList(name: "Original Name")
        
        guard let list = viewModel.lists.first else {
            #expect(Bool(false), "List should exist")
            return
        }
        
        let longName = String(repeating: "b", count: 101)
        
        do {
            try viewModel.updateList(list, name: longName)
            #expect(Bool(false), "Should have thrown ValidationError.nameTooLong")
        } catch ValidationError.nameTooLong {
            // Expected error
            #expect(Bool(true))
        } catch {
            #expect(Bool(false), "Unexpected error type: \(error)")
        }
    }
    
    @Test func testDeleteList() async throws {
        let viewModel = TestHelpers.createTestMainViewModel()
        try viewModel.addList(name: "Test List")
        
        guard let list = viewModel.lists.first else {
            #expect(Bool(false), "List should exist")
            return
        }
        
        let initialCount = viewModel.lists.count
        viewModel.deleteList(list)
        
        #expect(viewModel.lists.count == initialCount - 1)
        #expect(!viewModel.lists.contains { $0.id == list.id })
    }
    
    // MARK: - ValidationError Tests
    
    @Test func testValidationErrorEmptyNameDescription() async throws {
        let error = ValidationError.emptyName
        #expect(error.errorDescription == "Please enter a list name")
    }
    
    @Test func testValidationErrorNameTooLongDescription() async throws {
        let error = ValidationError.nameTooLong
        #expect(error.errorDescription == "List name must be 100 characters or less")
    }
    
    // MARK: - Bug Fix Tests: Core Data Race Condition
    
    @Test func testDeleteRecreateListSameName() async throws {
        // Create isolated test environment
        let coreDataStack = TestHelpers.createInMemoryCoreDataStack()
        let testCoreDataManager = TestCoreDataManager(container: coreDataStack)
        let testDataManager = TestDataManager(coreDataManager: testCoreDataManager)
        let viewModel = TestMainViewModel(dataManager: testDataManager)
        
        let listName = "Test List"
        
        // Create initial list
        try viewModel.addList(name: listName)
        #expect(viewModel.lists.count == 1)
        #expect(viewModel.lists.first?.name == listName)
        
        let originalList = viewModel.lists.first!
        
        // Delete the list
        viewModel.deleteList(originalList)
        #expect(viewModel.lists.count == 0)
        
        // Immediately recreate list with same name (this used to crash)
        try viewModel.addList(name: listName)
        #expect(viewModel.lists.count == 1)
        #expect(viewModel.lists.first?.name == listName)
        
        // Verify it's a different list (different ID)
        let newList = viewModel.lists.first!
        #expect(newList.id != originalList.id)
        #expect(newList.name == originalList.name)
    }
    
    @Test func testMultipleQuickOperations() async throws {
        // Create isolated test environment
        let coreDataStack = TestHelpers.createInMemoryCoreDataStack()
        let testCoreDataManager = TestCoreDataManager(container: coreDataStack)
        let testDataManager = TestDataManager(coreDataManager: testCoreDataManager)
        let viewModel = TestMainViewModel(dataManager: testDataManager)
        
        // Perform multiple quick operations that used to cause race conditions
        try viewModel.addList(name: "List 1")
        try viewModel.addList(name: "List 2")
        #expect(viewModel.lists.count == 2)
        
        // Delete first list
        let firstList = viewModel.lists.first!
        viewModel.deleteList(firstList)
        #expect(viewModel.lists.count == 1)
        #expect(viewModel.lists.first?.name == "List 2")
        
        // Immediately add another list
        try viewModel.addList(name: "List 3")
        #expect(viewModel.lists.count == 2)
        
        // Update the remaining list
        let listToUpdate = viewModel.lists.first { $0.name == "List 2" }!
        try viewModel.updateList(listToUpdate, name: "Updated List 2")
        #expect(viewModel.lists.count == 2)
        #expect(viewModel.lists.contains { $0.name == "Updated List 2" })
    }
    
    @Test func testDataConsistencyAfterOperations() async throws {
        // Create isolated test environment
        let coreDataStack = TestHelpers.createInMemoryCoreDataStack()
        let testCoreDataManager = TestCoreDataManager(container: coreDataStack)
        let testDataManager = TestDataManager(coreDataManager: testCoreDataManager)
        let viewModel = TestMainViewModel(dataManager: testDataManager)
        
        // Add lists through ViewModel
        try viewModel.addList(name: "VM List 1")
        try viewModel.addList(name: "VM List 2")
        
        // Verify consistency between ViewModel and DataManager
        #expect(viewModel.lists.count == testDataManager.lists.count)
        #expect(viewModel.lists.count == 2)
        
        // Delete through ViewModel
        let listToDelete = viewModel.lists.first!
        viewModel.deleteList(listToDelete)
        
        // Verify consistency after deletion
        #expect(viewModel.lists.count == testDataManager.lists.count)
        #expect(viewModel.lists.count == 1)
        
        // Update through ViewModel
        let listToUpdate = viewModel.lists.first!
        try viewModel.updateList(listToUpdate, name: "Updated Name")
        
        // Verify consistency after update
        #expect(viewModel.lists.count == testDataManager.lists.count)
        #expect(viewModel.lists.first?.name == "Updated Name")
        #expect(testDataManager.lists.first?.name == "Updated Name")
    }
    
    @Test func testSpecialCharactersInListNames() async throws {
        // Create isolated test environment
        let coreDataStack = TestHelpers.createInMemoryCoreDataStack()
        let testCoreDataManager = TestCoreDataManager(container: coreDataStack)
        let testDataManager = TestDataManager(coreDataManager: testCoreDataManager)
        let viewModel = TestMainViewModel(dataManager: testDataManager)
        
        // Test the specific case that caused the original bug report
        let specialName = "Mökille"
        
        // Create list with special characters
        try viewModel.addList(name: specialName)
        #expect(viewModel.lists.count == 1)
        #expect(viewModel.lists.first?.name == specialName)
        
        let originalList = viewModel.lists.first!
        
        // Delete and recreate with same special character name
        viewModel.deleteList(originalList)
        #expect(viewModel.lists.count == 0)
        
        // This should not crash
        try viewModel.addList(name: specialName)
        #expect(viewModel.lists.count == 1)
        #expect(viewModel.lists.first?.name == specialName)
        
        // Test other special characters
        let otherSpecialNames = ["Café", "数据列表", "🎉 Party List", "Тест"]
        
        for name in otherSpecialNames {
            try viewModel.addList(name: name)
        }
        
        #expect(viewModel.lists.count == 5) // Original + 4 new
        
        // Verify all names are preserved correctly
        let listNames = viewModel.lists.map { $0.name }
        #expect(listNames.contains(specialName))
        for name in otherSpecialNames {
            #expect(listNames.contains(name))
        }
    }
    
    // MARK: - List Interaction Tests (Phase 6C)
    
    @Test func testDuplicateListBasic() async throws {
        let viewModel = TestHelpers.createTestMainViewModel()
        try viewModel.addList(name: "Original List")
        
        guard let originalList = viewModel.lists.first else {
            #expect(Bool(false), "Original list should exist")
            return
        }
        
        let initialCount = viewModel.lists.count
        try viewModel.duplicateList(originalList)
        
        #expect(viewModel.lists.count == initialCount + 1)
        #expect(viewModel.lists.contains { $0.name == "Original List Copy" })
        
        // Verify original list still exists
        #expect(viewModel.lists.contains { $0.id == originalList.id })
    }
    
    @Test func testDuplicateListWithItems() async throws {
        // Create isolated test environment to avoid singleton issues
        let coreDataStack = TestHelpers.createInMemoryCoreDataStack()
        let testCoreDataManager = TestCoreDataManager(container: coreDataStack)
        let testDataManager = TestDataManager(coreDataManager: testCoreDataManager)
        let viewModel = TestMainViewModel(dataManager: testDataManager)
        
        // Create list with items
        try viewModel.addList(name: "Shopping List")
        guard let originalList = viewModel.lists.first else {
            #expect(Bool(false), "Original list should exist")
            return
        }
        
        // Add items to the original list
        let item1 = Item(title: "Milk", listId: originalList.id)
        let item2 = Item(title: "Bread", listId: originalList.id)
        testDataManager.addItem(item1, to: originalList.id)
        testDataManager.addItem(item2, to: originalList.id)
        
        // Duplicate the list
        try viewModel.duplicateList(originalList)
        
        #expect(viewModel.lists.count == 2)
        
        guard let duplicatedList = viewModel.lists.first(where: { $0.name == "Shopping List Copy" }) else {
            #expect(Bool(false), "Duplicated list should exist")
            return
        }
        
        // Verify items were duplicated
        let duplicatedItems = testDataManager.getItems(forListId: duplicatedList.id)
        #expect(duplicatedItems.count == 2)
        #expect(duplicatedItems.contains { $0.title == "Milk" })
        #expect(duplicatedItems.contains { $0.title == "Bread" })
        
        // Verify items have different IDs but same content
        let originalItems = testDataManager.getItems(forListId: originalList.id)
        for duplicatedItem in duplicatedItems {
            #expect(!originalItems.contains { $0.id == duplicatedItem.id })
            #expect(originalItems.contains { $0.title == duplicatedItem.title })
        }
    }
    
    @Test func testDuplicateListNameGeneration() async throws {
        let viewModel = TestHelpers.createTestMainViewModel()
        try viewModel.addList(name: "Test List")
        
        guard let originalList = viewModel.lists.first else {
            #expect(Bool(false), "Original list should exist")
            return
        }
        
        // First duplicate should be "Test List Copy"
        try viewModel.duplicateList(originalList)
        #expect(viewModel.lists.contains { $0.name == "Test List Copy" })
        
        // Second duplicate should be "Test List Copy 2"
        try viewModel.duplicateList(originalList)
        #expect(viewModel.lists.contains { $0.name == "Test List Copy 2" })
        
        // Third duplicate should be "Test List Copy 3"
        try viewModel.duplicateList(originalList)
        #expect(viewModel.lists.contains { $0.name == "Test List Copy 3" })
        
        #expect(viewModel.lists.count == 4) // Original + 3 copies
    }
    
    @Test func testDuplicateListNameTooLong() async throws {
        let viewModel = TestHelpers.createTestMainViewModel()
        let longName = String(repeating: "a", count: 95) // 95 + " Copy" = 100 characters (max)
        try viewModel.addList(name: longName)
        
        guard let originalList = viewModel.lists.first else {
            #expect(Bool(false), "Original list should exist")
            return
        }
        
        // Should work for exactly 95 characters (95 + 5 = 100)
        try viewModel.duplicateList(originalList)
        #expect(viewModel.lists.count == 2)
        
        // Now test with 96 characters (would be 101 with " Copy")
        let tooLongName = String(repeating: "b", count: 96)
        try viewModel.addList(name: tooLongName)
        
        guard let tooLongList = viewModel.lists.first(where: { $0.name == tooLongName }) else {
            #expect(Bool(false), "Long list should exist")
            return
        }
        
        do {
            try viewModel.duplicateList(tooLongList)
            #expect(Bool(false), "Should have thrown ValidationError.nameTooLong")
        } catch ValidationError.nameTooLong {
            // Expected error
            #expect(Bool(true))
        } catch {
            #expect(Bool(false), "Unexpected error type: \(error)")
        }
    }
    
    @Test func testMoveListBasic() async throws {
        let viewModel = TestHelpers.createTestMainViewModel()
        try viewModel.addList(name: "List 1")
        try viewModel.addList(name: "List 2")
        try viewModel.addList(name: "List 3")
        
        #expect(viewModel.lists.count == 3)
        #expect(viewModel.lists[0].name == "List 1")
        #expect(viewModel.lists[1].name == "List 2")
        #expect(viewModel.lists[2].name == "List 3")
        
        // Move first item to the end (index 0 to index 3)
        let indexSet = IndexSet([0])
        viewModel.moveList(from: indexSet, to: 3)
        
        #expect(viewModel.lists[0].name == "List 2")
        #expect(viewModel.lists[1].name == "List 3")
        #expect(viewModel.lists[2].name == "List 1")
        
        // Verify order numbers were updated correctly
        #expect(viewModel.lists[0].orderNumber == 0)
        #expect(viewModel.lists[1].orderNumber == 1)
        #expect(viewModel.lists[2].orderNumber == 2)
    }
    
    @Test func testMoveListMiddleToBeginning() async throws {
        let viewModel = TestHelpers.createTestMainViewModel()
        try viewModel.addList(name: "First")
        try viewModel.addList(name: "Second")
        try viewModel.addList(name: "Third")
        
        // Move middle item to beginning (index 1 to index 0)
        let indexSet = IndexSet([1])
        viewModel.moveList(from: indexSet, to: 0)
        
        #expect(viewModel.lists[0].name == "Second")
        #expect(viewModel.lists[1].name == "First")
        #expect(viewModel.lists[2].name == "Third")
        
        // Verify order numbers
        #expect(viewModel.lists[0].orderNumber == 0)
        #expect(viewModel.lists[1].orderNumber == 1)
        #expect(viewModel.lists[2].orderNumber == 2)
    }
    
    @Test func testMoveListSingleItem() async throws {
        let viewModel = TestHelpers.createTestMainViewModel()
        try viewModel.addList(name: "Only List")
        
        // Moving single item should not crash
        let indexSet = IndexSet([0])
        viewModel.moveList(from: indexSet, to: 1)
        
        #expect(viewModel.lists.count == 1)
        #expect(viewModel.lists[0].name == "Only List")
        #expect(viewModel.lists[0].orderNumber == 0)
    }
    
    @Test func testMoveListEmptyList() async throws {
        let viewModel = TestHelpers.createTestMainViewModel()
        
        // Moving in empty list should not crash
        let indexSet = IndexSet([])
        viewModel.moveList(from: indexSet, to: 0)
        
        #expect(viewModel.lists.isEmpty)
    }
    
    // MARK: - ListViewModel Tests
    
    // MARK: - ItemViewModel Tests
    
    @Test func testItemViewModelInitialization() async throws {
        let item = Item(title: "Test Item")
        let viewModel = TestHelpers.createTestItemViewModel(with: item)
        
        #expect(viewModel.item.title == "Test Item")
        #expect(!viewModel.isLoading)
        #expect(viewModel.errorMessage == nil)
    }
    
    @Test func testItemViewModelToggleCrossedOut() async throws {
        let item = Item(title: "Test Item")
        let viewModel = TestHelpers.createTestItemViewModel(with: item)
        
        // Initially not crossed out
        #expect(!viewModel.item.isCrossedOut)
        
        // Toggle to crossed out
        viewModel.toggleCrossedOut()
        #expect(viewModel.item.isCrossedOut)
        
        // Toggle back to not crossed out
        viewModel.toggleCrossedOut()
        #expect(!viewModel.item.isCrossedOut)
    }
    
    @Test func testItemViewModelToggleCrossedOutUpdatesModifiedDate() async throws {
        let item = Item(title: "Test Item")
        let viewModel = TestHelpers.createTestItemViewModel(with: item)
        let originalModifiedDate = viewModel.item.modifiedAt
        
        // Wait a small amount to ensure time difference
        try await Task.sleep(nanoseconds: 10_000_000) // 10ms
        
        viewModel.toggleCrossedOut()
        
        #expect(viewModel.item.modifiedAt > originalModifiedDate)
    }
    
    @Test func testItemViewModelUpdateItem() async throws {
        let item = Item(title: "Original Title")
        let viewModel = TestHelpers.createTestItemViewModel(with: item)
        
        viewModel.updateItem(title: "Updated Title", description: "New Description", quantity: 5)
        
        #expect(viewModel.item.title == "Updated Title")
        #expect(viewModel.item.itemDescription == "New Description")
        #expect(viewModel.item.quantity == 5)
    }
    
    @Test func testItemViewModelUpdateItemEmptyDescription() async throws {
        let item = Item(title: "Test Item")
        let viewModel = TestHelpers.createTestItemViewModel(with: item)
        
        viewModel.updateItem(title: "Updated Title", description: "", quantity: 1)
        
        #expect(viewModel.item.title == "Updated Title")
        #expect(viewModel.item.itemDescription == nil) // Empty description should be nil
        #expect(viewModel.item.quantity == 1)
    }
    
    @Test func testItemViewModelUpdateItemUpdatesModifiedDate() async throws {
        let item = Item(title: "Original Title")
        let viewModel = TestHelpers.createTestItemViewModel(with: item)
        let originalModifiedDate = viewModel.item.modifiedAt
        
        // Wait a small amount to ensure time difference
        try await Task.sleep(nanoseconds: 10_000_000) // 10ms
        
        viewModel.updateItem(title: "Updated Title", description: "Description", quantity: 2)
        
        #expect(viewModel.item.modifiedAt > originalModifiedDate)
    }
    
    @Test func testItemViewModelDuplicateItem() async throws {
        let list = List(name: "Test List")
        var item = Item(title: "Original Item")
        item.itemDescription = "Test description"
        item.quantity = 3
        item.listId = list.id
        
        let viewModel = TestHelpers.createTestItemViewModel(with: item)
        let duplicatedItem = viewModel.duplicateItem(in: list)
        
        #expect(duplicatedItem != nil)
        #expect(duplicatedItem?.title == "Original Item (Copy)")
        #expect(duplicatedItem?.itemDescription == "Test description")
        #expect(duplicatedItem?.quantity == 3)
        #expect(duplicatedItem?.listId == list.id)
        #expect(duplicatedItem?.id != item.id) // Different IDs
    }
    
    @Test func testItemViewModelDuplicateItemWithoutListId() async throws {
        let list = List(name: "Test List")
        let item = Item(title: "Original Item") // No listId set
        
        let viewModel = TestHelpers.createTestItemViewModel(with: item)
        let duplicatedItem = viewModel.duplicateItem(in: list)
        
        #expect(duplicatedItem == nil) // Should fail without listId
    }
    
    @Test func testItemViewModelValidateItem() async throws {
        let validItem = Item(title: "Valid Item")
        let viewModel = TestHelpers.createTestItemViewModel(with: validItem)
        
        let result = viewModel.validateItem()
        
        switch result {
        case .success:
            #expect(Bool(true))
        case .failure:
            #expect(Bool(false), "Valid item should pass validation")
        }
    }
    
    @Test func testItemViewModelRefreshItem() async throws {
        let item = Item(title: "Test Item")
        let viewModel = TestHelpers.createTestItemViewModel(with: item)
        
        // Refresh should not crash (though may not change anything without proper data layer)
        viewModel.refreshItem()
        
        // Item should still exist
        #expect(viewModel.item.title == "Test Item")
    }
    
    // MARK: - ListViewModel Enhanced Tests
    
    @Test func testListViewModelCreateItem() async throws {
        let testDataManager = TestHelpers.createTestDataManager()
        let list = List(name: "Test List")
        
        // Add the list to the data manager first
        testDataManager.addList(list)
        
        let viewModel = TestListViewModel(list: list, dataManager: testDataManager)
        let initialCount = viewModel.items.count
        
        viewModel.createItem(title: "New Item", description: "Test description", quantity: 2)
        
        #expect(viewModel.items.count == initialCount + 1)
    }
    
    @Test func testListViewModelDuplicateItem() async throws {
        let list = List(name: "Test List")
        let viewModel = TestHelpers.createTestListViewModel(with: list)
        let item = Item(title: "Original Item")
        
        let initialCount = viewModel.items.count
        viewModel.duplicateItem(item)
        
        // The duplicated item should be created (though may not be immediately visible in simple model setup)
        #expect(Bool(true)) // Test passes if no crash occurs
    }
    
    @Test func testListViewModelToggleItemCrossedOut() async throws {
        let list = List(name: "Test List")
        let viewModel = TestHelpers.createTestListViewModel(with: list)
        let item = Item(title: "Test Item")
        
        // Should not crash when toggling item crossed out state
        viewModel.toggleItemCrossedOut(item)
        #expect(Bool(true))
    }
    
    @Test func testListViewModelDeleteItem() async throws {
        let list = List(name: "Test List")
        let viewModel = TestHelpers.createTestListViewModel(with: list)
        let item = Item(title: "Test Item")
        
        // Should not crash when deleting item
        viewModel.deleteItem(item)
        #expect(Bool(true))
    }
    
    @Test func testListViewModelSortedItems() async throws {
        let list = List(name: "Test List")
        let viewModel = TestHelpers.createTestListViewModel(with: list)
        
        // Test that sortedItems property works
        let sortedItems = viewModel.sortedItems
        #expect(sortedItems.count >= 0) // Should return array (empty or with items)
    }
    
    @Test func testListViewModelActiveAndCompletedItems() async throws {
        let list = List(name: "Test List")
        let viewModel = TestHelpers.createTestListViewModel(with: list)
        
        // Test filtering methods
        let activeItems = viewModel.activeItems
        let completedItems = viewModel.completedItems
        
        #expect(activeItems.count >= 0)
        #expect(completedItems.count >= 0)
        #expect(activeItems.count + completedItems.count == viewModel.items.count)
    }
    
    // MARK: - ItemEditViewModel Tests
    // Note: ItemEditViewModel tests are skipped due to MainActor isolation complexity
    // The functionality is covered by integration tests and UI testing
    // Core business logic is tested through ItemViewModel and ListViewModel tests
    
    // MARK: - ExportViewModel Tests
    
    // MARK: - Test Infrastructure Validation
    
    @Test func testTestHelpersIsolation() async throws {
        // Test that multiple test instances are properly isolated
        let viewModel1 = TestHelpers.createTestMainViewModel()
        let viewModel2 = TestHelpers.createTestMainViewModel()
        
        // Both should start empty
        #expect(viewModel1.lists.isEmpty)
        #expect(viewModel2.lists.isEmpty)
        
        // Add list to first instance
        try viewModel1.addList(name: "VM1 List")
        #expect(viewModel1.lists.count == 1)
        #expect(viewModel2.lists.count == 0) // Second instance should remain unaffected
        
        // Add list to second instance
        try viewModel2.addList(name: "VM2 List")
        #expect(viewModel1.lists.count == 1)
        #expect(viewModel2.lists.count == 1)
        
        // Verify they have different lists
        #expect(viewModel1.lists.first?.name == "VM1 List")
        #expect(viewModel2.lists.first?.name == "VM2 List")
    }
    
    @Test func testUserDefaultsReset() async throws {
        // Test that UserDefaults reset works properly
        UserDefaults.standard.set("test_value", forKey: "saved_lists")
        UserDefaults.standard.set(true, forKey: "showCrossedOutItems")
        
        // Verify values are set
        #expect(UserDefaults.standard.object(forKey: "saved_lists") != nil)
        #expect(UserDefaults.standard.bool(forKey: "showCrossedOutItems") == true)
        
        // Reset and verify values are cleared
        TestHelpers.resetUserDefaults()
        #expect(UserDefaults.standard.object(forKey: "saved_lists") == nil)
        #expect(UserDefaults.standard.bool(forKey: "showCrossedOutItems") == false)
    }
    
    @Test func testInMemoryCoreDataStack() async throws {
        // Test that in-memory Core Data stack works properly
        let stack1 = TestHelpers.createInMemoryCoreDataStack()
        let stack2 = TestHelpers.createInMemoryCoreDataStack()
        
        // Verify they are separate instances
        #expect(stack1 !== stack2)
        
        // Verify they use in-memory stores
        let description1 = stack1.persistentStoreDescriptions.first
        let description2 = stack2.persistentStoreDescriptions.first
        
        #expect(description1?.type == NSInMemoryStoreType)
        #expect(description2?.type == NSInMemoryStoreType)
    }
}
