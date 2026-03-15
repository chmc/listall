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
}
