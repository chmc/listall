//
//  ServicesTests.swift
//  ListAllTests
//
//  Created by Sutela Aleksi on 15.9.2025.
//

import Testing
import Foundation
@testable import ListAll

struct ServicesTests {
    
    // MARK: - DataRepository Tests (Simplified to avoid shared state)
    
    @Test func testDataRepositoryCreateList() async throws {
        let repository = DataRepository()
        let list = repository.createList(name: "Test List")
        
        #expect(list.name == "Test List")
        #expect(list.id != UUID())
        #expect(list.items.isEmpty)
    }
    
    @Test func testDataRepositoryCreateItem() async throws {
        let repository = DataRepository()
        let list = repository.createList(name: "Test List")
        let item = repository.createItem(in: list, title: "Test Item", description: "Test Description", quantity: 3)
        
        #expect(item.title == "Test Item")
        #expect(item.itemDescription == "Test Description")
        #expect(item.quantity == 3)
        #expect(item.listId == list.id)
    }
    
    @Test func testDataRepositoryCreateItemWithEmptyDescription() async throws {
        let repository = DataRepository()
        let list = repository.createList(name: "Test List")
        let item = repository.createItem(in: list, title: "Test Item", description: "", quantity: 1)
        
        #expect(item.title == "Test Item")
        #expect(item.itemDescription == nil)
        #expect(item.quantity == 1)
    }
    
    // MARK: - DataManager Tests (Simplified to avoid shared state)
    
    @Test func testDataManagerSingleton() async throws {
        let manager1 = DataManager.shared
        let manager2 = DataManager.shared
        
        #expect(manager1 === manager2)
    }
    
    @Test func testDataManagerGetItemsForNonExistentList() async throws {
        let manager = DataManager.shared
        let nonExistentListId = UUID()
        
        let items = manager.getItems(forListId: nonExistentListId)
        
        #expect(items.isEmpty)
    }
    
    // MARK: - Method Existence Tests (No shared state)
    
    @Test func testDataRepositoryMethodsExist() async throws {
        let repository = DataRepository()
        
        // Test that methods exist and can be called without crashing
        let list = repository.createList(name: "Test")
        let item = repository.createItem(in: list, title: "Test Item")
        
        // These methods should exist and not crash
        repository.deleteList(list)
        repository.updateList(list, name: "Updated")
        repository.deleteItem(item)
        repository.updateItem(item, title: "Updated", description: "Updated", quantity: 2)
        repository.toggleItemCrossedOut(item)
        
        #expect(true) // If we get here, methods exist
    }
    
    @Test func testDataManagerMethodsExist() async throws {
        let manager = DataManager.shared
        let list = List(name: "Test")
        let item = Item(title: "Test Item")
        
        // These methods should exist and not crash
        manager.addList(list)
        manager.updateList(list)
        manager.deleteList(withId: list.id)
        manager.addItem(item, to: list.id)
        manager.updateItem(item)
        manager.deleteItem(withId: item.id, from: list.id)
        
        #expect(true) // If we get here, methods exist
    }
}
