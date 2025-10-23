import XCTest
@testable import ListAll

class WatchConnectivitySyncTests: XCTestCase {
    
    func testListSyncDataExcludesImages() {
        // Create a list with items that have images
        var list = List(name: "Test List")
        
        // Add items with images
        for i in 1...5 {
            var item = Item(title: "Item \(i)", listId: list.id)
            
            // Add large images to items
            for j in 1...3 {
                let imageData = Data(repeating: 0xFF, count: 100_000) // 100KB per image
                var itemImage = ItemImage(imageData: imageData, itemId: item.id)
                itemImage.orderNumber = j
                item.images.append(itemImage)
            }
            
            list.items.append(item)
        }
        
        // Full list with images should be large
        let encoder = JSONEncoder()
        let fullData = try! encoder.encode(list)
        let fullSizeKB = Double(fullData.count) / 1024.0
        print("Full list data size: \(String(format: "%.2f", fullSizeKB)) KB")
        
        // List with images should be > 1MB
        XCTAssertGreaterThan(fullSizeKB, 1000.0, "Full list should be > 1MB")
        
        // Convert to sync data (should exclude images)
        let syncData = ListSyncData(from: list)
        let syncJsonData = try! encoder.encode(syncData)
        let syncSizeKB = Double(syncJsonData.count) / 1024.0
        print("Sync data size: \(String(format: "%.2f", syncSizeKB)) KB")
        
        // Sync data should be much smaller (< 10KB for metadata only)
        XCTAssertLessThan(syncSizeKB, 10.0, "Sync data should be < 10KB")
        
        // Verify sync data maintains all metadata
        XCTAssertEqual(syncData.id, list.id)
        XCTAssertEqual(syncData.name, list.name)
        XCTAssertEqual(syncData.items.count, list.items.count)
        
        // Verify items have imageCount but no image data
        for (i, syncItem) in syncData.items.enumerated() {
            XCTAssertEqual(syncItem.id, list.items[i].id)
            XCTAssertEqual(syncItem.title, list.items[i].title)
            XCTAssertEqual(syncItem.imageCount, list.items[i].images.count)
        }
    }
    
    func testListSyncDataRoundTrip() {
        // Create a list with items
        var list = List(name: "Round Trip Test")
        list.orderNumber = 5
        list.isArchived = false
        
        var item1 = Item(title: "Item 1", listId: list.id)
        item1.itemDescription = "Test description"
        item1.quantity = 3
        item1.isCrossedOut = true
        list.items.append(item1)
        
        var item2 = Item(title: "Item 2", listId: list.id)
        item2.quantity = 1
        item2.isCrossedOut = false
        list.items.append(item2)
        
        // Convert to sync data and back
        let syncData = ListSyncData(from: list)
        let restoredList = syncData.toList()
        
        // Verify all metadata is preserved
        XCTAssertEqual(restoredList.id, list.id)
        XCTAssertEqual(restoredList.name, list.name)
        XCTAssertEqual(restoredList.orderNumber, list.orderNumber)
        XCTAssertEqual(restoredList.isArchived, list.isArchived)
        XCTAssertEqual(restoredList.items.count, list.items.count)
        
        // Verify item metadata
        XCTAssertEqual(restoredList.items[0].id, item1.id)
        XCTAssertEqual(restoredList.items[0].title, item1.title)
        XCTAssertEqual(restoredList.items[0].itemDescription, item1.itemDescription)
        XCTAssertEqual(restoredList.items[0].quantity, item1.quantity)
        XCTAssertEqual(restoredList.items[0].isCrossedOut, item1.isCrossedOut)
        
        XCTAssertEqual(restoredList.items[1].id, item2.id)
        XCTAssertEqual(restoredList.items[1].title, item2.title)
        XCTAssertEqual(restoredList.items[1].quantity, item2.quantity)
        XCTAssertEqual(restoredList.items[1].isCrossedOut, item2.isCrossedOut)
        
        // Verify images are empty (as expected for sync data)
        XCTAssertEqual(restoredList.items[0].images.count, 0)
        XCTAssertEqual(restoredList.items[1].images.count, 0)
    }
    
    func testMultipleListsSyncDataSize() {
        // Create 7 lists (like user's actual data)
        var lists: [List] = []
        for i in 1...7 {
            var list = List(name: "List \(i)")
            
            // Add 30 items per list
            for j in 1...30 {
                var item = Item(title: "Item \(j)", listId: list.id)
                item.itemDescription = "Description for item \(j) in list \(i)"
                item.quantity = j % 5 + 1
                
                // Add images (simulating realistic data)
                for k in 1...2 {
                    let imageData = Data(repeating: 0xFF, count: 50_000) // 50KB per image
                    let itemImage = ItemImage(imageData: imageData, itemId: item.id)
                    item.images.append(itemImage)
                }
                
                list.items.append(item)
            }
            lists.append(list)
        }
        
        // Test full data size
        let encoder = JSONEncoder()
        let fullData = try! encoder.encode(lists)
        let fullSizeKB = Double(fullData.count) / 1024.0
        print("Full 7 lists with images: \(String(format: "%.2f", fullSizeKB)) KB")
        
        // Should be several MB
        XCTAssertGreaterThan(fullSizeKB, 2000.0, "Full data should be > 2MB")
        
        // Convert to sync data
        let syncData = lists.map { ListSyncData(from: $0) }
        let syncJsonData = try! encoder.encode(syncData)
        let syncSizeKB = Double(syncJsonData.count) / 1024.0
        print("Sync data for 7 lists (no images): \(String(format: "%.2f", syncSizeKB)) KB")
        
        // Sync data should be under 256KB limit
        XCTAssertLessThan(syncSizeKB, 256.0, "Sync data should be < 256KB for WatchConnectivity")
        
        // Should be a significant reduction
        let reductionPercent = ((fullSizeKB - syncSizeKB) / fullSizeKB) * 100.0
        print("Size reduction: \(String(format: "%.1f", reductionPercent))%")
        XCTAssertGreaterThan(reductionPercent, 90.0, "Should reduce size by > 90%")
    }
}

