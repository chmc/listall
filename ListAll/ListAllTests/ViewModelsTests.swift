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
}