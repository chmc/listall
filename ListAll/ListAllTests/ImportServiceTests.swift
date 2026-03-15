import XCTest
import UIKit
@testable import ListAll

final class ImportServiceTests: XCTestCase {

    // MARK: - Phase 27 ImportService Tests

    func testImportServiceInitialization() throws {
        let importService = ImportService()
        XCTAssertNotNil(importService, "ImportService should initialize successfully")
    }

    func testImportFromJSONBasic() throws {
        let testDataManager = TestHelpers.createTestDataManager()
        let repository = TestDataRepository(dataManager: testDataManager)
        let exportService = ExportService(dataRepository: repository)
        let importService = ImportService(dataRepository: repository)

        // Create test data and export it
        let list = List(name: "Test List")
        testDataManager.addList(list)
        let _ = repository.createItem(in: list, title: "Test Item", description: "Test Description", quantity: 2)

        let jsonData = exportService.exportToJSON()
        XCTAssertNotNil(jsonData, "Should export data")

        // Clear data
        testDataManager.clearAll()
        XCTAssertEqual(testDataManager.lists.count, 0, "Data should be cleared")

        // Import data
        let result = try importService.importFromJSON(jsonData!)
        XCTAssertTrue(result.wasSuccessful, "Import should succeed")
        XCTAssertEqual(result.listsCreated, 1, "Should create one list")
        XCTAssertEqual(result.itemsCreated, 1, "Should create one item")

        // Verify imported data
        let importedLists = testDataManager.lists
        XCTAssertEqual(importedLists.count, 1, "Should have one list")
        XCTAssertEqual(importedLists.first?.name, "Test List", "Should preserve list name")

        let importedItems = testDataManager.getItems(forListId: importedLists.first!.id)
        XCTAssertEqual(importedItems.count, 1, "Should have one item")
        XCTAssertEqual(importedItems.first?.title, "Test Item", "Should preserve item title")
        XCTAssertEqual(importedItems.first?.itemDescription, "Test Description", "Should preserve item description")
        XCTAssertEqual(importedItems.first?.quantity, 2, "Should preserve item quantity")
    }

    func testImportFromJSONMultipleLists() throws {
        let testDataManager = TestHelpers.createTestDataManager()
        let repository = TestDataRepository(dataManager: testDataManager)
        let exportService = ExportService(dataRepository: repository)
        let importService = ImportService(dataRepository: repository)

        // Create multiple lists with items
        let list1 = List(name: "Grocery List")
        let list2 = List(name: "Todo List")
        testDataManager.addList(list1)
        testDataManager.addList(list2)

        let _ = repository.createItem(in: list1, title: "Milk", description: "2% low fat", quantity: 1)
        let _ = repository.createItem(in: list1, title: "Bread", description: "Whole wheat", quantity: 2)
        let _ = repository.createItem(in: list2, title: "Buy groceries", description: "", quantity: 1)

        // Export
        let jsonData = exportService.exportToJSON()
        XCTAssertNotNil(jsonData, "Should export data")

        // Clear and import
        testDataManager.clearAll()
        let result = try importService.importFromJSON(jsonData!)

        XCTAssertTrue(result.wasSuccessful, "Import should succeed")
        XCTAssertEqual(result.listsCreated, 2, "Should create two lists")
        XCTAssertEqual(result.itemsCreated, 3, "Should create three items")

        // Verify imported data
        XCTAssertEqual(testDataManager.lists.count, 2, "Should have two lists")

        let importedGroceryList = testDataManager.lists.first { $0.name == "Grocery List" }
        XCTAssertNotNil(importedGroceryList, "Should find Grocery List")
        XCTAssertEqual(testDataManager.getItems(forListId: importedGroceryList!.id).count, 2, "Should have two items in Grocery List")

        let importedTodoList = testDataManager.lists.first { $0.name == "Todo List" }
        XCTAssertNotNil(importedTodoList, "Should find Todo List")
        XCTAssertEqual(testDataManager.getItems(forListId: importedTodoList!.id).count, 1, "Should have one item in Todo List")
    }

    func testImportFromJSONInvalidData() throws {
        let testDataManager = TestHelpers.createTestDataManager()
        let repository = TestDataRepository(dataManager: testDataManager)
        let importService = ImportService(dataRepository: repository)

        // Try to import invalid JSON
        let invalidData = "invalid json".data(using: .utf8)!

        XCTAssertThrowsError(try importService.importFromJSON(invalidData)) { error in
            XCTAssertTrue(error is ImportError, "Should throw ImportError")
            if let importError = error as? ImportError {
                switch importError {
                case .decodingFailed:
                    // Expected error
                    break
                default:
                    XCTFail("Should throw decodingFailed error")
                }
            }
        }
    }

    func testImportFromJSONReplaceStrategy() throws {
        let testDataManager = TestHelpers.createTestDataManager()
        let repository = TestDataRepository(dataManager: testDataManager)
        let exportService = ExportService(dataRepository: repository)
        let importService = ImportService(dataRepository: repository)

        // Create initial data
        let list1 = List(name: "List 1")
        testDataManager.addList(list1)
        let _ = repository.createItem(in: list1, title: "Item 1", description: "", quantity: 1)

        // Export second set of data
        let list2 = List(name: "List 2")
        testDataManager.addList(list2)
        let _ = repository.createItem(in: list2, title: "Item 2", description: "", quantity: 1)

        let jsonData = exportService.exportToJSON()
        XCTAssertNotNil(jsonData, "Should export data")

        // Clear and add different data
        testDataManager.clearAll()
        let list3 = List(name: "List 3")
        testDataManager.addList(list3)
        let _ = repository.createItem(in: list3, title: "Item 3", description: "", quantity: 1)

        // Import with replace strategy (should delete List 3 and import List 1 & 2)
        let result = try importService.importFromJSON(jsonData!, options: .replace)

        XCTAssertTrue(result.wasSuccessful, "Import should succeed")
        XCTAssertEqual(result.listsCreated, 2, "Should create two lists")
        XCTAssertEqual(result.itemsCreated, 2, "Should create two items")

        // Verify List 3 is gone and List 1 & 2 are present
        XCTAssertEqual(testDataManager.lists.count, 2, "Should have two lists")
        XCTAssertNil(testDataManager.lists.first { $0.name == "List 3" }, "List 3 should be deleted")
        XCTAssertNotNil(testDataManager.lists.first { $0.name == "List 1" }, "List 1 should exist")
        XCTAssertNotNil(testDataManager.lists.first { $0.name == "List 2" }, "List 2 should exist")
    }

    func testImportFromJSONMergeStrategy() throws {
        let testDataManager = TestHelpers.createTestDataManager()
        let repository = TestDataRepository(dataManager: testDataManager)
        let exportService = ExportService(dataRepository: repository)
        let importService = ImportService(dataRepository: repository)

        // Create and export first list
        let list1 = List(name: "List 1")
        testDataManager.addList(list1)
        let item1 = repository.createItem(in: list1, title: "Item 1", description: "Original", quantity: 1)

        let jsonData = exportService.exportToJSON()
        XCTAssertNotNil(jsonData, "Should export data")

        // Modify the item
        repository.updateItem(item1, title: "Item 1", description: "Modified", quantity: 2)

        // Import with merge strategy (should update existing item)
        let result = try importService.importFromJSON(jsonData!, options: .default) // default uses merge

        XCTAssertTrue(result.wasSuccessful, "Import should succeed")
        XCTAssertEqual(result.listsUpdated, 1, "Should update one list")
        XCTAssertEqual(result.itemsUpdated, 1, "Should update one item")

        // Verify item was updated back to original
        let importedItems = testDataManager.getItems(forListId: list1.id)
        XCTAssertEqual(importedItems.first?.itemDescription, "Original", "Should restore original description")
        XCTAssertEqual(importedItems.first?.quantity, 1, "Should restore original quantity")
    }

    func testImportFromJSONAppendStrategy() throws {
        let testDataManager = TestHelpers.createTestDataManager()
        let repository = TestDataRepository(dataManager: testDataManager)
        let exportService = ExportService(dataRepository: repository)
        let importService = ImportService(dataRepository: repository)

        // Create and export a list
        let list1 = List(name: "List 1")
        testDataManager.addList(list1)
        let _ = repository.createItem(in: list1, title: "Item 1", description: "", quantity: 1)

        let jsonData = exportService.exportToJSON()
        XCTAssertNotNil(jsonData, "Should export data")

        // Import with append strategy (should create duplicate with new IDs)
        let result = try importService.importFromJSON(jsonData!, options: .append)

        XCTAssertTrue(result.wasSuccessful, "Import should succeed")
        XCTAssertEqual(result.listsCreated, 1, "Should create one new list")
        XCTAssertEqual(result.itemsCreated, 1, "Should create one new item")

        // Verify we now have two lists with the same name but different IDs
        let listsWithSameName = testDataManager.lists.filter { $0.name == "List 1" }
        XCTAssertEqual(listsWithSameName.count, 2, "Should have two lists with the same name")
        XCTAssertNotEqual(listsWithSameName[0].id, listsWithSameName[1].id, "Lists should have different IDs")
    }

    func testImportValidationEmptyListName() throws {
        let testDataManager = TestHelpers.createTestDataManager()
        let repository = TestDataRepository(dataManager: testDataManager)
        let importService = ImportService(dataRepository: repository)

        // Create malformed JSON with empty list name
        var malformedList = List(name: "   ") // Empty after trimming
        malformedList.id = UUID()
        malformedList.createdAt = Date()
        malformedList.modifiedAt = Date()

        let malformedExportData = ExportData(lists: [
            ListExportData(from: malformedList, items: [])
        ])

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let jsonData = try encoder.encode(malformedExportData)

        // Should throw validation error
        XCTAssertThrowsError(try importService.importFromJSON(jsonData)) { error in
            XCTAssertTrue(error is ImportError, "Should throw ImportError")
            if let importError = error as? ImportError {
                switch importError {
                case .validationFailed(let message):
                    XCTAssertTrue(message.contains("empty"), "Error should mention empty name")
                default:
                    XCTFail("Should throw validationFailed error")
                }
            }
        }
    }

    func testImportValidationEmptyItemTitle() throws {
        let testDataManager = TestHelpers.createTestDataManager()
        let repository = TestDataRepository(dataManager: testDataManager)
        let importService = ImportService(dataRepository: repository)

        // Create malformed JSON with empty item title
        var list = List(name: "Test List")
        list.id = UUID()

        var malformedItem = Item(title: "   ") // Empty after trimming
        malformedItem.id = UUID()
        malformedItem.itemDescription = ""
        malformedItem.quantity = 1
        malformedItem.orderNumber = 0
        malformedItem.isCrossedOut = false
        malformedItem.createdAt = Date()
        malformedItem.modifiedAt = Date()

        let malformedExportData = ExportData(lists: [
            ListExportData(from: list, items: [malformedItem])
        ])

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let jsonData = try encoder.encode(malformedExportData)

        // Should throw validation error
        XCTAssertThrowsError(try importService.importFromJSON(jsonData)) { error in
            XCTAssertTrue(error is ImportError, "Should throw ImportError")
            if let importError = error as? ImportError {
                switch importError {
                case .validationFailed(let message):
                    XCTAssertTrue(message.contains("empty"), "Error should mention empty title")
                default:
                    XCTFail("Should throw validationFailed error")
                }
            }
        }
    }

    func testImportValidationNegativeQuantity() throws {
        let testDataManager = TestHelpers.createTestDataManager()
        let repository = TestDataRepository(dataManager: testDataManager)
        let importService = ImportService(dataRepository: repository)

        // Create malformed JSON with negative quantity
        var list = List(name: "Test List")
        list.id = UUID()

        var malformedItem = Item(title: "Test Item")
        malformedItem.id = UUID()
        malformedItem.itemDescription = ""
        malformedItem.quantity = -1 // Invalid negative quantity
        malformedItem.orderNumber = 0
        malformedItem.isCrossedOut = false
        malformedItem.createdAt = Date()
        malformedItem.modifiedAt = Date()

        let malformedExportData = ExportData(lists: [
            ListExportData(from: list, items: [malformedItem])
        ])

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let jsonData = try encoder.encode(malformedExportData)

        // Should throw validation error
        XCTAssertThrowsError(try importService.importFromJSON(jsonData)) { error in
            XCTAssertTrue(error is ImportError, "Should throw ImportError")
            if let importError = error as? ImportError {
                switch importError {
                case .validationFailed(let message):
                    XCTAssertTrue(message.contains("negative"), "Error should mention negative quantity")
                default:
                    XCTFail("Should throw validationFailed error")
                }
            }
        }
    }

    func testImportResult() throws {
        let result = ImportResult(
            listsCreated: 2,
            listsUpdated: 1,
            itemsCreated: 5,
            itemsUpdated: 3,
            errors: [],
            conflicts: []
        )

        XCTAssertTrue(result.wasSuccessful, "Should be successful with no errors")
        XCTAssertEqual(result.totalChanges, 11, "Should calculate total changes correctly")
        XCTAssertFalse(result.hasConflicts, "Should have no conflicts")

        let failedResult = ImportResult(
            listsCreated: 0,
            listsUpdated: 0,
            itemsCreated: 0,
            itemsUpdated: 0,
            errors: ["Error 1", "Error 2"],
            conflicts: []
        )

        XCTAssertFalse(failedResult.wasSuccessful, "Should not be successful with errors")
        XCTAssertEqual(failedResult.totalChanges, 0, "Should have no changes")
    }

    func testImportOptions() throws {
        let defaultOptions = ImportOptions.default
        switch defaultOptions.mergeStrategy {
        case .merge:
            // Expected
            break
        default:
            XCTFail("Default should use merge strategy")
        }
        XCTAssertTrue(defaultOptions.validateData, "Default should validate data")

        let replaceOptions = ImportOptions.replace
        switch replaceOptions.mergeStrategy {
        case .replace:
            // Expected
            break
        default:
            XCTFail("Replace should use replace strategy")
        }

        let appendOptions = ImportOptions.append
        switch appendOptions.mergeStrategy {
        case .append:
            // Expected
            break
        default:
            XCTFail("Append should use append strategy")
        }
    }

    // MARK: - Phase 28 Advanced Import Tests

    func testImportPreviewBasic() throws {
        let testDataManager = TestHelpers.createTestDataManager()
        let repository = TestDataRepository(dataManager: testDataManager)
        let exportService = ExportService(dataRepository: repository)
        let importService = ImportService(dataRepository: repository)

        // Create test data and export it
        let list = List(name: "Test List")
        testDataManager.addList(list)
        let _ = repository.createItem(in: list, title: "Test Item", description: "Test Description", quantity: 2)

        let jsonData = exportService.exportToJSON()
        XCTAssertNotNil(jsonData, "Should export data")

        // Clear data so preview will show everything as new
        testDataManager.clearAll()

        // Preview import (data is empty, so everything will be created)
        let preview = try importService.previewImport(jsonData!, options: .default)

        XCTAssertTrue(preview.isValid, "Preview should be valid")
        XCTAssertEqual(preview.listsToCreate, 1, "Should show 1 list to create")
        XCTAssertEqual(preview.itemsToCreate, 1, "Should show 1 item to create")
        XCTAssertEqual(preview.listsToUpdate, 0, "Should show 0 lists to update")
        XCTAssertEqual(preview.itemsToUpdate, 0, "Should show 0 items to update")
        XCTAssertFalse(preview.hasConflicts, "Should have no conflicts for new data")
    }

    func testImportPreviewMergeWithConflicts() throws {
        let testDataManager = TestHelpers.createTestDataManager()
        let repository = TestDataRepository(dataManager: testDataManager)
        let exportService = ExportService(dataRepository: repository)
        let importService = ImportService(dataRepository: repository)

        // Create and export initial data
        let list = List(name: "Grocery List")
        testDataManager.addList(list)
        let item = repository.createItem(in: list, title: "Milk", description: "2% low fat", quantity: 1)

        let jsonData = exportService.exportToJSON()
        XCTAssertNotNil(jsonData, "Should export data")

        // Modify existing data to create conflicts
        repository.updateItem(item, title: "Milk", description: "Whole milk", quantity: 2)

        // Preview merge (should detect conflicts)
        let preview = try importService.previewImport(jsonData!, options: .default)

        XCTAssertTrue(preview.isValid, "Preview should be valid")
        XCTAssertEqual(preview.listsToUpdate, 1, "Should show 1 list to update")
        XCTAssertEqual(preview.itemsToUpdate, 1, "Should show 1 item to update")
        XCTAssertTrue(preview.hasConflicts, "Should detect conflicts")
        XCTAssertGreaterThan(preview.conflicts.count, 0, "Should have conflict details")
    }

    func testImportPreviewReplaceStrategy() throws {
        let testDataManager = TestHelpers.createTestDataManager()
        let repository = TestDataRepository(dataManager: testDataManager)
        let exportService = ExportService(dataRepository: repository)
        let importService = ImportService(dataRepository: repository)

        // Create initial data
        let list1 = List(name: "List 1")
        testDataManager.addList(list1)
        let _ = repository.createItem(in: list1, title: "Item 1", description: "", quantity: 1)

        // Export different data
        testDataManager.clearAll()
        let list2 = List(name: "List 2")
        testDataManager.addList(list2)
        let _ = repository.createItem(in: list2, title: "Item 2", description: "", quantity: 1)

        let jsonData = exportService.exportToJSON()
        XCTAssertNotNil(jsonData, "Should export data")

        // Add back list1 for preview
        testDataManager.addList(list1)

        // Preview replace (should show deletions)
        let preview = try importService.previewImport(jsonData!, options: .replace)

        XCTAssertTrue(preview.isValid, "Preview should be valid")
        XCTAssertEqual(preview.listsToCreate, 1, "Should show 1 list to create")
        XCTAssertTrue(preview.hasConflicts, "Should show deletion conflicts")

        // Check for deletion conflicts
        let deletionConflicts = preview.conflicts.filter { $0.type == .listDeleted || $0.type == .itemDeleted }
        XCTAssertGreaterThan(deletionConflicts.count, 0, "Should have deletion conflicts")
    }

    func testImportPreviewAppendStrategy() throws {
        let testDataManager = TestHelpers.createTestDataManager()
        let repository = TestDataRepository(dataManager: testDataManager)
        let exportService = ExportService(dataRepository: repository)
        let importService = ImportService(dataRepository: repository)

        // Create test data and export it
        let list = List(name: "Test List")
        testDataManager.addList(list)
        let _ = repository.createItem(in: list, title: "Test Item", description: "", quantity: 1)

        let jsonData = exportService.exportToJSON()
        XCTAssertNotNil(jsonData, "Should export data")

        // Preview append (should create new items, no conflicts)
        let preview = try importService.previewImport(jsonData!, options: .append)

        XCTAssertTrue(preview.isValid, "Preview should be valid")
        XCTAssertEqual(preview.listsToCreate, 1, "Should show 1 list to create")
        XCTAssertEqual(preview.itemsToCreate, 1, "Should show 1 item to create")
        XCTAssertEqual(preview.listsToUpdate, 0, "Should show 0 lists to update")
        XCTAssertEqual(preview.itemsToUpdate, 0, "Should show 0 items to update")
        XCTAssertFalse(preview.hasConflicts, "Should have no conflicts for append")
    }

    func testImportWithConflictTracking() throws {
        let testDataManager = TestHelpers.createTestDataManager()
        let repository = TestDataRepository(dataManager: testDataManager)
        let exportService = ExportService(dataRepository: repository)
        let importService = ImportService(dataRepository: repository)

        // Create and export initial data
        let list = List(name: "Shopping List")
        testDataManager.addList(list)
        let item = repository.createItem(in: list, title: "Bread", description: "White bread", quantity: 1)

        let jsonData = exportService.exportToJSON()
        XCTAssertNotNil(jsonData, "Should export data")

        // Modify existing data
        repository.updateItem(item, title: "Bread", description: "Whole wheat bread", quantity: 2)

        // Import with merge (should track conflicts)
        let result = try importService.importFromJSON(jsonData!, options: .default)

        XCTAssertTrue(result.wasSuccessful, "Import should succeed")
        XCTAssertEqual(result.itemsUpdated, 1, "Should update 1 item")
        XCTAssertTrue(result.hasConflicts, "Should have conflicts")
        XCTAssertGreaterThan(result.conflicts.count, 0, "Should track conflict details")

        // Verify conflict details
        let itemConflicts = result.conflicts.filter { $0.type == .itemModified }
        XCTAssertGreaterThan(itemConflicts.count, 0, "Should have item modification conflicts")
    }

    func testImportProgressTracking() throws {
        let testDataManager = TestHelpers.createTestDataManager()
        let repository = TestDataRepository(dataManager: testDataManager)
        let exportService = ExportService(dataRepository: repository)
        let importService = ImportService(dataRepository: repository)

        // Create multiple lists with items for progress tracking
        let list1 = List(name: "List 1")
        let list2 = List(name: "List 2")
        testDataManager.addList(list1)
        testDataManager.addList(list2)

        let _ = repository.createItem(in: list1, title: "Item 1.1", description: "", quantity: 1)
        let _ = repository.createItem(in: list1, title: "Item 1.2", description: "", quantity: 1)
        let _ = repository.createItem(in: list2, title: "Item 2.1", description: "", quantity: 1)

        let jsonData = exportService.exportToJSON()
        XCTAssertNotNil(jsonData, "Should export data")

        // Clear data for fresh import
        testDataManager.clearAll()

        // Track progress
        var progressUpdates: [ImportProgress] = []
        importService.progressHandler = { progress in
            progressUpdates.append(progress)
        }

        // Perform import
        let result = try importService.importFromJSON(jsonData!, options: .default)

        XCTAssertTrue(result.wasSuccessful, "Import should succeed")
        XCTAssertGreaterThan(progressUpdates.count, 0, "Should receive progress updates")

        // Verify progress tracking
        if let firstProgress = progressUpdates.first {
            XCTAssertEqual(firstProgress.totalLists, 2, "Should track total lists")
            XCTAssertEqual(firstProgress.totalItems, 3, "Should track total items")
        }

        if let lastProgress = progressUpdates.last {
            XCTAssertEqual(lastProgress.processedLists, 2, "Should complete all lists")
            XCTAssertEqual(lastProgress.processedItems, 3, "Should complete all items")
            XCTAssertEqual(lastProgress.progressPercentage, 100, "Should reach 100%")
        }
    }

    func testImportProgressPercentageCalculation() throws {
        let progress = ImportProgress(
            totalLists: 2,
            processedLists: 1,
            totalItems: 10,
            processedItems: 5,
            currentOperation: "Importing..."
        )

        // 1 list + 5 items = 6 out of 12 total = 50%
        XCTAssertEqual(progress.progressPercentage, 50, "Should calculate progress correctly")
        XCTAssertEqual(progress.overallProgress, 0.5, accuracy: 0.01, "Should calculate overall progress correctly")
    }

    func testConflictDetailTypes() throws {
        let listModified = ConflictDetail(
            type: .listModified,
            entityName: "Test List",
            entityId: UUID(),
            currentValue: "Old Name",
            incomingValue: "New Name",
            message: "List modified"
        )
        XCTAssertEqual(listModified.type, .listModified, "Should be list modified type")

        let itemModified = ConflictDetail(
            type: .itemModified,
            entityName: "Test Item",
            entityId: UUID(),
            currentValue: "Old Title",
            incomingValue: "New Title",
            message: "Item modified"
        )
        XCTAssertEqual(itemModified.type, .itemModified, "Should be item modified type")

        let listDeleted = ConflictDetail(
            type: .listDeleted,
            entityName: "Deleted List",
            entityId: UUID(),
            currentValue: "List Name",
            incomingValue: nil,
            message: "List deleted"
        )
        XCTAssertEqual(listDeleted.type, .listDeleted, "Should be list deleted type")
    }

    func testImportPreviewInvalidData() throws {
        let testDataManager = TestHelpers.createTestDataManager()
        let repository = TestDataRepository(dataManager: testDataManager)
        let importService = ImportService(dataRepository: repository)

        // Try to preview empty data (fails both JSON and plain text parsing)
        let invalidData = "".data(using: .utf8)!

        XCTAssertThrowsError(try importService.previewImport(invalidData)) { error in
            XCTAssertTrue(error is ImportError, "Should throw ImportError")
        }
    }

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
