import XCTest
import Foundation
import CoreData
@testable import ListAll

class ImportViewModelTests: XCTestCase {

    // MARK: - ImportViewModel Message Formatting Tests

    /// Helper: creates a JSON string with the given number of lists/items
    private func makeImportJSON(listCount: Int, itemsPerList: Int) -> String {
        var lists: [ListExportData] = []
        for i in 0..<listCount {
            var items: [ItemExportData] = []
            for j in 0..<itemsPerList {
                items.append(ItemExportData(title: "Item \(j)"))
            }
            lists.append(ListExportData(name: "List \(i)", items: items))
        }
        let exportData = ExportData(lists: lists)
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try! encoder.encode(exportData)
        return String(data: data, encoding: .utf8)!
    }

    func testImportViewModelSingularMessage() throws {
        let testDataManager = TestHelpers.createTestDataManager()
        let repository = TestDataRepository(dataManager: testDataManager)
        let importService = ImportService(dataRepository: repository)
        let vm = ImportViewModel(importService: importService)

        let json = makeImportJSON(listCount: 1, itemsPerList: 1)
        vm.importFromText(json)

        let message = try XCTUnwrap(vm.successMessage, "Expected success message but got error: \(vm.errorMessage ?? "nil")")
        XCTAssertTrue(message.contains("1 list"), "Should use singular 'list', got: \(message)")
        XCTAssertTrue(message.contains("1 item"), "Should use singular 'item', got: \(message)")
    }

    func testImportViewModelPluralMessage() throws {
        let testDataManager = TestHelpers.createTestDataManager()
        let repository = TestDataRepository(dataManager: testDataManager)
        let importService = ImportService(dataRepository: repository)
        let vm = ImportViewModel(importService: importService)

        let json = makeImportJSON(listCount: 2, itemsPerList: 3)
        vm.importFromText(json)

        let message = try XCTUnwrap(vm.successMessage, "Expected success message but got error: \(vm.errorMessage ?? "nil")")
        XCTAssertTrue(message.contains("2 lists"), "Should use plural 'lists', got: \(message)")
        XCTAssertTrue(message.contains("6 items"), "Should use plural 'items', got: \(message)")
    }

    func testImportViewModelUpdateCountMessage() throws {
        let testDataManager = TestHelpers.createTestDataManager()
        let repository = TestDataRepository(dataManager: testDataManager)
        let importService = ImportService(dataRepository: repository)
        let vm = ImportViewModel(importService: importService)

        // Import once to create data
        let json = makeImportJSON(listCount: 1, itemsPerList: 1)
        vm.importFromText(json)

        // Import again with merge strategy to trigger updates
        vm.selectedStrategy = .merge
        vm.importFromText(json)

        let message = try XCTUnwrap(vm.successMessage, "Expected success message but got error: \(vm.errorMessage ?? "nil")")
        XCTAssertTrue(message.contains("Successfully imported"), "Should contain success prefix, got: \(message)")
    }
}
