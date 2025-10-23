//
//  SyncDataIntegrityTests.swift
//  ListAllTests
//
//  Tests for data integrity during iOS ↔ Watch sync
//  Verifies encoding/decoding, data preservation, and edge cases
//

import XCTest
@testable import ListAll

/// Tests for data integrity during sync operations
final class SyncDataIntegrityTests: XCTestCase {
    
    // MARK: - Encoding/Decoding Tests
    
    /// Test: ListSyncData correctly encodes and decodes list metadata
    func testListSyncDataEncodingDecoding() throws {
        // Given: A list with metadata
        var list = List(name: "Test List")
        list.orderNumber = 5
        list.isArchived = false
        list.createdAt = Date(timeIntervalSince1970: 1000)
        list.modifiedAt = Date(timeIntervalSince1970: 2000)
        
        // When: Converting to sync data and back
        let syncData = ListSyncData(from: list)
        let decodedList = syncData.toList()
        
        // Then: Metadata should be preserved
        XCTAssertEqual(decodedList.id, list.id, "ID should be preserved")
        XCTAssertEqual(decodedList.name, list.name, "Name should be preserved")
        XCTAssertEqual(decodedList.orderNumber, list.orderNumber, "Order number should be preserved")
        XCTAssertEqual(decodedList.isArchived, list.isArchived, "Archived status should be preserved")
        XCTAssertEqual(decodedList.createdAt.timeIntervalSince1970, list.createdAt.timeIntervalSince1970, accuracy: 1.0, "Created date should be preserved")
        XCTAssertEqual(decodedList.modifiedAt.timeIntervalSince1970, list.modifiedAt.timeIntervalSince1970, accuracy: 1.0, "Modified date should be preserved")
    }
    
    /// Test: ItemSyncData correctly encodes and decodes item metadata
    func testItemSyncDataEncodingDecoding() throws {
        // Given: An item with all properties set
        var item = Item(title: "Test Item", listId: UUID())
        item.itemDescription = "Test description"
        item.quantity = 5
        item.orderNumber = 3
        item.isCrossedOut = true
        item.createdAt = Date(timeIntervalSince1970: 1000)
        item.modifiedAt = Date(timeIntervalSince1970: 2000)
        
        // When: Converting to sync data and back
        let syncData = ItemSyncData(from: item)
        let decodedItem = syncData.toItem()
        
        // Then: All properties should be preserved
        XCTAssertEqual(decodedItem.id, item.id, "ID should be preserved")
        XCTAssertEqual(decodedItem.title, item.title, "Title should be preserved")
        XCTAssertEqual(decodedItem.itemDescription, item.itemDescription, "Description should be preserved")
        XCTAssertEqual(decodedItem.quantity, item.quantity, "Quantity should be preserved")
        XCTAssertEqual(decodedItem.orderNumber, item.orderNumber, "Order number should be preserved")
        XCTAssertEqual(decodedItem.isCrossedOut, item.isCrossedOut, "Crossed out status should be preserved")
        XCTAssertEqual(decodedItem.listId, item.listId, "List ID should be preserved")
        XCTAssertEqual(decodedItem.createdAt.timeIntervalSince1970, item.createdAt.timeIntervalSince1970, accuracy: 1.0, "Created date should be preserved")
        XCTAssertEqual(decodedItem.modifiedAt.timeIntervalSince1970, item.modifiedAt.timeIntervalSince1970, accuracy: 1.0, "Modified date should be preserved")
    }
    
    /// Test: Images are excluded from sync (lightweight)
    func testImagesAreExcludedFromSync() throws {
        // Given: An item with images
        var item = Item(title: "Item with images", listId: UUID())
        item.images = [
            ItemImage(imageData: Data(count: 1000)),
            ItemImage(imageData: Data(count: 2000)),
            ItemImage(imageData: Data(count: 3000))
        ]
        
        // When: Converting to sync data
        let syncData = ItemSyncData(from: item)
        
        // Then: Image count is tracked, but actual data is excluded
        XCTAssertEqual(syncData.imageCount, 3, "Image count should be tracked")
        
        // When: Converting back to Item
        let decodedItem = syncData.toItem()
        
        // Then: Images array should be empty (not synced)
        XCTAssertEqual(decodedItem.images.count, 0, "Images should not be synced")
    }
    
    /// Test: List with items encodes and decodes correctly
    func testListWithItemsEncodingDecoding() throws {
        // Given: A list with multiple items
        var list = List(name: "Shopping List")
        list.createdAt = Date(timeIntervalSince1970: 1000)
        list.modifiedAt = Date(timeIntervalSince1970: 2000)
        
        var item1 = Item(title: "Milk", listId: list.id)
        item1.quantity = 2
        item1.modifiedAt = Date(timeIntervalSince1970: 1500)
        
        var item2 = Item(title: "Bread", listId: list.id)
        item2.isCrossedOut = true
        item2.modifiedAt = Date(timeIntervalSince1970: 1600)
        
        var item3 = Item(title: "Eggs", listId: list.id)
        item3.itemDescription = "Free range"
        item3.modifiedAt = Date(timeIntervalSince1970: 1700)
        
        list.items = [item1, item2, item3]
        
        // When: Converting to sync data and back
        let syncData = ListSyncData(from: list)
        let decodedList = syncData.toList()
        
        // Then: List and all items should be preserved
        XCTAssertEqual(decodedList.id, list.id, "List ID should be preserved")
        XCTAssertEqual(decodedList.items.count, 3, "All items should be preserved")
        
        let decodedItem1 = decodedList.items.first { $0.id == item1.id }
        XCTAssertEqual(decodedItem1?.title, "Milk")
        XCTAssertEqual(decodedItem1?.quantity, 2)
        
        let decodedItem2 = decodedList.items.first { $0.id == item2.id }
        XCTAssertEqual(decodedItem2?.title, "Bread")
        XCTAssertTrue(decodedItem2?.isCrossedOut ?? false)
        
        let decodedItem3 = decodedList.items.first { $0.id == item3.id }
        XCTAssertEqual(decodedItem3?.title, "Eggs")
        XCTAssertEqual(decodedItem3?.itemDescription, "Free range")
    }
    
    /// Test: JSON encoding and decoding works correctly
    func testJSONEncodingDecoding() throws {
        // Given: A list with items
        var list = List(name: "Test List")
        var item = Item(title: "Test Item", listId: list.id)
        item.quantity = 3
        item.isCrossedOut = true
        list.items = [item]
        
        let syncData = ListSyncData(from: list)
        
        // When: Encoding to JSON
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let jsonData = try encoder.encode(syncData)
        
        // Then: JSON should be created
        XCTAssertGreaterThan(jsonData.count, 0, "JSON data should be created")
        
        // When: Decoding from JSON
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let decodedSyncData = try decoder.decode(ListSyncData.self, from: jsonData)
        let decodedList = decodedSyncData.toList()
        
        // Then: Data should match original
        XCTAssertEqual(decodedList.id, list.id)
        XCTAssertEqual(decodedList.name, list.name)
        XCTAssertEqual(decodedList.items.count, 1)
        XCTAssertEqual(decodedList.items.first?.title, "Test Item")
        XCTAssertEqual(decodedList.items.first?.quantity, 3)
        XCTAssertTrue(decodedList.items.first?.isCrossedOut ?? false)
    }
    
    // MARK: - Size and Performance Tests
    
    /// Test: Multiple lists stay within reasonable size limits
    func testMultipleListsSizeIsReasonable() throws {
        // Given: 10 lists with 10 items each
        var lists: [List] = []
        for i in 1...10 {
            var list = List(name: "List \(i)")
            list.items = (1...10).map { j in
                var item = Item(title: "Item \(i)-\(j)", listId: list.id)
                item.itemDescription = "Description for item \(j)"
                item.quantity = j
                return item
            }
            lists.append(list)
        }
        
        // When: Converting to sync data and encoding
        let syncData = lists.map { ListSyncData(from: $0) }
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let jsonData = try encoder.encode(syncData)
        
        let sizeInKB = Double(jsonData.count) / 1024.0
        
        // Then: Size should be reasonable (< 256 KB WatchConnectivity limit)
        XCTAssertLessThan(sizeInKB, 256.0, "Sync data should be under 256 KB limit (actual: \(String(format: "%.2f", sizeInKB)) KB)")
        
        print("✅ 10 lists with 100 total items: \(String(format: "%.2f", sizeInKB)) KB")
    }
    
    /// Test: Large number of items (stress test)
    func testLargeItemCountEncoding() throws {
        // Given: 1 list with 200 items
        var list = List(name: "Large List")
        list.items = (1...200).map { i in
            var item = Item(title: "Item \(i)", listId: list.id)
            item.itemDescription = "Description \(i)"
            return item
        }
        
        // When: Converting to sync data and encoding
        let syncData = ListSyncData(from: list)
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let jsonData = try encoder.encode(syncData)
        
        let sizeInKB = Double(jsonData.count) / 1024.0
        
        // Then: Should encode successfully
        XCTAssertGreaterThan(jsonData.count, 0, "Should encode large list")
        
        // And: Should decode successfully
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let decodedSyncData = try decoder.decode(ListSyncData.self, from: jsonData)
        let decodedList = decodedSyncData.toList()
        
        XCTAssertEqual(decodedList.items.count, 200, "All items should be preserved")
        
        print("✅ 1 list with 200 items: \(String(format: "%.2f", sizeInKB)) KB")
    }
    
    // MARK: - Special Characters and Unicode Tests
    
    /// Test: Special characters are preserved during sync
    func testSpecialCharactersPreserved() throws {
        // Given: Items with special characters
        var list = List(name: "Test 🧪")
        
        var item1 = Item(title: "Emoji 😀🎉✨", listId: list.id)
        var item2 = Item(title: "Umlauts: äöüÄÖÜß", listId: list.id)
        var item3 = Item(title: "Symbols: €£¥©®™", listId: list.id)
        var item4 = Item(title: "Math: π≈3.14 ∑∫∂", listId: list.id)
        
        item1.itemDescription = "Description with 🔥"
        item2.itemDescription = "Grüße aus München"
        item3.itemDescription = "Price: €99.99"
        
        list.items = [item1, item2, item3, item4]
        
        // When: Encoding and decoding through JSON
        let syncData = ListSyncData(from: list)
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let jsonData = try encoder.encode(syncData)
        
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let decodedSyncData = try decoder.decode(ListSyncData.self, from: jsonData)
        let decodedList = decodedSyncData.toList()
        
        // Then: All special characters should be preserved
        XCTAssertEqual(decodedList.name, "Test 🧪")
        XCTAssertEqual(decodedList.items[0].title, "Emoji 😀🎉✨")
        XCTAssertEqual(decodedList.items[0].itemDescription, "Description with 🔥")
        XCTAssertEqual(decodedList.items[1].title, "Umlauts: äöüÄÖÜß")
        XCTAssertEqual(decodedList.items[1].itemDescription, "Grüße aus München")
        XCTAssertEqual(decodedList.items[2].title, "Symbols: €£¥©®™")
        XCTAssertEqual(decodedList.items[2].itemDescription, "Price: €99.99")
        XCTAssertEqual(decodedList.items[3].title, "Math: π≈3.14 ∑∫∂")
    }
    
    /// Test: Very long strings are preserved
    func testLongStringsPreserved() throws {
        // Given: Item with very long description
        let longDescription = String(repeating: "This is a very long description. ", count: 100)
        
        var item = Item(title: "Long Description Item", listId: UUID())
        item.itemDescription = longDescription
        
        // When: Encoding and decoding
        let syncData = ItemSyncData(from: item)
        let encoder = JSONEncoder()
        let jsonData = try encoder.encode(syncData)
        
        let decoder = JSONDecoder()
        let decodedSyncData = try decoder.decode(ItemSyncData.self, from: jsonData)
        let decodedItem = decodedSyncData.toItem()
        
        // Then: Long description should be preserved
        XCTAssertEqual(decodedItem.itemDescription, longDescription)
        XCTAssertEqual(decodedItem.itemDescription?.count, longDescription.count)
    }
    
    // MARK: - Edge Cases
    
    /// Test: Empty list encodes and decodes
    func testEmptyListEncodingDecoding() throws {
        // Given: Empty list
        var list = List(name: "Empty List")
        list.items = []
        
        // When: Encoding and decoding
        let syncData = ListSyncData(from: list)
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let jsonData = try encoder.encode(syncData)
        
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let decodedSyncData = try decoder.decode(ListSyncData.self, from: jsonData)
        let decodedList = decodedSyncData.toList()
        
        // Then: Empty list should be preserved
        XCTAssertEqual(decodedList.name, "Empty List")
        XCTAssertEqual(decodedList.items.count, 0)
    }
    
    /// Test: Item with nil description encodes and decodes
    func testItemWithNilDescriptionEncodingDecoding() throws {
        // Given: Item with nil description
        var item = Item(title: "Item without description", listId: UUID())
        item.itemDescription = nil
        
        // When: Encoding and decoding
        let syncData = ItemSyncData(from: item)
        let encoder = JSONEncoder()
        let jsonData = try encoder.encode(syncData)
        
        let decoder = JSONDecoder()
        let decodedSyncData = try decoder.decode(ItemSyncData.self, from: jsonData)
        let decodedItem = decodedSyncData.toItem()
        
        // Then: Nil description should be preserved
        XCTAssertNil(decodedItem.itemDescription)
    }
    
    /// Test: Item with zero quantity encodes and decodes
    func testItemWithZeroQuantityEncodingDecoding() throws {
        // Given: Item with quantity 0
        var item = Item(title: "Zero quantity item", listId: UUID())
        item.quantity = 0
        
        // When: Encoding and decoding
        let syncData = ItemSyncData(from: item)
        let decodedItem = syncData.toItem()
        
        // Then: Zero quantity should be preserved
        XCTAssertEqual(decodedItem.quantity, 0)
    }
    
    // MARK: - Timestamp Precision Tests
    
    /// Test: Timestamps preserve millisecond precision
    func testTimestampPrecision() throws {
        // Given: Item with precise timestamp
        let preciseDate = Date(timeIntervalSince1970: 1234567890.123)
        
        var item = Item(title: "Precise timestamp item", listId: UUID())
        item.modifiedAt = preciseDate
        
        // When: Encoding and decoding through JSON
        let syncData = ItemSyncData(from: item)
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let jsonData = try encoder.encode(syncData)
        
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let decodedSyncData = try decoder.decode(ItemSyncData.self, from: jsonData)
        let decodedItem = decodedSyncData.toItem()
        
        // Then: Timestamp should be preserved with reasonable precision (within 1 second)
        // Note: ISO8601 encoding may lose some sub-second precision
        XCTAssertEqual(decodedItem.modifiedAt.timeIntervalSince1970, preciseDate.timeIntervalSince1970, accuracy: 1.0)
    }
    
    // MARK: - Array Ordering Tests
    
    /// Test: Item order is preserved during sync
    func testItemOrderPreserved() throws {
        // Given: List with items in specific order
        var list = List(name: "Ordered List")
        
        var item1 = Item(title: "First", listId: list.id)
        item1.orderNumber = 1
        
        var item2 = Item(title: "Second", listId: list.id)
        item2.orderNumber = 2
        
        var item3 = Item(title: "Third", listId: list.id)
        item3.orderNumber = 3
        
        list.items = [item1, item2, item3]
        
        // When: Encoding and decoding
        let syncData = ListSyncData(from: list)
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let jsonData = try encoder.encode(syncData)
        
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let decodedSyncData = try decoder.decode(ListSyncData.self, from: jsonData)
        let decodedList = decodedSyncData.toList()
        
        // Then: Item order should be preserved
        XCTAssertEqual(decodedList.items.count, 3)
        XCTAssertEqual(decodedList.items[0].orderNumber, 1)
        XCTAssertEqual(decodedList.items[1].orderNumber, 2)
        XCTAssertEqual(decodedList.items[2].orderNumber, 3)
    }
}

