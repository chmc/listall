//
//  ListAllMacTests.swift
//  ListAllMacTests
//
//  Created by Aleksi Sutela on 5.12.2025.
//

import XCTest
import CoreData
@testable import ListAllMac

/// Unit tests for Core Data model extensions on macOS
/// Verifies that all entity extensions (ListEntity, ItemEntity, ItemImageEntity, UserDataEntity)
/// compile and function correctly on the macOS platform.
final class ListAllMacTests: XCTestCase {

    var testContainer: NSPersistentContainer!
    var testContext: NSManagedObjectContext!

    override func setUpWithError() throws {
        try super.setUpWithError()

        // Create in-memory Core Data stack for testing
        testContainer = NSPersistentContainer(name: "ListAll")

        let description = NSPersistentStoreDescription()
        description.type = NSInMemoryStoreType
        description.url = URL(fileURLWithPath: "/dev/null")
        testContainer.persistentStoreDescriptions = [description]

        let expectation = XCTestExpectation(description: "Load stores")
        testContainer.loadPersistentStores { _, error in
            XCTAssertNil(error, "Failed to load in-memory store: \(error?.localizedDescription ?? "unknown")")
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 5.0)

        testContext = testContainer.viewContext
        testContext.automaticallyMergesChangesFromParent = true
        testContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
    }

    override func tearDownWithError() throws {
        testContext = nil
        testContainer = nil
        try super.tearDownWithError()
    }

    // MARK: - ListEntity Extension Tests

    /// Test that ListEntity.toList() correctly converts entity to model
    func testListEntityToList() throws {
        // Given
        let listEntity = ListEntity(context: testContext)
        let testId = UUID()
        let testName = "Test List"
        let testCreatedAt = Date()
        let testModifiedAt = Date().addingTimeInterval(3600)

        listEntity.id = testId
        listEntity.name = testName
        listEntity.orderNumber = 5
        listEntity.createdAt = testCreatedAt
        listEntity.modifiedAt = testModifiedAt
        listEntity.isArchived = true

        // When
        let list = listEntity.toList()

        // Then
        XCTAssertEqual(list.id, testId)
        XCTAssertEqual(list.name, testName)
        XCTAssertEqual(list.orderNumber, 5)
        XCTAssertEqual(list.createdAt, testCreatedAt)
        XCTAssertEqual(list.modifiedAt, testModifiedAt)
        XCTAssertTrue(list.isArchived)
    }

    /// Test that ListEntity.toList() handles nil values with defaults
    func testListEntityToListWithNilValues() throws {
        // Given
        let listEntity = ListEntity(context: testContext)
        // Leave all optional values nil

        // When
        let list = listEntity.toList()

        // Then
        XCTAssertEqual(list.name, "Untitled List")
        XCTAssertNotNil(list.id)
        XCTAssertNotNil(list.createdAt)
        XCTAssertNotNil(list.modifiedAt)
    }

    /// Test that ListEntity.fromList() correctly creates entity from model
    func testListEntityFromList() throws {
        // Given
        var list = List(name: "New List")
        list.orderNumber = 3
        list.isArchived = true

        // When
        let listEntity = ListEntity.fromList(list, context: testContext)

        // Then
        XCTAssertEqual(listEntity.id, list.id)
        XCTAssertEqual(listEntity.name, list.name)
        XCTAssertEqual(listEntity.orderNumber, Int32(list.orderNumber))
        XCTAssertEqual(listEntity.createdAt, list.createdAt)
        XCTAssertEqual(listEntity.modifiedAt, list.modifiedAt)
        XCTAssertTrue(listEntity.isArchived)
    }

    /// Test round-trip conversion: List → ListEntity → List
    func testListEntityRoundTrip() throws {
        // Given
        var originalList = List(name: "Round Trip Test")
        originalList.orderNumber = 7
        originalList.isArchived = false

        // When: Convert to entity and back
        let listEntity = ListEntity.fromList(originalList, context: testContext)
        let convertedList = listEntity.toList()

        // Then
        XCTAssertEqual(convertedList.id, originalList.id)
        XCTAssertEqual(convertedList.name, originalList.name)
        XCTAssertEqual(convertedList.orderNumber, originalList.orderNumber)
        XCTAssertEqual(convertedList.isArchived, originalList.isArchived)
    }

    // MARK: - ItemEntity Extension Tests

    /// Test that ItemEntity.toItem() correctly converts entity to model
    func testItemEntityToItem() throws {
        // Given
        let itemEntity = ItemEntity(context: testContext)
        let testId = UUID()
        let testTitle = "Test Item"
        let testDescription = "Test description"
        let testCreatedAt = Date()
        let testModifiedAt = Date().addingTimeInterval(1800)

        itemEntity.id = testId
        itemEntity.title = testTitle
        itemEntity.itemDescription = testDescription
        itemEntity.quantity = 3
        itemEntity.orderNumber = 2
        itemEntity.isCrossedOut = true
        itemEntity.createdAt = testCreatedAt
        itemEntity.modifiedAt = testModifiedAt

        // When
        let item = itemEntity.toItem()

        // Then
        XCTAssertEqual(item.id, testId)
        XCTAssertEqual(item.title, testTitle)
        XCTAssertEqual(item.itemDescription, testDescription)
        XCTAssertEqual(item.quantity, 3)
        XCTAssertEqual(item.orderNumber, 2)
        XCTAssertTrue(item.isCrossedOut)
        XCTAssertEqual(item.createdAt, testCreatedAt)
        XCTAssertEqual(item.modifiedAt, testModifiedAt)
    }

    /// Test that ItemEntity.toItem() handles nil values with defaults
    func testItemEntityToItemWithNilValues() throws {
        // Given
        let itemEntity = ItemEntity(context: testContext)
        // Leave all optional values nil

        // When
        let item = itemEntity.toItem()

        // Then
        XCTAssertEqual(item.title, "Untitled Item")
        XCTAssertNotNil(item.id)
        XCTAssertNil(item.itemDescription)
        XCTAssertNotNil(item.createdAt)
        XCTAssertNotNil(item.modifiedAt)
    }

    /// Test that ItemEntity.fromItem() correctly creates entity from model
    func testItemEntityFromItem() throws {
        // Given
        var item = Item(title: "New Item")
        item.itemDescription = "Item description"
        item.quantity = 5
        item.orderNumber = 10
        item.isCrossedOut = true

        // When
        let itemEntity = ItemEntity.fromItem(item, context: testContext)

        // Then
        XCTAssertEqual(itemEntity.id, item.id)
        XCTAssertEqual(itemEntity.title, item.title)
        XCTAssertEqual(itemEntity.itemDescription, item.itemDescription)
        XCTAssertEqual(itemEntity.quantity, Int32(item.quantity))
        XCTAssertEqual(itemEntity.orderNumber, Int32(item.orderNumber))
        XCTAssertTrue(itemEntity.isCrossedOut)
        XCTAssertEqual(itemEntity.createdAt, item.createdAt)
        XCTAssertEqual(itemEntity.modifiedAt, item.modifiedAt)
    }

    /// Test round-trip conversion: Item → ItemEntity → Item
    func testItemEntityRoundTrip() throws {
        // Given
        var originalItem = Item(title: "Round Trip Item")
        originalItem.itemDescription = "Description for round trip"
        originalItem.quantity = 2
        originalItem.orderNumber = 5
        originalItem.isCrossedOut = false

        // When: Convert to entity and back
        let itemEntity = ItemEntity.fromItem(originalItem, context: testContext)
        let convertedItem = itemEntity.toItem()

        // Then
        XCTAssertEqual(convertedItem.id, originalItem.id)
        XCTAssertEqual(convertedItem.title, originalItem.title)
        XCTAssertEqual(convertedItem.itemDescription, originalItem.itemDescription)
        XCTAssertEqual(convertedItem.quantity, originalItem.quantity)
        XCTAssertEqual(convertedItem.orderNumber, originalItem.orderNumber)
        XCTAssertEqual(convertedItem.isCrossedOut, originalItem.isCrossedOut)
    }

    // MARK: - ItemImageEntity Extension Tests

    /// Test that ItemImageEntity.toItemImage() correctly converts entity to model
    func testItemImageEntityToItemImage() throws {
        // Given
        let imageEntity = ItemImageEntity(context: testContext)
        let testId = UUID()
        let testImageData = Data("test image data".utf8)
        let testCreatedAt = Date()

        imageEntity.id = testId
        imageEntity.imageData = testImageData
        imageEntity.orderNumber = 3
        imageEntity.createdAt = testCreatedAt

        // When
        let itemImage = imageEntity.toItemImage()

        // Then
        XCTAssertEqual(itemImage.id, testId)
        XCTAssertEqual(itemImage.imageData, testImageData)
        XCTAssertEqual(itemImage.orderNumber, 3)
        XCTAssertEqual(itemImage.createdAt, testCreatedAt)
    }

    /// Test that ItemImageEntity.toItemImage() handles nil values with defaults
    func testItemImageEntityToItemImageWithNilValues() throws {
        // Given
        let imageEntity = ItemImageEntity(context: testContext)
        // Leave all optional values nil

        // When
        let itemImage = imageEntity.toItemImage()

        // Then
        XCTAssertNotNil(itemImage.id)
        XCTAssertNil(itemImage.imageData)
        XCTAssertNotNil(itemImage.createdAt)
    }

    /// Test that ItemImageEntity.fromItemImage() correctly creates entity from model
    func testItemImageEntityFromItemImage() throws {
        // Given
        let testImageData = Data("sample image data".utf8)
        let testItemId = UUID()
        var itemImage = ItemImage(imageData: testImageData, itemId: testItemId)
        itemImage.orderNumber = 2

        // When
        let imageEntity = ItemImageEntity.fromItemImage(itemImage, context: testContext)

        // Then
        XCTAssertEqual(imageEntity.id, itemImage.id)
        XCTAssertEqual(imageEntity.imageData, itemImage.imageData)
        XCTAssertEqual(imageEntity.orderNumber, Int32(itemImage.orderNumber))
        XCTAssertEqual(imageEntity.createdAt, itemImage.createdAt)
    }

    /// Test round-trip conversion: ItemImage → ItemImageEntity → ItemImage
    func testItemImageEntityRoundTrip() throws {
        // Given
        let testImageData = Data(count: 1024) // 1KB of zeros
        var originalImage = ItemImage(imageData: testImageData)
        originalImage.orderNumber = 4

        // When: Convert to entity and back
        let imageEntity = ItemImageEntity.fromItemImage(originalImage, context: testContext)
        let convertedImage = imageEntity.toItemImage()

        // Then
        XCTAssertEqual(convertedImage.id, originalImage.id)
        XCTAssertEqual(convertedImage.imageData, originalImage.imageData)
        XCTAssertEqual(convertedImage.orderNumber, originalImage.orderNumber)
    }

    // MARK: - UserDataEntity Extension Tests

    /// Test that UserDataEntity.toUserData() correctly converts entity to model
    func testUserDataEntityToUserData() throws {
        // Given
        let userDataEntity = UserDataEntity(context: testContext)
        let testId = UUID()
        let testUserId = "test_user_123"
        let testCreatedAt = Date()
        let testLastSync = Date().addingTimeInterval(-3600)

        userDataEntity.id = testId
        userDataEntity.userID = testUserId
        userDataEntity.showCrossedOutItems = false
        userDataEntity.createdAt = testCreatedAt
        userDataEntity.lastSyncDate = testLastSync

        // When
        let userData = userDataEntity.toUserData()

        // Then
        XCTAssertEqual(userData.id, testId)
        XCTAssertEqual(userData.userID, testUserId)
        XCTAssertFalse(userData.showCrossedOutItems)
        XCTAssertEqual(userData.createdAt, testCreatedAt)
        XCTAssertEqual(userData.lastSyncDate, testLastSync)
    }

    /// Test that UserDataEntity.toUserData() handles nil values with defaults
    func testUserDataEntityToUserDataWithNilValues() throws {
        // Given
        let userDataEntity = UserDataEntity(context: testContext)
        // Leave all optional values nil

        // When
        let userData = userDataEntity.toUserData()

        // Then
        XCTAssertEqual(userData.userID, "unknown")
        XCTAssertNotNil(userData.id)
        XCTAssertNotNil(userData.createdAt)
    }

    /// Test that UserDataEntity.fromUserData() correctly creates entity from model
    func testUserDataEntityFromUserData() throws {
        // Given
        var userData = UserData(userID: "new_user_456")
        userData.showCrossedOutItems = true
        userData.lastSyncDate = Date()
        userData.defaultSortOption = .title
        userData.defaultSortDirection = .descending
        userData.defaultFilterOption = .completed

        // When
        let userDataEntity = UserDataEntity.fromUserData(userData, context: testContext)

        // Then
        XCTAssertEqual(userDataEntity.id, userData.id)
        XCTAssertEqual(userDataEntity.userID, userData.userID)
        XCTAssertTrue(userDataEntity.showCrossedOutItems)
        XCTAssertEqual(userDataEntity.createdAt, userData.createdAt)
        XCTAssertEqual(userDataEntity.lastSyncDate, userData.lastSyncDate)
    }

    /// Test that UserDataEntity preserves organization preferences in JSON
    func testUserDataEntityPreferencesRoundTrip() throws {
        // Given
        var originalUserData = UserData(userID: "pref_user")
        originalUserData.defaultSortOption = .modifiedAt
        originalUserData.defaultSortDirection = .descending
        originalUserData.defaultFilterOption = .hasImages

        // When: Convert to entity and back
        let userDataEntity = UserDataEntity.fromUserData(originalUserData, context: testContext)
        let convertedUserData = userDataEntity.toUserData()

        // Then
        XCTAssertEqual(convertedUserData.defaultSortOption, originalUserData.defaultSortOption)
        XCTAssertEqual(convertedUserData.defaultSortDirection, originalUserData.defaultSortDirection)
        XCTAssertEqual(convertedUserData.defaultFilterOption, originalUserData.defaultFilterOption)
    }

    /// Test round-trip conversion: UserData → UserDataEntity → UserData
    func testUserDataEntityRoundTrip() throws {
        // Given
        var originalUserData = UserData(userID: "round_trip_user")
        originalUserData.showCrossedOutItems = false
        originalUserData.lastSyncDate = Date()

        // When: Convert to entity and back
        let userDataEntity = UserDataEntity.fromUserData(originalUserData, context: testContext)
        let convertedUserData = userDataEntity.toUserData()

        // Then
        XCTAssertEqual(convertedUserData.id, originalUserData.id)
        XCTAssertEqual(convertedUserData.userID, originalUserData.userID)
        XCTAssertEqual(convertedUserData.showCrossedOutItems, originalUserData.showCrossedOutItems)
    }

    // MARK: - Integration Tests

    /// Test that ListEntity properly includes items via relationship
    func testListEntityWithItems() throws {
        // Given
        let listEntity = ListEntity(context: testContext)
        listEntity.id = UUID()
        listEntity.name = "List with Items"
        listEntity.orderNumber = 0
        listEntity.createdAt = Date()
        listEntity.modifiedAt = Date()

        let itemEntity1 = ItemEntity(context: testContext)
        itemEntity1.id = UUID()
        itemEntity1.title = "Item 1"
        itemEntity1.orderNumber = 0
        itemEntity1.list = listEntity

        let itemEntity2 = ItemEntity(context: testContext)
        itemEntity2.id = UUID()
        itemEntity2.title = "Item 2"
        itemEntity2.orderNumber = 1
        itemEntity2.list = listEntity

        try testContext.save()

        // When
        let list = listEntity.toList()

        // Then
        XCTAssertEqual(list.items.count, 2)
        XCTAssertTrue(list.items.contains(where: { $0.title == "Item 1" }))
        XCTAssertTrue(list.items.contains(where: { $0.title == "Item 2" }))
    }

    /// Test that ItemEntity properly includes images via relationship
    func testItemEntityWithImages() throws {
        // Given
        let itemEntity = ItemEntity(context: testContext)
        itemEntity.id = UUID()
        itemEntity.title = "Item with Images"
        itemEntity.orderNumber = 0
        itemEntity.createdAt = Date()
        itemEntity.modifiedAt = Date()

        let imageEntity1 = ItemImageEntity(context: testContext)
        imageEntity1.id = UUID()
        imageEntity1.imageData = Data("image1".utf8)
        imageEntity1.orderNumber = 0
        imageEntity1.item = itemEntity

        let imageEntity2 = ItemImageEntity(context: testContext)
        imageEntity2.id = UUID()
        imageEntity2.imageData = Data("image2".utf8)
        imageEntity2.orderNumber = 1
        imageEntity2.item = itemEntity

        try testContext.save()

        // When
        let item = itemEntity.toItem()

        // Then
        XCTAssertEqual(item.images.count, 2)
        XCTAssertEqual(item.images[0].orderNumber, 0)
        XCTAssertEqual(item.images[1].orderNumber, 1)
    }

    // MARK: - macOS Platform Test

    /// Verify that the test is running on macOS
    func testRunningOnMacOS() throws {
        #if os(macOS)
        XCTAssertTrue(true, "Test is running on macOS")
        #else
        XCTFail("This test should only run on macOS")
        #endif
    }

    // MARK: - Performance Tests

    func testListEntityConversionPerformance() throws {
        // Create a list with many items
        let listEntity = ListEntity(context: testContext)
        listEntity.id = UUID()
        listEntity.name = "Performance Test List"
        listEntity.orderNumber = 0
        listEntity.createdAt = Date()
        listEntity.modifiedAt = Date()

        for i in 0..<100 {
            let itemEntity = ItemEntity(context: testContext)
            itemEntity.id = UUID()
            itemEntity.title = "Item \(i)"
            itemEntity.orderNumber = Int32(i)
            itemEntity.list = listEntity
        }

        try testContext.save()

        measure {
            _ = listEntity.toList()
        }
    }
}
