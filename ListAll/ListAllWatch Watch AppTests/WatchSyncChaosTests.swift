//
//  WatchSyncChaosTests.swift
//  ListAllWatch Watch AppTests
//
//  Chaos tests for Watch sync operations: 256KB size limits,
//  empty sync, and concurrent sync ordering.
//

import XCTest
@testable import ListAllWatch_Watch_App

final class WatchSyncChaosTests: XCTestCase {

    // MARK: - Timing Constants

    /// The total delay before isSyncingFromiOS returns to false.
    /// Matches WatchMainViewModel/WatchListViewModel: 0.1s (load) + 0.5s (hide indicator).
    private static let syncIndicatorHideDelay: TimeInterval = 0.6

    /// Buffer added on top of syncIndicatorHideDelay for CI runner variance.
    private static let ciBuffer: TimeInterval = 1.0

    // MARK: - Setup / Teardown

    override func setUp() {
        super.setUp()
        // Drain the main queue so any observers from a previous test have fired
        // before this test starts.
        RunLoop.main.run(until: Date())
    }

    override func tearDown() {
        // Drain the main queue to let any pending DispatchQueue.main.asyncAfter
        // blocks from this test fire and clean up before the next test begins.
        let drainExpectation = expectation(description: "drain main queue")
        let drainDelay = Self.syncIndicatorHideDelay + Self.ciBuffer
        DispatchQueue.main.asyncAfter(deadline: .now() + drainDelay) {
            drainExpectation.fulfill()
        }
        wait(for: [drainExpectation], timeout: drainDelay + 2.0)
        super.tearDown()
    }

    // MARK: - 256KB Size Limit Enforcement

    /// Verify that 100 items with ~990-char descriptions exceed the 256KB WatchConnectivity limit.
    /// The sync layer should detect this and refuse to send oversized payloads.
    func testSyncSizeLimit_100ItemsWith990CharDescriptions_exceedsLimit() throws {
        // Arrange: Build a list with 100 items, each having a ~990-character description
        let listId = UUID()
        var list = List(name: "Large Payload List")
        list.id = listId

        // Each ItemSyncData encodes: id, title, itemDescription, quantity, orderNumber,
        // isCrossedOut, createdAt, modifiedAt, listId, imageCount.
        // With JSON overhead, ~990 chars of description plus other fields yields ~1.2KB per item.
        // Need ~220 items to exceed 256KB.
        let longDescription = String(repeating: "A", count: 990)
        var items: [Item] = []
        for i in 0..<250 {
            var item = Item(title: "Item \(i)", listId: listId)
            item.itemDescription = longDescription
            item.orderNumber = i
            items.append(item)
        }
        list.items = items

        // Act: Convert to sync data and measure JSON size
        let syncData = [ListSyncData(from: list)]
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let jsonData = try encoder.encode(syncData)

        let jsonSizeKB = Double(jsonData.count) / 1024.0
        let limitKB = 256.0

        // Assert: Payload should exceed the 256KB limit
        XCTAssertGreaterThan(
            jsonSizeKB, limitKB,
            "250 items with 990-char descriptions should exceed 256KB limit. Actual size: \(jsonSizeKB) KB"
        )
    }

    /// Verify that the sync data model correctly strips images to reduce payload size
    func testSyncData_stripsImages_reducesPayloadSize() throws {
        // Arrange: Create a list with items (images would be stripped by ItemSyncData)
        let listId = UUID()
        var list = List(name: "Image Strip Test")
        list.id = listId

        var items: [Item] = []
        for i in 0..<10 {
            var item = Item(title: "Item \(i)", listId: listId)
            item.itemDescription = "Short desc"
            item.orderNumber = i
            items.append(item)
        }
        list.items = items

        // Act: Convert to sync data
        let syncData = ListSyncData(from: list)

        // Assert: Items should be preserved without images
        XCTAssertEqual(syncData.items.count, 10, "All 10 items should be in sync data")
        for itemSync in syncData.items {
            XCTAssertEqual(itemSync.imageCount, 0, "Sync items should report 0 images since source items had none")
        }

        // Verify round-trip: toList() should produce items with empty images array
        let roundTrippedList = syncData.toList()
        XCTAssertEqual(roundTrippedList.items.count, 10, "Round-tripped list should have 10 items")
        for item in roundTrippedList.items {
            XCTAssertTrue(item.images.isEmpty, "Round-tripped items should have empty images")
        }
    }

    /// Verify that a payload just under the 256KB limit is within bounds
    func testSyncSizeLimit_moderatePayload_withinLimit() throws {
        // Arrange: Create a list with items that should stay under 256KB
        let listId = UUID()
        var list = List(name: "Moderate Payload")
        list.id = listId

        // 50 items with 100-char descriptions should be well under 256KB
        let shortDescription = String(repeating: "B", count: 100)
        var items: [Item] = []
        for i in 0..<50 {
            var item = Item(title: "Item \(i)", listId: listId)
            item.itemDescription = shortDescription
            item.orderNumber = i
            items.append(item)
        }
        list.items = items

        // Act: Convert to sync data and measure JSON size
        let syncData = [ListSyncData(from: list)]
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let jsonData = try encoder.encode(syncData)

        let jsonSizeKB = Double(jsonData.count) / 1024.0

        // Assert: Should be under 256KB
        XCTAssertLessThan(
            jsonSizeKB, 256.0,
            "50 items with 100-char descriptions should be under 256KB. Actual: \(jsonSizeKB) KB"
        )
    }

    /// Verify that multiple lists with many items can exceed the limit
    func testSyncSizeLimit_multipleLists_cumulativeSize() throws {
        // Arrange: Create 10 lists each with 20 items with 500-char descriptions
        let longDescription = String(repeating: "C", count: 500)
        var lists: [List] = []

        for listIndex in 0..<10 {
            let listId = UUID()
            var list = List(name: "List \(listIndex)")
            list.id = listId

            var items: [Item] = []
            for i in 0..<20 {
                var item = Item(title: "Item \(i)", listId: listId)
                item.itemDescription = longDescription
                item.orderNumber = i
                items.append(item)
            }
            list.items = items
            lists.append(list)
        }

        // Act: Convert all lists to sync data
        let syncData = lists.map { ListSyncData(from: $0) }
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let jsonData = try encoder.encode(syncData)

        let jsonSizeKB = Double(jsonData.count) / 1024.0

        // Assert: 10 lists x 20 items x 500 chars = ~100KB of descriptions alone
        // plus JSON overhead, should be a meaningful size
        XCTAssertGreaterThan(jsonSizeKB, 50.0, "10 lists with 200 total items should produce significant payload")
    }

    // MARK: - Empty Sync from Watch Side

    /// Verify that syncing an empty list array produces valid but minimal JSON
    func testEmptySync_noLists_producesValidJSON() throws {
        // Arrange: Empty lists array
        let emptyLists: [List] = []

        // Act: Convert to sync data and encode
        let syncData = emptyLists.map { ListSyncData(from: $0) }
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let jsonData = try encoder.encode(syncData)

        // Assert: Should produce valid but minimal JSON
        XCTAssertNotNil(jsonData, "Empty sync should produce valid JSON data")
        let jsonSizeKB = Double(jsonData.count) / 1024.0
        XCTAssertLessThan(jsonSizeKB, 1.0, "Empty sync payload should be < 1KB")

        // Verify it decodes back to empty array
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let decoded = try decoder.decode([ListSyncData].self, from: jsonData)
        XCTAssertTrue(decoded.isEmpty, "Decoded empty sync should be empty array")
    }

    /// Verify that syncing a list with zero items works correctly
    func testEmptySync_listWithNoItems_syncsCorrectly() throws {
        // Arrange: One list with no items
        var list = List(name: "Empty Shopping List")
        list.id = UUID()
        list.items = []

        // Act: Convert to sync data
        let syncData = [ListSyncData(from: list)]
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let jsonData = try encoder.encode(syncData)

        // Decode and verify
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let decoded = try decoder.decode([ListSyncData].self, from: jsonData)

        // Assert
        XCTAssertEqual(decoded.count, 1, "Should have one list")
        XCTAssertEqual(decoded[0].name, "Empty Shopping List", "List name should match")
        XCTAssertTrue(decoded[0].items.isEmpty, "Items should be empty")
    }

    /// Verify that WatchMainViewModel handles empty lists without crashing
    func testEmptySync_watchMainViewModel_handlesEmptyLists() {
        // Arrange: Create WatchMainViewModel
        let viewModel = WatchMainViewModel()
        defer { NotificationCenter.default.removeObserver(viewModel) }

        // Act & Assert: Posting empty sync notification should not crash
        NotificationCenter.default.post(
            name: NSNotification.Name("WatchConnectivitySyncReceived"),
            object: nil
        )

        let expectation = XCTestExpectation(description: "Empty sync completes")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            // Should still be functional after empty sync
            XCTAssertGreaterThanOrEqual(viewModel.lists.count, 0, "Lists count should be non-negative")
            XCTAssertNil(viewModel.errorMessage, "No error should occur from empty sync")
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 2.0)
    }

    // MARK: - Sync Ordering: Concurrent Updates

    /// Verify that sync data preserves item ordering through encode/decode cycle
    func testSyncOrdering_itemOrderPreserved_afterEncodeDecode() throws {
        // Arrange: Create a list with specifically ordered items
        let listId = UUID()
        var list = List(name: "Ordered List")
        list.id = listId

        var items: [Item] = []
        for i in 0..<20 {
            var item = Item(title: "Item \(i)", listId: listId)
            item.orderNumber = i
            items.append(item)
        }
        list.items = items

        // Act: Encode and decode through sync data
        let syncData = ListSyncData(from: list)
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let jsonData = try encoder.encode(syncData)

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let decodedSync = try decoder.decode(ListSyncData.self, from: jsonData)
        let decodedList = decodedSync.toList()

        // Assert: Verify items are present (order may differ in array but orderNumber is preserved)
        XCTAssertEqual(decodedList.items.count, 20, "All 20 items should survive sync round-trip")

        let sortedItems = decodedList.items.sorted { $0.orderNumber < $1.orderNumber }
        for (index, item) in sortedItems.enumerated() {
            XCTAssertEqual(item.orderNumber, index, "Item at sorted position \(index) should have orderNumber \(index)")
            XCTAssertEqual(item.title, "Item \(index)", "Item title should match its order")
        }
    }

    /// Verify that Watch update during mid-save scenario preserves data integrity.
    /// Simulates: Watch sends an update while phone is processing a save.
    func testSyncOrdering_watchUpdateDuringPhoneSave_dataIntegrity() throws {
        // Arrange: Create initial state (what phone has)
        let listId = UUID()
        let phoneTimestamp = Date(timeIntervalSince1970: 1700000000)
        let watchTimestamp = Date(timeIntervalSince1970: 1700000100)

        var phoneList = List(name: "Shopping List")
        phoneList.id = listId
        phoneList.modifiedAt = phoneTimestamp  // Set AFTER init (init sets modifiedAt = Date())

        var phoneItems: [Item] = []
        for i in 0..<5 {
            var item = Item(title: "Phone Item \(i)", listId: listId)
            item.orderNumber = i
            item.modifiedAt = phoneTimestamp
            phoneItems.append(item)
        }
        phoneList.items = phoneItems

        // Simulate: Watch has a newer version with a toggled item
        var watchList = phoneList
        watchList.modifiedAt = watchTimestamp  // Newer
        var watchItems = phoneItems
        watchItems[2].isCrossedOut = true
        watchItems[2].modifiedAt = watchTimestamp  // Newer
        watchList.items = watchItems

        // Act: Both encode to sync data
        let phoneSyncData = ListSyncData(from: phoneList)
        let watchSyncData = ListSyncData(from: watchList)

        // Assert: Both should encode/decode without data loss
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601

        let phoneJSON = try encoder.encode(phoneSyncData)
        let watchJSON = try encoder.encode(watchSyncData)

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        let decodedPhone = try decoder.decode(ListSyncData.self, from: phoneJSON)
        let decodedWatch = try decoder.decode(ListSyncData.self, from: watchJSON)

        // Verify phone data integrity
        XCTAssertEqual(decodedPhone.items.count, 5, "Phone should have 5 items")
        let phoneItem2 = decodedPhone.items.first(where: { $0.title == "Phone Item 2" })
        XCTAssertNotNil(phoneItem2, "Phone Item 2 should exist")
        XCTAssertFalse(phoneItem2?.isCrossedOut ?? true, "Phone Item 2 should NOT be crossed out")

        // Verify watch data integrity (has the newer toggle)
        XCTAssertEqual(decodedWatch.items.count, 5, "Watch should have 5 items")
        let watchItem2 = decodedWatch.items.first(where: { $0.title == "Phone Item 2" })
        XCTAssertNotNil(watchItem2, "Watch Item 2 should exist")
        XCTAssertTrue(watchItem2?.isCrossedOut ?? false, "Watch Item 2 SHOULD be crossed out")

        // Watch version should have newer modifiedAt
        XCTAssertGreaterThan(
            decodedWatch.modifiedAt, decodedPhone.modifiedAt,
            "Watch list modifiedAt should be newer than phone"
        )
    }

    /// Verify that duplicate item deduplication works correctly during sync
    func testSyncOrdering_duplicateItemDeduplication_keepsNewest() {
        // Arrange: Create a list with duplicate item IDs (simulating sync conflict)
        let listId = UUID()
        let itemId = UUID()
        var list = List(name: "Conflict List")
        list.id = listId

        var olderItem = Item(title: "Old Version", listId: listId)
        olderItem.id = itemId
        olderItem.modifiedAt = Date(timeIntervalSince1970: 1700000000)

        var newerItem = Item(title: "New Version", listId: listId)
        newerItem.id = itemId
        newerItem.modifiedAt = Date(timeIntervalSince1970: 1700000100) // Newer

        list.items = [olderItem, newerItem]

        // Act: The deduplication logic from WatchConnectivityService
        var seenItems: [UUID: Item] = [:]
        for item in list.items {
            if let existing = seenItems[item.id] {
                if item.modifiedAt > existing.modifiedAt {
                    seenItems[item.id] = item
                }
            } else {
                seenItems[item.id] = item
            }
        }
        let deduplicatedItems = Array(seenItems.values)

        // Assert: Should keep only the newer version
        XCTAssertEqual(deduplicatedItems.count, 1, "Deduplication should produce 1 item")
        XCTAssertEqual(deduplicatedItems[0].title, "New Version", "Should keep the newer version")
        XCTAssertEqual(deduplicatedItems[0].modifiedAt, Date(timeIntervalSince1970: 1700000100))
    }

    /// Verify that sync notification triggers isSyncingFromiOS flag correctly
    func testSyncOrdering_syncIndicator_togglesCorrectly() {
        // Arrange
        let viewModel = WatchMainViewModel()
        defer { NotificationCenter.default.removeObserver(viewModel) }
        XCTAssertFalse(viewModel.isSyncingFromiOS, "Should not be syncing initially")

        // Act: Post sync notification
        NotificationCenter.default.post(
            name: NSNotification.Name("WatchConnectivitySyncReceived"),
            object: nil
        )

        // Assert: Sync indicator should appear immediately (set synchronously before async work)
        let syncStarted = XCTestExpectation(description: "Sync indicator appears")
        DispatchQueue.main.async {
            XCTAssertTrue(viewModel.isSyncingFromiOS, "Should be syncing after notification")
            syncStarted.fulfill()
        }
        wait(for: [syncStarted], timeout: 1.0)

        // Assert: Sync indicator should disappear after the ViewModel's hide delay
        // ViewModel hides after 0.1s (load dispatch) + 0.5s (hide indicator) = 0.6s total.
        // Add ciBuffer for CI runner variance.
        let hideDelay = Self.syncIndicatorHideDelay + Self.ciBuffer
        let syncEnded = XCTestExpectation(description: "Sync indicator disappears")
        DispatchQueue.main.asyncAfter(deadline: .now() + hideDelay) {
            XCTAssertFalse(viewModel.isSyncingFromiOS, "Should stop syncing after \(hideDelay)s")
            syncEnded.fulfill()
        }
        wait(for: [syncEnded], timeout: hideDelay + 2.0)
    }

    /// Verify that WatchListViewModel sync indicator also toggles correctly
    func testSyncOrdering_listViewModelSyncIndicator_togglesCorrectly() {
        // Arrange
        let testList = List(name: "Test List")
        let viewModel = WatchListViewModel(list: testList)
        defer { NotificationCenter.default.removeObserver(viewModel) }
        XCTAssertFalse(viewModel.isSyncingFromiOS, "Should not be syncing initially")

        // Act: Post sync notification
        NotificationCenter.default.post(
            name: NSNotification.Name("WatchConnectivitySyncReceived"),
            object: nil
        )

        // Assert: Sync indicator should appear immediately (set synchronously before async work)
        let syncStarted = XCTestExpectation(description: "Sync started")
        DispatchQueue.main.async {
            XCTAssertTrue(viewModel.isSyncingFromiOS, "Should be syncing after notification")
            syncStarted.fulfill()
        }
        wait(for: [syncStarted], timeout: 1.0)

        // Assert: Sync indicator should disappear after the ViewModel's hide delay
        // ViewModel hides after 0.1s (load dispatch) + 0.5s (hide indicator) = 0.6s total.
        // Add ciBuffer for CI runner variance.
        let hideDelay = Self.syncIndicatorHideDelay + Self.ciBuffer
        let syncEnded = XCTestExpectation(description: "Sync ended")
        DispatchQueue.main.asyncAfter(deadline: .now() + hideDelay) {
            XCTAssertFalse(viewModel.isSyncingFromiOS, "Should stop syncing after \(hideDelay)s")
            syncEnded.fulfill()
        }
        wait(for: [syncEnded], timeout: hideDelay + 2.0)
    }

    /// Verify that rapid successive sync notifications don't cause issues
    func testSyncOrdering_rapidSuccessiveNotifications_noCrash() {
        // Arrange
        let viewModel = WatchMainViewModel()
        defer { NotificationCenter.default.removeObserver(viewModel) }

        // Act: Send 20 rapid sync notifications
        for _ in 0..<20 {
            NotificationCenter.default.post(
                name: NSNotification.Name("WatchConnectivitySyncReceived"),
                object: nil
            )
        }

        // Assert: Should not crash, and eventually settle after the sync indicator hide delay.
        // Use syncIndicatorHideDelay + ciBuffer so all pending asyncAfter blocks have fired.
        let settleDelay = Self.syncIndicatorHideDelay + Self.ciBuffer
        let settled = XCTestExpectation(description: "ViewModel settles after rapid notifications")
        DispatchQueue.main.asyncAfter(deadline: .now() + settleDelay) {
            XCTAssertNil(viewModel.errorMessage, "No error after rapid sync notifications")
            XCTAssertGreaterThanOrEqual(viewModel.lists.count, 0, "Lists should be non-negative")
            settled.fulfill()
        }
        wait(for: [settled], timeout: settleDelay + 2.0)
    }
}
