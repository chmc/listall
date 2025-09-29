import XCTest
import Foundation
@testable import ListAll

class ServicesTests: XCTestCase {
    
    // MARK: - DataRepository Tests
    
    func testDataRepositoryReorderItems() throws {
        // Create test data manager and repository
        let dataManager = TestHelpers.createTestDataManager()
        let repository = TestDataRepository(dataManager: dataManager)
        
        // Create a test list
        let testList = List(name: "Test List")
        dataManager.addList(testList)
        
        // Create multiple items
        let item1 = repository.createItem(in: testList, title: "Item 1", description: "", quantity: 1)
        let item2 = repository.createItem(in: testList, title: "Item 2", description: "", quantity: 1)
        let item3 = repository.createItem(in: testList, title: "Item 3", description: "", quantity: 1)
        
        // Get initial items in order
        let initialItems = dataManager.getItems(forListId: testList.id).sorted { $0.orderNumber < $1.orderNumber }
        XCTAssertEqual(initialItems.count, 3)
        XCTAssertEqual(initialItems[0].title, "Item 1")
        XCTAssertEqual(initialItems[1].title, "Item 2")
        XCTAssertEqual(initialItems[2].title, "Item 3")
        
        // Test reordering: move first item to last position
        repository.reorderItems(in: testList, from: 0, to: 2)
        
        // Verify new order
        let reorderedItems = dataManager.getItems(forListId: testList.id).sorted { $0.orderNumber < $1.orderNumber }
        XCTAssertEqual(reorderedItems.count, 3)
        XCTAssertEqual(reorderedItems[0].title, "Item 2")
        XCTAssertEqual(reorderedItems[1].title, "Item 3")
        XCTAssertEqual(reorderedItems[2].title, "Item 1")
        
        // Verify order numbers are sequential
        XCTAssertEqual(reorderedItems[0].orderNumber, 0)
        XCTAssertEqual(reorderedItems[1].orderNumber, 1)
        XCTAssertEqual(reorderedItems[2].orderNumber, 2)
    }
    
    func testDataRepositoryReorderItemsInvalidIndices() throws {
        // Create test data manager and repository
        let dataManager = TestHelpers.createTestDataManager()
        let repository = TestDataRepository(dataManager: dataManager)
        
        // Create a test list
        let testList = List(name: "Test List")
        dataManager.addList(testList)
        
        // Create items
        let item1 = repository.createItem(in: testList, title: "Item 1", description: "", quantity: 1)
        let item2 = repository.createItem(in: testList, title: "Item 2", description: "", quantity: 1)
        
        // Get initial order
        let initialItems = dataManager.getItems(forListId: testList.id).sorted { $0.orderNumber < $1.orderNumber }
        
        // Test invalid indices - should not crash and should not change order
        repository.reorderItems(in: testList, from: -1, to: 0) // Invalid source
        repository.reorderItems(in: testList, from: 0, to: 10) // Invalid destination
        repository.reorderItems(in: testList, from: 0, to: 0) // Same index
        
        // Verify no changes occurred
        let finalItems = dataManager.getItems(forListId: testList.id).sorted { $0.orderNumber < $1.orderNumber }
        XCTAssertEqual(finalItems.count, initialItems.count)
        XCTAssertEqual(finalItems[0].title, initialItems[0].title)
        XCTAssertEqual(finalItems[1].title, initialItems[1].title)
    }
    
    // MARK: - SuggestionService Tests
    
    func testSuggestionServiceBasicSuggestions() throws {
        let testDataManager = TestHelpers.createTestDataManager()
        let testRepository = TestDataRepository(dataManager: testDataManager)
        let suggestionService = SuggestionService(dataRepository: testRepository)
        
        // Create test list and items
        let testList = List(name: "Grocery List")
        testDataManager.addList(testList)
        
        let _ = testRepository.createItem(in: testList, title: "Milk", description: "2% low fat")
        let _ = testRepository.createItem(in: testList, title: "Bread", description: "Whole wheat")
        let _ = testRepository.createItem(in: testList, title: "Eggs", description: "")
        let _ = testRepository.createItem(in: testList, title: "Butter", description: "")
        
        // Test exact match
        suggestionService.getSuggestions(for: "Milk", in: testList)
        XCTAssertEqual(suggestionService.suggestions.count, 1)
        XCTAssertEqual(suggestionService.suggestions.first?.title, "Milk")
        XCTAssertEqual(suggestionService.suggestions.first?.score, 100.0)
        
        // Test prefix match
        suggestionService.getSuggestions(for: "Br", in: testList)
        XCTAssertEqual(suggestionService.suggestions.count, 1)
        XCTAssertEqual(suggestionService.suggestions.first?.title, "Bread")
        XCTAssertEqual(suggestionService.suggestions.first?.score, 90.0)
        
        // Test contains match
        suggestionService.getSuggestions(for: "gg", in: testList)
        XCTAssertEqual(suggestionService.suggestions.count, 1)
        XCTAssertEqual(suggestionService.suggestions.first?.title, "Eggs")
        XCTAssertEqual(suggestionService.suggestions.first?.score, 70.0)
    }
    
    func testSuggestionServiceFuzzyMatching() throws {
        let testDataManager = TestHelpers.createTestDataManager()
        let testRepository = TestDataRepository(dataManager: testDataManager)
        let suggestionService = SuggestionService(dataRepository: testRepository)
        
        // Create test list and items
        let testList = List(name: "Shopping List")
        testDataManager.addList(testList)
        
        let _ = testRepository.createItem(in: testList, title: "Bananas", description: "")
        let _ = testRepository.createItem(in: testList, title: "Apples", description: "")
        
        // Test fuzzy matching with typos
        suggestionService.getSuggestions(for: "Banan", in: testList) // Missing 'a'
        XCTAssertGreaterThan(suggestionService.suggestions.count, 0)
        
        let bananaSuggestion = suggestionService.suggestions.first { $0.title == "Bananas" }
        XCTAssertNotNil(bananaSuggestion)
        XCTAssertGreaterThan(bananaSuggestion?.score ?? 0, 30.0) // Should have reasonable fuzzy score
        
        // Test with more typos
        suggestionService.getSuggestions(for: "Aples", in: testList) // Missing 'p'
        XCTAssertGreaterThan(suggestionService.suggestions.count, 0)
        
        let appleSuggestion = suggestionService.suggestions.first { $0.title == "Apples" }
        XCTAssertNotNil(appleSuggestion)
        XCTAssertGreaterThan(appleSuggestion?.score ?? 0, 30.0)
    }
    
    func testSuggestionServiceEmptySearch() throws {
        let testDataManager = TestHelpers.createTestDataManager()
        let testRepository = TestDataRepository(dataManager: testDataManager)
        let suggestionService = SuggestionService(dataRepository: testRepository)
        
        // Create test list and items
        let testList = List(name: "Test List")
        testDataManager.addList(testList)
        let _ = testRepository.createItem(in: testList, title: "Test Item", description: "")
        
        // Test empty search
        suggestionService.getSuggestions(for: "", in: testList)
        XCTAssertEqual(suggestionService.suggestions.count, 0)
        
        // Test whitespace only search
        suggestionService.getSuggestions(for: "   ", in: testList)
        XCTAssertEqual(suggestionService.suggestions.count, 0)
    }
    
    func testSuggestionServiceMultipleMatches() throws {
        let testDataManager = TestHelpers.createTestDataManager()
        let testRepository = TestDataRepository(dataManager: testDataManager)
        let suggestionService = SuggestionService(dataRepository: testRepository)
        
        // Create test list and items with similar names
        let testList = List(name: "Test List")
        testDataManager.addList(testList)
        
        let _ = testRepository.createItem(in: testList, title: "Apple Juice", description: "")
        let _ = testRepository.createItem(in: testList, title: "Apple Pie", description: "")
        let _ = testRepository.createItem(in: testList, title: "Pineapple", description: "")
        let _ = testRepository.createItem(in: testList, title: "Orange", description: "")
        
        // Test search that matches multiple items
        suggestionService.getSuggestions(for: "Apple", in: testList)
        XCTAssertGreaterThanOrEqual(suggestionService.suggestions.count, 2)
        
        // Verify suggestions are sorted by score (highest first)
        for i in 0..<(suggestionService.suggestions.count - 1) {
            XCTAssertGreaterThanOrEqual(
                suggestionService.suggestions[i].score,
                suggestionService.suggestions[i + 1].score
            )
        }
        
        // Exact matches should have highest scores
        let exactMatches = suggestionService.suggestions.filter { $0.score >= 90.0 }
        XCTAssertGreaterThan(exactMatches.count, 0)
    }
    
    func testSuggestionServiceFrequencyTracking() throws {
        let testDataManager = TestHelpers.createTestDataManager()
        let testRepository = TestDataRepository(dataManager: testDataManager)
        let suggestionService = SuggestionService(dataRepository: testRepository)
        
        // Create multiple lists with duplicate items
        let groceryList = List(name: "Grocery List")
        let shoppingList = List(name: "Shopping List")
        testDataManager.addList(groceryList)
        testDataManager.addList(shoppingList)
        
        // Add the same item to multiple lists
        let _ = testRepository.createItem(in: groceryList, title: "Milk", description: "")
        let _ = testRepository.createItem(in: shoppingList, title: "Milk", description: "")
        let _ = testRepository.createItem(in: groceryList, title: "Bread", description: "")
        
        // Test global suggestions (across all lists)
        suggestionService.getSuggestions(for: "Mi", in: nil)
        
        let milkSuggestion = suggestionService.suggestions.first { $0.title == "Milk" }
        XCTAssertNotNil(milkSuggestion)
        XCTAssertEqual(milkSuggestion?.frequency, 2) // Should appear in 2 lists
        
        let breadSuggestion = suggestionService.suggestions.first { $0.title == "Bread" }
        XCTAssertNotNil(breadSuggestion)
        XCTAssertEqual(breadSuggestion?.frequency, 1) // Should appear in 1 list
    }
    
    func testSuggestionServiceRecentItems() throws {
        let testDataManager = TestHelpers.createTestDataManager()
        let testRepository = TestDataRepository(dataManager: testDataManager)
        let suggestionService = SuggestionService(dataRepository: testRepository)
        
        // Create test list and items with different creation dates
        let testList = List(name: "Test List")
        testDataManager.addList(testList)
        
        let oldItem = testRepository.createItem(in: testList, title: "Old Item", description: "")
        let recentItem = testRepository.createItem(in: testList, title: "Recent Item", description: "")
        
        // Manually update creation dates to test sorting
        var updatedOldItem = oldItem
        updatedOldItem.createdAt = Date().addingTimeInterval(-86400) // 1 day ago
        testDataManager.updateItem(updatedOldItem)
        
        var updatedRecentItem = recentItem
        updatedRecentItem.createdAt = Date() // Now
        testDataManager.updateItem(updatedRecentItem)
        
        // Test recent items
        let recentItems = suggestionService.getRecentItems(limit: 10)
        XCTAssertGreaterThan(recentItems.count, 0)
        
        // Recent items should be sorted by creation date (most recent first)
        if recentItems.count >= 2 {
            XCTAssertEqual(recentItems[0].title, "Recent Item")
            XCTAssertEqual(recentItems[1].title, "Old Item")
        }
    }
    
    func testSuggestionServiceClearSuggestions() throws {
        let testDataManager = TestHelpers.createTestDataManager()
        let testRepository = TestDataRepository(dataManager: testDataManager)
        let suggestionService = SuggestionService(dataRepository: testRepository)
        
        // Create test data
        let testList = List(name: "Test List")
        testDataManager.addList(testList)
        let _ = testRepository.createItem(in: testList, title: "Test Item", description: "")
        
        // Get suggestions
        suggestionService.getSuggestions(for: "Test", in: testList)
        XCTAssertGreaterThan(suggestionService.suggestions.count, 0)
        
        // Clear suggestions
        suggestionService.clearSuggestions()
        XCTAssertEqual(suggestionService.suggestions.count, 0)
    }
    
    func testSuggestionServiceMaxResults() throws {
        let testDataManager = TestHelpers.createTestDataManager()
        let testRepository = TestDataRepository(dataManager: testDataManager)
        let suggestionService = SuggestionService(dataRepository: testRepository)
        
        // Create test list with many items
        let testList = List(name: "Test List")
        testDataManager.addList(testList)
        
        // Create 15 items that all match the search term
        for i in 1...15 {
            let _ = testRepository.createItem(in: testList, title: "Test Item \(i)", description: "")
        }
        
        // Test that suggestions are limited to 10
        suggestionService.getSuggestions(for: "Test", in: testList)
        XCTAssertLessThanOrEqual(suggestionService.suggestions.count, 10)
    }
    
    func testSuggestionServiceFuzzyMatchingEdgeCases() throws {
        let testDataManager = TestHelpers.createTestDataManager()
        let testRepository = TestDataRepository(dataManager: testDataManager)
        let suggestionService = SuggestionService(dataRepository: testRepository)
        
        // Create test list and items for edge case testing
        let testList = List(name: "Edge Case List")
        testDataManager.addList(testList)
        
        let _ = testRepository.createItem(in: testList, title: "test", description: "")
        let _ = testRepository.createItem(in: testList, title: "best", description: "")
        let _ = testRepository.createItem(in: testList, title: "apple", description: "")
        
        // Test close matches should return suggestions
        suggestionService.getSuggestions(for: "tst", in: testList) // Missing 'e'
        let testSuggestion = suggestionService.suggestions.first { $0.title == "test" }
        XCTAssertNotNil(testSuggestion, "Should find fuzzy match for 'tst' -> 'test'")
        
        // Test single character difference
        suggestionService.getSuggestions(for: "bst", in: testList) // 'b' instead of 't'
        let bestSuggestion = suggestionService.suggestions.first { $0.title == "best" }
        XCTAssertNotNil(bestSuggestion, "Should find fuzzy match for 'bst' -> 'best'")
        
        // Test completely different strings should not match
        suggestionService.getSuggestions(for: "zebra", in: testList)
        XCTAssertEqual(suggestionService.suggestions.count, 0, "Should not find matches for completely different strings")
    }
    
    func testPlaceholder() throws {
        // Placeholder test to ensure the test suite compiles
        XCTAssertTrue(true)
    }
}
