import XCTest
@testable import ListAll

final class SuggestionServiceTests: XCTestCase {

    // MARK: - SuggestionService Tests

    func testSuggestionServiceBasicSuggestions() throws {
        let testDataManager = TestHelpers.createTestDataManager()
        let testRepository = TestDataRepository(dataManager: testDataManager)
        let suggestionService = SuggestionService(dataRepository: testRepository)

        // Create test list and items
        let testList = List(name: "Grocery List")
        testDataManager.addList(testList)
        let _ = testRepository.createItem(in: testList, title: "Milk", description: "2% low fat")

        // Test exact match returns the item
        suggestionService.getSuggestions(for: "Milk", in: testList)
        XCTAssertEqual(suggestionService.suggestions.count, 1, "Should find exactly one match for 'Milk'")
        XCTAssertEqual(suggestionService.suggestions.first?.title, "Milk", "Should match 'Milk'")
        XCTAssertEqual(suggestionService.suggestions.first?.description, "2% low fat", "Should preserve description")

        // Test empty search returns no suggestions
        suggestionService.getSuggestions(for: "", in: testList)
        XCTAssertEqual(suggestionService.suggestions.count, 0, "Empty search should return no suggestions")
    }

    func testSuggestionServiceFuzzyMatching() throws {
        let testDataManager = TestHelpers.createTestDataManager()
        let testRepository = TestDataRepository(dataManager: testDataManager)
        let suggestionService = SuggestionService(dataRepository: testRepository)

        // Create test list and items
        let testList = List(name: "Shopping List")
        testDataManager.addList(testList)
        let _ = testRepository.createItem(in: testList, title: "Bananas", description: "")

        // Test prefix match
        suggestionService.getSuggestions(for: "Banan", in: testList)
        XCTAssertEqual(suggestionService.suggestions.count, 1, "Should find match for prefix 'Banan'")
        XCTAssertEqual(suggestionService.suggestions.first?.title, "Bananas", "Should match 'Bananas'")
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
        XCTAssertEqual(suggestionService.suggestions.count, 0, "Empty search should return no suggestions")

        // Test whitespace only search
        suggestionService.getSuggestions(for: "   ", in: testList)
        XCTAssertEqual(suggestionService.suggestions.count, 0, "Whitespace-only search should return no suggestions")
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

        // Test search that matches multiple items
        suggestionService.getSuggestions(for: "Apple", in: testList)
        XCTAssertEqual(suggestionService.suggestions.count, 2, "Should find 2 matches for 'Apple'")

        let titles = Set(suggestionService.suggestions.map { $0.title })
        XCTAssertTrue(titles.contains("Apple Juice"), "Should include 'Apple Juice'")
        XCTAssertTrue(titles.contains("Apple Pie"), "Should include 'Apple Pie'")
    }

    func testSuggestionServiceIndividualItems() throws {
        let testDataManager = TestHelpers.createTestDataManager()
        let testRepository = TestDataRepository(dataManager: testDataManager)
        let suggestionService = SuggestionService(dataRepository: testRepository)

        // Create test lists with items
        let list1 = List(name: "List 1")
        let list2 = List(name: "List 2")
        testDataManager.addList(list1)
        testDataManager.addList(list2)
        let _ = testRepository.createItem(in: list1, title: "Milk", description: "2% low fat")
        let _ = testRepository.createItem(in: list2, title: "Milk Chocolate", description: "Dark")

        // Test global search (nil list) finds items from all lists
        suggestionService.getSuggestions(for: "Milk", in: nil as List?)
        XCTAssertEqual(suggestionService.suggestions.count, 2, "Should find 2 items matching 'Milk' globally")

        // Verify frequency is 1 for individual items (not grouped)
        for suggestion in suggestionService.suggestions {
            XCTAssertEqual(suggestion.frequency, 1, "Individual item frequency should be 1")
        }
    }

    func testSuggestionServiceRecentItems() throws {
        let testDataManager = TestHelpers.createTestDataManager()
        let testRepository = TestDataRepository(dataManager: testDataManager)
        let suggestionService = SuggestionService(dataRepository: testRepository)

        // Create test list with items
        let testList = List(name: "Test List")
        testDataManager.addList(testList)
        let _ = testRepository.createItem(in: testList, title: "Recent Item 1", description: "")
        let _ = testRepository.createItem(in: testList, title: "Recent Item 2", description: "")

        // Test recent items
        let recentItems = suggestionService.getRecentItems(limit: 10)
        XCTAssertEqual(recentItems.count, 2, "Should return 2 recent items")

        // Verify recent items have valid scores
        for item in recentItems {
            XCTAssertGreaterThan(item.recencyScore, 0, "Recent items should have positive recency score")
            XCTAssertGreaterThanOrEqual(item.frequencyScore, 0, "Frequency score should be non-negative")
        }
    }

    func testSuggestionServiceClearSuggestions() throws {
        let testDataManager = TestHelpers.createTestDataManager()
        let testRepository = TestDataRepository(dataManager: testDataManager)
        let suggestionService = SuggestionService(dataRepository: testRepository)

        // Create test data
        let testList = List(name: "Clear Test")
        testDataManager.addList(testList)
        let _ = testRepository.createItem(in: testList, title: "Test Item", description: "")

        // Get suggestions first
        suggestionService.getSuggestions(for: "Test", in: testList)
        XCTAssertEqual(suggestionService.suggestions.count, 1, "Should find one suggestion")

        // Clear suggestions
        suggestionService.clearSuggestions()
        XCTAssertEqual(suggestionService.suggestions.count, 0, "Suggestions should be cleared")

        // Should be able to get suggestions again after clearing
        suggestionService.getSuggestions(for: "Test", in: testList)
        XCTAssertEqual(suggestionService.suggestions.count, 1, "Should find suggestion again after clear")
    }

    func testSuggestionServiceNoMatch() throws {
        let testDataManager = TestHelpers.createTestDataManager()
        let testRepository = TestDataRepository(dataManager: testDataManager)
        let suggestionService = SuggestionService(dataRepository: testRepository)

        // Create test list and items
        let testList = List(name: "Test List")
        testDataManager.addList(testList)
        let _ = testRepository.createItem(in: testList, title: "Test", description: "")

        // Test completely different strings should not match
        suggestionService.getSuggestions(for: "zebra", in: testList)
        XCTAssertEqual(suggestionService.suggestions.count, 0, "Should not find matches for unrelated strings")

        suggestionService.getSuggestions(for: "xyz123", in: testList)
        XCTAssertEqual(suggestionService.suggestions.count, 0, "Should not find matches for completely different strings")
    }

    // MARK: - Advanced Suggestion Tests

    func testAdvancedSuggestionScoring() throws {
        let testDataManager = TestHelpers.createTestDataManager()
        let testRepository = TestDataRepository(dataManager: testDataManager)
        let suggestionService = SuggestionService(dataRepository: testRepository)

        // Create test list and item
        let testList = List(name: "Test List")
        testDataManager.addList(testList)
        let _ = testRepository.createItem(in: testList, title: "Test Item", description: "")

        // Get suggestions and verify scoring properties
        suggestionService.getSuggestions(for: "Test", in: testList)
        XCTAssertEqual(suggestionService.suggestions.count, 1, "Should find one suggestion")

        let suggestion = suggestionService.suggestions.first!
        XCTAssertGreaterThan(suggestion.score, 0, "Score should be positive for a match")
        XCTAssertGreaterThanOrEqual(suggestion.recencyScore, 0, "Recency score should be non-negative")
        XCTAssertGreaterThanOrEqual(suggestion.frequencyScore, 0, "Frequency score should be non-negative")
        XCTAssertEqual(suggestion.totalOccurrences, 1, "Total occurrences should be 1 for single item")
    }

    func testSuggestionCaching() throws {
        let testDataManager = TestHelpers.createTestDataManager()
        let testRepository = TestDataRepository(dataManager: testDataManager)
        let suggestionService = SuggestionService(dataRepository: testRepository)

        // Create test data
        let testList = List(name: "Cache Test")
        testDataManager.addList(testList)
        let _ = testRepository.createItem(in: testList, title: "Cached Item", description: "")

        // Get suggestions, then clear cache, then get again
        suggestionService.getSuggestions(for: "Cached", in: testList)
        XCTAssertEqual(suggestionService.suggestions.count, 1, "Should find item before cache clear")

        suggestionService.clearSuggestionCache()

        suggestionService.getSuggestions(for: "Cached", in: testList)
        XCTAssertEqual(suggestionService.suggestions.count, 1, "Should find item after cache clear")
    }

    func testGlobalSearchAcrossLists() throws {
        let testDataManager = TestHelpers.createTestDataManager()
        let testRepository = TestDataRepository(dataManager: testDataManager)
        let suggestionService = SuggestionService(dataRepository: testRepository)

        // Create test lists with same-named items
        let list1 = List(name: "List 1")
        let list2 = List(name: "List 2")
        testDataManager.addList(list1)
        testDataManager.addList(list2)

        // Add items to both lists
        let _ = testRepository.createItem(in: list1, title: "Frequent Item", description: "In list 1")
        let _ = testRepository.createItem(in: list2, title: "Frequent Item", description: "In list 2")

        // Test global suggestions finds both
        suggestionService.getSuggestions(for: "Frequent", in: nil as List?)
        XCTAssertEqual(suggestionService.suggestions.count, 2, "Should find 2 items with same title across lists")
    }

    func testRecencyScoring() throws {
        let testDataManager = TestHelpers.createTestDataManager()
        let testRepository = TestDataRepository(dataManager: testDataManager)
        let suggestionService = SuggestionService(dataRepository: testRepository)

        // Create test list and item
        let testList = List(name: "Recency Test")
        testDataManager.addList(testList)
        let _ = testRepository.createItem(in: testList, title: "Recent Item", description: "")

        // Get suggestions for recently created item
        suggestionService.getSuggestions(for: "Recent", in: testList)
        XCTAssertEqual(suggestionService.suggestions.count, 1, "Should find recently created item")

        let suggestion = suggestionService.suggestions.first!
        // Recently created items should have high recency score (close to 100)
        XCTAssertGreaterThan(suggestion.recencyScore, 50, "Recently created item should have high recency score")
        XCTAssertLessThanOrEqual(suggestion.recencyScore, 100, "Recency score should not exceed 100")
    }

    func testCombinedScoringWeights() throws {
        let testDataManager = TestHelpers.createTestDataManager()
        let testRepository = TestDataRepository(dataManager: testDataManager)
        let suggestionService = SuggestionService(dataRepository: testRepository)

        // Create test list and item
        let testList = List(name: "Combined Test")
        testDataManager.addList(testList)
        let _ = testRepository.createItem(in: testList, title: "Combined Item", description: "")

        // Get suggestions
        suggestionService.getSuggestions(for: "Combined", in: testList)
        XCTAssertEqual(suggestionService.suggestions.count, 1, "Should find one suggestion")

        let suggestion = suggestionService.suggestions.first!
        // Combined score should be positive and reasonable
        XCTAssertGreaterThan(suggestion.score, 0, "Combined score should be positive")
        XCTAssertLessThanOrEqual(suggestion.score, 100, "Combined score should not exceed 100")
    }

    func testSuggestionCacheInvalidation() throws {
        let testDataManager = TestHelpers.createTestDataManager()
        let testRepository = TestDataRepository(dataManager: testDataManager)
        let suggestionService = SuggestionService(dataRepository: testRepository)

        // Create test data
        let testList = List(name: "Cache Invalidation Test")
        testDataManager.addList(testList)
        let _ = testRepository.createItem(in: testList, title: "Invalidation Item", description: "")

        // Get suggestions
        suggestionService.getSuggestions(for: "Invalidation", in: testList)
        XCTAssertEqual(suggestionService.suggestions.count, 1, "Should find item")

        // Invalidate cache for specific search text
        suggestionService.invalidateCacheFor(searchText: "Invalidation")

        // Should still work after invalidation
        suggestionService.getSuggestions(for: "Invalidation", in: testList)
        XCTAssertEqual(suggestionService.suggestions.count, 1, "Should still find item after cache invalidation")

        // Test data changes invalidation
        suggestionService.invalidateCacheForDataChanges()
        suggestionService.getSuggestions(for: "Invalidation", in: testList)
        XCTAssertEqual(suggestionService.suggestions.count, 1, "Should still find item after data changes invalidation")
    }

    // MARK: - Limit Tests

    func testGetSuggestionsWithLimit() throws {
        let testDataManager = TestHelpers.createTestDataManager()
        let testRepository = TestDataRepository(dataManager: testDataManager)
        let suggestionService = SuggestionService(dataRepository: testRepository)

        // Create test list with many items
        let testList = List(name: "Limit Test")
        testDataManager.addList(testList)
        for i in 1...10 {
            let _ = testRepository.createItem(in: testList, title: "Item \(i)", description: "")
        }

        // Test with limit
        suggestionService.getSuggestions(for: "Item", in: testList, limit: 3)
        XCTAssertEqual(suggestionService.suggestions.count, 3, "Should respect limit of 3")

        // Test with different limit
        suggestionService.getSuggestions(for: "Item", in: testList, limit: 5)
        XCTAssertEqual(suggestionService.suggestions.count, 5, "Should respect limit of 5")
    }

    func testGetSuggestionsWithoutLimit() throws {
        let testDataManager = TestHelpers.createTestDataManager()
        let testRepository = TestDataRepository(dataManager: testDataManager)
        let suggestionService = SuggestionService(dataRepository: testRepository)

        // Create test list with items
        let testList = List(name: "No Limit Test")
        testDataManager.addList(testList)
        for i in 1...5 {
            let _ = testRepository.createItem(in: testList, title: "Apple \(i)", description: "")
        }

        // Test without limit returns all matches
        suggestionService.getSuggestions(for: "Apple", in: testList, limit: nil)
        XCTAssertEqual(suggestionService.suggestions.count, 5, "Should return all 5 matches without limit")

        // Verify suggestions are sorted by score (descending)
        for i in 1..<suggestionService.suggestions.count {
            XCTAssertGreaterThanOrEqual(
                suggestionService.suggestions[i-1].score,
                suggestionService.suggestions[i].score,
                "Suggestions should be sorted by score in descending order"
            )
        }
    }

    func testSuggestionDetailsIncluded() throws {
        let testDataManager = TestHelpers.createTestDataManager()
        let testRepository = TestDataRepository(dataManager: testDataManager)
        let suggestionService = SuggestionService(dataRepository: testRepository)

        // Create test list with detailed item
        let testList = List(name: "Details Test")
        testDataManager.addList(testList)
        let _ = testRepository.createItem(in: testList, title: "Detailed Item", description: "With description", quantity: 3)

        // Get suggestions
        suggestionService.getSuggestions(for: "Detailed", in: testList)
        XCTAssertEqual(suggestionService.suggestions.count, 1, "Should find one suggestion")

        let suggestion = suggestionService.suggestions.first!
        XCTAssertEqual(suggestion.title, "Detailed Item", "Should preserve title")
        XCTAssertEqual(suggestion.description, "With description", "Should preserve description")
        XCTAssertEqual(suggestion.quantity, 3, "Should preserve quantity")
        XCTAssertGreaterThan(suggestion.score, 0, "Score should be positive")
    }
}
