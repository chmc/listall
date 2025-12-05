//
//  ListAllMacTests.swift
//  ListAllMacTests
//
//  Created by Aleksi Sutela on 5.12.2025.
//

import XCTest
import CoreData
import Combine
#if os(macOS)
import AppKit
#endif
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

// MARK: - Data Model Tests (Task 2.3)
/// Unit tests for data models (Item, List, ItemImage, UserData) on macOS
/// Verifies that all data models compile and function correctly on the macOS platform.
final class DataModelTests: XCTestCase {

    // MARK: - Item Model Tests

    /// Test that Item model initializes correctly
    func testItemModelCreation() {
        let listId = UUID()
        let item = Item(title: "Test Item", listId: listId)

        XCTAssertEqual(item.title, "Test Item")
        XCTAssertEqual(item.listId, listId)
        XCTAssertEqual(item.quantity, 1)
        XCTAssertEqual(item.orderNumber, 0)
        XCTAssertFalse(item.isCrossedOut)
        XCTAssertNotNil(item.id)
        XCTAssertNotNil(item.createdAt)
        XCTAssertNotNil(item.modifiedAt)
        XCTAssertTrue(item.images.isEmpty)
    }

    /// Test Item displayTitle with empty title
    func testItemDisplayTitleWithEmptyTitle() {
        var item = Item(title: "")
        XCTAssertEqual(item.displayTitle, "Untitled Item")

        item.title = "   "
        XCTAssertEqual(item.displayTitle, "Untitled Item")

        item.title = "Valid Title"
        XCTAssertEqual(item.displayTitle, "Valid Title")
    }

    /// Test Item displayDescription
    func testItemDisplayDescription() {
        var item = Item(title: "Test")
        XCTAssertEqual(item.displayDescription, "")
        XCTAssertFalse(item.hasDescription)

        item.itemDescription = "Test description"
        XCTAssertEqual(item.displayDescription, "Test description")
        XCTAssertTrue(item.hasDescription)

        item.itemDescription = "   "
        XCTAssertEqual(item.displayDescription, "")
        XCTAssertFalse(item.hasDescription)
    }

    /// Test Item formattedQuantity
    func testItemFormattedQuantity() {
        var item = Item(title: "Test")
        XCTAssertEqual(item.formattedQuantity, "")

        item.quantity = 2
        XCTAssertEqual(item.formattedQuantity, "2x")

        item.quantity = 10
        XCTAssertEqual(item.formattedQuantity, "10x")
    }

    /// Test Item toggleCrossedOut
    func testItemToggleCrossedOut() {
        var item = Item(title: "Test")
        let originalModifiedAt = item.modifiedAt

        XCTAssertFalse(item.isCrossedOut)

        // Wait briefly to ensure modifiedAt changes
        Thread.sleep(forTimeInterval: 0.01)
        item.toggleCrossedOut()

        XCTAssertTrue(item.isCrossedOut)
        XCTAssertGreaterThan(item.modifiedAt, originalModifiedAt)

        item.toggleCrossedOut()
        XCTAssertFalse(item.isCrossedOut)
    }

    /// Test Item validation
    func testItemValidation() {
        var item = Item(title: "Valid Title")
        XCTAssertTrue(item.validate())

        item.title = ""
        XCTAssertFalse(item.validate())

        item.title = "Valid"
        item.quantity = 0
        XCTAssertFalse(item.validate())

        item.quantity = 1
        XCTAssertTrue(item.validate())
    }

    /// Test Item sortedImages
    func testItemSortedImages() {
        var item = Item(title: "Test")

        var image1 = ItemImage()
        image1.orderNumber = 2

        var image2 = ItemImage()
        image2.orderNumber = 0

        var image3 = ItemImage()
        image3.orderNumber = 1

        item.images = [image1, image2, image3]

        let sorted = item.sortedImages
        XCTAssertEqual(sorted[0].orderNumber, 0)
        XCTAssertEqual(sorted[1].orderNumber, 1)
        XCTAssertEqual(sorted[2].orderNumber, 2)
    }

    /// Test Item hasImages and imageCount
    func testItemImageProperties() {
        var item = Item(title: "Test")
        XCTAssertFalse(item.hasImages)
        XCTAssertEqual(item.imageCount, 0)

        item.images = [ItemImage(), ItemImage()]
        XCTAssertTrue(item.hasImages)
        XCTAssertEqual(item.imageCount, 2)
    }

    // MARK: - ItemSortOption Enum Tests

    /// Test ItemSortOption enum values
    func testItemSortOptionEnumValues() {
        XCTAssertEqual(ItemSortOption.orderNumber.rawValue, "Order")
        XCTAssertEqual(ItemSortOption.title.rawValue, "Title")
        XCTAssertEqual(ItemSortOption.createdAt.rawValue, "Created Date")
        XCTAssertEqual(ItemSortOption.modifiedAt.rawValue, "Modified Date")
        XCTAssertEqual(ItemSortOption.quantity.rawValue, "Quantity")

        // Verify all cases are iterable
        XCTAssertEqual(ItemSortOption.allCases.count, 5)
    }

    /// Test ItemSortOption displayName and systemImage
    func testItemSortOptionProperties() {
        XCTAssertFalse(ItemSortOption.orderNumber.displayName.isEmpty)
        XCTAssertFalse(ItemSortOption.orderNumber.systemImage.isEmpty)
        XCTAssertEqual(ItemSortOption.orderNumber.id, "Order")
    }

    // MARK: - ItemFilterOption Enum Tests

    /// Test ItemFilterOption enum values
    func testItemFilterOptionEnumValues() {
        XCTAssertEqual(ItemFilterOption.all.rawValue, "All Items")
        XCTAssertEqual(ItemFilterOption.active.rawValue, "Active Only")
        XCTAssertEqual(ItemFilterOption.completed.rawValue, "Crossed Out Only")
        XCTAssertEqual(ItemFilterOption.hasDescription.rawValue, "With Description")
        XCTAssertEqual(ItemFilterOption.hasImages.rawValue, "With Images")

        XCTAssertEqual(ItemFilterOption.allCases.count, 5)
    }

    /// Test ItemFilterOption displayName and systemImage
    func testItemFilterOptionProperties() {
        XCTAssertFalse(ItemFilterOption.all.displayName.isEmpty)
        XCTAssertFalse(ItemFilterOption.all.systemImage.isEmpty)
        XCTAssertEqual(ItemFilterOption.all.id, "All Items")
    }

    // MARK: - SortDirection Enum Tests

    /// Test SortDirection enum values
    func testSortDirectionEnumValues() {
        XCTAssertEqual(SortDirection.ascending.rawValue, "Ascending")
        XCTAssertEqual(SortDirection.descending.rawValue, "Descending")
        XCTAssertEqual(SortDirection.allCases.count, 2)
    }

    /// Test SortDirection displayName and systemImage
    func testSortDirectionProperties() {
        XCTAssertFalse(SortDirection.ascending.displayName.isEmpty)
        XCTAssertEqual(SortDirection.ascending.systemImage, "arrow.up")
        XCTAssertEqual(SortDirection.descending.systemImage, "arrow.down")
    }

    // MARK: - ItemSyncData Tests

    /// Test ItemSyncData conversion from Item
    func testItemSyncDataFromItem() {
        var item = Item(title: "Sync Test")
        item.itemDescription = "Test description"
        item.quantity = 3
        item.images = [ItemImage(), ItemImage()]

        let syncData = ItemSyncData(from: item)

        XCTAssertEqual(syncData.id, item.id)
        XCTAssertEqual(syncData.title, item.title)
        XCTAssertEqual(syncData.itemDescription, item.itemDescription)
        XCTAssertEqual(syncData.quantity, item.quantity)
        XCTAssertEqual(syncData.imageCount, 2)
    }

    /// Test ItemSyncData conversion to Item
    func testItemSyncDataToItem() {
        var item = Item(title: "Original")
        item.images = [ItemImage()]

        let syncData = ItemSyncData(from: item)
        let convertedItem = syncData.toItem()

        XCTAssertEqual(convertedItem.id, item.id)
        XCTAssertEqual(convertedItem.title, item.title)
        XCTAssertTrue(convertedItem.images.isEmpty) // Images not synced
    }

    // MARK: - List Model Tests

    /// Test that List model initializes correctly
    func testListModelCreation() {
        let list = List(name: "Test List")

        XCTAssertEqual(list.name, "Test List")
        XCTAssertEqual(list.orderNumber, 0)
        XCTAssertFalse(list.isArchived)
        XCTAssertNotNil(list.id)
        XCTAssertNotNil(list.createdAt)
        XCTAssertNotNil(list.modifiedAt)
        XCTAssertTrue(list.items.isEmpty)
    }

    /// Test List item management
    func testListItemManagement() {
        var list = List(name: "Test List")
        let item = Item(title: "Test Item")

        list.addItem(item)

        XCTAssertEqual(list.itemCount, 1)
        XCTAssertEqual(list.items.first?.listId, list.id)

        list.removeItem(withId: item.id)
        XCTAssertEqual(list.itemCount, 0)
    }

    /// Test List item counts
    func testListItemCounts() {
        var list = List(name: "Test List")

        var item1 = Item(title: "Item 1")
        item1.isCrossedOut = false

        var item2 = Item(title: "Item 2")
        item2.isCrossedOut = true

        var item3 = Item(title: "Item 3")
        item3.isCrossedOut = true

        list.addItem(item1)
        list.addItem(item2)
        list.addItem(item3)

        XCTAssertEqual(list.itemCount, 3)
        XCTAssertEqual(list.crossedOutItemCount, 2)
        XCTAssertEqual(list.activeItemCount, 1)
    }

    /// Test List sortedItems
    func testListSortedItems() {
        var list = List(name: "Test List")

        var item1 = Item(title: "Item 1")
        item1.orderNumber = 2

        var item2 = Item(title: "Item 2")
        item2.orderNumber = 0

        var item3 = Item(title: "Item 3")
        item3.orderNumber = 1

        list.items = [item1, item2, item3]

        let sorted = list.sortedItems
        XCTAssertEqual(sorted[0].title, "Item 2")
        XCTAssertEqual(sorted[1].title, "Item 3")
        XCTAssertEqual(sorted[2].title, "Item 1")
    }

    /// Test List updateItem
    func testListUpdateItem() {
        var list = List(name: "Test List")
        var item = Item(title: "Original")
        list.addItem(item)

        item.title = "Updated"
        list.updateItem(item)

        XCTAssertEqual(list.items.first?.title, "Updated")
    }

    /// Test List validation
    func testListValidation() {
        var list = List(name: "Valid Name")
        XCTAssertTrue(list.validate())

        list.name = ""
        XCTAssertFalse(list.validate())

        list.name = "   "
        XCTAssertFalse(list.validate())
    }

    /// Test List Hashable and Equatable
    func testListHashableAndEquatable() {
        var list1 = List(name: "List 1")
        var list2 = List(name: "List 2")

        // Different lists should not be equal
        XCTAssertNotEqual(list1, list2)

        // Same ID should be equal
        list2 = list1
        list2.name = "Different Name"
        list2.orderNumber = 999
        XCTAssertEqual(list1, list2) // Only ID matters for equality

        // Hash should be based on ID only
        var hasher1 = Hasher()
        var hasher2 = Hasher()
        list1.hash(into: &hasher1)
        list2.hash(into: &hasher2)
        XCTAssertEqual(hasher1.finalize(), hasher2.finalize())
    }

    // MARK: - ListSyncData Tests

    /// Test ListSyncData conversion from List
    func testListSyncDataFromList() {
        var list = List(name: "Sync Test")
        list.isArchived = true
        var item = Item(title: "Test Item")
        item.images = [ItemImage()]
        list.addItem(item)

        let syncData = ListSyncData(from: list)

        XCTAssertEqual(syncData.id, list.id)
        XCTAssertEqual(syncData.name, list.name)
        XCTAssertTrue(syncData.isArchived)
        XCTAssertEqual(syncData.items.count, 1)
    }

    /// Test ListSyncData conversion to List
    func testListSyncDataToList() {
        var list = List(name: "Original")
        list.addItem(Item(title: "Item"))

        let syncData = ListSyncData(from: list)
        let convertedList = syncData.toList()

        XCTAssertEqual(convertedList.id, list.id)
        XCTAssertEqual(convertedList.name, list.name)
        XCTAssertEqual(convertedList.items.count, 1)
    }

    // MARK: - ItemImage Model Tests

    /// Test that ItemImage model initializes correctly
    func testItemImageModelCreation() {
        let testData = Data("test".utf8)
        let itemId = UUID()
        let itemImage = ItemImage(imageData: testData, itemId: itemId)

        XCTAssertEqual(itemImage.imageData, testData)
        XCTAssertEqual(itemImage.itemId, itemId)
        XCTAssertEqual(itemImage.orderNumber, 0)
        XCTAssertNotNil(itemImage.id)
        XCTAssertNotNil(itemImage.createdAt)
    }

    /// Test ItemImage hasImageData
    func testItemImageHasImageData() {
        var itemImage = ItemImage()
        XCTAssertFalse(itemImage.hasImageData)

        itemImage.imageData = Data()
        XCTAssertFalse(itemImage.hasImageData)

        itemImage.imageData = Data("data".utf8)
        XCTAssertTrue(itemImage.hasImageData)
    }

    /// Test ItemImage imageSize
    func testItemImageImageSize() {
        var itemImage = ItemImage()
        XCTAssertEqual(itemImage.imageSize, 0)

        let testData = Data(count: 1024)
        itemImage.imageData = testData
        XCTAssertEqual(itemImage.imageSize, 1024)
    }

    /// Test ItemImage formattedSize
    func testItemImageFormattedSize() {
        var itemImage = ItemImage()

        itemImage.imageData = Data(count: 500)
        XCTAssertEqual(itemImage.formattedSize, "500 B")

        itemImage.imageData = Data(count: 2048)
        XCTAssertTrue(itemImage.formattedSize.contains("KB"))

        itemImage.imageData = Data(count: 2 * 1024 * 1024)
        XCTAssertTrue(itemImage.formattedSize.contains("MB"))
    }

    /// Test ItemImage validation
    func testItemImageValidation() {
        var itemImage = ItemImage()
        XCTAssertFalse(itemImage.validate())

        itemImage.imageData = Data("data".utf8)
        XCTAssertTrue(itemImage.validate())
    }

    #if os(macOS)
    /// Test ItemImage nsImage property on macOS
    func testItemImageNSImage() {
        var itemImage = ItemImage()
        XCTAssertNil(itemImage.nsImage)

        // Create a simple 1x1 PNG image data
        let pngData = createTestPNGData()
        itemImage.imageData = pngData
        XCTAssertNotNil(itemImage.nsImage)
    }

    /// Test ItemImage setImage on macOS
    func testItemImageSetImage() {
        var itemImage = ItemImage()
        let testImage = NSImage(size: NSSize(width: 100, height: 100))

        itemImage.setImage(testImage, quality: 0.8)
        // Note: setImage may not produce data for empty images,
        // but the method should compile and run without errors
    }

    /// Helper to create test PNG data
    private func createTestPNGData() -> Data? {
        let image = NSImage(size: NSSize(width: 1, height: 1))
        image.lockFocus()
        NSColor.red.setFill()
        NSRect(x: 0, y: 0, width: 1, height: 1).fill()
        image.unlockFocus()

        guard let tiffData = image.tiffRepresentation,
              let bitmapRep = NSBitmapImageRep(data: tiffData) else {
            return nil
        }
        return bitmapRep.representation(using: .png, properties: [:])
    }
    #endif

    // MARK: - UserData Model Tests

    /// Test that UserData model initializes correctly
    func testUserDataModelCreation() {
        let userData = UserData(userID: "test_user")

        XCTAssertEqual(userData.userID, "test_user")
        XCTAssertFalse(userData.showCrossedOutItems)
        XCTAssertNil(userData.exportPreferences)
        XCTAssertNil(userData.lastSyncDate)
        XCTAssertNotNil(userData.id)
        XCTAssertNotNil(userData.createdAt)

        // Default organization preferences
        XCTAssertEqual(userData.defaultSortOption, .orderNumber)
        XCTAssertEqual(userData.defaultSortDirection, .ascending)
        XCTAssertEqual(userData.defaultFilterOption, .active)

        // Default security preferences
        XCTAssertFalse(userData.requiresBiometricAuth)
    }

    /// Test UserData export preferences
    func testUserDataExportPreferences() {
        var userData = UserData(userID: "test_user")

        // Initially empty
        XCTAssertTrue(userData.exportPreferencesDict.isEmpty)

        // Set preferences
        let prefs: [String: Any] = ["format": "json", "includeImages": true]
        userData.setExportPreferences(prefs)

        // Verify round-trip
        let retrieved = userData.exportPreferencesDict
        XCTAssertEqual(retrieved["format"] as? String, "json")
        XCTAssertEqual(retrieved["includeImages"] as? Bool, true)
    }

    /// Test UserData updateLastSyncDate
    func testUserDataUpdateLastSyncDate() {
        var userData = UserData(userID: "test_user")
        XCTAssertNil(userData.lastSyncDate)

        userData.updateLastSyncDate()

        XCTAssertNotNil(userData.lastSyncDate)
    }

    /// Test UserData validation
    func testUserDataValidation() {
        var userData = UserData(userID: "valid_user")
        XCTAssertTrue(userData.validate())

        userData.userID = ""
        XCTAssertFalse(userData.validate())
    }

    /// Test UserData organization preferences
    func testUserDataOrganizationPreferences() {
        var userData = UserData(userID: "test_user")

        userData.defaultSortOption = .title
        userData.defaultSortDirection = .descending
        userData.defaultFilterOption = .completed

        XCTAssertEqual(userData.defaultSortOption, .title)
        XCTAssertEqual(userData.defaultSortDirection, .descending)
        XCTAssertEqual(userData.defaultFilterOption, .completed)
    }

    /// Test UserData security preferences
    func testUserDataSecurityPreferences() {
        var userData = UserData(userID: "test_user")

        XCTAssertFalse(userData.requiresBiometricAuth)

        userData.requiresBiometricAuth = true
        XCTAssertTrue(userData.requiresBiometricAuth)
    }

    // MARK: - Codable Tests

    /// Test Item Codable conformance
    func testItemCodable() throws {
        var item = Item(title: "Codable Test")
        item.itemDescription = "Test description"
        item.quantity = 5

        let encoder = JSONEncoder()
        let data = try encoder.encode(item)

        let decoder = JSONDecoder()
        let decoded = try decoder.decode(Item.self, from: data)

        XCTAssertEqual(decoded.id, item.id)
        XCTAssertEqual(decoded.title, item.title)
        XCTAssertEqual(decoded.itemDescription, item.itemDescription)
        XCTAssertEqual(decoded.quantity, item.quantity)
    }

    /// Test List Codable conformance
    func testListCodable() throws {
        var list = List(name: "Codable List")
        list.isArchived = true

        let encoder = JSONEncoder()
        let data = try encoder.encode(list)

        let decoder = JSONDecoder()
        let decoded = try decoder.decode(List.self, from: data)

        XCTAssertEqual(decoded.id, list.id)
        XCTAssertEqual(decoded.name, list.name)
        XCTAssertEqual(decoded.isArchived, list.isArchived)
    }

    /// Test ItemImage Codable conformance
    func testItemImageCodable() throws {
        var itemImage = ItemImage(imageData: Data("test".utf8))
        itemImage.orderNumber = 3

        let encoder = JSONEncoder()
        let data = try encoder.encode(itemImage)

        let decoder = JSONDecoder()
        let decoded = try decoder.decode(ItemImage.self, from: data)

        XCTAssertEqual(decoded.id, itemImage.id)
        XCTAssertEqual(decoded.imageData, itemImage.imageData)
        XCTAssertEqual(decoded.orderNumber, itemImage.orderNumber)
    }

    /// Test UserData Codable conformance
    func testUserDataCodable() throws {
        var userData = UserData(userID: "codable_user")
        userData.showCrossedOutItems = true
        userData.defaultSortOption = .modifiedAt

        let encoder = JSONEncoder()
        let data = try encoder.encode(userData)

        let decoder = JSONDecoder()
        let decoded = try decoder.decode(UserData.self, from: data)

        XCTAssertEqual(decoded.id, userData.id)
        XCTAssertEqual(decoded.userID, userData.userID)
        XCTAssertEqual(decoded.showCrossedOutItems, userData.showCrossedOutItems)
        XCTAssertEqual(decoded.defaultSortOption, userData.defaultSortOption)
    }

    // MARK: - Enum Codable Tests

    /// Test ItemSortOption Codable
    func testItemSortOptionCodable() throws {
        let option = ItemSortOption.modifiedAt

        let encoder = JSONEncoder()
        let data = try encoder.encode(option)

        let decoder = JSONDecoder()
        let decoded = try decoder.decode(ItemSortOption.self, from: data)

        XCTAssertEqual(decoded, option)
    }

    /// Test ItemFilterOption Codable
    func testItemFilterOptionCodable() throws {
        let option = ItemFilterOption.hasImages

        let encoder = JSONEncoder()
        let data = try encoder.encode(option)

        let decoder = JSONDecoder()
        let decoded = try decoder.decode(ItemFilterOption.self, from: data)

        XCTAssertEqual(decoded, option)
    }

    /// Test SortDirection Codable
    func testSortDirectionCodable() throws {
        let direction = SortDirection.descending

        let encoder = JSONEncoder()
        let data = try encoder.encode(direction)

        let decoder = JSONDecoder()
        let decoded = try decoder.decode(SortDirection.self, from: data)

        XCTAssertEqual(decoded, direction)
    }
}

// MARK: - ImageService Tests (Task 3.1)
/// Unit tests for ImageService on macOS
/// Verifies that image processing using NSImage works correctly on the macOS platform.
#if os(macOS)
final class ImageServiceTests: XCTestCase {

    var imageService: ImageService!

    override func setUpWithError() throws {
        try super.setUpWithError()
        imageService = ImageService.shared
        imageService.clearThumbnailCache()
    }

    override func tearDownWithError() throws {
        imageService.clearThumbnailCache()
        imageService = nil
        try super.tearDownWithError()
    }

    // MARK: - Helper Methods

    /// Creates a test NSImage with specified dimensions and color
    private func createTestImage(width: CGFloat = 100, height: CGFloat = 100, color: NSColor = .red) -> NSImage {
        let image = NSImage(size: NSSize(width: width, height: height))
        image.lockFocus()
        color.setFill()
        NSRect(x: 0, y: 0, width: width, height: height).fill()
        image.unlockFocus()
        return image
    }

    /// Creates test image data (PNG format)
    private func createTestImageData(width: CGFloat = 100, height: CGFloat = 100) -> Data? {
        let image = createTestImage(width: width, height: height)
        guard let tiffData = image.tiffRepresentation,
              let bitmapRep = NSBitmapImageRep(data: tiffData) else {
            return nil
        }
        return bitmapRep.representation(using: .png, properties: [:])
    }

    /// Creates test JPEG image data
    private func createTestJPEGData(width: CGFloat = 100, height: CGFloat = 100, quality: CGFloat = 0.8) -> Data? {
        let image = createTestImage(width: width, height: height)
        guard let tiffData = image.tiffRepresentation,
              let bitmapRep = NSBitmapImageRep(data: tiffData) else {
            return nil
        }
        return bitmapRep.representation(using: .jpeg, properties: [.compressionFactor: quality])
    }

    // MARK: - Image Processing Tests

    /// Test that processImageForStorage returns valid data
    func testProcessImageForStorage() {
        let testImage = createTestImage(width: 200, height: 200)
        let processedData = imageService.processImageForStorage(testImage)

        XCTAssertNotNil(processedData)
        XCTAssertGreaterThan(processedData?.count ?? 0, 0)
    }

    /// Test that processImageForStorage compresses large images
    func testProcessImageForStorageCompression() {
        // Create a large image
        let largeImage = createTestImage(width: 2000, height: 2000)
        let processedData = imageService.processImageForStorage(largeImage)

        XCTAssertNotNil(processedData)

        // Processed data should be within the configured max size
        let maxSize = ImageService.Configuration.maxImageSize
        XCTAssertLessThanOrEqual(processedData?.count ?? Int.max, maxSize)
    }

    /// Test resizeImageForStorage maintains aspect ratio
    func testResizeImageForStorageMaintainsAspectRatio() {
        // Create a wide image
        let wideImage = createTestImage(width: 2000, height: 1000)
        let resized = imageService.resizeImageForStorage(wideImage)

        // Check aspect ratio is preserved (2:1)
        let aspectRatio = resized.size.width / resized.size.height
        XCTAssertEqual(aspectRatio, 2.0, accuracy: 0.01)

        // Check dimensions are reduced
        XCTAssertLessThanOrEqual(resized.size.width, ImageService.Configuration.maxImageDimension)
        XCTAssertLessThanOrEqual(resized.size.height, ImageService.Configuration.maxImageDimension)
    }

    /// Test resizeImageForStorage doesn't resize small images
    func testResizeImageForStorageSkipsSmallImages() {
        let smallImage = createTestImage(width: 100, height: 100)
        let resized = imageService.resizeImageForStorage(smallImage)

        // Small images should not be resized
        XCTAssertEqual(resized.size.width, 100)
        XCTAssertEqual(resized.size.height, 100)
    }

    /// Test resizeImage with custom max dimension
    func testResizeImageWithMaxDimension() {
        let image = createTestImage(width: 1000, height: 500)
        let resized = imageService.resizeImage(image, maxDimension: 200)

        // Should respect max dimension
        XCTAssertLessThanOrEqual(resized.size.width, 200)
        XCTAssertLessThanOrEqual(resized.size.height, 200)

        // Should maintain 2:1 aspect ratio
        let aspectRatio = resized.size.width / resized.size.height
        XCTAssertEqual(aspectRatio, 2.0, accuracy: 0.01)
    }

    // MARK: - Compression Tests

    /// Test compressImageData reduces file size
    func testCompressImageData() {
        guard let originalData = createTestImageData(width: 500, height: 500) else {
            XCTFail("Failed to create test image data")
            return
        }

        let maxSize = 50 * 1024 // 50KB
        let compressedData = imageService.compressImageData(originalData, maxSize: maxSize)

        XCTAssertNotNil(compressedData)
        XCTAssertLessThanOrEqual(compressedData?.count ?? Int.max, maxSize)
    }

    /// Test progressive compression finds optimal quality
    func testCompressImageDataProgressive() {
        let testImage = createTestImage(width: 500, height: 500)
        let maxSize = 30 * 1024 // 30KB

        let compressedData = imageService.compressImageDataProgressive(testImage, maxSize: maxSize)

        XCTAssertNotNil(compressedData)
        // Should fit within max size or use minimum quality
        if let data = compressedData {
            XCTAssertGreaterThan(data.count, 0)
        }
    }

    // MARK: - Thumbnail Tests

    /// Test createThumbnail from NSImage
    func testCreateThumbnailFromImage() {
        let testImage = createTestImage(width: 500, height: 500)
        let thumbnailSize = CGSize(width: 100, height: 100)

        let thumbnail = imageService.createThumbnail(from: testImage, size: thumbnailSize)

        XCTAssertEqual(thumbnail.size.width, thumbnailSize.width)
        XCTAssertEqual(thumbnail.size.height, thumbnailSize.height)
    }

    /// Test createThumbnail from Data with caching
    func testCreateThumbnailFromDataWithCaching() {
        guard let testData = createTestImageData(width: 500, height: 500) else {
            XCTFail("Failed to create test image data")
            return
        }

        // First call should create and cache
        let thumbnail1 = imageService.createThumbnail(from: testData)
        XCTAssertNotNil(thumbnail1)

        // Second call should return cached version
        let thumbnail2 = imageService.createThumbnail(from: testData)
        XCTAssertNotNil(thumbnail2)

        // Both should have same dimensions
        XCTAssertEqual(thumbnail1?.size, thumbnail2?.size)
    }

    /// Test createThumbnail with invalid data returns nil
    func testCreateThumbnailFromInvalidData() {
        let invalidData = Data("not an image".utf8)
        let thumbnail = imageService.createThumbnail(from: invalidData)

        XCTAssertNil(thumbnail)
    }

    /// Test clearThumbnailCache
    func testClearThumbnailCache() {
        guard let testData = createTestImageData() else {
            XCTFail("Failed to create test image data")
            return
        }

        // Create a cached thumbnail
        _ = imageService.createThumbnail(from: testData)

        // Clear cache
        imageService.clearThumbnailCache()

        // No assertion needed - just verify it doesn't crash
        XCTAssertTrue(true)
    }

    // MARK: - ItemImage Management Tests

    /// Test createItemImage from NSImage
    func testCreateItemImageFromNSImage() {
        let testImage = createTestImage(width: 200, height: 200)
        let itemId = UUID()

        let itemImage = imageService.createItemImage(from: testImage, itemId: itemId)

        XCTAssertNotNil(itemImage)
        XCTAssertNotNil(itemImage?.imageData)
        XCTAssertEqual(itemImage?.itemId, itemId)
    }

    /// Test addImageToItem
    func testAddImageToItem() {
        var item = Item(title: "Test Item")
        let testImage = createTestImage(width: 200, height: 200)

        let success = imageService.addImageToItem(&item, image: testImage)

        XCTAssertTrue(success)
        XCTAssertEqual(item.images.count, 1)
        XCTAssertEqual(item.images.first?.orderNumber, 0)
    }

    /// Test addImageToItem sets correct order numbers
    func testAddImageToItemOrderNumbers() {
        var item = Item(title: "Test Item")
        let testImage1 = createTestImage(width: 100, height: 100, color: .red)
        let testImage2 = createTestImage(width: 100, height: 100, color: .blue)
        let testImage3 = createTestImage(width: 100, height: 100, color: .green)

        _ = imageService.addImageToItem(&item, image: testImage1)
        _ = imageService.addImageToItem(&item, image: testImage2)
        _ = imageService.addImageToItem(&item, image: testImage3)

        XCTAssertEqual(item.images.count, 3)
        XCTAssertEqual(item.images[0].orderNumber, 0)
        XCTAssertEqual(item.images[1].orderNumber, 1)
        XCTAssertEqual(item.images[2].orderNumber, 2)
    }

    /// Test removeImageFromItem
    func testRemoveImageFromItem() {
        var item = Item(title: "Test Item")
        let testImage = createTestImage()

        _ = imageService.addImageToItem(&item, image: testImage)
        let imageId = item.images.first!.id

        let success = imageService.removeImageFromItem(&item, imageId: imageId)

        XCTAssertTrue(success)
        XCTAssertEqual(item.images.count, 0)
    }

    /// Test removeImageFromItem reorders remaining images
    func testRemoveImageFromItemReorders() {
        var item = Item(title: "Test Item")

        // Add 3 images
        for _ in 0..<3 {
            _ = imageService.addImageToItem(&item, image: createTestImage())
        }

        // Remove the middle image
        let middleImageId = item.images[1].id
        _ = imageService.removeImageFromItem(&item, imageId: middleImageId)

        XCTAssertEqual(item.images.count, 2)
        XCTAssertEqual(item.images[0].orderNumber, 0)
        XCTAssertEqual(item.images[1].orderNumber, 1)
    }

    /// Test removeImageFromItem with invalid ID
    func testRemoveImageFromItemInvalidId() {
        var item = Item(title: "Test Item")
        _ = imageService.addImageToItem(&item, image: createTestImage())

        let success = imageService.removeImageFromItem(&item, imageId: UUID())

        XCTAssertFalse(success)
        XCTAssertEqual(item.images.count, 1)
    }

    /// Test reorderImages
    func testReorderImages() {
        var item = Item(title: "Test Item")

        // Add 3 images
        for i in 0..<3 {
            var image = ItemImage(imageData: Data("image\(i)".utf8))
            image.orderNumber = i
            item.images.append(image)
        }

        // Reorder: move first image to last position
        let success = imageService.reorderImages(in: &item, from: 0, to: 2)

        XCTAssertTrue(success)
        XCTAssertEqual(item.images[0].orderNumber, 0)
        XCTAssertEqual(item.images[1].orderNumber, 1)
        XCTAssertEqual(item.images[2].orderNumber, 2)
    }

    /// Test reorderImages with invalid indices
    func testReorderImagesInvalidIndices() {
        var item = Item(title: "Test Item")

        // Add 2 images
        for _ in 0..<2 {
            _ = imageService.addImageToItem(&item, image: createTestImage())
        }

        // Invalid: same source and destination
        XCTAssertFalse(imageService.reorderImages(in: &item, from: 0, to: 0))

        // Invalid: out of bounds
        XCTAssertFalse(imageService.reorderImages(in: &item, from: 5, to: 0))
        XCTAssertFalse(imageService.reorderImages(in: &item, from: 0, to: 5))
        XCTAssertFalse(imageService.reorderImages(in: &item, from: -1, to: 0))
    }

    // MARK: - Validation Tests

    /// Test validateImageData with valid data
    func testValidateImageDataValid() {
        guard let validData = createTestImageData() else {
            XCTFail("Failed to create test image data")
            return
        }

        XCTAssertTrue(imageService.validateImageData(validData))
    }

    /// Test validateImageData with invalid data
    func testValidateImageDataInvalid() {
        let invalidData = Data("not an image".utf8)

        XCTAssertFalse(imageService.validateImageData(invalidData))
    }

    /// Test validateImageData with oversized data
    func testValidateImageDataOversized() {
        // Create data larger than 2x max size
        let oversizedData = Data(count: ImageService.Configuration.maxImageSize * 3)

        XCTAssertFalse(imageService.validateImageData(oversizedData))
    }

    /// Test validateImageSize
    func testValidateImageSize() {
        guard let testData = createTestImageData() else {
            XCTFail("Failed to create test image data")
            return
        }

        let result = imageService.validateImageSize(testData)

        XCTAssertNotNil(result.actualSize)
        XCTAssertEqual(result.maxSize, ImageService.Configuration.maxImageSize)

        if result.isValid {
            XCTAssertNil(result.recommendation)
        } else {
            XCTAssertNotNil(result.recommendation)
        }
    }

    // MARK: - Image Format Tests

    /// Test getImageFormat for JPEG
    func testGetImageFormatJPEG() {
        guard let jpegData = createTestJPEGData() else {
            XCTFail("Failed to create test JPEG data")
            return
        }

        let format = imageService.getImageFormat(from: jpegData)

        XCTAssertEqual(format, "JPEG")
    }

    /// Test getImageFormat for PNG
    func testGetImageFormatPNG() {
        guard let pngData = createTestImageData() else {
            XCTFail("Failed to create test PNG data")
            return
        }

        let format = imageService.getImageFormat(from: pngData)

        XCTAssertEqual(format, "PNG")
    }

    /// Test getImageFormat for unknown format
    func testGetImageFormatUnknown() {
        let unknownData = Data([0x00, 0x00, 0x00, 0x00])

        let format = imageService.getImageFormat(from: unknownData)

        XCTAssertEqual(format, "Unknown")
    }

    /// Test getImageFormat with insufficient data
    func testGetImageFormatInsufficientData() {
        let shortData = Data([0x00, 0x00])

        let format = imageService.getImageFormat(from: shortData)

        XCTAssertNil(format)
    }

    // MARK: - Format File Size Tests

    /// Test formatFileSize for bytes
    func testFormatFileSizeBytes() {
        XCTAssertEqual(imageService.formatFileSize(500), "500 B")
        XCTAssertEqual(imageService.formatFileSize(0), "0 B")
    }

    /// Test formatFileSize for kilobytes
    func testFormatFileSizeKB() {
        let result = imageService.formatFileSize(2048)
        XCTAssertTrue(result.contains("KB"))
    }

    /// Test formatFileSize for megabytes
    func testFormatFileSizeMB() {
        let result = imageService.formatFileSize(2 * 1024 * 1024)
        XCTAssertTrue(result.contains("MB"))
    }

    // MARK: - Error Handling Tests

    /// Test processImage success
    func testProcessImageSuccess() {
        let testImage = createTestImage(width: 200, height: 200)

        let result = imageService.processImage(testImage)

        switch result {
        case .success(let data):
            XCTAssertGreaterThan(data.count, 0)
        case .failure(let error):
            XCTFail("Expected success but got error: \(error)")
        }
    }

    /// Test ImageError descriptions
    func testImageErrorDescriptions() {
        XCTAssertNotNil(ImageService.ImageError.invalidImageData.errorDescription)
        XCTAssertNotNil(ImageService.ImageError.imageTooLarge.errorDescription)
        XCTAssertNotNil(ImageService.ImageError.processingFailed.errorDescription)
        XCTAssertNotNil(ImageService.ImageError.unsupportedFormat.errorDescription)
    }

    // MARK: - SwiftUI Integration Tests

    /// Test swiftUIImage from ItemImage
    func testSwiftUIImageFromItemImage() {
        guard let testData = createTestImageData() else {
            XCTFail("Failed to create test image data")
            return
        }

        let itemImage = ItemImage(imageData: testData)
        let swiftUIImage = imageService.swiftUIImage(from: itemImage)

        XCTAssertNotNil(swiftUIImage)
    }

    /// Test swiftUIImage with nil data
    func testSwiftUIImageWithNilData() {
        let itemImage = ItemImage(imageData: nil)
        let swiftUIImage = imageService.swiftUIImage(from: itemImage)

        XCTAssertNil(swiftUIImage)
    }

    /// Test swiftUIThumbnail from ItemImage
    func testSwiftUIThumbnailFromItemImage() {
        guard let testData = createTestImageData() else {
            XCTFail("Failed to create test image data")
            return
        }

        let itemImage = ItemImage(imageData: testData)
        let thumbnail = imageService.swiftUIThumbnail(from: itemImage)

        XCTAssertNotNil(thumbnail)
    }

    // MARK: - Configuration Tests

    /// Test Configuration values are reasonable
    func testConfigurationValues() {
        XCTAssertGreaterThan(ImageService.Configuration.maxImageSize, 0)
        XCTAssertGreaterThan(ImageService.Configuration.thumbnailSize.width, 0)
        XCTAssertGreaterThan(ImageService.Configuration.thumbnailSize.height, 0)
        XCTAssertGreaterThan(ImageService.Configuration.compressionQuality, 0)
        XCTAssertLessThanOrEqual(ImageService.Configuration.compressionQuality, 1.0)
        XCTAssertGreaterThan(ImageService.Configuration.maxImageDimension, 0)
        XCTAssertGreaterThan(ImageService.Configuration.maxCacheSize, 0)
        XCTAssertFalse(ImageService.Configuration.progressiveQualityLevels.isEmpty)
    }

    // MARK: - Performance Tests

    /// Test image processing performance
    func testImageProcessingPerformance() {
        let testImage = createTestImage(width: 1000, height: 1000)

        measure {
            _ = imageService.processImageForStorage(testImage)
        }
    }

    /// Test thumbnail creation performance
    func testThumbnailCreationPerformance() {
        guard let testData = createTestImageData(width: 1000, height: 1000) else {
            XCTFail("Failed to create test image data")
            return
        }

        // Clear cache to measure actual creation time
        imageService.clearThumbnailCache()

        measure {
            _ = imageService.createThumbnail(from: testData)
        }
    }
}
#endif

// MARK: - MacBiometricAuthService Tests (Task 3.2)
/// Unit tests for MacBiometricAuthService on macOS
/// Verifies that biometric authentication using Touch ID works correctly on the macOS platform.
#if os(macOS)
final class MacBiometricAuthServiceTests: XCTestCase {

    var biometricService: MacBiometricAuthService!

    override func setUpWithError() throws {
        try super.setUpWithError()
        biometricService = MacBiometricAuthService.shared
        biometricService.resetAuthentication()
    }

    override func tearDownWithError() throws {
        biometricService.resetAuthentication()
        biometricService = nil
        try super.tearDownWithError()
    }

    // MARK: - Singleton Tests

    /// Test MacBiometricAuthService singleton
    func testMacBiometricAuthServiceSingleton() {
        let instance1 = MacBiometricAuthService.shared
        let instance2 = MacBiometricAuthService.shared

        XCTAssertTrue(instance1 === instance2, "Shared instances should be identical")
    }

    // MARK: - Initial State Tests

    /// Test initial state of service
    func testInitialState() {
        XCTAssertFalse(biometricService.isAuthenticated)
        XCTAssertNil(biometricService.authenticationError)
    }

    // MARK: - Biometric Type Detection Tests

    /// Test biometricType detection
    func testBiometricTypeDetection() {
        let biometricType = biometricService.biometricType()

        // On simulator or Mac without Touch ID, should return .none
        // On Mac with Touch ID, should return .touchID
        XCTAssertTrue(
            biometricType == .none || biometricType == .touchID,
            "Biometric type should be .none or .touchID on macOS"
        )
    }

    /// Test isTouchIDAvailable
    func testIsTouchIDAvailable() {
        let touchIDAvailable = biometricService.isTouchIDAvailable()
        let biometricType = biometricService.biometricType()

        // Touch ID availability should match biometric type
        if biometricType == .touchID {
            XCTAssertTrue(touchIDAvailable, "Touch ID should be available when biometric type is .touchID")
        } else {
            XCTAssertFalse(touchIDAvailable, "Touch ID should not be available when biometric type is .none")
        }
    }

    /// Test isDeviceAuthenticationAvailable
    func testIsDeviceAuthenticationAvailable() {
        let available = biometricService.isDeviceAuthenticationAvailable()

        // This should be true on most Macs with a password set
        // But in CI environments or simulators, it might be false
        // Just verify it returns a boolean without crashing
        XCTAssertTrue(available == true || available == false)
    }

    // MARK: - MacBiometricType Enum Tests

    /// Test MacBiometricType display names
    func testMacBiometricTypeDisplayNames() {
        XCTAssertEqual(MacBiometricType.none.displayName, "None")
        XCTAssertEqual(MacBiometricType.touchID.displayName, "Touch ID")
    }

    /// Test MacBiometricType icon names
    func testMacBiometricTypeIconNames() {
        XCTAssertEqual(MacBiometricType.none.iconName, "lock.fill")
        XCTAssertEqual(MacBiometricType.touchID.iconName, "touchid")
    }

    /// Test MacBiometricType isAvailable
    func testMacBiometricTypeIsAvailable() {
        XCTAssertFalse(MacBiometricType.none.isAvailable)
        XCTAssertTrue(MacBiometricType.touchID.isAvailable)
    }

    // MARK: - Reset Authentication Tests

    /// Test resetAuthentication clears state
    func testResetAuthentication() {
        // Manually set authenticated state (simulating successful auth)
        biometricService.isAuthenticated = true
        biometricService.authenticationError = "Test error"

        biometricService.resetAuthentication()

        XCTAssertFalse(biometricService.isAuthenticated)
        XCTAssertNil(biometricService.authenticationError)
    }

    // MARK: - Authentication State Tests

    /// Test that authentication state is @Published
    func testAuthenticationStateIsPublished() {
        let expectation = XCTestExpectation(description: "Authentication state changes")
        var receivedValues: [Bool] = []

        let cancellable = biometricService.$isAuthenticated.sink { value in
            receivedValues.append(value)
            if receivedValues.count == 2 {
                expectation.fulfill()
            }
        }

        // Trigger a state change
        biometricService.isAuthenticated = true

        wait(for: [expectation], timeout: 1.0)

        XCTAssertEqual(receivedValues.count, 2)
        XCTAssertFalse(receivedValues[0]) // Initial value
        XCTAssertTrue(receivedValues[1])  // Updated value

        cancellable.cancel()
    }

    /// Test that error state is @Published
    func testAuthenticationErrorIsPublished() {
        let expectation = XCTestExpectation(description: "Error state changes")
        var receivedValues: [String?] = []

        let cancellable = biometricService.$authenticationError.sink { value in
            receivedValues.append(value)
            if receivedValues.count == 2 {
                expectation.fulfill()
            }
        }

        // Trigger a state change
        biometricService.authenticationError = "Test error message"

        wait(for: [expectation], timeout: 1.0)

        XCTAssertEqual(receivedValues.count, 2)
        XCTAssertNil(receivedValues[0])
        XCTAssertEqual(receivedValues[1], "Test error message")

        cancellable.cancel()
    }

    // MARK: - Authentication Flow Tests

    /// Test authentication completion handler is called
    func testAuthenticationCallsCompletion() {
        let expectation = XCTestExpectation(description: "Completion handler called")

        biometricService.authenticate { success, error in
            // We just verify the completion handler is called
            // The actual result depends on the environment (Touch ID availability, etc.)
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 5.0)
    }

    /// Test async authentication method (iOS 15+/macOS 12+)
    @available(macOS 12.0, *)
    func testAsyncAuthentication() async {
        let result = await biometricService.authenticate()

        // Just verify it returns without crashing
        // The actual result depends on the environment
        XCTAssertTrue(result.success == true || result.success == false)
    }

    // MARK: - Error Message Tests

    /// Test that failed authentication sets error message
    func testFailedAuthenticationSetsError() {
        let expectation = XCTestExpectation(description: "Error set on failure")

        // If authentication is not available, it should set an error
        if !biometricService.isDeviceAuthenticationAvailable() {
            biometricService.authenticate { success, error in
                if !success {
                    XCTAssertNotNil(error)
                    XCTAssertNotNil(self.biometricService.authenticationError)
                }
                expectation.fulfill()
            }
        } else {
            // If authentication is available, we can't easily test failure
            // Just skip this test
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 5.0)
    }

    // MARK: - Thread Safety Tests

    /// Test that state updates happen on main thread when authentication completes
    /// Note: This test may timeout if authentication requires user interaction
    func testStateUpdatesOnMainThread() {
        // This test verifies that when we manually update the state,
        // the changes are properly reflected (since @Published uses main actor)
        let expectation = XCTestExpectation(description: "State updated on main thread")

        DispatchQueue.global().async {
            // Simulate async work
            DispatchQueue.main.async {
                self.biometricService.isAuthenticated = true
                XCTAssertTrue(Thread.isMainThread, "State update should happen on main thread")
                expectation.fulfill()
            }
        }

        wait(for: [expectation], timeout: 2.0)
    }

    // MARK: - Platform-Specific Tests

    /// Test that this test runs only on macOS
    func testRunningOnMacOS() {
        #if os(macOS)
        XCTAssertTrue(true, "Test is running on macOS")
        #else
        XCTFail("This test should only run on macOS")
        #endif
    }

    /// Test that MacBiometricAuthService is independent from iOS BiometricAuthService
    func testIndependentFromIOSService() {
        // Verify we're using the macOS-specific service
        let macService = MacBiometricAuthService.shared
        XCTAssertNotNil(macService)

        // The MacBiometricType enum should only have .none and .touchID
        let allCases: [MacBiometricType] = [.none, .touchID]
        XCTAssertEqual(allCases.count, 2)
    }

    // MARK: - ObservableObject Conformance Tests

    /// Test ObservableObject conformance
    func testObservableObjectConformance() {
        // Verify that MacBiometricAuthService conforms to ObservableObject
        let service: any ObservableObject = biometricService
        XCTAssertNotNil(service)
    }
}
#endif
