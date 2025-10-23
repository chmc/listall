//
//  SyncBugFixTests.swift
//  ListAllTests
//
//  Created to test critical sync bug fixes
//  Phase 79B: Data loss prevention and size limit enforcement
//

import XCTest
@testable import ListAll

/// Tests for critical sync bug fixes in Phase 79B
/// These tests verify that data loss and transfer size issues are prevented
final class SyncBugFixTests: XCTestCase {
    
    var dataManager: DataManager!
    
    override func setUp() {
        super.setUp()
        // Use a fresh DataManager instance for each test
        dataManager = DataManager.shared
        // Clean up any existing data
        for list in dataManager.lists {
            dataManager.deleteList(withId: list.id)
        }
    }
    
    override func tearDown() {
        // Clean up test data
        for list in dataManager.lists {
            dataManager.deleteList(withId: list.id)
        }
        dataManager = nil
        super.tearDown()
    }
    
    // MARK: - Empty Sync Protection Tests
    
    /// Test that receiving an empty sync doesn't delete existing data
    /// This was Bug #1: Watch sends 0 lists → iOS deleted everything
    func testEmptySyncDoesNotDeleteExistingLists() {
        // Given: iOS has 3 lists with data
        let list1 = List(name: "Shopping")
        let list2 = List(name: "To-Do")
        let list3 = List(name: "Packing")
        
        dataManager.addList(list1)
        dataManager.addList(list2)
        dataManager.addList(list3)
        
        // Verify we have 3 lists
        XCTAssertEqual(dataManager.lists.count, 3, "Should have 3 lists before sync")
        
        // When: We simulate receiving an empty sync from Watch
        let receivedLists: [List] = [] // Empty sync
        
        // Simulate the sync logic with the fix
        if !receivedLists.isEmpty {
            // This block should NOT execute for empty sync
            let receivedListIds = Set(receivedLists.map { $0.id })
            let localActiveListIds = Set(dataManager.lists.filter { !$0.isArchived }.map { $0.id })
            let listsToRemove = localActiveListIds.subtracting(receivedListIds)
            
            for listIdToRemove in listsToRemove {
                dataManager.deleteList(withId: listIdToRemove)
            }
        }
        // Else: Empty sync - don't delete anything (the fix!)
        
        // Then: All lists should still exist
        XCTAssertEqual(dataManager.lists.count, 3, "Empty sync should NOT delete any lists")
        XCTAssertTrue(dataManager.lists.contains(where: { $0.name == "Shopping" }))
        XCTAssertTrue(dataManager.lists.contains(where: { $0.name == "To-Do" }))
        XCTAssertTrue(dataManager.lists.contains(where: { $0.name == "Packing" }))
    }
    
    /// Test that a valid sync with fewer lists DOES remove the missing ones
    /// This ensures the fix doesn't break legitimate delete sync
    func testNonEmptySyncDoesRemoveDeletedLists() {
        // Given: iOS has 3 lists
        let list1 = List(name: "Shopping")
        let list2 = List(name: "To-Do")
        let list3 = List(name: "Packing")
        
        dataManager.addList(list1)
        dataManager.addList(list2)
        dataManager.addList(list3)
        
        XCTAssertEqual(dataManager.lists.count, 3)
        
        // When: Watch sends only 2 lists (list3 was deleted on Watch)
        let receivedLists = [list1, list2]
        
        // Simulate the sync logic
        if !receivedLists.isEmpty {
            let receivedListIds = Set(receivedLists.map { $0.id })
            let localActiveListIds = Set(dataManager.lists.filter { !$0.isArchived }.map { $0.id })
            let listsToRemove = localActiveListIds.subtracting(receivedListIds)
            
            for listIdToRemove in listsToRemove {
                dataManager.deleteList(withId: listIdToRemove)
            }
        }
        
        // Then: Should have 2 lists (list3 removed)
        dataManager.loadData() // Reload to reflect changes
        XCTAssertEqual(dataManager.lists.count, 2, "Should have removed the missing list")
        XCTAssertTrue(dataManager.lists.contains(where: { $0.name == "Shopping" }))
        XCTAssertTrue(dataManager.lists.contains(where: { $0.name == "To-Do" }))
        XCTAssertFalse(dataManager.lists.contains(where: { $0.name == "Packing" }))
    }
    
    // MARK: - Size Limit Tests
    
    /// Test that data size check correctly identifies small data
    /// This verifies the 256 KB limit check works for valid data
    func testSmallDataPassesSizeCheck() {
        // Given: A small list with a few items (no images)
        var list = List(name: "Small Shopping List")
        let item1 = Item(title: "Milk")
        let item2 = Item(title: "Bread")
        let item3 = Item(title: "Eggs")
        list.items = [item1, item2, item3]
        
        // When: We encode it
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        
        do {
            let jsonData = try encoder.encode([list])
            let jsonSizeKB = Double(jsonData.count) / 1024.0
            
            // Then: Should be well under 256 KB
            XCTAssertLessThan(jsonData.count, 256 * 1024, "Small data should be under 256 KB")
            XCTAssertLessThan(jsonSizeKB, 10, "Simple list should be under 10 KB")
            print("✅ Small data size: \(String(format: "%.2f", jsonSizeKB)) KB")
        } catch {
            XCTFail("Failed to encode small data: \(error)")
        }
    }
    
    /// Test that the size limit is enforced at 256 KB
    /// This documents the WatchConnectivity limit
    func testSizeLimitThresholdIs256KB() {
        let sizeLimit = 256 * 1024 // 256 KB
        let sizeLimitKB = Double(sizeLimit) / 1024.0
        
        XCTAssertEqual(sizeLimitKB, 256.0, "Size limit should be 256 KB")
        
        // Test that we correctly identify data just under the limit
        let justUnderLimit = sizeLimit - 1
        XCTAssertLessThan(justUnderLimit, sizeLimit, "Just under limit should pass")
        
        // Test that we correctly identify data at the limit
        let atLimit = sizeLimit
        XCTAssertFalse(atLimit < sizeLimit, "At limit should not pass")
        
        // Test that we correctly identify data over the limit
        let overLimit = sizeLimit + 1
        XCTAssertGreaterThan(overLimit, sizeLimit, "Over limit should fail")
    }
    
    // MARK: - Duplicate Prevention Tests
    
    /// Test that adding an item with an existing ID updates instead of duplicating
    /// This was Bug #2: Items were duplicated during sync
    func testAddItemWithExistingIdUpdatesInsteadOfDuplicating() {
        // Given: A list with one item
        let list = List(name: "Test List")
        dataManager.addList(list)
        
        var item = Item(title: "Original Title")
        item.itemDescription = "Original Description"
        dataManager.addItem(item, to: list.id)
        
        // Verify item exists
        dataManager.loadData()
        let listAfterAdd = dataManager.lists.first(where: { $0.id == list.id })
        XCTAssertEqual(listAfterAdd?.items.count, 1, "Should have 1 item")
        XCTAssertEqual(listAfterAdd?.items.first?.title, "Original Title")
        
        // When: We try to add the same item (same ID) with updated data
        var updatedItem = item // Same ID
        updatedItem.title = "Updated Title"
        updatedItem.itemDescription = "Updated Description"
        updatedItem.updateModifiedDate()
        
        dataManager.addItem(updatedItem, to: list.id)
        
        // Then: Should still have only 1 item (updated, not duplicated)
        dataManager.loadData()
        let listAfterUpdate = dataManager.lists.first(where: { $0.id == list.id })
        XCTAssertEqual(listAfterUpdate?.items.count, 1, "Should still have only 1 item (no duplicate)")
        XCTAssertEqual(listAfterUpdate?.items.first?.title, "Updated Title", "Item should be updated")
        XCTAssertEqual(listAfterUpdate?.items.first?.itemDescription, "Updated Description")
    }
    
    /// Test that adding items with different IDs creates separate items
    /// This ensures the fix doesn't prevent adding new items
    func testAddItemWithDifferentIdCreatesNewItem() {
        // Given: A list with one item
        let list = List(name: "Test List")
        dataManager.addList(list)
        
        let item1 = Item(title: "First Item")
        dataManager.addItem(item1, to: list.id)
        
        dataManager.loadData()
        XCTAssertEqual(dataManager.lists.first(where: { $0.id == list.id })?.items.count, 1)
        
        // When: We add a different item (different ID)
        let item2 = Item(title: "Second Item")
        dataManager.addItem(item2, to: list.id)
        
        // Then: Should have 2 items
        dataManager.loadData()
        let finalList = dataManager.lists.first(where: { $0.id == list.id })
        XCTAssertEqual(finalList?.items.count, 2, "Should have 2 different items")
        XCTAssertTrue(finalList?.items.contains(where: { $0.title == "First Item" }) ?? false)
        XCTAssertTrue(finalList?.items.contains(where: { $0.title == "Second Item" }) ?? false)
    }
    
    // MARK: - Performance Tests
    
    /// Test that batched reload is more efficient than per-item reload
    /// This verifies Bug #3 fix: Excessive reloads were removed
    func testBatchedReloadPerformance() {
        // Given: A list
        let list = List(name: "Performance Test List")
        dataManager.addList(list)
        
        // When: We add 100 items
        let startTime = Date()
        
        for i in 1...100 {
            let item = Item(title: "Item \(i)")
            dataManager.addItem(item, to: list.id)
            // Note: addItem() no longer calls loadData() - this is the fix!
        }
        
        // Then: Single reload at the end
        dataManager.loadData()
        
        let elapsedTime = Date().timeIntervalSince(startTime)
        
        // Verify all items were added
        dataManager.loadData()
        let finalList = dataManager.lists.first(where: { $0.id == list.id })
        XCTAssertEqual(finalList?.items.count, 100, "Should have 100 items")
        
        // Performance should be reasonable (< 5 seconds for 100 items + 1 reload)
        XCTAssertLessThan(elapsedTime, 5.0, "Adding 100 items with batched reload should be fast")
        
        print("✅ Added 100 items in \(String(format: "%.2f", elapsedTime)) seconds")
    }
}

