import XCTest
import UIKit
@testable import ListAll

final class ExportServiceTests: XCTestCase {

    // MARK: - ExportService Tests

    func testExportServiceInitialization() throws {
        let exportService = ExportService()
        XCTAssertNotNil(exportService, "ExportService should initialize successfully")
    }

    func testExportToJSONBasic() throws {
        let testDataManager = TestHelpers.createTestDataManager()
        let repository = TestDataRepository(dataManager: testDataManager)
        let exportService = ExportService(dataRepository: repository)

        // Create test data
        let list = List(name: "Test List")
        testDataManager.addList(list)
        let _ = repository.createItem(in: list, title: "Test Item", description: "Test Description", quantity: 2)

        // Test JSON export
        let jsonData = exportService.exportToJSON()
        XCTAssertNotNil(jsonData, "Should export data to JSON")

        // Verify JSON can be decoded
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let exportData = try decoder.decode(ExportData.self, from: jsonData!)

        XCTAssertEqual(exportData.lists.count, 1, "Should have one list")
        XCTAssertEqual(exportData.lists.first?.name, "Test List", "Should preserve list name")
        XCTAssertEqual(exportData.lists.first?.items.count, 1, "Should have one item")
        XCTAssertEqual(exportData.lists.first?.items.first?.title, "Test Item", "Should preserve item title")
        XCTAssertEqual(exportData.lists.first?.items.first?.description, "Test Description", "Should preserve item description")
        XCTAssertEqual(exportData.lists.first?.items.first?.quantity, 2, "Should preserve item quantity")
    }

    func testExportToJSONMultipleLists() throws {
        let testDataManager = TestHelpers.createTestDataManager()
        let repository = TestDataRepository(dataManager: testDataManager)
        let exportService = ExportService(dataRepository: repository)

        // Create multiple lists with items
        let list1 = List(name: "Grocery List")
        let list2 = List(name: "Todo List")
        testDataManager.addList(list1)
        testDataManager.addList(list2)

        let _ = repository.createItem(in: list1, title: "Milk", description: "2% low fat", quantity: 1)
        let _ = repository.createItem(in: list1, title: "Bread", description: "Whole wheat", quantity: 2)
        let _ = repository.createItem(in: list2, title: "Buy groceries", description: "", quantity: 1)

        // Export to JSON
        let jsonData = exportService.exportToJSON()
        XCTAssertNotNil(jsonData, "Should export multiple lists to JSON")

        // Verify JSON structure
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let exportData = try decoder.decode(ExportData.self, from: jsonData!)

        XCTAssertEqual(exportData.lists.count, 2, "Should have two lists")

        // Find lists by item count (order may vary)
        let listWith2Items = exportData.lists.first { $0.items.count == 2 }
        let listWith1Item = exportData.lists.first { $0.items.count == 1 }

        XCTAssertNotNil(listWith2Items, "Should have a list with 2 items")
        XCTAssertNotNil(listWith1Item, "Should have a list with 1 item")
        XCTAssertEqual(listWith2Items?.name, "Grocery List", "List with 2 items should be Grocery List")
        XCTAssertEqual(listWith1Item?.name, "Todo List", "List with 1 item should be Todo List")
    }

    func testExportToJSONEmptyList() throws {
        let testDataManager = TestHelpers.createTestDataManager()
        let repository = TestDataRepository(dataManager: testDataManager)
        let exportService = ExportService(dataRepository: repository)

        // Create empty list
        let emptyList = List(name: "Empty List")
        testDataManager.addList(emptyList)

        // Export to JSON
        let jsonData = exportService.exportToJSON()
        XCTAssertNotNil(jsonData, "Should export empty list to JSON")

        // Verify JSON structure
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let exportData = try decoder.decode(ExportData.self, from: jsonData!)

        XCTAssertEqual(exportData.lists.count, 1, "Should have one list")
        XCTAssertEqual(exportData.lists.first?.items.count, 0, "List should have no items")
    }

    func testExportToJSONMetadata() throws {
        let testDataManager = TestHelpers.createTestDataManager()
        let repository = TestDataRepository(dataManager: testDataManager)
        let exportService = ExportService(dataRepository: repository)

        let list = List(name: "Test List")
        testDataManager.addList(list)

        // Export to JSON
        let jsonData = exportService.exportToJSON()
        XCTAssertNotNil(jsonData, "Should export data to JSON")

        // Verify metadata
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let exportData = try decoder.decode(ExportData.self, from: jsonData!)

        XCTAssertEqual(exportData.version, "1.0", "Should have version 1.0")
        XCTAssertNotNil(exportData.exportDate, "Should have export date")

        // Verify export date is recent (within last minute)
        let timeDifference = abs(exportData.exportDate.timeIntervalSinceNow)
        XCTAssertLessThan(timeDifference, 60, "Export date should be recent")
    }

    func testExportToCSVBasic() throws {
        let testDataManager = TestHelpers.createTestDataManager()
        let repository = TestDataRepository(dataManager: testDataManager)
        let exportService = ExportService(dataRepository: repository)

        // Create test data
        let list = List(name: "Test List")
        testDataManager.addList(list)
        let _ = repository.createItem(in: list, title: "Test Item", description: "Test Description", quantity: 2)

        // Export to CSV
        let csvString = exportService.exportToCSV()
        XCTAssertNotNil(csvString, "Should export data to CSV")

        // Verify CSV structure
        let lines = csvString!.components(separatedBy: "\n")
        XCTAssertGreaterThan(lines.count, 1, "Should have header and at least one data row")

        // Verify header
        let header = lines[0]
        XCTAssertTrue(header.contains("List Name"), "Header should contain List Name")
        XCTAssertTrue(header.contains("Item Title"), "Header should contain Item Title")
        XCTAssertTrue(header.contains("Description"), "Header should contain Description")
        XCTAssertTrue(header.contains("Quantity"), "Header should contain Quantity")
        XCTAssertTrue(header.contains("Crossed Out"), "Header should contain Crossed Out")

        // Verify data row contains expected values
        let dataRow = lines[1]
        XCTAssertTrue(dataRow.contains("Test List"), "Data row should contain list name")
        XCTAssertTrue(dataRow.contains("Test Item"), "Data row should contain item title")
        XCTAssertTrue(dataRow.contains("Test Description"), "Data row should contain description")
        XCTAssertTrue(dataRow.contains("2"), "Data row should contain quantity")
    }

    func testExportToCSVMultipleItems() throws {
        let testDataManager = TestHelpers.createTestDataManager()
        let repository = TestDataRepository(dataManager: testDataManager)
        let exportService = ExportService(dataRepository: repository)

        // Create list with multiple items
        let list = List(name: "Shopping List")
        testDataManager.addList(list)
        let _ = repository.createItem(in: list, title: "Milk", description: "2% low fat", quantity: 1)
        let _ = repository.createItem(in: list, title: "Bread", description: "Whole wheat", quantity: 2)
        let _ = repository.createItem(in: list, title: "Eggs", description: "Free range", quantity: 12)

        // Export to CSV
        let csvString = exportService.exportToCSV()
        XCTAssertNotNil(csvString, "Should export data to CSV")

        // Verify CSV structure
        let lines = csvString!.components(separatedBy: "\n").filter { !$0.isEmpty }
        XCTAssertEqual(lines.count, 4, "Should have header + 3 data rows") // Header + 3 items

        // Verify all items are present
        let csvContent = csvString!
        XCTAssertTrue(csvContent.contains("Milk"), "Should contain Milk")
        XCTAssertTrue(csvContent.contains("Bread"), "Should contain Bread")
        XCTAssertTrue(csvContent.contains("Eggs"), "Should contain Eggs")
    }

    func testExportToCSVEmptyList() throws {
        let testDataManager = TestHelpers.createTestDataManager()
        let repository = TestDataRepository(dataManager: testDataManager)
        let exportService = ExportService(dataRepository: repository)

        // Create empty list
        let emptyList = List(name: "Empty List")
        testDataManager.addList(emptyList)

        // Export to CSV
        let csvString = exportService.exportToCSV()
        XCTAssertNotNil(csvString, "Should export empty list to CSV")

        // Verify CSV structure - should have header + 1 row for the empty list
        let lines = csvString!.components(separatedBy: "\n").filter { !$0.isEmpty }
        XCTAssertEqual(lines.count, 2, "Should have header + 1 row for empty list")

        // Verify empty list row contains list name
        let dataRow = lines[1]
        XCTAssertTrue(dataRow.contains("Empty List"), "Should contain empty list name")
    }

    func testExportToCSVSpecialCharacters() throws {
        let testDataManager = TestHelpers.createTestDataManager()
        let repository = TestDataRepository(dataManager: testDataManager)
        let exportService = ExportService(dataRepository: repository)

        // Create item with special characters (comma, quotes, newlines)
        let list = List(name: "Special \"Characters\" List")
        testDataManager.addList(list)
        let _ = repository.createItem(in: list, title: "Item, with commas", description: "Description with \"quotes\"", quantity: 1)

        // Export to CSV
        let csvString = exportService.exportToCSV()
        XCTAssertNotNil(csvString, "Should export data with special characters to CSV")

        // Verify CSV escapes special characters properly
        let lines = csvString!.components(separatedBy: "\n")
        let dataRow = lines[1]

        // CSV should escape fields containing special characters with quotes
        XCTAssertTrue(dataRow.contains("\""), "Should escape special characters")
    }

    func testExportToCSVCrossedOutItems() throws {
        let testDataManager = TestHelpers.createTestDataManager()
        let repository = TestDataRepository(dataManager: testDataManager)
        let exportService = ExportService(dataRepository: repository)

        // Create items with different crossed out states
        let list = List(name: "Test List")
        testDataManager.addList(list)
        _ = repository.createItem(in: list, title: "Active Item", description: "", quantity: 1)
        let item2 = repository.createItem(in: list, title: "Completed Item", description: "", quantity: 1)

        // Cross out second item
        repository.toggleItemCrossedOut(item2)

        // Export to CSV
        let csvString = exportService.exportToCSV()
        XCTAssertNotNil(csvString, "Should export data to CSV")

        // Verify CSV contains Yes/No for crossed out status
        let lines = csvString!.components(separatedBy: "\n")
        let activeRow = lines.first { $0.contains("Active Item") }
        let completedRow = lines.first { $0.contains("Completed Item") }

        XCTAssertNotNil(activeRow, "Should find active item row")
        XCTAssertNotNil(completedRow, "Should find completed item row")
        XCTAssertTrue(activeRow!.contains("No"), "Active item should have 'No' for crossed out")
        XCTAssertTrue(completedRow!.contains("Yes"), "Completed item should have 'Yes' for crossed out")
    }

    func testExportToCSVNoData() throws {
        let testDataManager = TestHelpers.createTestDataManager()
        let repository = TestDataRepository(dataManager: testDataManager)
        let exportService = ExportService(dataRepository: repository)

        // Export with no data
        let csvString = exportService.exportToCSV()
        XCTAssertNotNil(csvString, "Should export even with no data")

        // Verify CSV has only header
        let lines = csvString!.components(separatedBy: "\n").filter { !$0.isEmpty }
        XCTAssertEqual(lines.count, 1, "Should have only header row when no data")
    }

    // MARK: - Phase 26 Advanced Export Tests

    func testExportOptionsDefault() throws {
        let defaultOptions = ExportOptions.default

        XCTAssertTrue(defaultOptions.includeCrossedOutItems, "Default should include crossed out items")
        XCTAssertTrue(defaultOptions.includeDescriptions, "Default should include descriptions")
        XCTAssertTrue(defaultOptions.includeQuantities, "Default should include quantities")
        XCTAssertTrue(defaultOptions.includeDates, "Default should include dates")
        XCTAssertFalse(defaultOptions.includeArchivedLists, "Default should not include archived lists")
    }

    func testExportOptionsMinimal() throws {
        let minimalOptions = ExportOptions.minimal

        XCTAssertFalse(minimalOptions.includeCrossedOutItems, "Minimal should not include crossed out items")
        XCTAssertFalse(minimalOptions.includeDescriptions, "Minimal should not include descriptions")
        XCTAssertFalse(minimalOptions.includeQuantities, "Minimal should not include quantities")
        XCTAssertFalse(minimalOptions.includeDates, "Minimal should not include dates")
        XCTAssertFalse(minimalOptions.includeArchivedLists, "Minimal should not include archived lists")
    }

    func testExportToPlainTextBasic() throws {
        let testDataManager = TestHelpers.createTestDataManager()
        let repository = TestDataRepository(dataManager: testDataManager)
        let exportService = ExportService(dataRepository: repository)

        // Create test data
        let list = List(name: "Grocery List")
        testDataManager.addList(list)
        let _ = repository.createItem(in: list, title: "Milk", description: "2% low fat", quantity: 2)

        // Export to plain text
        let plainText = exportService.exportToPlainText()
        XCTAssertNotNil(plainText, "Should export data to plain text")

        // Verify content
        XCTAssertTrue(plainText!.contains("ListAll Export"), "Should contain header")
        XCTAssertTrue(plainText!.contains("Grocery List"), "Should contain list name")
        XCTAssertTrue(plainText!.contains("Milk"), "Should contain item title")
        XCTAssertTrue(plainText!.contains("2% low fat"), "Should contain item description")
        XCTAssertTrue(plainText!.contains("×2"), "Should contain quantity")
    }

    func testExportToPlainTextWithOptions() throws {
        let testDataManager = TestHelpers.createTestDataManager()
        let repository = TestDataRepository(dataManager: testDataManager)
        let exportService = ExportService(dataRepository: repository)

        // Create test data
        let list = List(name: "Todo List")
        testDataManager.addList(list)
        let item = repository.createItem(in: list, title: "Buy groceries", description: "Get milk and bread", quantity: 1)
        repository.toggleItemCrossedOut(item)

        // Export with minimal options (should exclude crossed out items)
        let minimalOptions = ExportOptions.minimal
        let plainText = exportService.exportToPlainText(options: minimalOptions)
        XCTAssertNotNil(plainText, "Should export with minimal options")

        // Verify crossed out item is excluded
        XCTAssertFalse(plainText!.contains("Buy groceries"), "Should not contain crossed out item with minimal options")

        // Export with default options (should include crossed out items)
        let defaultText = exportService.exportToPlainText(options: .default)
        XCTAssertNotNil(defaultText, "Should export with default options")
        XCTAssertTrue(defaultText!.contains("Buy groceries"), "Should contain crossed out item with default options")
    }

    func testExportToPlainTextCrossedOutMarkers() throws {
        let testDataManager = TestHelpers.createTestDataManager()
        let repository = TestDataRepository(dataManager: testDataManager)
        let exportService = ExportService(dataRepository: repository)

        // Create test data with mixed crossed out states
        let list = List(name: "Test List")
        testDataManager.addList(list)
        _ = repository.createItem(in: list, title: "Active Item", description: "", quantity: 1)
        let item2 = repository.createItem(in: list, title: "Completed Item", description: "", quantity: 1)
        repository.toggleItemCrossedOut(item2)

        // Export to plain text
        let plainText = exportService.exportToPlainText()
        XCTAssertNotNil(plainText, "Should export data to plain text")

        // Verify checkbox markers
        XCTAssertTrue(plainText!.contains("[ ] Active Item"), "Active item should have empty checkbox")
        XCTAssertTrue(plainText!.contains("[✓] Completed Item"), "Completed item should have checked checkbox")
    }

    func testExportToPlainTextEmptyList() throws {
        let testDataManager = TestHelpers.createTestDataManager()
        let repository = TestDataRepository(dataManager: testDataManager)
        let exportService = ExportService(dataRepository: repository)

        // Create empty list
        let emptyList = List(name: "Empty List")
        testDataManager.addList(emptyList)

        // Export to plain text
        let plainText = exportService.exportToPlainText()
        XCTAssertNotNil(plainText, "Should export empty list to plain text")

        // Verify content
        XCTAssertTrue(plainText!.contains("Empty List"), "Should contain list name")
        XCTAssertTrue(plainText!.contains("(No items)"), "Should indicate no items")
    }

    func testExportToJSONWithOptions() throws {
        let testDataManager = TestHelpers.createTestDataManager()
        let repository = TestDataRepository(dataManager: testDataManager)
        let exportService = ExportService(dataRepository: repository)

        // Create test data with crossed out item
        let list = List(name: "Test List")
        testDataManager.addList(list)
        _ = repository.createItem(in: list, title: "Active Item", description: "Active description", quantity: 1)
        let item2 = repository.createItem(in: list, title: "Completed Item", description: "Completed description", quantity: 1)
        repository.toggleItemCrossedOut(item2)

        // Export with minimal options (exclude crossed out items)
        let minimalOptions = ExportOptions.minimal
        let jsonData = exportService.exportToJSON(options: minimalOptions)
        XCTAssertNotNil(jsonData, "Should export with minimal options")

        // Verify crossed out item is excluded
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let exportData = try decoder.decode(ExportData.self, from: jsonData!)

        XCTAssertEqual(exportData.lists.count, 1, "Should have one list")
        XCTAssertEqual(exportData.lists.first?.items.count, 1, "Should have only one item (active)")
        XCTAssertEqual(exportData.lists.first?.items.first?.title, "Active Item", "Should only include active item")
    }

    func testExportToCSVWithOptions() throws {
        let testDataManager = TestHelpers.createTestDataManager()
        let repository = TestDataRepository(dataManager: testDataManager)
        let exportService = ExportService(dataRepository: repository)

        // Create test data with crossed out item
        let list = List(name: "Test List")
        testDataManager.addList(list)
        _ = repository.createItem(in: list, title: "Active Item", description: "", quantity: 1)
        let item2 = repository.createItem(in: list, title: "Completed Item", description: "", quantity: 1)
        repository.toggleItemCrossedOut(item2)

        // Export with minimal options (exclude crossed out items)
        let minimalOptions = ExportOptions.minimal
        let csvString = exportService.exportToCSV(options: minimalOptions)
        XCTAssertNotNil(csvString, "Should export with minimal options")

        // Verify crossed out item is excluded
        XCTAssertTrue(csvString!.contains("Active Item"), "Should contain active item")
        XCTAssertFalse(csvString!.contains("Completed Item"), "Should not contain completed item")
    }

    func testExportFilterArchivedLists() throws {
        let testDataManager = TestHelpers.createTestDataManager()
        let repository = TestDataRepository(dataManager: testDataManager)
        let exportService = ExportService(dataRepository: repository)

        // Create test data with archived list
        let activeList = List(name: "Active List")
        var archivedList = List(name: "Archived List")
        archivedList.isArchived = true
        testDataManager.addList(activeList)
        testDataManager.addList(archivedList)

        // Export with default options (exclude archived lists)
        let jsonData = exportService.exportToJSON(options: .default)
        XCTAssertNotNil(jsonData, "Should export with default options")

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let exportData = try decoder.decode(ExportData.self, from: jsonData!)

        XCTAssertEqual(exportData.lists.count, 1, "Should have only one list (active)")
        XCTAssertEqual(exportData.lists.first?.name, "Active List", "Should only include active list")

        // Export with archived lists included
        var optionsWithArchived = ExportOptions.default
        optionsWithArchived.includeArchivedLists = true
        let jsonDataWithArchived = exportService.exportToJSON(options: optionsWithArchived)
        XCTAssertNotNil(jsonDataWithArchived, "Should export with archived lists")

        let exportDataWithArchived = try decoder.decode(ExportData.self, from: jsonDataWithArchived!)
        XCTAssertEqual(exportDataWithArchived.lists.count, 2, "Should have both lists")
    }

    // MARK: - Export with Images Tests

    func testExportToJSONWithImages() throws {
        let testDataManager = TestHelpers.createTestDataManager()
        let repository = TestDataRepository(dataManager: testDataManager)
        let exportService = ExportService(dataRepository: repository)

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

        // Export with images included (default option)
        let jsonData = exportService.exportToJSON(options: .default)
        XCTAssertNotNil(jsonData, "Should export data with images to JSON")

        // Verify JSON can be decoded
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let exportData = try decoder.decode(ExportData.self, from: jsonData!)

        XCTAssertEqual(exportData.lists.count, 1, "Should have one list")
        XCTAssertEqual(exportData.lists.first?.items.count, 1, "Should have one item")

        let exportedItem = exportData.lists.first?.items.first
        XCTAssertNotNil(exportedItem, "Should have exported item")
        XCTAssertEqual(exportedItem?.images.count, 1, "Should have one image")
        XCTAssertFalse(exportedItem?.images.first?.imageData.isEmpty ?? true, "Image data should not be empty")

        // Verify the image data is valid base64
        let base64String = exportedItem?.images.first?.imageData ?? ""
        XCTAssertNotNil(Data(base64Encoded: base64String), "Image data should be valid base64")
    }

    func testExportToJSONWithoutImages() throws {
        let testDataManager = TestHelpers.createTestDataManager()
        let repository = TestDataRepository(dataManager: testDataManager)
        let exportService = ExportService(dataRepository: repository)

        // Create test data with an item that has images
        let list = List(name: "Test List")
        testDataManager.addList(list)
        let item = repository.createItem(in: list, title: "Item with Image", description: "Test Description", quantity: 1)

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

        // Export with images excluded (minimal option)
        let jsonData = exportService.exportToJSON(options: .minimal)
        XCTAssertNotNil(jsonData, "Should export data without images to JSON")

        // Verify JSON can be decoded
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let exportData = try decoder.decode(ExportData.self, from: jsonData!)

        XCTAssertEqual(exportData.lists.count, 1, "Should have one list")
        XCTAssertEqual(exportData.lists.first?.items.count, 1, "Should have one item")

        let exportedItem = exportData.lists.first?.items.first
        XCTAssertNotNil(exportedItem, "Should have exported item")
        XCTAssertEqual(exportedItem?.images.count, 0, "Should have no images when includeImages is false")
    }

    func testExportToJSONWithMultipleImages() throws {
        let testDataManager = TestHelpers.createTestDataManager()
        let repository = TestDataRepository(dataManager: testDataManager)
        let exportService = ExportService(dataRepository: repository)

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
        let jsonData = exportService.exportToJSON(options: .default)
        XCTAssertNotNil(jsonData, "Should export data with multiple images to JSON")

        // Verify JSON can be decoded
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let exportData = try decoder.decode(ExportData.self, from: jsonData!)

        let exportedItem = exportData.lists.first?.items.first
        XCTAssertNotNil(exportedItem, "Should have exported item")
        XCTAssertEqual(exportedItem?.images.count, 3, "Should have three images")

        // Verify all images have valid base64 data
        for image in exportedItem?.images ?? [] {
            XCTAssertFalse(image.imageData.isEmpty, "Image data should not be empty")
            XCTAssertNotNil(Data(base64Encoded: image.imageData), "Image data should be valid base64")
        }
    }

    func testExportOptionsIncludeImages() throws {
        // Test default options includes images
        let defaultOptions = ExportOptions.default
        XCTAssertTrue(defaultOptions.includeImages, "Default should include images")

        // Test minimal options excludes images
        let minimalOptions = ExportOptions.minimal
        XCTAssertFalse(minimalOptions.includeImages, "Minimal should not include images")

        // Test custom options
        var customOptions = ExportOptions.default
        customOptions.includeImages = false
        XCTAssertFalse(customOptions.includeImages, "Custom option should respect includeImages setting")
    }

    func testExportToJSONItemWithNoImages() throws {
        let testDataManager = TestHelpers.createTestDataManager()
        let repository = TestDataRepository(dataManager: testDataManager)
        let exportService = ExportService(dataRepository: repository)

        // Create test data with an item that has no images
        let list = List(name: "Test List")
        testDataManager.addList(list)
        let _ = repository.createItem(in: list, title: "Item without Image", description: "Test", quantity: 1)

        // Export with images included
        let jsonData = exportService.exportToJSON(options: .default)
        XCTAssertNotNil(jsonData, "Should export data to JSON")

        // Verify JSON can be decoded
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let exportData = try decoder.decode(ExportData.self, from: jsonData!)

        let exportedItem = exportData.lists.first?.items.first
        XCTAssertNotNil(exportedItem, "Should have exported item")
        XCTAssertEqual(exportedItem?.images.count, 0, "Should have zero images for item without images")
    }

    func testExportPlainTextWithoutDescriptions() throws {
        let testDataManager = TestHelpers.createTestDataManager()
        let repository = TestDataRepository(dataManager: testDataManager)
        let exportService = ExportService(dataRepository: repository)

        // Create test data
        let list = List(name: "Test List")
        testDataManager.addList(list)
        let _ = repository.createItem(in: list, title: "Item with Description", description: "This is a description", quantity: 1)

        // Export without descriptions
        var optionsWithoutDesc = ExportOptions.default
        optionsWithoutDesc.includeDescriptions = false
        let plainText = exportService.exportToPlainText(options: optionsWithoutDesc)
        XCTAssertNotNil(plainText, "Should export without descriptions")

        // Verify description is excluded but title is included
        XCTAssertTrue(plainText!.contains("Item with Description"), "Should contain item title")
        XCTAssertFalse(plainText!.contains("This is a description"), "Should not contain item description")
    }

    func testExportPlainTextWithoutQuantities() throws {
        let testDataManager = TestHelpers.createTestDataManager()
        let repository = TestDataRepository(dataManager: testDataManager)
        let exportService = ExportService(dataRepository: repository)

        // Create test data
        let list = List(name: "Test List")
        testDataManager.addList(list)
        let _ = repository.createItem(in: list, title: "Multiple Items", description: "", quantity: 5)

        // Export without quantities
        var optionsWithoutQty = ExportOptions.default
        optionsWithoutQty.includeQuantities = false
        let plainText = exportService.exportToPlainText(options: optionsWithoutQty)
        XCTAssertNotNil(plainText, "Should export without quantities")

        // Verify quantity marker is excluded
        XCTAssertFalse(plainText!.contains("×5"), "Should not contain quantity marker")
    }

    func testExportPlainTextWithoutDates() throws {
        let testDataManager = TestHelpers.createTestDataManager()
        let repository = TestDataRepository(dataManager: testDataManager)
        let exportService = ExportService(dataRepository: repository)

        // Create test data
        let list = List(name: "Test List")
        testDataManager.addList(list)
        let _ = repository.createItem(in: list, title: "Test Item", description: "", quantity: 1)

        // Export without dates
        var optionsWithoutDates = ExportOptions.default
        optionsWithoutDates.includeDates = false
        let plainText = exportService.exportToPlainText(options: optionsWithoutDates)
        XCTAssertNotNil(plainText, "Should export without dates")

        // Verify "Created:" text is not present (indicates dates are excluded)
        let lines = plainText!.components(separatedBy: "\n")
        let createdLines = lines.filter { $0.contains("Created:") && !$0.contains("Exported:") }
        XCTAssertEqual(createdLines.count, 0, "Should not contain item/list creation dates")
    }
}
