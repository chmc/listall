import Testing
import Foundation
@testable import ListAll

struct ViewModelsTests {
    
    // MARK: - MainViewModel Tests
    
    @Test func testMainViewModelInitialization() async throws {
        TestHelpers.resetSharedSingletons()
        
        let viewModel = MainViewModel()
        
        #expect(viewModel.lists.isEmpty)
        #expect(!viewModel.isLoading)
        #expect(viewModel.errorMessage == nil)
    }
    
    @Test func testAddListSuccess() async throws {
        TestHelpers.resetSharedSingletons()
        
        let viewModel = MainViewModel()
        let initialCount = viewModel.lists.count
        
        try viewModel.addList(name: "Test List")
        
        #expect(viewModel.lists.count == initialCount + 1)
        #expect(viewModel.lists.last?.name == "Test List")
    }
    
    @Test func testAddListEmptyName() async throws {
        TestHelpers.resetSharedSingletons()
        
        let viewModel = MainViewModel()
        
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
        TestHelpers.resetSharedSingletons()
        
        let viewModel = MainViewModel()
        
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
        TestHelpers.resetSharedSingletons()
        
        let viewModel = MainViewModel()
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
        TestHelpers.resetSharedSingletons()
        
        let viewModel = MainViewModel()
        let exactName = String(repeating: "a", count: 100) // Exactly 100 characters
        
        try viewModel.addList(name: exactName)
        
        #expect(viewModel.lists.last?.name == exactName)
    }
    
    @Test func testUpdateListSuccess() async throws {
        TestHelpers.resetSharedSingletons()
        
        let viewModel = MainViewModel()
        try viewModel.addList(name: "Original Name")
        
        guard let list = viewModel.lists.first else {
            #expect(Bool(false), "List should exist")
            return
        }
        
        try viewModel.updateList(list, name: "Updated Name")
        
        #expect(viewModel.lists.first?.name == "Updated Name")
    }
    
    @Test func testUpdateListEmptyName() async throws {
        TestHelpers.resetSharedSingletons()
        
        let viewModel = MainViewModel()
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
        TestHelpers.resetSharedSingletons()
        
        let viewModel = MainViewModel()
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
        TestHelpers.resetSharedSingletons()
        
        let viewModel = MainViewModel()
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
    
    // MARK: - ListViewModel Tests
    
    // MARK: - ItemViewModel Tests
    
    // MARK: - ExportViewModel Tests
}
