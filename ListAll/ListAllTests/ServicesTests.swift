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
    
    func testPlaceholder() throws {
        // Placeholder test to ensure the test suite compiles
        XCTAssertTrue(true)
    }
}
