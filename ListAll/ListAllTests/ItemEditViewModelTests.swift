import XCTest
@testable import ListAll

final class ItemEditViewModelTests: XCTestCase {
    
    @MainActor
    func testApplyingSuggestionCreatesDeepCopiedImages() async {
        // Arrange
        let testDataManager = TestHelpers.createTestDataManager()
        let repo = TestDataRepository(dataManager: testDataManager)
        
        let listA = repo.createList(name: "List A")
        let listB = repo.createList(name: "List B")
        
        // Create item with image in list A
        var itemInListA = repo.createItem(in: listA, title: "Test Item", description: "Test Description", quantity: 1)
        let imageData = UIImage(systemName: "star")!.pngData()!
        let originalImage = repo.addImage(to: itemInListA, imageData: imageData)
        
        // Refresh item to get the image
        guard let storedItem = repo.getItem(by: itemInListA.id) else {
            XCTFail("Item should exist in database")
            return
        }
        
        XCTAssertEqual(storedItem.images.count, 1, "Original item should have 1 image")
        
        // Create suggestion from the item
        let suggestion = ItemSuggestion(
            id: storedItem.id,
            title: storedItem.title,
            description: storedItem.itemDescription,
            quantity: storedItem.quantity,
            images: storedItem.images,
            frequency: 1,
            lastUsed: Date(),
            score: 1.0,
            recencyScore: 1.0,
            frequencyScore: 1.0,
            totalOccurrences: 1,
            averageUsageGap: 0
        )
        
        // Act
        let vm = ItemEditViewModel(list: listB, item: nil, dataRepository: repo)
        vm.applySuggestion(suggestion)
        
        // Assert
        XCTAssertEqual(vm.images.count, 1, "View model should have 1 deep-copied image")
        
        let copiedImage = vm.images.first!
        XCTAssertNotEqual(copiedImage.id, originalImage.id, "Image should have new ID")
        XCTAssertEqual(copiedImage.imageData, originalImage.imageData, "Image data should be same")
        XCTAssertNil(copiedImage.itemId, "Copied image should have nil itemId until saved")
    }
    
    @MainActor
    func testAddingExistingSuggestionToNewListCreatesNewItem() async {
        // Arrange
        let testDataManager = TestHelpers.createTestDataManager()
        let repo = TestDataRepository(dataManager: testDataManager)
        
        let listA = repo.createList(name: "List A")
        let listB = repo.createList(name: "List B")
        
        // Create item with image in list A
        let itemInListA = repo.createItem(in: listA, title: "Milk", description: "2L", quantity: 2)
        let imageData = UIImage(systemName: "star")!.pngData()!
        _ = repo.addImage(to: itemInListA, imageData: imageData)
        
        // Refresh item to get the image
        guard let storedItem = repo.getItem(by: itemInListA.id) else {
            XCTFail("Item should exist in database")
            return
        }
        
        XCTAssertEqual(storedItem.images.count, 1, "Item should have 1 image before suggestion")
        
        let suggestion = ItemSuggestion(
            id: storedItem.id,
            title: storedItem.title,
            description: storedItem.itemDescription,
            quantity: storedItem.quantity,
            images: storedItem.images,
            frequency: 1,
            lastUsed: Date(),
            score: 1.0,
            recencyScore: 1.0,
            frequencyScore: 1.0,
            totalOccurrences: 1,
            averageUsageGap: 0
        )
        
        // Act
        let vm = ItemEditViewModel(list: listB, item: nil, dataRepository: repo)
        vm.applySuggestion(suggestion)
        
        // Verify suggestion was applied to view model
        XCTAssertEqual(vm.title, "Milk", "View model should have suggestion title")
        XCTAssertEqual(vm.images.count, 1, "View model should have deep-copied image")
        
        // Save the suggestion
        await vm.save()
        
        // Assert
        let itemsInListB = testDataManager.getItems(forListId: listB.id)
        XCTAssertEqual(itemsInListB.count, 1, "List B should have 1 item")
        
        guard let copiedItem = itemsInListB.first else {
            XCTFail("Should have an item in list B")
            return
        }
        
        XCTAssertEqual(copiedItem.title, "Milk", "Copied item should have same title")
        XCTAssertNotEqual(copiedItem.id, storedItem.id, "Copied item should have different ID")
        XCTAssertEqual(copiedItem.quantity, 2, "Copied item should have same quantity")
        
        // Verify images were deep-copied with new IDs
        XCTAssertEqual(copiedItem.images.count, 1, "Copied item should have 1 image")
        
        if let copiedImage = copiedItem.images.first,
           let originalImage = storedItem.images.first {
            XCTAssertNotEqual(copiedImage.id, originalImage.id, "Copied image should have different ID")
            XCTAssertEqual(copiedImage.imageData, originalImage.imageData, "Copied image should have same data")
        } else {
            XCTFail("Should have images")
        }
        
        // Verify original item is unchanged
        guard let originalItem = repo.getItem(by: storedItem.id) else {
            XCTFail("Original item should still exist")
            return
        }
        XCTAssertEqual(originalItem.images.count, 1, "Original item should still have 1 image")
    }
    
    @MainActor
    func testModifyingSuggestionCreatesNewItemInsteadOfCopy() async {
        // Arrange
        let testDataManager = TestHelpers.createTestDataManager()
        let repo = TestDataRepository(dataManager: testDataManager)
        
        let listA = repo.createList(name: "List A")
        let listB = repo.createList(name: "List B")
        
        let itemInListA = repo.createItem(in: listA, title: "Bread", description: "White", quantity: 1)
        
        guard let storedItem = repo.getItem(by: itemInListA.id) else {
            XCTFail("Item should exist in database")
            return
        }
        
        let suggestion = ItemSuggestion(
            id: storedItem.id,
            title: storedItem.title,
            description: storedItem.itemDescription,
            quantity: storedItem.quantity,
            images: storedItem.images,
            frequency: 1,
            lastUsed: Date(),
            score: 1.0,
            recencyScore: 1.0,
            frequencyScore: 1.0,
            totalOccurrences: 1,
            averageUsageGap: 0
        )
        
        // Act
        let vm = ItemEditViewModel(list: listB, item: nil, dataRepository: repo)
        vm.applySuggestion(suggestion)
        
        // Modify the suggestion
        vm.description = "Whole Wheat" // Changed from "White"
        
        await vm.save()
        
        // Assert
        let itemsInListB = testDataManager.getItems(forListId: listB.id)
        XCTAssertEqual(itemsInListB.count, 1, "List B should have 1 item")
        
        let newItem = itemsInListB.first!
        XCTAssertEqual(newItem.title, "Bread", "New item should have same title")
        XCTAssertEqual(newItem.itemDescription, "Whole Wheat", "New item should have modified description")
        XCTAssertNotEqual(newItem.id, storedItem.id, "New item should have different ID from original")
        
        // Verify it's a completely new item, not a copy of the existing item
        let itemsInListA = testDataManager.getItems(forListId: listA.id)
        XCTAssertEqual(itemsInListA.count, 1, "List A should still have 1 item")
        XCTAssertEqual(itemsInListA.first!.itemDescription, "White", "Original item description unchanged")
    }
}
