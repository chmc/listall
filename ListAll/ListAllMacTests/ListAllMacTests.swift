//
//  ListAllMacTests.swift
//  ListAllMacTests
//
//  Created by Aleksi Sutela on 5.12.2025.
//

import XCTest
import CoreData
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
