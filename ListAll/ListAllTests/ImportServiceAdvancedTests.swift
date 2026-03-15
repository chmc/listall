import XCTest
import UIKit
@testable import ListAll

final class ImportServiceAdvancedTests: XCTestCase {

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
}
