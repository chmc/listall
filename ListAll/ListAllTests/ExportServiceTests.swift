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
}
