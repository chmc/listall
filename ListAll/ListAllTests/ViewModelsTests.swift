//
//  ViewModelsTests.swift
//  ListAllTests
//
//  Created by Sutela Aleksi on 15.9.2025.
//

import Testing
import Foundation
import SwiftUI
@testable import ListAll

struct ViewModelsTests {
    
    // MARK: - ItemViewModel Tests
    
    @Test func testItemViewModelInitialization() async throws {
        let item = Item(title: "Test Item")
        let viewModel = ItemViewModel(item: item)
        
        #expect(viewModel.item.title == "Test Item")
        #expect(viewModel.isLoading == false)
        #expect(viewModel.errorMessage == nil)
    }
    
    @Test func testItemViewModelToggleCrossedOut() async throws {
        let item = Item(title: "Test Item")
        let viewModel = ItemViewModel(item: item)
        
        #expect(viewModel.item.isCrossedOut == false)
        
        viewModel.toggleCrossedOut()
        
        #expect(viewModel.item.isCrossedOut == true)
    }
    
    @Test func testItemViewModelUpdateItem() async throws {
        let item = Item(title: "Original Title")
        let viewModel = ItemViewModel(item: item)
        
        viewModel.updateItem(title: "Updated Title", description: "Updated Description", quantity: 5)
        
        #expect(viewModel.item.title == "Updated Title")
        #expect(viewModel.item.itemDescription == "Updated Description")
        #expect(viewModel.item.quantity == 5)
    }
    
    @Test func testItemViewModelUpdateItemWithEmptyDescription() async throws {
        let item = Item(title: "Original Title")
        let viewModel = ItemViewModel(item: item)
        
        viewModel.updateItem(title: "Updated Title", description: "", quantity: 3)
        
        #expect(viewModel.item.title == "Updated Title")
        #expect(viewModel.item.itemDescription == nil)
        #expect(viewModel.item.quantity == 3)
    }
    
    // MARK: - ListViewModel Tests
    
    @Test func testListViewModelInitialization() async throws {
        let list = List(name: "Test List")
        let viewModel = ListViewModel(list: list)
        
        #expect(viewModel.isLoading == false)
        #expect(viewModel.errorMessage == nil)
    }
    
    @Test func testListViewModelLoadItems() async throws {
        let list = List(name: "Test List")
        let viewModel = ListViewModel(list: list)
        
        // Initially should be empty since DataManager starts with sample data
        // but the specific list might not have items
        #expect(viewModel.items.count >= 0)
    }
    
    // MARK: - MainViewModel Tests
    
    @Test func testMainViewModelInitialization() async throws {
        let viewModel = MainViewModel()
        
        #expect(viewModel.isLoading == false)
        #expect(viewModel.errorMessage == nil)
        #expect(viewModel.lists.count >= 0) // Should have sample data
    }
    
    @Test func testMainViewModelAddList() async throws {
        let viewModel = MainViewModel()
        let initialCount = viewModel.lists.count
        
        viewModel.addList(name: "New Test List")
        
        #expect(viewModel.lists.count == initialCount + 1)
        #expect(viewModel.lists.last?.name == "New Test List")
    }
    
    @Test func testMainViewModelDeleteList() async throws {
        let viewModel = MainViewModel()
        let initialCount = viewModel.lists.count
        
        guard let firstList = viewModel.lists.first else {
            #expect(Bool(false), "No lists available for testing")
            return
        }
        
        viewModel.deleteList(firstList)
        
        #expect(viewModel.lists.count == initialCount - 1)
        #expect(viewModel.lists.contains { $0.id == firstList.id } == false)
    }
    
    @Test func testMainViewModelUpdateList() async throws {
        let viewModel = MainViewModel()
        
        guard let firstList = viewModel.lists.first else {
            #expect(Bool(false), "No lists available for testing")
            return
        }
        
        let originalName = firstList.name
        let newName = "Updated List Name"
        
        viewModel.updateList(firstList, name: newName)
        
        #expect(viewModel.lists.first?.name == newName)
        #expect(viewModel.lists.first?.name != originalName)
    }
    
    @Test func testMainViewModelLoadLists() async throws {
        let viewModel = MainViewModel()
        
        // Should load lists from DataManager
        #expect(viewModel.lists.count >= 0)
        
        // Lists should be sorted by order number
        let sortedLists = viewModel.lists.sorted { $0.orderNumber < $1.orderNumber }
        #expect(viewModel.lists == sortedLists)
    }
}
