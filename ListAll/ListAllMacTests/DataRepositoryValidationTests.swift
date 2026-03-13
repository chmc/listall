//
//  DataRepositoryValidationTests.swift
//  ListAllMacTests
//

import XCTest
import CoreData
import Combine
#if os(macOS)
@preconcurrency import AppKit
#endif
@testable import ListAll

#if os(macOS)

final class DataRepositoryValidationTests: XCTestCase {

    // MARK: - Helper to check if all results are success
    private func allValid(_ results: [ValidationResult]) -> Bool {
        results.allSatisfy { $0.isValid }
    }

    private func hasFailure(_ results: [ValidationResult]) -> Bool {
        results.contains { !$0.isValid }
    }

    // MARK: - List Validation Tests (using ValidationHelper directly)

    /// Test validateListName with valid name
    func testValidateListNameValid() {
        let result = ValidationHelper.validateListName("Valid List")
        XCTAssertTrue(result.isValid)
    }

    /// Test validateListName with empty name
    func testValidateListNameEmpty() {
        let result = ValidationHelper.validateListName("")
        XCTAssertFalse(result.isValid)
    }

    /// Test validateListName with whitespace-only name
    func testValidateListNameWhitespace() {
        let result = ValidationHelper.validateListName("   ")
        XCTAssertFalse(result.isValid)
    }

    /// Test validateListName with name exceeding max length
    func testValidateListNameTooLong() {
        let longName = String(repeating: "a", count: 101)
        let result = ValidationHelper.validateListName(longName)
        XCTAssertFalse(result.isValid)
    }

    /// Test validateList with valid list (returns array)
    func testValidateListValid() {
        let list = List(name: "Valid List")
        let results = ValidationHelper.validateList(list)
        XCTAssertTrue(allValid(results))
    }

    /// Test validateList with empty name (returns array)
    func testValidateListEmptyName() {
        let list = List(name: "")
        let results = ValidationHelper.validateList(list)
        XCTAssertTrue(hasFailure(results))
    }

    // MARK: - Item Validation Tests

    /// Test validateItemTitle with valid title
    func testValidateItemTitleValid() {
        let result = ValidationHelper.validateItemTitle("Valid Item")
        XCTAssertTrue(result.isValid)
    }

    /// Test validateItemTitle with empty title
    func testValidateItemTitleEmpty() {
        let result = ValidationHelper.validateItemTitle("")
        XCTAssertFalse(result.isValid)
    }

    /// Test validateItemTitle with title exceeding max length
    func testValidateItemTitleTooLong() {
        let longTitle = String(repeating: "a", count: 201)
        let result = ValidationHelper.validateItemTitle(longTitle)
        XCTAssertFalse(result.isValid)
    }

    /// Test validateItemQuantity with valid quantity
    func testValidateItemQuantityValid() {
        let result = ValidationHelper.validateItemQuantity(1)
        XCTAssertTrue(result.isValid)
    }

    /// Test validateItemQuantity with invalid quantity
    func testValidateItemQuantityInvalid() {
        let result = ValidationHelper.validateItemQuantity(0)
        XCTAssertFalse(result.isValid)
    }

    /// Test validateItemDescription with valid description
    func testValidateItemDescriptionValid() {
        let result = ValidationHelper.validateItemDescription("A short description")
        XCTAssertTrue(result.isValid)
    }

    /// Test validateItemDescription with nil (valid)
    func testValidateItemDescriptionNil() {
        let result = ValidationHelper.validateItemDescription(nil)
        XCTAssertTrue(result.isValid)
    }

    /// Test validateItemDescription with description exceeding max length
    func testValidateItemDescriptionTooLong() {
        let longDesc = String(repeating: "a", count: 1001)
        let result = ValidationHelper.validateItemDescription(longDesc)
        XCTAssertFalse(result.isValid)
    }

    /// Test validateItem with valid item (returns array)
    func testValidateItemValid() {
        var item = Item(title: "Valid Item")
        item.quantity = 1
        let results = ValidationHelper.validateItem(item)
        XCTAssertTrue(allValid(results))
    }

    /// Test validateItem with empty title (returns array)
    func testValidateItemEmptyTitle() {
        let item = Item(title: "")
        let results = ValidationHelper.validateItem(item)
        XCTAssertTrue(hasFailure(results))
    }

    // MARK: - Image Validation Tests

    /// Test validateImageData with nil data
    func testValidateImageDataNil() {
        let result = ValidationHelper.validateImageData(nil)
        XCTAssertFalse(result.isValid)
    }

    /// Test validateImageData with oversized data
    func testValidateImageDataOversized() {
        let oversizedData = Data(count: 6 * 1024 * 1024) // 6MB
        let result = ValidationHelper.validateImageData(oversizedData)
        XCTAssertFalse(result.isValid)
    }

    /// Test validateImageCount with valid count
    func testValidateImageCountValid() {
        let result = ValidationHelper.validateImageCount(5)
        XCTAssertTrue(result.isValid)
    }

    /// Test validateImageCount with too many images
    func testValidateImageCountTooMany() {
        let result = ValidationHelper.validateImageCount(11)
        XCTAssertFalse(result.isValid)
    }

    // MARK: - Model Tests (pure unit tests, no file access)

    /// Test List model creation
    func testListModelCreation() {
        let list = List(name: "Test List")

        XCTAssertEqual(list.name, "Test List")
        XCTAssertNotNil(list.id)
        XCTAssertNotNil(list.createdAt)
    }

    /// Test List with special characters
    func testListWithSpecialCharacters() {
        let list = List(name: "Test 📝 émojis!")

        XCTAssertEqual(list.name, "Test 📝 émojis!")
    }

    /// Test Item model creation
    func testItemModelCreation() {
        let item = Item(title: "Test Item")

        XCTAssertEqual(item.title, "Test Item")
        XCTAssertNotNil(item.id)
        XCTAssertEqual(item.quantity, 1)
        XCTAssertFalse(item.isCrossedOut)
    }

    /// Test Item toggleCrossedOut
    func testItemToggleCrossedOut() {
        var item = Item(title: "Test")
        XCTAssertFalse(item.isCrossedOut)

        item.toggleCrossedOut()
        XCTAssertTrue(item.isCrossedOut)

        item.toggleCrossedOut()
        XCTAssertFalse(item.isCrossedOut)
    }

    /// Test ItemImage model creation
    func testItemImageModelCreation() {
        let imageData = Data("test".utf8)
        let image = ItemImage(imageData: imageData)

        XCTAssertNotNil(image.id)
        XCTAssertEqual(image.imageData, imageData)
    }

    // MARK: - Platform-Specific Test

    /// Verify that the test is running on macOS
    func testRunningOnMacOS() {
        #if os(macOS)
        XCTAssertTrue(true, "Test is running on macOS")
        #else
        XCTFail("This test should only run on macOS")
        #endif
    }
}

#endif

// MARK: - ValidationResult Helper
/// Helper extension for validation result assertions
extension ValidationResult {
    var isValid: Bool {
        switch self {
        case .success: return true
        case .failure: return false
        }
    }
}
