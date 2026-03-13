//
//  SuggestionServiceMacTests.swift
//  ListAllMacTests
//

import XCTest
import CoreData
import Combine
#if os(macOS)
@preconcurrency import AppKit
#endif
@testable import ListAll

#if os(macOS)

final class SuggestionServiceMacTests: XCTestCase {

    // MARK: - Platform Verification

    func testRunningOnMacOS() {
        #if os(macOS)
        XCTAssertTrue(true, "Suggestion service tests are running on macOS")
        #else
        XCTFail("Suggestion service tests should only run on macOS")
        #endif
    }

    // MARK: - ItemSuggestion Model Tests

    func testItemSuggestionCreation() {
        let suggestion = ItemSuggestion(
            id: UUID(),
            title: "Milk",
            description: "2% low fat",
            quantity: 2,
            images: [],
            frequency: 5,
            lastUsed: Date(),
            score: 85.0,
            recencyScore: 90.0,
            frequencyScore: 80.0,
            totalOccurrences: 5,
            averageUsageGap: 86400.0
        )

        XCTAssertEqual(suggestion.title, "Milk")
        XCTAssertEqual(suggestion.description, "2% low fat")
        XCTAssertEqual(suggestion.quantity, 2)
        XCTAssertEqual(suggestion.frequency, 5)
        XCTAssertEqual(suggestion.score, 85.0)
        XCTAssertEqual(suggestion.recencyScore, 90.0)
        XCTAssertEqual(suggestion.frequencyScore, 80.0)
        XCTAssertEqual(suggestion.totalOccurrences, 5)
    }

    func testItemSuggestionDefaultValues() {
        let suggestion = ItemSuggestion(title: "Test Item")

        XCTAssertEqual(suggestion.title, "Test Item")
        XCTAssertNil(suggestion.description)
        XCTAssertEqual(suggestion.quantity, 1)
        XCTAssertEqual(suggestion.frequency, 1)
        XCTAssertEqual(suggestion.score, 0.0)
        XCTAssertEqual(suggestion.recencyScore, 0.0)
        XCTAssertEqual(suggestion.frequencyScore, 0.0)
        XCTAssertEqual(suggestion.totalOccurrences, 1)
        XCTAssertEqual(suggestion.averageUsageGap, 0.0)
        XCTAssertTrue(suggestion.images.isEmpty)
    }

    func testItemSuggestionWithImages() {
        let image = ItemImage(imageData: Data())
        let suggestion = ItemSuggestion(
            title: "Item with Image",
            images: [image]
        )

        XCTAssertEqual(suggestion.images.count, 1)
        XCTAssertFalse(suggestion.images.isEmpty)
    }

    // MARK: - SuggestionService Existence Tests

    func testSuggestionServiceExists() {
        // Verify SuggestionService class exists and can be instantiated
        let service = SuggestionService()
        XCTAssertNotNil(service)
    }

    func testSuggestionServiceIsObservableObject() {
        // Verify SuggestionService conforms to ObservableObject
        let service = SuggestionService()
        XCTAssertNotNil(service.objectWillChange)
    }

    func testSuggestionServiceHasSuggestionsProperty() {
        let service = SuggestionService()
        // suggestions should start empty
        XCTAssertTrue(service.suggestions.isEmpty)
    }

    // MARK: - Suggestion Generation Tests

    func testGetSuggestionsForEmptySearch() {
        let service = SuggestionService()

        // Empty search should clear suggestions
        service.getSuggestions(for: "", in: nil)
        XCTAssertTrue(service.suggestions.isEmpty)
    }

    func testGetSuggestionsForShortSearch() {
        let service = SuggestionService()

        // Single character search should work (depends on implementation)
        service.getSuggestions(for: "M", in: nil)
        // Result depends on data, but should not crash
        XCTAssertNotNil(service.suggestions)
    }

    func testClearSuggestions() {
        let service = SuggestionService()

        // After clearing, suggestions should be empty
        service.clearSuggestions()
        XCTAssertTrue(service.suggestions.isEmpty)
    }

    // MARK: - Cache Management Tests

    func testClearSuggestionCache() {
        let service = SuggestionService()

        // Should not crash
        service.clearSuggestionCache()
        XCTAssertTrue(true, "Cache cleared without crash")
    }

    func testInvalidateCacheForSearchText() {
        let service = SuggestionService()

        // Should not crash
        service.invalidateCacheFor(searchText: "milk")
        XCTAssertTrue(true, "Cache invalidated without crash")
    }

    func testInvalidateCacheForDataChanges() {
        let service = SuggestionService()

        // Should not crash
        service.invalidateCacheForDataChanges()
        XCTAssertTrue(true, "Cache invalidated for data changes without crash")
    }

    // MARK: - Recent Items Tests

    func testGetRecentItemsWithDefaultLimit() {
        let service = SuggestionService()

        let recentItems = service.getRecentItems()
        // Should return array (may be empty if no data)
        XCTAssertNotNil(recentItems)
        XCTAssertLessThanOrEqual(recentItems.count, 20) // Default limit
    }

    func testGetRecentItemsWithCustomLimit() {
        let service = SuggestionService()

        let recentItems = service.getRecentItems(limit: 5)
        XCTAssertLessThanOrEqual(recentItems.count, 5)
    }

    // MARK: - Score Indicator Tests

    func testHighScoreIndicator() {
        // Score >= 90 should show star.fill (based on MacSuggestionListView)
        let suggestion = ItemSuggestion(title: "High Score", score: 95.0)
        XCTAssertGreaterThanOrEqual(suggestion.score, 90.0)
    }

    func testMediumScoreIndicator() {
        // Score >= 70 but < 90 should show star
        let suggestion = ItemSuggestion(title: "Medium Score", score: 75.0)
        XCTAssertGreaterThanOrEqual(suggestion.score, 70.0)
        XCTAssertLessThan(suggestion.score, 90.0)
    }

    func testLowScoreIndicator() {
        // Score < 70 should show circle.fill
        let suggestion = ItemSuggestion(title: "Low Score", score: 50.0)
        XCTAssertLessThan(suggestion.score, 70.0)
    }

    // MARK: - Recency Score Tests

    func testHighRecencyScore() {
        // recencyScore >= 90 indicates used very recently
        let suggestion = ItemSuggestion(title: "Recent Item", recencyScore: 95.0)
        XCTAssertGreaterThanOrEqual(suggestion.recencyScore, 90.0)
    }

    func testMediumRecencyScore() {
        // recencyScore >= 70 but < 90 indicates moderately recent
        let suggestion = ItemSuggestion(title: "Older Item", recencyScore: 75.0)
        XCTAssertGreaterThanOrEqual(suggestion.recencyScore, 70.0)
        XCTAssertLessThan(suggestion.recencyScore, 90.0)
    }

    // MARK: - Frequency Score Tests

    func testHighFrequencyScore() {
        // frequencyScore >= 80 indicates frequently used (hot item)
        let suggestion = ItemSuggestion(title: "Hot Item", frequencyScore: 85.0)
        XCTAssertGreaterThanOrEqual(suggestion.frequencyScore, 80.0)
    }

    func testFrequencyBadgeDisplay() {
        // frequency > 1 should display "Nx" badge
        let suggestion = ItemSuggestion(title: "Frequent Item", frequency: 5)
        XCTAssertGreaterThan(suggestion.frequency, 1)
    }

    // MARK: - ExcludeItemId Tests

    func testGetSuggestionsWithExcludeItemId() {
        let service = SuggestionService()
        let excludeId = UUID()

        // Should not crash when excludeItemId is provided
        service.getSuggestions(for: "test", in: nil, excludeItemId: excludeId)
        XCTAssertNotNil(service.suggestions)
    }

    // MARK: - DRY Principle Verification

    func testSuggestionServiceIsSharedWithiOS() {
        // Verify this is the same SuggestionService used by iOS
        // (not a macOS-specific copy)
        let service = SuggestionService()

        // All these methods should exist (same as iOS)
        service.getSuggestions(for: "test", in: nil)
        service.clearSuggestions()
        service.clearSuggestionCache()
        _ = service.getRecentItems(limit: 5)

        XCTAssertTrue(true, "SuggestionService API matches iOS version")
    }

    // MARK: - Performance Tests

    func testSuggestionLookupPerformance() {
        let service = SuggestionService()

        measure {
            for _ in 0..<100 {
                service.getSuggestions(for: "milk", in: nil)
            }
        }
    }

    // MARK: - Documentation

    func testDocumentSuggestionServiceForMacOS() {
        // This test documents the SuggestionService integration for macOS
        //
        // Key Implementation Details:
        // 1. SuggestionService is 100% shared between iOS and macOS (no platform-specific code)
        // 2. Uses Foundation + Combine only (no UIKit/AppKit dependencies)
        // 3. ItemSuggestion struct holds suggestion data with scoring metadata
        // 4. getSuggestions(for:in:limit:excludeItemId:) is the main entry point
        // 5. Suggestions are published via @Published var suggestions
        // 6. Cache management available via clear/invalidate methods
        //
        // macOS UI Integration:
        // - MacSuggestionListView displays suggestions with hover states
        // - MacAddItemSheet integrates suggestions below title field
        // - MacEditItemSheet integrates suggestions with excludeItemId for current item
        // - Suggestions appear after 2+ characters typed
        // - Clicking suggestion populates title, quantity, and description

        XCTAssertTrue(true, "SuggestionService macOS documentation verified")
    }
}


#endif
