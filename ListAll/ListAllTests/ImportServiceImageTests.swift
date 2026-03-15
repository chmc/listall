import XCTest
import UIKit
@testable import ListAll

final class ImportServiceImageTests: XCTestCase {

    // MARK: - Phase 44 Import Image Support Tests

    func testImportFromJSONWithImages() throws {
        let testDataManager = TestHelpers.createTestDataManager()
        let repository = TestDataRepository(dataManager: testDataManager)
        let exportService = ExportService(dataRepository: repository)
        let importService = ImportService(dataRepository: repository)

        // Create test data with an item that has images
        let list = List(name: "Test List")
        testDataManager.addList(list)
        let item = repository.createItem(in: list, title: "Item with Image", description: "Test Description", quantity: 1)

        // Create a simple 1x1 red pixel image
        let imageSize = CGSize(width: 1, height: 1)
        let renderer = UIGraphicsImageRenderer(size: imageSize)
        let testImage = renderer.image { context in
            UIColor.red.setFill()
            context.fill(CGRect(origin: .zero, size: imageSize))
        }

        // Add image to item
        guard let imageData = testImage.jpegData(compressionQuality: 0.8) else {
            XCTFail("Failed to create test image data")
            return
        }
        let _ = repository.addImage(to: item, imageData: imageData)

        // Export with images included
        guard let jsonData = exportService.exportToJSON(options: .default) else {
            XCTFail("Failed to export data to JSON")
            return
        }

        // Clear all data
        testDataManager.deleteList(withId: list.id)

        // Import from JSON
        let result = try importService.importFromJSON(jsonData, options: .default)

        XCTAssertTrue(result.wasSuccessful, "Import should succeed")
        XCTAssertEqual(result.listsCreated, 1, "Should create 1 list")
        XCTAssertEqual(result.itemsCreated, 1, "Should create 1 item")

        // Verify imported item has image
        let importedLists = testDataManager.lists
        XCTAssertEqual(importedLists.count, 1, "Should have 1 list")

        let importedList = importedLists.first!
        let importedItems = testDataManager.getItems(forListId: importedList.id)
        XCTAssertEqual(importedItems.count, 1, "Should have 1 item")

        let importedItem = importedItems.first!
        XCTAssertEqual(importedItem.images.count, 1, "Should have 1 image")
        XCTAssertNotNil(importedItem.images.first?.imageData, "Image should have data")
    }

    func testImportFromJSONWithMultipleImages() throws {
        let testDataManager = TestHelpers.createTestDataManager()
        let repository = TestDataRepository(dataManager: testDataManager)
        let exportService = ExportService(dataRepository: repository)
        let importService = ImportService(dataRepository: repository)

        // Create test data with an item that has multiple images
        let list = List(name: "Test List")
        testDataManager.addList(list)
        let item = repository.createItem(in: list, title: "Item with Multiple Images", description: "", quantity: 1)

        // Add multiple images
        for i in 0..<3 {
            let imageSize = CGSize(width: 1, height: 1)
            let renderer = UIGraphicsImageRenderer(size: imageSize)
            let testImage = renderer.image { context in
                // Use different colors for each image
                let colors: [UIColor] = [.red, .green, .blue]
                colors[i].setFill()
                context.fill(CGRect(origin: .zero, size: imageSize))
            }

            if let imageData = testImage.jpegData(compressionQuality: 0.8) {
                let _ = repository.addImage(to: item, imageData: imageData)
            }
        }

        // Export with images included
        guard let jsonData = exportService.exportToJSON(options: .default) else {
            XCTFail("Failed to export data to JSON")
            return
        }

        // Clear all data
        testDataManager.deleteList(withId: list.id)

        // Import from JSON
        let result = try importService.importFromJSON(jsonData, options: .default)

        XCTAssertTrue(result.wasSuccessful, "Import should succeed")
        XCTAssertEqual(result.listsCreated, 1, "Should create 1 list")
        XCTAssertEqual(result.itemsCreated, 1, "Should create 1 item")

        // Verify imported item has all images
        let importedLists = testDataManager.lists
        let importedList = importedLists.first!
        let importedItems = testDataManager.getItems(forListId: importedList.id)
        let importedItem = importedItems.first!

        XCTAssertEqual(importedItem.images.count, 3, "Should have 3 images")

        // Verify images are sorted by order number
        for i in 0..<importedItem.images.count - 1 {
            XCTAssertLessThan(importedItem.images[i].orderNumber, importedItem.images[i + 1].orderNumber, "Images should be sorted by order number")
        }
    }

    func testImportFromJSONWithoutImages() throws {
        let testDataManager = TestHelpers.createTestDataManager()
        let repository = TestDataRepository(dataManager: testDataManager)
        let exportService = ExportService(dataRepository: repository)
        let importService = ImportService(dataRepository: repository)

        // Create test data with an item that has images
        let list = List(name: "Test List")
        testDataManager.addList(list)
        let item = repository.createItem(in: list, title: "Item with Image", description: "", quantity: 1)

        // Create a simple test image
        let imageSize = CGSize(width: 1, height: 1)
        let renderer = UIGraphicsImageRenderer(size: imageSize)
        let testImage = renderer.image { context in
            UIColor.blue.setFill()
            context.fill(CGRect(origin: .zero, size: imageSize))
        }

        // Add image to item
        guard let imageData = testImage.jpegData(compressionQuality: 0.8) else {
            XCTFail("Failed to create test image data")
            return
        }
        let _ = repository.addImage(to: item, imageData: imageData)

        // Export without images (minimal options)
        guard let jsonData = exportService.exportToJSON(options: .minimal) else {
            XCTFail("Failed to export data to JSON")
            return
        }

        // Clear all data
        testDataManager.deleteList(withId: list.id)

        // Import from JSON
        let result = try importService.importFromJSON(jsonData, options: .default)

        XCTAssertTrue(result.wasSuccessful, "Import should succeed")
        XCTAssertEqual(result.listsCreated, 1, "Should create 1 list")
        XCTAssertEqual(result.itemsCreated, 1, "Should create 1 item")

        // Verify imported item has no images
        let importedLists = testDataManager.lists
        let importedList = importedLists.first!
        let importedItems = testDataManager.getItems(forListId: importedList.id)
        let importedItem = importedItems.first!

        XCTAssertEqual(importedItem.images.count, 0, "Should have 0 images")
    }

    func testImportMergeStrategyWithImages() throws {
        let testDataManager = TestHelpers.createTestDataManager()
        let repository = TestDataRepository(dataManager: testDataManager)
        let exportService = ExportService(dataRepository: repository)
        let importService = ImportService(dataRepository: repository)

        // Create initial data with one image
        let list = List(name: "Test List")
        testDataManager.addList(list)
        let item = repository.createItem(in: list, title: "Item", description: "", quantity: 1)

        // Add first image
        let imageSize = CGSize(width: 1, height: 1)
        let renderer = UIGraphicsImageRenderer(size: imageSize)
        let testImage1 = renderer.image { context in
            UIColor.red.setFill()
            context.fill(CGRect(origin: .zero, size: imageSize))
        }

        guard let imageData1 = testImage1.jpegData(compressionQuality: 0.8) else {
            XCTFail("Failed to create test image data")
            return
        }
        let _ = repository.addImage(to: item, imageData: imageData1)

        // Export current state
        guard let jsonData = exportService.exportToJSON(options: .default) else {
            XCTFail("Failed to export data to JSON")
            return
        }

        // Now add a second image to the item
        let testImage2 = renderer.image { context in
            UIColor.green.setFill()
            context.fill(CGRect(origin: .zero, size: imageSize))
        }

        guard let imageData2 = testImage2.jpegData(compressionQuality: 0.8) else {
            XCTFail("Failed to create test image data")
            return
        }

        // Get the current item from data manager
        let currentItem = testDataManager.getItems(forListId: list.id).first!
        let _ = repository.addImage(to: currentItem, imageData: imageData2)

        // Verify we have 2 images now
        let itemBeforeMerge = testDataManager.getItems(forListId: list.id).first!
        XCTAssertEqual(itemBeforeMerge.images.count, 2, "Should have 2 images before merge")

        // Import with merge strategy (should preserve the second image and update first)
        let result = try importService.importFromJSON(jsonData, options: ImportOptions(mergeStrategy: .merge, validateData: true))

        XCTAssertTrue(result.wasSuccessful, "Import should succeed")
        XCTAssertEqual(result.listsUpdated, 1, "Should update 1 list")
        XCTAssertEqual(result.itemsUpdated, 1, "Should update 1 item")

        // Verify merged item still has both images (1 from import, 1 preserved)
        let mergedItem = testDataManager.getItems(forListId: list.id).first!
        XCTAssertEqual(mergedItem.images.count, 2, "Should have 2 images after merge")
    }

    func testImportReplaceStrategyWithImages() throws {
        let testDataManager = TestHelpers.createTestDataManager()
        let repository = TestDataRepository(dataManager: testDataManager)
        let exportService = ExportService(dataRepository: repository)
        let importService = ImportService(dataRepository: repository)

        // Create test data with images
        let list = List(name: "Test List")
        testDataManager.addList(list)
        let item = repository.createItem(in: list, title: "Item with Image", description: "", quantity: 1)

        // Add image
        let imageSize = CGSize(width: 1, height: 1)
        let renderer = UIGraphicsImageRenderer(size: imageSize)
        let testImage = renderer.image { context in
            UIColor.red.setFill()
            context.fill(CGRect(origin: .zero, size: imageSize))
        }

        guard let imageData = testImage.jpegData(compressionQuality: 0.8) else {
            XCTFail("Failed to create test image data")
            return
        }
        let _ = repository.addImage(to: item, imageData: imageData)

        // Export with images
        guard let jsonData = exportService.exportToJSON(options: .default) else {
            XCTFail("Failed to export data to JSON")
            return
        }

        // Add a different list and item to existing data
        let anotherList = List(name: "Another List")
        testDataManager.addList(anotherList)
        let _ = repository.createItem(in: anotherList, title: "Another Item", description: "", quantity: 1)

        // Import with replace strategy (should delete all and import fresh)
        let result = try importService.importFromJSON(jsonData, options: ImportOptions(mergeStrategy: .replace, validateData: true))

        XCTAssertTrue(result.wasSuccessful, "Import should succeed")
        XCTAssertEqual(result.listsCreated, 1, "Should create 1 list")
        XCTAssertEqual(result.itemsCreated, 1, "Should create 1 item")

        // Verify only imported data exists
        let finalLists = testDataManager.lists
        XCTAssertEqual(finalLists.count, 1, "Should have only 1 list")
        XCTAssertEqual(finalLists.first?.name, "Test List", "Should be the imported list")

        // Verify image is present
        let finalItem = testDataManager.getItems(forListId: finalLists.first!.id).first!
        XCTAssertEqual(finalItem.images.count, 1, "Should have 1 image")
    }

    func testImportAppendStrategyWithImages() throws {
        let testDataManager = TestHelpers.createTestDataManager()
        let repository = TestDataRepository(dataManager: testDataManager)
        let exportService = ExportService(dataRepository: repository)
        let importService = ImportService(dataRepository: repository)

        // Create test data with images
        let list = List(name: "Test List")
        testDataManager.addList(list)
        let item = repository.createItem(in: list, title: "Item with Image", description: "", quantity: 1)

        // Add image
        let imageSize = CGSize(width: 1, height: 1)
        let renderer = UIGraphicsImageRenderer(size: imageSize)
        let testImage = renderer.image { context in
            UIColor.red.setFill()
            context.fill(CGRect(origin: .zero, size: imageSize))
        }

        guard let imageData = testImage.jpegData(compressionQuality: 0.8) else {
            XCTFail("Failed to create test image data")
            return
        }
        let _ = repository.addImage(to: item, imageData: imageData)

        // Export with images
        guard let jsonData = exportService.exportToJSON(options: .default) else {
            XCTFail("Failed to export data to JSON")
            return
        }

        // Import with append strategy (should create duplicates)
        let result = try importService.importFromJSON(jsonData, options: ImportOptions(mergeStrategy: .append, validateData: true))

        XCTAssertTrue(result.wasSuccessful, "Import should succeed")
        XCTAssertEqual(result.listsCreated, 1, "Should create 1 new list")
        XCTAssertEqual(result.itemsCreated, 1, "Should create 1 new item")

        // Verify we have duplicates
        let allLists = testDataManager.lists
        XCTAssertEqual(allLists.count, 2, "Should have 2 lists (original + appended)")

        // Verify both items have images
        var itemsWithImages = 0
        for list in allLists {
            let items = testDataManager.getItems(forListId: list.id)
            for item in items {
                if item.images.count > 0 {
                    itemsWithImages += 1
                }
            }
        }
        XCTAssertEqual(itemsWithImages, 2, "Both items should have images")
    }

    func testImportItemImageOrderPreserved() throws {
        let testDataManager = TestHelpers.createTestDataManager()
        let repository = TestDataRepository(dataManager: testDataManager)
        let exportService = ExportService(dataRepository: repository)
        let importService = ImportService(dataRepository: repository)

        // Create test data with multiple images
        let list = List(name: "Test List")
        testDataManager.addList(list)
        let item = repository.createItem(in: list, title: "Item", description: "", quantity: 1)

        // Add images with specific order
        let colors: [UIColor] = [.red, .green, .blue, .yellow]
        for color in colors {
            let imageSize = CGSize(width: 1, height: 1)
            let renderer = UIGraphicsImageRenderer(size: imageSize)
            let testImage = renderer.image { context in
                color.setFill()
                context.fill(CGRect(origin: .zero, size: imageSize))
            }

            if let imageData = testImage.jpegData(compressionQuality: 0.8) {
                let _ = repository.addImage(to: item, imageData: imageData)
            }
        }

        // Get original item with images
        let originalItem = testDataManager.getItems(forListId: list.id).first!
        XCTAssertEqual(originalItem.images.count, 4, "Should have 4 images")

        // Store original order
        let originalImageIds = originalItem.images.map { $0.id }

        // Export and import
        guard let jsonData = exportService.exportToJSON(options: .default) else {
            XCTFail("Failed to export data to JSON")
            return
        }

        testDataManager.deleteList(withId: list.id)

        let result = try importService.importFromJSON(jsonData, options: .default)

        XCTAssertTrue(result.wasSuccessful, "Import should succeed")

        // Verify image order is preserved
        let importedItem = testDataManager.getItems(forListId: testDataManager.lists.first!.id).first!
        XCTAssertEqual(importedItem.images.count, 4, "Should have 4 images")

        let importedImageIds = importedItem.images.map { $0.id }
        XCTAssertEqual(importedImageIds, originalImageIds, "Image order should be preserved")

        // Verify order numbers are correct
        for (index, image) in importedItem.images.enumerated() {
            XCTAssertEqual(image.orderNumber, index, "Image order number should match index")
        }
    }
}
