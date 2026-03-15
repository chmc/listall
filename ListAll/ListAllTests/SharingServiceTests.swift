import XCTest
@testable import ListAll

final class SharingServiceTests: XCTestCase {

    // MARK: - SharingService Tests

    func testSharingServiceInitialization() throws {
        let testDataManager = TestHelpers.createTestDataManager()
        let repository = TestDataRepository(dataManager: testDataManager)
        let exportService = ExportService(dataRepository: repository)
        let sharingService = SharingService(dataRepository: repository, exportService: exportService)

        XCTAssertNotNil(sharingService, "SharingService should initialize")
        XCTAssertFalse(sharingService.isSharing, "Should not be sharing initially")
        XCTAssertNil(sharingService.shareError, "Should have no error initially")
    }

    func testShareListAsPlainText() throws {
        let testDataManager = TestHelpers.createTestDataManager()
        let repository = TestDataRepository(dataManager: testDataManager)
        let exportService = ExportService(dataRepository: repository)
        let sharingService = SharingService(dataRepository: repository, exportService: exportService)

        // Create test list with items
        let testList = List(name: "Shopping List")
        testDataManager.addList(testList)

        let _ = repository.createItem(in: testList, title: "Milk", description: "2% low fat", quantity: 2)
        let _ = repository.createItem(in: testList, title: "Bread", description: "", quantity: 1)

        // Share list as plain text
        let result = sharingService.shareList(testList, format: .plainText, options: .default)

        XCTAssertNotNil(result, "Should create share result")
        XCTAssertEqual(result?.format, .plainText, "Should be plain text format")

        guard let textContent = result?.content as? String else {
            XCTFail("Content should be a string")
            return
        }

        // Verify content
        XCTAssertTrue(textContent.contains("Shopping List"), "Should contain list name")
        XCTAssertTrue(textContent.contains("Milk"), "Should contain item title")
        XCTAssertTrue(textContent.contains("2% low fat"), "Should contain item description")
        XCTAssertTrue(textContent.contains("×2"), "Should contain quantity")
        XCTAssertTrue(textContent.contains("Bread"), "Should contain second item")
        XCTAssertTrue(textContent.contains("Shared from ListAll"), "Should contain attribution")
    }

    func testShareListAsPlainTextWithOptions() throws {
        let testDataManager = TestHelpers.createTestDataManager()
        let repository = TestDataRepository(dataManager: testDataManager)
        let exportService = ExportService(dataRepository: repository)
        let sharingService = SharingService(dataRepository: repository, exportService: exportService)

        // Create test list with crossed out item
        let testList = List(name: "Todo List")
        testDataManager.addList(testList)

        let _ = repository.createItem(in: testList, title: "Active Item", description: "Description", quantity: 1)
        var item2 = repository.createItem(in: testList, title: "Completed Item", description: "Done", quantity: 1)
        item2.isCrossedOut = true
        repository.updateItem(item2, title: item2.title, description: item2.itemDescription ?? "", quantity: item2.quantity)

        // Share with minimal options (no crossed out items, no descriptions)
        let result = sharingService.shareList(testList, format: .plainText, options: .minimal)

        XCTAssertNotNil(result, "Should create share result")

        guard let textContent = result?.content as? String else {
            XCTFail("Content should be a string")
            return
        }

        // Verify filtering
        XCTAssertTrue(textContent.contains("Active Item"), "Should contain active item")
        XCTAssertFalse(textContent.contains("Completed Item"), "Should not contain crossed out item")
        XCTAssertFalse(textContent.contains("Description"), "Should not contain descriptions")
    }

    func testShareListAsJSON() throws {
        let testDataManager = TestHelpers.createTestDataManager()
        let repository = TestDataRepository(dataManager: testDataManager)
        let exportService = ExportService(dataRepository: repository)
        let sharingService = SharingService(dataRepository: repository, exportService: exportService)

        // Create test list with items
        let testList = List(name: "Work Tasks")
        testDataManager.addList(testList)

        let _ = repository.createItem(in: testList, title: "Task 1", description: "Important task", quantity: 1)
        let _ = repository.createItem(in: testList, title: "Task 2", description: "", quantity: 3)

        // Share list as JSON
        let result = sharingService.shareList(testList, format: .json, options: .default)

        XCTAssertNotNil(result, "Should create share result")
        XCTAssertEqual(result?.format, .json, "Should be JSON format")
        XCTAssertNotNil(result?.fileName, "Should have filename")

        guard let fileURL = result?.content as? URL else {
            XCTFail("Content should be a URL")
            return
        }

        // Verify file exists
        XCTAssertTrue(FileManager.default.fileExists(atPath: fileURL.path), "File should exist")

        // Verify file content
        let jsonData = try Data(contentsOf: fileURL)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        let listData = try decoder.decode(ListExportData.self, from: jsonData)
        XCTAssertEqual(listData.name, "Work Tasks", "Should contain correct list name")
        XCTAssertEqual(listData.items.count, 2, "Should contain 2 items")
        XCTAssertEqual(listData.items[0].title, "Task 1", "Should contain correct item")

        // Clean up
        try? FileManager.default.removeItem(at: fileURL)
    }

    func testShareListAsURL() throws {
        let testDataManager = TestHelpers.createTestDataManager()
        let repository = TestDataRepository(dataManager: testDataManager)
        let exportService = ExportService(dataRepository: repository)
        let sharingService = SharingService(dataRepository: repository, exportService: exportService)

        // Create test list
        let testList = List(name: "My List")
        testDataManager.addList(testList)

        // Share list as URL - should now return error (URL sharing removed)
        let result = sharingService.shareList(testList, format: .url)

        XCTAssertNil(result, "Should not create share result for URL format")
        XCTAssertNotNil(sharingService.shareError, "Should have error message")
        XCTAssertEqual(sharingService.shareError, "URL sharing is not supported (app is not publicly distributed)", "Should have correct error message")
    }

    func testShareListInvalidList() throws {
        let testDataManager = TestHelpers.createTestDataManager()
        let repository = TestDataRepository(dataManager: testDataManager)
        let exportService = ExportService(dataRepository: repository)
        let sharingService = SharingService(dataRepository: repository, exportService: exportService)

        // Create invalid list (empty name)
        let invalidList = List(name: "")
        testDataManager.addList(invalidList)

        // Try to share invalid list
        let result = sharingService.shareList(invalidList, format: .plainText)

        XCTAssertNil(result, "Should not create share result for invalid list")
        XCTAssertNotNil(sharingService.shareError, "Should have error message")
    }

    func testShareListEmptyList() throws {
        let testDataManager = TestHelpers.createTestDataManager()
        let repository = TestDataRepository(dataManager: testDataManager)
        let exportService = ExportService(dataRepository: repository)
        let sharingService = SharingService(dataRepository: repository, exportService: exportService)

        // Create empty list
        let emptyList = List(name: "Empty List")
        testDataManager.addList(emptyList)

        // Share empty list
        let result = sharingService.shareList(emptyList, format: .plainText)

        XCTAssertNotNil(result, "Should create share result for empty list")

        guard let textContent = result?.content as? String else {
            XCTFail("Content should be a string")
            return
        }

        XCTAssertTrue(textContent.contains("Empty List"), "Should contain list name")
        XCTAssertTrue(textContent.contains("(No items)"), "Should indicate no items")
    }

    func testShareAllDataAsJSON() throws {
        let testDataManager = TestHelpers.createTestDataManager()
        let repository = TestDataRepository(dataManager: testDataManager)
        let exportService = ExportService(dataRepository: repository)
        let sharingService = SharingService(dataRepository: repository, exportService: exportService)

        // Create multiple lists with items
        let list1 = List(name: "List 1")
        let list2 = List(name: "List 2")
        testDataManager.addList(list1)
        testDataManager.addList(list2)

        let _ = repository.createItem(in: list1, title: "Item 1.1", description: "", quantity: 1)
        let _ = repository.createItem(in: list2, title: "Item 2.1", description: "", quantity: 1)

        // Share all data
        let result = sharingService.shareAllData(format: .json)

        XCTAssertNotNil(result, "Should create share result")
        XCTAssertEqual(result?.format, .json, "Should be JSON format")

        guard let fileURL = result?.content as? URL else {
            XCTFail("Content should be a URL")
            return
        }

        // Verify file exists
        XCTAssertTrue(FileManager.default.fileExists(atPath: fileURL.path), "File should exist")

        // Verify file content
        let jsonData = try Data(contentsOf: fileURL)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        let exportData = try decoder.decode(ExportData.self, from: jsonData)
        XCTAssertEqual(exportData.lists.count, 2, "Should contain 2 lists")
        XCTAssertEqual(exportData.version, "1.0", "Should have version")

        // Clean up
        try? FileManager.default.removeItem(at: fileURL)
    }

    func testShareAllDataAsPlainText() throws {
        let testDataManager = TestHelpers.createTestDataManager()
        let repository = TestDataRepository(dataManager: testDataManager)
        let exportService = ExportService(dataRepository: repository)
        let sharingService = SharingService(dataRepository: repository, exportService: exportService)

        // Create test data
        let list1 = List(name: "Groceries")
        let list2 = List(name: "Tasks")
        testDataManager.addList(list1)
        testDataManager.addList(list2)

        let _ = repository.createItem(in: list1, title: "Milk", description: "", quantity: 1)
        let _ = repository.createItem(in: list2, title: "Laundry", description: "", quantity: 1)

        // Share all data as plain text
        let result = sharingService.shareAllData(format: .plainText)

        XCTAssertNotNil(result, "Should create share result")
        XCTAssertEqual(result?.format, .plainText, "Should be plain text format")

        guard let textContent = result?.content as? String else {
            XCTFail("Content should be a string")
            return
        }

        // Verify content
        XCTAssertTrue(textContent.contains("ListAll Export"), "Should contain export header")
        XCTAssertTrue(textContent.contains("Groceries"), "Should contain list 1")
        XCTAssertTrue(textContent.contains("Tasks"), "Should contain list 2")
        XCTAssertTrue(textContent.contains("Milk"), "Should contain item from list 1")
        XCTAssertTrue(textContent.contains("Laundry"), "Should contain item from list 2")
    }

    func testShareAllDataURLNotSupported() throws {
        let testDataManager = TestHelpers.createTestDataManager()
        let repository = TestDataRepository(dataManager: testDataManager)
        let exportService = ExportService(dataRepository: repository)
        let sharingService = SharingService(dataRepository: repository, exportService: exportService)

        // Try to share all data as URL (not supported)
        let result = sharingService.shareAllData(format: .url)

        XCTAssertNil(result, "Should not create share result for URL format")
        XCTAssertNotNil(sharingService.shareError, "Should have error message")
        XCTAssertEqual(sharingService.shareError, "URL format not supported for all data")
    }

    func testParseListURL() throws {
        let testDataManager = TestHelpers.createTestDataManager()
        let repository = TestDataRepository(dataManager: testDataManager)
        let exportService = ExportService(dataRepository: repository)
        let sharingService = SharingService(dataRepository: repository, exportService: exportService)

        // Create a test list and URL
        let testList = List(name: "Test List")
        let urlString = "listall://list/\(testList.id.uuidString)?name=Test%20List"
        let url = URL(string: urlString)!

        // Parse URL
        let parsed = sharingService.parseListURL(url)

        XCTAssertNotNil(parsed, "Should parse URL")
        XCTAssertEqual(parsed?.listId, testList.id, "Should extract correct list ID")
        XCTAssertEqual(parsed?.listName, "Test List", "Should extract and decode list name")
    }

    func testParseListURLInvalidScheme() throws {
        let testDataManager = TestHelpers.createTestDataManager()
        let repository = TestDataRepository(dataManager: testDataManager)
        let exportService = ExportService(dataRepository: repository)
        let sharingService = SharingService(dataRepository: repository, exportService: exportService)

        // Invalid scheme
        let invalidURL = URL(string: "https://example.com/list/123")!
        let parsed = sharingService.parseListURL(invalidURL)

        XCTAssertNil(parsed, "Should not parse URL with invalid scheme")
    }

    func testParseListURLInvalidFormat() throws {
        let testDataManager = TestHelpers.createTestDataManager()
        let repository = TestDataRepository(dataManager: testDataManager)
        let exportService = ExportService(dataRepository: repository)
        let sharingService = SharingService(dataRepository: repository, exportService: exportService)

        // Invalid UUID
        let invalidURL = URL(string: "listall://list/not-a-uuid?name=Test")!
        let parsed = sharingService.parseListURL(invalidURL)

        XCTAssertNil(parsed, "Should not parse URL with invalid UUID")
    }

    func testValidateListForSharing() throws {
        let testDataManager = TestHelpers.createTestDataManager()
        let repository = TestDataRepository(dataManager: testDataManager)
        let exportService = ExportService(dataRepository: repository)
        let sharingService = SharingService(dataRepository: repository, exportService: exportService)

        // Valid list
        let validList = List(name: "Valid List")
        XCTAssertTrue(sharingService.validateListForSharing(validList), "Should validate valid list")
        XCTAssertNil(sharingService.shareError, "Should have no error for valid list")

        // Invalid list (empty name)
        let invalidList = List(name: "")
        XCTAssertFalse(sharingService.validateListForSharing(invalidList), "Should not validate invalid list")
        XCTAssertNotNil(sharingService.shareError, "Should have error for invalid list")
    }

    func testShareOptionsDefaults() throws {
        let defaultOptions = ShareOptions.default
        XCTAssertTrue(defaultOptions.includeCrossedOutItems, "Default should include crossed out items")
        XCTAssertTrue(defaultOptions.includeDescriptions, "Default should include descriptions")
        XCTAssertTrue(defaultOptions.includeQuantities, "Default should include quantities")
        XCTAssertFalse(defaultOptions.includeDates, "Default should not include dates")

        let minimalOptions = ShareOptions.minimal
        XCTAssertFalse(minimalOptions.includeCrossedOutItems, "Minimal should not include crossed out items")
        XCTAssertFalse(minimalOptions.includeDescriptions, "Minimal should not include descriptions")
        XCTAssertFalse(minimalOptions.includeQuantities, "Minimal should not include quantities")
        XCTAssertFalse(minimalOptions.includeDates, "Minimal should not include dates")
    }

    func testClearError() throws {
        let testDataManager = TestHelpers.createTestDataManager()
        let repository = TestDataRepository(dataManager: testDataManager)
        let exportService = ExportService(dataRepository: repository)
        let sharingService = SharingService(dataRepository: repository, exportService: exportService)

        // Set an error
        sharingService.shareError = "Test error"
        XCTAssertNotNil(sharingService.shareError, "Error should be set")

        // Clear error
        sharingService.clearError()
        XCTAssertNil(sharingService.shareError, "Error should be cleared")
    }
}
