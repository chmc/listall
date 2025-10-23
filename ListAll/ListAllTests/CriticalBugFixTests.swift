//
//  CriticalBugFixTests.swift
//  ListAllTests
//
//  Tests for 5 critical bug fixes:
//  1. Suggested items not being added
//  2. Archive list not syncing
//  3. Reorder items not syncing
//  4. Delete/move/copy items not syncing
//  5. Smart duplicate detection
//

import XCTest
@testable import ListAll

/// Tests for critical bug fixes that were causing data loss and sync issues
final class CriticalBugFixTests: XCTestCase {
    
    var dataRepository: DataRepository!
    var dataManager: DataManager!
    
    override func setUp() {
        super.setUp()
        dataRepository = DataRepository()
        dataManager = DataManager.shared
        
        // Clean up any existing data
        dataManager.loadData()
        for list in dataManager.lists {
            dataManager.deleteList(withId: list.id)
        }
    }
    
    override func tearDown() {
        // Clean up test data
        dataManager.loadData()
        for list in dataManager.lists {
            dataManager.deleteList(withId: list.id)
        }
        dataRepository = nil
        dataManager = nil
        super.tearDown()
    }
    
    // MARK: - Bug Fix 5: Suggested Items Not Being Added
    
    /// Test: Suggested item from another list actually gets added (not updated)
    /// This was a CRITICAL bug where items disappeared instead of being added
    func testSuggestedItemGetsAdded() {
        // Given: A source list with an item
        let sourceList = dataRepository.createList(name: "Groceries")
        let sourceItem = dataRepository.createItem(
            in: sourceList,
            title: "Milk",
            description: "Whole milk",
            quantity: 1
        )
        
        // And: A destination list (empty)
        let destList = dataRepository.createList(name: "Shopping")
        
        dataManager.loadData()
        let destListBefore = dataManager.lists.first { $0.id == destList.id }
        XCTAssertEqual(destListBefore?.items.count, 0, "Destination list should be empty")
        
        // When: We add the suggested item to the destination list
        dataRepository.addExistingItemToList(sourceItem, listId: destList.id)
        
        // Then: Item should be added to destination list
        dataManager.loadData()
        let destListAfter = dataManager.lists.first { $0.id == destList.id }
        XCTAssertEqual(destListAfter?.items.count, 1, "Destination list should have 1 item")
        XCTAssertEqual(destListAfter?.items.first?.title, "Milk", "Item should have correct title")
        
        // And: Source item should still exist in source list
        let sourceListAfter = dataManager.lists.first { $0.id == sourceList.id }
        XCTAssertEqual(sourceListAfter?.items.count, 1, "Source list should still have 1 item")
        
        // And: They should have DIFFERENT IDs (not the same item)
        let sourceItemId = sourceListAfter?.items.first?.id
        let destItemId = destListAfter?.items.first?.id
        XCTAssertNotEqual(sourceItemId, destItemId, "Source and destination items should have different IDs")
        
        // CRITICAL: Item should be added as UNCROSSED (active)
        XCTAssertFalse(destListAfter?.items.first?.isCrossedOut ?? true, "Suggested item should be added as uncrossed (active)")
    }
    
    /// Test: Adding suggested item preserves images with new IDs
    func testSuggestedItemWithImagesGetsCopied() {
        // Given: A source list with an item that has images
        let sourceList = dataRepository.createList(name: "Groceries")
        var sourceItem = dataRepository.createItem(
            in: sourceList,
            title: "Product",
            description: "With image",
            quantity: 1
        )
        
        // Add an image to the item
        let imageData = Data(count: 100)
        let image = dataRepository.addImage(to: sourceItem, imageData: imageData)
        sourceItem.images = [image]
        
        // And: A destination list
        let destList = dataRepository.createList(name: "Shopping")
        
        // When: We add the suggested item with its images
        dataRepository.addExistingItemToList(sourceItem, listId: destList.id)
        
        // Then: Item should be added with images copied
        dataManager.loadData()
        let destListAfter = dataManager.lists.first { $0.id == destList.id }
        let addedItem = destListAfter?.items.first
        
        XCTAssertEqual(addedItem?.images.count, 1, "Item should have 1 image")
        
        // And: Image should have a NEW ID (not same as source)
        XCTAssertNotEqual(addedItem?.images.first?.id, image.id, "Image should have new ID")
    }
    
    // MARK: - Bug Fix 4: Smart Duplicate Detection
    
    /// Test: Adding item with same title+metadata when crossed-out item exists → uncrosses it
    func testSmartDuplicateDetectionUncrossesExisting() {
        // Given: A list with a crossed-out item
        let list = dataRepository.createList(name: "Shopping")
        var item = dataRepository.createItem(
            in: list,
            title: "Milk",
            description: "Whole milk",
            quantity: 2
        )
        
        // Cross it out
        dataRepository.toggleItemCrossedOut(item)
        
        dataManager.loadData()
        let listBefore = dataManager.lists.first { $0.id == list.id }
        let crossedItem = listBefore?.items.first { $0.id == item.id }
        XCTAssertTrue(crossedItem?.isCrossedOut ?? false, "Item should be crossed out")
        XCTAssertEqual(listBefore?.items.count, 1, "Should have 1 item")
        
        // When: We try to add the exact same item (same title, description, quantity)
        let returnedItem = dataRepository.createItem(
            in: list,
            title: "Milk",
            description: "Whole milk",
            quantity: 2
        )
        
        // Then: Should NOT create duplicate, should uncross existing
        dataManager.loadData()
        let listAfter = dataManager.lists.first { $0.id == list.id }
        XCTAssertEqual(listAfter?.items.count, 1, "Should still have only 1 item (no duplicate)")
        
        let uncrossedItem = listAfter?.items.first { $0.id == item.id }
        XCTAssertFalse(uncrossedItem?.isCrossedOut ?? true, "Item should be uncrossed")
        
        // And: Returned item should be the uncrossed one
        XCTAssertEqual(returnedItem.id, item.id, "Should return the existing item")
        XCTAssertFalse(returnedItem.isCrossedOut, "Returned item should be uncrossed")
    }
    
    /// Test: Adding item with different metadata creates new item (even with same title)
    func testSmartDuplicateDetectionCreatesNewIfMetadataDiffers() {
        // Given: A list with "Milk" (whole milk, qty 1)
        let list = dataRepository.createList(name: "Shopping")
        let item1 = dataRepository.createItem(
            in: list,
            title: "Milk",
            description: "Whole milk",
            quantity: 1
        )
        
        // Cross it out
        dataRepository.toggleItemCrossedOut(item1)
        
        // When: We add "Milk" with different description
        let item2 = dataRepository.createItem(
            in: list,
            title: "Milk",
            description: "2% milk",
            quantity: 1
        )
        
        // Then: Should create new item (metadata differs)
        dataManager.loadData()
        let listAfter = dataManager.lists.first { $0.id == list.id }
        XCTAssertEqual(listAfter?.items.count, 2, "Should have 2 items (different metadata)")
        XCTAssertNotEqual(item1.id, item2.id, "Should be different items")
        
        // And: Original should still be crossed out
        let originalItem = listAfter?.items.first { $0.id == item1.id }
        XCTAssertTrue(originalItem?.isCrossedOut ?? false, "Original should still be crossed out")
        
        // And: New item should not be crossed out
        XCTAssertFalse(item2.isCrossedOut, "New item should not be crossed out")
    }
    
    /// Test: Adding item with different quantity creates new item
    func testSmartDuplicateDetectionCreatesNewIfQuantityDiffers() {
        // Given: A list with "Milk" qty 1
        let list = dataRepository.createList(name: "Shopping")
        let item1 = dataRepository.createItem(
            in: list,
            title: "Milk",
            description: "",
            quantity: 1
        )
        
        dataRepository.toggleItemCrossedOut(item1)
        
        // When: We add "Milk" qty 2
        let item2 = dataRepository.createItem(
            in: list,
            title: "Milk",
            description: "",
            quantity: 2
        )
        
        // Then: Should create new item (quantity differs)
        dataManager.loadData()
        let listAfter = dataManager.lists.first { $0.id == list.id }
        XCTAssertEqual(listAfter?.items.count, 2, "Should have 2 items (different quantity)")
    }
    
    /// Test: Adding item that already exists uncrossed returns existing
    func testSmartDuplicateDetectionReturnsExistingIfNotCrossed() {
        // Given: A list with an uncrossed item
        let list = dataRepository.createList(name: "Shopping")
        let item1 = dataRepository.createItem(
            in: list,
            title: "Milk",
            description: "",
            quantity: 1
        )
        
        dataManager.loadData()
        let listBefore = dataManager.lists.first { $0.id == list.id }
        XCTAssertEqual(listBefore?.items.count, 1)
        
        // When: We try to add the exact same item
        let item2 = dataRepository.createItem(
            in: list,
            title: "Milk",
            description: "",
            quantity: 1
        )
        
        // Then: Should return existing item without creating duplicate
        dataManager.loadData()
        let listAfter = dataManager.lists.first { $0.id == list.id }
        XCTAssertEqual(listAfter?.items.count, 1, "Should still have only 1 item")
        XCTAssertEqual(item2.id, item1.id, "Should return existing item")
    }
    
    // MARK: - Bug Fix 1-3: Auto-Sync Tests
    
    /// Test: Archive list operation completes without errors
    /// Note: We can't easily test WatchConnectivity sync in unit tests,
    /// but we verify the operation completes successfully
    func testArchiveListCompletes() {
        // Given: A list
        let list = dataRepository.createList(name: "Test List")
        
        dataManager.loadData()
        XCTAssertTrue(dataManager.lists.contains { $0.id == list.id }, "List should exist")
        
        // When: We archive it (via deleteList which archives)
        dataManager.deleteList(withId: list.id)
        
        // Then: List should be archived (not in active lists)
        dataManager.loadData()
        XCTAssertFalse(dataManager.lists.contains { $0.id == list.id }, "List should not be in active lists")
        
        // And: Should be in archived lists
        let archivedLists = dataManager.loadArchivedLists()
        XCTAssertTrue(archivedLists.contains { $0.id == list.id }, "List should be in archived lists")
    }
    
    /// Test: Restore list operation completes without errors
    func testRestoreListCompletes() {
        // Given: An archived list
        let list = dataRepository.createList(name: "Test List")
        dataManager.deleteList(withId: list.id) // Archive it
        
        dataManager.loadData()
        XCTAssertFalse(dataManager.lists.contains { $0.id == list.id }, "List should be archived")
        
        // When: We restore it
        dataManager.restoreList(withId: list.id)
        
        // Then: List should be back in active lists
        dataManager.loadData()
        XCTAssertTrue(dataManager.lists.contains { $0.id == list.id }, "List should be restored")
    }
    
    /// Test: Reorder items operation completes without errors
    func testReorderItemsCompletes() {
        // Given: A list with 3 items
        let list = dataRepository.createList(name: "Test List")
        let item1 = dataRepository.createItem(in: list, title: "Item 1")
        let item2 = dataRepository.createItem(in: list, title: "Item 2")
        let item3 = dataRepository.createItem(in: list, title: "Item 3")
        
        dataManager.loadData()
        let listBefore = dataManager.lists.first { $0.id == list.id }
        XCTAssertEqual(listBefore?.items.count, 3)
        
        // When: We reorder (move item at index 0 to index 2)
        dataRepository.reorderItems(in: list, from: 0, to: 2)
        
        // Then: Operation should complete without errors
        dataManager.loadData()
        let listAfter = dataManager.lists.first { $0.id == list.id }
        XCTAssertEqual(listAfter?.items.count, 3, "Should still have 3 items")
        
        // Verify order changed (item that was first should now be last)
        let items = listAfter?.items.sorted { $0.orderNumber < $1.orderNumber } ?? []
        XCTAssertEqual(items.last?.id, item1.id, "First item should now be last")
    }
    
    /// Test: Delete item operation completes without errors
    func testDeleteItemCompletes() {
        // Given: A list with an item
        let list = dataRepository.createList(name: "Test List")
        let item = dataRepository.createItem(in: list, title: "Test Item")
        
        dataManager.loadData()
        let listBefore = dataManager.lists.first { $0.id == list.id }
        XCTAssertEqual(listBefore?.items.count, 1)
        
        // When: We delete the item
        dataRepository.deleteItem(item)
        
        // Then: Item should be removed
        dataManager.loadData()
        let listAfter = dataManager.lists.first { $0.id == list.id }
        XCTAssertEqual(listAfter?.items.count, 0, "Item should be deleted")
    }
    
    /// Test: Move item operation completes without errors
    func testMoveItemCompletes() {
        // Given: Two lists, item in first list
        let sourceList = dataRepository.createList(name: "Source")
        let destList = dataRepository.createList(name: "Destination")
        var item = dataRepository.createItem(in: sourceList, title: "Item")
        
        dataManager.loadData()
        let sourceBefore = dataManager.lists.first { $0.id == sourceList.id }
        let destBefore = dataManager.lists.first { $0.id == destList.id }
        XCTAssertEqual(sourceBefore?.items.count, 1)
        XCTAssertEqual(destBefore?.items.count, 0)
        
        // When: We move the item
        dataRepository.moveItem(item, to: destList)
        
        // Then: Item should be in destination list
        dataManager.loadData()
        let sourceAfter = dataManager.lists.first { $0.id == sourceList.id }
        let destAfter = dataManager.lists.first { $0.id == destList.id }
        XCTAssertEqual(sourceAfter?.items.count, 0, "Item should be removed from source")
        XCTAssertEqual(destAfter?.items.count, 1, "Item should be in destination")
    }
    
    /// Test: Copy item operation completes without errors
    func testCopyItemCompletes() {
        // Given: Two lists, item in first list
        let sourceList = dataRepository.createList(name: "Source")
        let destList = dataRepository.createList(name: "Destination")
        let item = dataRepository.createItem(in: sourceList, title: "Item")
        
        dataManager.loadData()
        let sourceBefore = dataManager.lists.first { $0.id == sourceList.id }
        let destBefore = dataManager.lists.first { $0.id == destList.id }
        XCTAssertEqual(sourceBefore?.items.count, 1)
        XCTAssertEqual(destBefore?.items.count, 0)
        
        // When: We copy the item
        dataRepository.copyItem(item, to: destList)
        
        // Then: Item should be in BOTH lists
        dataManager.loadData()
        let sourceAfter = dataManager.lists.first { $0.id == sourceList.id }
        let destAfter = dataManager.lists.first { $0.id == destList.id }
        XCTAssertEqual(sourceAfter?.items.count, 1, "Item should still be in source")
        XCTAssertEqual(destAfter?.items.count, 1, "Item should be copied to destination")
        
        // And: They should have different IDs
        let sourceItemId = sourceAfter?.items.first?.id
        let destItemId = destAfter?.items.first?.id
        XCTAssertNotEqual(sourceItemId, destItemId, "Copied item should have different ID")
    }
    
    // MARK: - Additional Edge Case Tests
    
    /// Test: Suggested item with nil description works correctly
    func testSuggestedItemWithNilDescription() {
        let sourceList = dataRepository.createList(name: "Source")
        let sourceItem = dataRepository.createItem(in: sourceList, title: "Item", description: "", quantity: 1)
        
        let destList = dataRepository.createList(name: "Dest")
        dataRepository.addExistingItemToList(sourceItem, listId: destList.id)
        
        dataManager.loadData()
        let destListAfter = dataManager.lists.first { $0.id == destList.id }
        XCTAssertEqual(destListAfter?.items.count, 1, "Item should be added")
        XCTAssertNil(destListAfter?.items.first?.itemDescription, "Description should be nil")
    }
    
    /// Test: Multiple reorder operations complete successfully
    func testMultipleReorderOperations() {
        let list = dataRepository.createList(name: "Test")
        _ = dataRepository.createItem(in: list, title: "A")
        _ = dataRepository.createItem(in: list, title: "B")
        _ = dataRepository.createItem(in: list, title: "C")
        _ = dataRepository.createItem(in: list, title: "D")
        
        // Perform multiple reorders
        dataRepository.reorderItems(in: list, from: 0, to: 3)
        dataRepository.reorderItems(in: list, from: 2, to: 1)
        dataRepository.reorderItems(in: list, from: 1, to: 2)
        
        // Verify no crashes and items still exist
        dataManager.loadData()
        let listAfter = dataManager.lists.first { $0.id == list.id }
        XCTAssertEqual(listAfter?.items.count, 4, "All items should still exist")
    }
    
    /// Test: Smart duplicate detection with empty string vs nil description
    func testSmartDuplicateDetectionWithEmptyVsNilDescription() {
        let list = dataRepository.createList(name: "Test")
        
        // Create item with empty description (becomes nil)
        let item1 = dataRepository.createItem(in: list, title: "Item", description: "", quantity: 1)
        dataRepository.toggleItemCrossedOut(item1)
        
        // Try to add with empty description again
        let item2 = dataRepository.createItem(in: list, title: "Item", description: "", quantity: 1)
        
        // Should uncross existing (empty string = nil = same metadata)
        dataManager.loadData()
        let listAfter = dataManager.lists.first { $0.id == list.id }
        XCTAssertEqual(listAfter?.items.count, 1, "Should not create duplicate")
        XCTAssertFalse(listAfter?.items.first?.isCrossedOut ?? true, "Should uncross")
    }
    
    /// Test: Reorder with invalid indices doesn't crash
    func testReorderWithInvalidIndices() {
        let list = dataRepository.createList(name: "Test")
        _ = dataRepository.createItem(in: list, title: "A")
        _ = dataRepository.createItem(in: list, title: "B")
        
        // Try invalid reorders (should be no-ops)
        dataRepository.reorderItems(in: list, from: -1, to: 0)
        dataRepository.reorderItems(in: list, from: 0, to: 10)
        dataRepository.reorderItems(in: list, from: 5, to: 0)
        
        // Should not crash and items should be unchanged
        dataManager.loadData()
        let listAfter = dataManager.lists.first { $0.id == list.id }
        XCTAssertEqual(listAfter?.items.count, 2, "Items should be unchanged")
    }
    
    /// Test: CRITICAL - Suggested item added as UNCROSSED even if source is crossed out
    func testSuggestedItemAddedAsUncrossedEvenIfSourceCrossed() {
        // Given: A source list with a CROSSED OUT item
        let sourceList = dataRepository.createList(name: "Groceries")
        var sourceItem = dataRepository.createItem(
            in: sourceList,
            title: "Milk",
            description: "Already bought",
            quantity: 1
        )
        
        // Cross it out
        dataRepository.toggleItemCrossedOut(sourceItem)
        
        // Verify it's crossed out
        dataManager.loadData()
        let sourceListBefore = dataManager.lists.first { $0.id == sourceList.id }
        let crossedItem = sourceListBefore?.items.first { $0.title == "Milk" }
        XCTAssertTrue(crossedItem?.isCrossedOut ?? false, "Source item should be crossed out")
        
        // And: A destination list (empty)
        let destList = dataRepository.createList(name: "Shopping")
        
        // When: We add the CROSSED OUT item as a suggestion to destination list
        if let itemToAdd = crossedItem {
            dataRepository.addExistingItemToList(itemToAdd, listId: destList.id)
        }
        
        // Then: Item should be added as UNCROSSED (active) to destination
        dataManager.loadData()
        let destListAfter = dataManager.lists.first { $0.id == destList.id }
        XCTAssertEqual(destListAfter?.items.count, 1, "Destination list should have 1 item")
        
        let addedItem = destListAfter?.items.first
        XCTAssertEqual(addedItem?.title, "Milk", "Item should have correct title")
        XCTAssertFalse(addedItem?.isCrossedOut ?? true, "CRITICAL: Suggested item MUST be added as uncrossed (active), not crossed out")
        
        // And: Source item should remain crossed out (unchanged)
        let sourceListAfter = dataManager.lists.first { $0.id == sourceList.id }
        let sourceItemAfter = sourceListAfter?.items.first { $0.title == "Milk" }
        XCTAssertTrue(sourceItemAfter?.isCrossedOut ?? false, "Source item should remain crossed out")
        
        // And: They should have DIFFERENT IDs
        XCTAssertNotEqual(sourceItemAfter?.id, addedItem?.id, "Source and destination items should have different IDs")
    }
}

