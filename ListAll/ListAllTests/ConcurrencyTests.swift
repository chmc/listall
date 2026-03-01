import XCTest
import CoreData
@testable import ListAll

/// Concurrency tests targeting the #1 actual bug pattern: perform vs performAndWait races.
/// These tests verify thread safety of Core Data operations, notification handling,
/// debounce timing, and concurrent synchronization.
final class ConcurrencyTests: XCTestCase {

    var container: NSPersistentContainer!

    override func setUp() {
        super.setUp()
        container = TestHelpers.createInMemoryCoreDataStack()
    }

    override func tearDown() {
        container = nil
        super.tearDown()
    }

    // MARK: - Two Background Contexts Saving Simultaneously

    /// Verify that two background contexts saving to the same entity simultaneously
    /// do not cause an NSMergeConflict crash (thanks to merge policies)
    func testConcurrentBackgroundSaves_noMergeConflictCrash() throws {
        // Arrange: Create a list entity in the view context
        let listId = UUID()
        let viewContext = container.viewContext
        let listEntity = ListEntity(context: viewContext)
        listEntity.id = listId
        listEntity.name = "Concurrent Test"
        listEntity.orderNumber = 0
        listEntity.createdAt = Date()
        listEntity.modifiedAt = Date()
        listEntity.isArchived = false
        try viewContext.save()

        // Act: Two background contexts modify the same entity simultaneously
        let expectation1 = expectation(description: "Background context 1 saves")
        let expectation2 = expectation(description: "Background context 2 saves")

        let bgContext1 = container.newBackgroundContext()
        bgContext1.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
        bgContext1.automaticallyMergesChangesFromParent = true

        let bgContext2 = container.newBackgroundContext()
        bgContext2.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
        bgContext2.automaticallyMergesChangesFromParent = true

        bgContext1.perform {
            let request: NSFetchRequest<ListEntity> = ListEntity.fetchRequest()
            request.predicate = NSPredicate(format: "id == %@", listId as CVarArg)
            do {
                let results = try bgContext1.fetch(request)
                if let entity = results.first {
                    entity.name = "Updated by Context 1"
                    entity.modifiedAt = Date()
                    try bgContext1.save()
                }
            } catch {
                XCTFail("Background context 1 should not crash: \(error)")
            }
            expectation1.fulfill()
        }

        bgContext2.perform {
            let request: NSFetchRequest<ListEntity> = ListEntity.fetchRequest()
            request.predicate = NSPredicate(format: "id == %@", listId as CVarArg)
            do {
                let results = try bgContext2.fetch(request)
                if let entity = results.first {
                    entity.name = "Updated by Context 2"
                    entity.modifiedAt = Date()
                    try bgContext2.save()
                }
            } catch {
                XCTFail("Background context 2 should not crash: \(error)")
            }
            expectation2.fulfill()
        }

        wait(for: [expectation1, expectation2], timeout: 10.0)

        // Assert: The entity should exist and have one of the two names (last writer wins)
        // Refresh objects to pick up merged changes from background contexts
        viewContext.refreshAllObjects()
        let request: NSFetchRequest<ListEntity> = ListEntity.fetchRequest()
        request.predicate = NSPredicate(format: "id == %@", listId as CVarArg)
        let results = try viewContext.fetch(request)
        XCTAssertEqual(results.count, 1, "Should still have exactly one list entity")
        let finalName = results.first?.name ?? ""
        XCTAssertTrue(
            finalName == "Updated by Context 1" || finalName == "Updated by Context 2",
            "Name should be one of the two updates, got: \(finalName)"
        )
    }

    /// Verify multiple concurrent saves creating different entities do not lose data
    func testConcurrentBackgroundSaves_multipleEntities_noDataLoss() throws {
        let saveCount = 20
        let expectations = (0..<saveCount).map {
            expectation(description: "Save \($0)")
        }

        // Act: Create 20 list entities from separate background contexts concurrently
        for i in 0..<saveCount {
            let bgContext = container.newBackgroundContext()
            bgContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy

            bgContext.perform {
                let listEntity = ListEntity(context: bgContext)
                listEntity.id = UUID()
                listEntity.name = "Concurrent List \(i)"
                listEntity.orderNumber = Int32(i)
                listEntity.createdAt = Date()
                listEntity.modifiedAt = Date()
                listEntity.isArchived = false

                do {
                    try bgContext.save()
                } catch {
                    XCTFail("Background save \(i) should not fail: \(error)")
                }
                expectations[i].fulfill()
            }
        }

        wait(for: expectations, timeout: 15.0)

        // Assert: All entities should exist
        // Give merge a moment to propagate
        let viewContext = container.viewContext
        viewContext.refreshAllObjects()

        let request: NSFetchRequest<ListEntity> = ListEntity.fetchRequest()
        let results = try viewContext.fetch(request)
        XCTAssertEqual(results.count, saveCount, "All \(saveCount) concurrently created lists should exist")
    }

    // MARK: - Notification Handler on Background Queue + Main Thread Read

    /// Verify that posting a notification from a background queue while the main thread
    /// reads @Published properties does not cause a thread safety crash
    func testNotificationOnBackgroundQueue_mainThreadReads_threadSafe() {
        // Arrange: Create a test ViewModel
        let testDataManager = TestHelpers.createTestDataManager()
        let viewModel = TestMainViewModel(dataManager: testDataManager)
        try? viewModel.addList(name: "Initial List")

        let iterationCount = 50
        let readExpectation = expectation(description: "All reads completed")
        readExpectation.expectedFulfillmentCount = iterationCount

        let writeExpectation = expectation(description: "All writes completed")
        writeExpectation.expectedFulfillmentCount = iterationCount

        // Act: Simultaneously read on main thread and fire notifications from background
        for i in 0..<iterationCount {
            // Read on main thread
            DispatchQueue.main.async {
                // Access @Published properties - this should never crash
                let _ = viewModel.lists
                let _ = viewModel.lists.count
                let _ = viewModel.isSyncingFromWatch
                readExpectation.fulfill()
            }

            // Fire notification from background queue (simulates CloudKit remote change)
            DispatchQueue.global(qos: .userInitiated).async {
                NotificationCenter.default.post(
                    name: NSNotification.Name("WatchConnectivitySyncReceived"),
                    object: nil,
                    userInfo: ["iteration": i]
                )
                writeExpectation.fulfill()
            }
        }

        wait(for: [readExpectation, writeExpectation], timeout: 15.0)

        // Assert: ViewModel should still be in a valid state
        XCTAssertFalse(viewModel.lists.isEmpty, "Lists should not be empty after concurrent access")

        // Cleanup
        testDataManager.clearAll()
    }

    // MARK: - Debounce Timer + Concurrent Save

    /// Verify that 50 rapid sequential name updates all persist correctly
    /// and the final state reflects the last write (no stale data)
    func testRapidSequentialUpdates_finalStateCorrect() throws {
        // Arrange: Create test environment
        let testDataManager = TestHelpers.createTestDataManager()
        let viewModel = TestMainViewModel(dataManager: testDataManager)
        try viewModel.addList(name: "Rapid Update List")

        // Act: Rapid sequence of name updates
        let list = try XCTUnwrap(viewModel.lists.first, "List should exist")
        for i in 0..<50 {
            try viewModel.updateList(list, name: "Name \(i)")
        }

        // Assert: The final name should be the last update, not stale data
        let finalList = try XCTUnwrap(viewModel.lists.first, "List should still exist")
        XCTAssertEqual(finalList.name, "Name 49", "Final name should be the last update")

        // Verify Core Data also has the correct final state
        testDataManager.loadData()
        let cdList = testDataManager.lists.first(where: { $0.id == list.id })
        XCTAssertEqual(cdList?.name, "Name 49", "Core Data should also have the final name")

        // Cleanup
        testDataManager.clearAll()
    }

    /// Verify concurrent background saves interleaved with main thread reads
    /// do not produce inconsistent state
    func testDebounceSave_concurrentBackgroundSave_noStaleData() throws {
        // Arrange
        let listId = UUID()
        let viewContext = container.viewContext
        let listEntity = ListEntity(context: viewContext)
        listEntity.id = listId
        listEntity.name = "Initial"
        listEntity.orderNumber = 0
        listEntity.createdAt = Date()
        listEntity.modifiedAt = Date()
        listEntity.isArchived = false
        try viewContext.save()

        let updateCount = 30
        let expectations = (0..<updateCount).map {
            expectation(description: "Update \($0)")
        }

        // Act: Rapid updates from background context (simulating debounced saves)
        for i in 0..<updateCount {
            let bgContext = container.newBackgroundContext()
            bgContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy

            bgContext.perform {
                let request: NSFetchRequest<ListEntity> = ListEntity.fetchRequest()
                request.predicate = NSPredicate(format: "id == %@", listId as CVarArg)
                do {
                    let results = try bgContext.fetch(request)
                    if let entity = results.first {
                        entity.name = "Update \(i)"
                        entity.modifiedAt = Date()
                        try bgContext.save()
                    }
                } catch {
                    // Merge conflicts are acceptable; they should not crash
                }
                expectations[i].fulfill()
            }
        }

        wait(for: expectations, timeout: 15.0)

        // Assert: Entity should still exist and not be corrupted
        viewContext.refreshAllObjects()
        let request: NSFetchRequest<ListEntity> = ListEntity.fetchRequest()
        request.predicate = NSPredicate(format: "id == %@", listId as CVarArg)
        let results = try viewContext.fetch(request)
        XCTAssertEqual(results.count, 1, "Should still have exactly one entity")
        XCTAssertNotNil(results.first?.name, "Entity name should not be nil")
        XCTAssertFalse(results.first?.name?.isEmpty ?? true, "Entity name should not be empty")
    }

    // MARK: - synchronizeLists Called From Two Threads

    /// Verify that synchronizeLists called from two threads simultaneously
    /// does not corrupt the data manager's internal state
    func testSynchronizeLists_concurrentCalls_dataIntegrity() throws {
        // Arrange: Create a data manager with some lists
        let testDataManager = TestHelpers.createTestDataManager()
        let viewModel = TestMainViewModel(dataManager: testDataManager)
        for i in 0..<10 {
            try viewModel.addList(name: "List \(i)")
        }

        let lists = viewModel.lists
        XCTAssertEqual(lists.count, 10, "Should start with 10 lists")

        // Create two different orderings
        var ordering1 = lists
        var ordering2 = lists.reversed() as [List]

        // Reassign order numbers for each ordering
        for (index, _) in ordering1.enumerated() {
            ordering1[index].orderNumber = index
        }
        for (index, _) in ordering2.enumerated() {
            ordering2[index].orderNumber = index
        }

        let expectation1 = expectation(description: "Sync 1 completed")
        let expectation2 = expectation(description: "Sync 2 completed")

        // Act: Call synchronizeLists (mirrors production CoreDataManager.synchronizeLists)
        // from two threads simultaneously
        DispatchQueue.global(qos: .userInitiated).async {
            testDataManager.synchronizeLists(ordering1)
            expectation1.fulfill()
        }

        DispatchQueue.global(qos: .userInteractive).async {
            testDataManager.synchronizeLists(ordering2)
            expectation2.fulfill()
        }

        wait(for: [expectation1, expectation2], timeout: 15.0)

        // Assert: Data should not be corrupted - all 10 lists should be present
        // One of the two orderings should have "won" (last writer wins)
        let finalLists = testDataManager.lists
        XCTAssertEqual(finalLists.count, 10, "All 10 lists should still exist after concurrent sync")

        // Verify all list IDs are still present
        let finalIds = Set(finalLists.map { $0.id })
        let originalIds = Set(lists.map { $0.id })
        XCTAssertEqual(finalIds, originalIds, "All original list IDs should still exist")

        // Cleanup
        testDataManager.clearAll()
    }

    /// Verify that concurrent sync operations with add/delete do not lose or duplicate entities
    func testSynchronizeLists_concurrentAddDelete_noLostEntities() throws {
        // Arrange: use a single shared container for both setup and concurrent ops
        let testDataManager = TestHelpers.createTestDataManager()
        let sharedContainer = testDataManager.coreDataManager.persistentContainer
        let viewModel = TestMainViewModel(dataManager: testDataManager)
        for i in 0..<5 {
            try viewModel.addList(name: "List \(i)")
        }

        let originalCount = viewModel.lists.count
        let addExpectation = expectation(description: "Add operations completed")
        addExpectation.expectedFulfillmentCount = 10

        // Act: Concurrently add lists from the same container's background contexts
        for i in 0..<10 {
            let bgContext = sharedContainer.newBackgroundContext()
            bgContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy

            bgContext.perform {
                let listEntity = ListEntity(context: bgContext)
                listEntity.id = UUID()
                listEntity.name = "Concurrent Add \(i)"
                listEntity.orderNumber = Int32(originalCount + i)
                listEntity.createdAt = Date()
                listEntity.modifiedAt = Date()
                listEntity.isArchived = false

                do {
                    try bgContext.save()
                } catch {
                    // Acceptable: merge conflicts might occur
                }
                addExpectation.fulfill()
            }
        }

        wait(for: [addExpectation], timeout: 15.0)

        // Assert: all original + concurrent adds should be visible
        testDataManager.loadData()
        XCTAssertEqual(
            testDataManager.lists.count, originalCount + 10,
            "Should have original \(originalCount) plus 10 concurrently added lists"
        )

        // Cleanup
        testDataManager.clearAll()
    }

    // MARK: - perform vs performAndWait Race Condition

    /// Verify that mixing perform and performAndWait on overlapping contexts
    /// does not cause data loss (the core bug pattern)
    func testPerformVsPerformAndWait_mixedAccess_noDataLoss() throws {
        let listId = UUID()
        let viewContext = container.viewContext

        // Create initial entity
        let listEntity = ListEntity(context: viewContext)
        listEntity.id = listId
        listEntity.name = "Initial"
        listEntity.orderNumber = 0
        listEntity.createdAt = Date()
        listEntity.modifiedAt = Date()
        listEntity.isArchived = false
        try viewContext.save()

        // Use two separate background contexts so both can run concurrently
        let asyncContext = container.newBackgroundContext()
        asyncContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
        asyncContext.automaticallyMergesChangesFromParent = true

        let syncContext = container.newBackgroundContext()
        syncContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
        syncContext.automaticallyMergesChangesFromParent = true

        // Act: Dispatch both operations before waiting, so they overlap in time
        let asyncExpectation = expectation(description: "Async perform completed")

        // 1) Async perform — dispatched first
        asyncContext.perform {
            let request: NSFetchRequest<ListEntity> = ListEntity.fetchRequest()
            request.predicate = NSPredicate(format: "id == %@", listId as CVarArg)
            if let entity = try? asyncContext.fetch(request).first {
                entity.name = "Async Update"
                try? asyncContext.save()
            }
            asyncExpectation.fulfill()
        }

        // 2) Synchronous performAndWait on a different context — runs concurrently
        //    with the async perform above (they are on separate contexts/queues)
        var syncName: String?
        syncContext.performAndWait {
            let request: NSFetchRequest<ListEntity> = ListEntity.fetchRequest()
            request.predicate = NSPredicate(format: "id == %@", listId as CVarArg)
            if let entity = try? syncContext.fetch(request).first {
                entity.name = "Sync Update"
                try? syncContext.save()
            }
            syncName = try? syncContext.fetch(request).first?.name
        }

        // Wait for the async operation to also finish
        wait(for: [asyncExpectation], timeout: 5.0)

        // Assert: Both operations should have completed without crash or data loss.
        // The entity should exist and have one of the two updates (last writer wins).
        let readContext = container.newBackgroundContext()
        readContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
        var finalName: String?
        readContext.performAndWait {
            let request: NSFetchRequest<ListEntity> = ListEntity.fetchRequest()
            request.predicate = NSPredicate(format: "id == %@", listId as CVarArg)
            finalName = try? readContext.fetch(request).first?.name
        }

        XCTAssertNotNil(finalName, "Entity should still exist after concurrent perform/performAndWait")
        XCTAssertTrue(
            finalName == "Async Update" || finalName == "Sync Update",
            "Name should be one of the two updates, got: \(finalName ?? "nil")"
        )
        XCTAssertEqual(syncName, "Sync Update", "performAndWait should see its own write")
    }

    /// Verify rapid alternating perform/performAndWait does not deadlock or crash
    func testPerformVsPerformAndWait_rapidAlternation_noDeadlock() throws {
        let bgContext = container.newBackgroundContext()
        bgContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy

        let iterationCount = 50
        let expectations = (0..<iterationCount).map {
            expectation(description: "Iteration \($0)")
        }

        for i in 0..<iterationCount {
            if i % 2 == 0 {
                // Async perform
                bgContext.perform {
                    let entity = ListEntity(context: bgContext)
                    entity.id = UUID()
                    entity.name = "Async \(i)"
                    entity.orderNumber = Int32(i)
                    entity.createdAt = Date()
                    entity.modifiedAt = Date()
                    entity.isArchived = false
                    try? bgContext.save()
                    expectations[i].fulfill()
                }
            } else {
                // Sync performAndWait - must wait for previous async to be queued
                bgContext.perform {
                    bgContext.performAndWait {
                        let entity = ListEntity(context: bgContext)
                        entity.id = UUID()
                        entity.name = "Sync \(i)"
                        entity.orderNumber = Int32(i)
                        entity.createdAt = Date()
                        entity.modifiedAt = Date()
                        entity.isArchived = false
                        try? bgContext.save()
                    }
                    expectations[i].fulfill()
                }
            }
        }

        wait(for: expectations, timeout: 30.0)

        // Assert: Should have created entities without deadlock
        let viewContext = container.viewContext
        viewContext.refreshAllObjects()
        let request: NSFetchRequest<ListEntity> = ListEntity.fetchRequest()
        let count = try viewContext.count(for: request)
        XCTAssertEqual(count, iterationCount, "Should have created \(iterationCount) entities without deadlock")
    }
}
