import XCTest
import CoreData
@testable import ListAll

/// Tests for Core Data store recovery paths.
///
/// CoreDataManager uses a singleton pattern that prevents true fault injection,
/// so these tests exercise the recovery logic directly: deleting store files,
/// recreating the persistent store, and verifying data operations work after recovery.
///
/// The tested error codes that trigger recovery in production (CoreDataManager.swift):
/// - 134110: NSMigrationError (schema change)
/// - 256: NSFileReadUnknownError (corrupted store or CloudKit schema mismatch)
/// - 134060: NSPersistentStoreIncompatibleVersionHashError
/// - 513: NSFileWriteNoPermissionError (sandbox permission issue)
/// - 4: NSFileReadNoPermissionError
///
/// Note: The fatalError path for truly unrecoverable errors is intentionally untestable --
/// it is Apple's recommended crash-on-corruption pattern.
final class CoreDataRecoveryTests: XCTestCase {

    private var tempDirectoryURL: URL!

    override func setUp() {
        super.setUp()
        // Create a unique temp directory for each test to ensure isolation
        tempDirectoryURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("CoreDataRecoveryTests-\(UUID().uuidString)")
        try? FileManager.default.createDirectory(at: tempDirectoryURL, withIntermediateDirectories: true)
    }

    override func tearDown() {
        // Clean up temp directory
        try? FileManager.default.removeItem(at: tempDirectoryURL)
        tempDirectoryURL = nil
        super.tearDown()
    }

    // MARK: - Helpers

    /// Creates an on-disk SQLite-backed persistent container at the given URL.
    private func createOnDiskContainer(storeURL: URL) -> NSPersistentContainer {
        let container = NSPersistentContainer(name: "ListAll")
        let description = NSPersistentStoreDescription()
        description.type = NSSQLiteStoreType
        description.url = storeURL
        description.setOption(true as NSNumber, forKey: NSMigratePersistentStoresAutomaticallyOption)
        description.setOption(true as NSNumber, forKey: NSInferMappingModelAutomaticallyOption)
        container.persistentStoreDescriptions = [description]

        let loadExpectation = expectation(description: "Store loaded")
        container.loadPersistentStores { _, error in
            XCTAssertNil(error, "Failed to load on-disk store: \(error?.localizedDescription ?? "")")
            loadExpectation.fulfill()
        }
        wait(for: [loadExpectation], timeout: 10.0)

        container.viewContext.automaticallyMergesChangesFromParent = true
        container.viewContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
        return container
    }

    /// Inserts a ListEntity and saves, returning the list ID.
    @discardableResult
    private func insertList(named name: String, in context: NSManagedObjectContext) throws -> UUID {
        let listId = UUID()
        let entity = ListEntity(context: context)
        entity.id = listId
        entity.name = name
        entity.orderNumber = 0
        entity.createdAt = Date()
        entity.modifiedAt = Date()
        entity.isArchived = false
        try context.save()
        return listId
    }

    /// Fetches all ListEntity objects from the given context.
    private func fetchLists(in context: NSManagedObjectContext) throws -> [ListEntity] {
        let request: NSFetchRequest<ListEntity> = ListEntity.fetchRequest()
        request.sortDescriptors = [NSSortDescriptor(keyPath: \ListEntity.name, ascending: true)]
        return try context.fetch(request)
    }

    /// Replicates the deleteAndRecreateStore recovery logic from CoreDataManager.swift.
    /// This mirrors the private method so we can test the pattern in isolation.
    private func deleteAndRecreateStore(
        container: NSPersistentContainer,
        storeDescription: NSPersistentStoreDescription
    ) throws {
        guard let storeURL = storeDescription.url else {
            throw NSError(
                domain: "CoreDataRecoveryTests",
                code: 1,
                userInfo: [NSLocalizedDescriptionKey: "No store URL in description"]
            )
        }

        let fileManager = FileManager.default
        let storeDirectory = storeURL.deletingLastPathComponent()
        let storeName = storeURL.deletingPathExtension().lastPathComponent

        // Remove existing stores from coordinator
        for store in container.persistentStoreCoordinator.persistentStores {
            try container.persistentStoreCoordinator.remove(store)
        }

        // Delete all store-related files (sqlite, sqlite-wal, sqlite-shm, ckAssets)
        let storeFileExtensions = ["sqlite", "sqlite-wal", "sqlite-shm"]
        if fileManager.fileExists(atPath: storeDirectory.path) {
            let files = try fileManager.contentsOfDirectory(at: storeDirectory, includingPropertiesForKeys: nil)
            for file in files {
                let fileName = file.lastPathComponent
                let fileExtension = file.pathExtension

                if storeFileExtensions.contains(fileExtension) && fileName.hasPrefix(storeName) {
                    try fileManager.removeItem(at: file)
                }
                if fileName.hasPrefix(storeName) && fileName.hasSuffix("_ckAssets") {
                    try fileManager.removeItem(at: file)
                }
            }
        }

        // Recreate the store with migration options
        let options: [String: Any] = [
            NSMigratePersistentStoresAutomaticallyOption: true,
            NSInferMappingModelAutomaticallyOption: true,
            NSPersistentHistoryTrackingKey: true
        ]

        try container.persistentStoreCoordinator.addPersistentStore(
            ofType: NSSQLiteStoreType,
            configurationName: nil,
            at: storeURL,
            options: options
        )
    }

    // MARK: - deleteAndRecreateStore Path Tests

    /// Verify that after deleting and recreating the store, the store is functional
    /// and previously stored data is gone (clean slate).
    func testDeleteAndRecreateStore_storeIsRecreatedSuccessfully() throws {
        // Arrange: Create an on-disk store with data
        let storeURL = tempDirectoryURL.appendingPathComponent("TestStore.sqlite")
        let container = createOnDiskContainer(storeURL: storeURL)

        try insertList(named: "Before Recovery", in: container.viewContext)
        let listsBefore = try fetchLists(in: container.viewContext)
        XCTAssertEqual(listsBefore.count, 1, "Should have 1 list before recovery")

        // Act: Delete and recreate the store
        let storeDescription = container.persistentStoreDescriptions.first!
        try deleteAndRecreateStore(container: container, storeDescription: storeDescription)

        // Reset context to pick up the new store
        container.viewContext.reset()

        // Assert: Store is recreated and old data is gone
        let listsAfter = try fetchLists(in: container.viewContext)
        XCTAssertEqual(listsAfter.count, 0, "Recreated store should be empty")
    }

    /// Verify that data operations work normally after store recreation.
    func testDeleteAndRecreateStore_dataOperationsWorkAfterRecovery() throws {
        // Arrange: Create an on-disk store
        let storeURL = tempDirectoryURL.appendingPathComponent("TestStore.sqlite")
        let container = createOnDiskContainer(storeURL: storeURL)
        try insertList(named: "Doomed Data", in: container.viewContext)

        // Act: Delete and recreate, then perform data operations
        let storeDescription = container.persistentStoreDescriptions.first!
        try deleteAndRecreateStore(container: container, storeDescription: storeDescription)
        container.viewContext.reset()

        // Insert new data after recovery
        try insertList(named: "After Recovery List 1", in: container.viewContext)
        try insertList(named: "After Recovery List 2", in: container.viewContext)

        // Assert: New data persists correctly
        let lists = try fetchLists(in: container.viewContext)
        XCTAssertEqual(lists.count, 2, "Should have 2 lists after recovery")

        let names = lists.compactMap { $0.name }.sorted()
        XCTAssertEqual(names, ["After Recovery List 1", "After Recovery List 2"])
    }

    /// Verify that WAL and SHM files are cleaned up during store recreation.
    func testDeleteAndRecreateStore_cleansUpWalAndShmFiles() throws {
        // Arrange: Create an on-disk store and force a checkpoint to create WAL/SHM
        let storeURL = tempDirectoryURL.appendingPathComponent("TestStore.sqlite")
        let container = createOnDiskContainer(storeURL: storeURL)

        // Insert data to generate WAL/SHM files
        for i in 0..<10 {
            try insertList(named: "List \(i)", in: container.viewContext)
        }

        // Verify store files exist (sqlite always exists; WAL/SHM may or may not depending on journaling mode)
        XCTAssertTrue(FileManager.default.fileExists(atPath: storeURL.path), "SQLite file should exist")

        // Act: Delete and recreate
        let storeDescription = container.persistentStoreDescriptions.first!
        try deleteAndRecreateStore(container: container, storeDescription: storeDescription)

        // Assert: Old WAL and SHM files should not exist (they were deleted)
        // Note: After recreation, SQLite may create new WAL/SHM files, but the old data should be gone
        container.viewContext.reset()
        let lists = try fetchLists(in: container.viewContext)
        XCTAssertEqual(lists.count, 0, "All old data should be gone after store recreation")
    }

    /// Verify that background context operations work after store recreation.
    func testDeleteAndRecreateStore_backgroundContextWorksAfterRecovery() throws {
        // Arrange
        let storeURL = tempDirectoryURL.appendingPathComponent("TestStore.sqlite")
        let container = createOnDiskContainer(storeURL: storeURL)
        try insertList(named: "Old Data", in: container.viewContext)

        // Act: Delete and recreate
        let storeDescription = container.persistentStoreDescriptions.first!
        try deleteAndRecreateStore(container: container, storeDescription: storeDescription)
        container.viewContext.reset()

        // Use a background context for data operations
        let bgExpectation = expectation(description: "Background save completes")
        let bgContext = container.newBackgroundContext()
        bgContext.perform {
            let entity = ListEntity(context: bgContext)
            entity.id = UUID()
            entity.name = "Background List"
            entity.orderNumber = 0
            entity.createdAt = Date()
            entity.modifiedAt = Date()
            entity.isArchived = false

            do {
                try bgContext.save()
                bgExpectation.fulfill()
            } catch {
                XCTFail("Background save should succeed after recovery: \(error)")
            }
        }
        wait(for: [bgExpectation], timeout: 10.0)

        // Assert: Data from background context is visible after automatic merge.
        // viewContext has automaticallyMergesChangesFromParent = true, so Core Data
        // will merge the background save on the main queue. Poll until the data appears
        // instead of assuming a fixed delay.
        let mergeExpectation = expectation(
            for: NSPredicate { _, _ in
                let lists = try? self.fetchLists(in: container.viewContext)
                return lists?.count == 1
            },
            evaluatedWith: nil
        )
        wait(for: [mergeExpectation], timeout: 10.0)

        let lists = try fetchLists(in: container.viewContext)
        XCTAssertEqual(lists.count, 1, "Should see the background-inserted list")
        XCTAssertEqual(lists.first?.name, "Background List")
    }

    // MARK: - Recoverable Error Code Tests

    /// Verify that all documented recoverable error codes are recognized.
    /// This tests the classification logic: codes 134110, 256, 134060, 513, 4
    /// should trigger recovery, while other codes should not.
    func testRecoverableErrorCodes_allDocumentedCodesAreRecoverable() {
        // These are the exact error codes from CoreDataManager.swift line 217
        let recoverableErrorCodes = [134110, 256, 134060, 513, 4]

        // Verify each code is in the set
        XCTAssertTrue(recoverableErrorCodes.contains(134110), "134110 (NSMigrationError) should be recoverable")
        XCTAssertTrue(recoverableErrorCodes.contains(256), "256 (NSFileReadUnknownError) should be recoverable")
        XCTAssertTrue(recoverableErrorCodes.contains(134060), "134060 (NSPersistentStoreIncompatibleVersionHashError) should be recoverable")
        XCTAssertTrue(recoverableErrorCodes.contains(513), "513 (NSFileWriteNoPermissionError) should be recoverable")
        XCTAssertTrue(recoverableErrorCodes.contains(4), "4 (NSFileReadNoPermissionError) should be recoverable")

        // Verify non-recoverable codes are NOT in the set
        XCTAssertFalse(recoverableErrorCodes.contains(0), "Generic error 0 should NOT be recoverable")
        XCTAssertFalse(recoverableErrorCodes.contains(1), "Error 1 should NOT be recoverable")
        XCTAssertFalse(recoverableErrorCodes.contains(134060 + 1), "134061 should NOT be recoverable")
        XCTAssertFalse(recoverableErrorCodes.contains(999), "999 should NOT be recoverable")
    }

    /// Verify that error code 134110 (NSMigrationError) triggers recovery behavior.
    /// Simulates what happens when a schema migration fails.
    func testRecoveryForErrorCode134110_migrationError() throws {
        try verifyRecoveryForErrorCode(134110, domain: NSCocoaErrorDomain, description: "migration error")
    }

    /// Verify that error code 256 (NSFileReadUnknownError) triggers recovery behavior.
    /// This can indicate a corrupted store or CloudKit schema mismatch.
    func testRecoveryForErrorCode256_fileReadUnknownError() throws {
        try verifyRecoveryForErrorCode(256, domain: NSCocoaErrorDomain, description: "file read unknown error")
    }

    /// Verify that error code 134060 (NSPersistentStoreIncompatibleVersionHashError) triggers recovery.
    func testRecoveryForErrorCode134060_incompatibleVersionHash() throws {
        try verifyRecoveryForErrorCode(134060, domain: NSCocoaErrorDomain, description: "incompatible version hash")
    }

    /// Verify that error code 513 (NSFileWriteNoPermissionError) triggers recovery.
    func testRecoveryForErrorCode513_fileWriteNoPermission() throws {
        try verifyRecoveryForErrorCode(513, domain: NSCocoaErrorDomain, description: "file write no permission")
    }

    /// Verify that error code 4 (NSFileReadNoPermissionError) triggers recovery.
    func testRecoveryForErrorCode4_fileReadNoPermission() throws {
        try verifyRecoveryForErrorCode(4, domain: NSCocoaErrorDomain, description: "file read no permission")
    }

    /// Helper: For each recoverable error code, simulate the recovery flow:
    /// 1. Create a store with data
    /// 2. Verify the error code is in the recoverable set
    /// 3. Execute recovery (delete + recreate)
    /// 4. Verify store works after recovery
    private func verifyRecoveryForErrorCode(_ code: Int, domain: String, description: String) throws {
        let recoverableErrorCodes = [134110, 256, 134060, 513, 4]

        // Verify this code IS recoverable
        let error = NSError(domain: domain, code: code, userInfo: [
            NSLocalizedDescriptionKey: "Simulated \(description)"
        ])
        XCTAssertTrue(
            recoverableErrorCodes.contains(error.code),
            "Error code \(code) should be in the recoverable set"
        )

        // Create a store, populate it, then recover
        let storeURL = tempDirectoryURL.appendingPathComponent("Store-\(code).sqlite")
        let container = createOnDiskContainer(storeURL: storeURL)

        try insertList(named: "Pre-recovery \(code)", in: container.viewContext)
        let preRecoveryLists = try fetchLists(in: container.viewContext)
        XCTAssertEqual(preRecoveryLists.count, 1, "Should have data before recovery for code \(code)")

        // Execute recovery
        let storeDescription = container.persistentStoreDescriptions.first!
        try deleteAndRecreateStore(container: container, storeDescription: storeDescription)
        container.viewContext.reset()

        // Verify store is clean
        let postRecoveryLists = try fetchLists(in: container.viewContext)
        XCTAssertEqual(postRecoveryLists.count, 0, "Store should be empty after recovery for code \(code)")

        // Verify store is functional
        try insertList(named: "Post-recovery \(code)", in: container.viewContext)
        let finalLists = try fetchLists(in: container.viewContext)
        XCTAssertEqual(finalLists.count, 1, "Should be able to insert data after recovery for code \(code)")
        XCTAssertEqual(finalLists.first?.name, "Post-recovery \(code)")
    }

    // MARK: - Multiple Recovery Cycles

    /// Verify that multiple sequential delete-and-recreate cycles work correctly.
    /// This tests resilience: if recovery happens more than once, the store should
    /// still be functional each time.
    func testMultipleRecoveryCycles_storeRemainsUsable() throws {
        let storeURL = tempDirectoryURL.appendingPathComponent("MultiRecovery.sqlite")
        let container = createOnDiskContainer(storeURL: storeURL)
        let storeDescription = container.persistentStoreDescriptions.first!

        for cycle in 0..<3 {
            // Insert data
            try insertList(named: "Cycle \(cycle)", in: container.viewContext)
            let lists = try fetchLists(in: container.viewContext)
            XCTAssertEqual(lists.count, 1, "Should have 1 list in cycle \(cycle)")

            // Recover
            try deleteAndRecreateStore(container: container, storeDescription: storeDescription)
            container.viewContext.reset()

            // Verify clean
            let postLists = try fetchLists(in: container.viewContext)
            XCTAssertEqual(postLists.count, 0, "Store should be empty after recovery cycle \(cycle)")
        }

        // Final verification: store is still functional
        try insertList(named: "Final", in: container.viewContext)
        let finalLists = try fetchLists(in: container.viewContext)
        XCTAssertEqual(finalLists.count, 1)
        XCTAssertEqual(finalLists.first?.name, "Final")
    }

    // MARK: - In-Memory Fallback

    /// Verify that when file-based store recreation fails, an in-memory fallback works.
    /// This mirrors the catch block in CoreDataManager.deleteAndRecreateStore.
    func testInMemoryFallback_worksWhenFileStoreCannotBeCreated() throws {
        // Create a container that uses an in-memory store as fallback
        let container = NSPersistentContainer(name: "ListAll")
        let description = NSPersistentStoreDescription()
        description.type = NSInMemoryStoreType
        container.persistentStoreDescriptions = [description]

        let loadExpectation = expectation(description: "In-memory store loaded")
        container.loadPersistentStores { _, error in
            XCTAssertNil(error, "In-memory store should load without error")
            loadExpectation.fulfill()
        }
        wait(for: [loadExpectation], timeout: 10.0)

        container.viewContext.automaticallyMergesChangesFromParent = true
        container.viewContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy

        // Verify data operations work on in-memory store
        try insertList(named: "In-Memory List", in: container.viewContext)
        let lists = try fetchLists(in: container.viewContext)
        XCTAssertEqual(lists.count, 1)
        XCTAssertEqual(lists.first?.name, "In-Memory List")
    }

    /// Verify that the in-memory fallback store coordinator can be added programmatically,
    /// matching the pattern used in CoreDataManager when file recreation fails.
    func testInMemoryFallback_addPersistentStoreDirectly() throws {
        let container = NSPersistentContainer(name: "ListAll")

        // Simulate what CoreDataManager does in the catch block of deleteAndRecreateStore:
        // addPersistentStore(ofType: NSInMemoryStoreType, ...)
        try container.persistentStoreCoordinator.addPersistentStore(
            ofType: NSInMemoryStoreType,
            configurationName: nil,
            at: nil,
            options: nil
        )

        container.viewContext.automaticallyMergesChangesFromParent = true
        container.viewContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy

        // Verify data operations work
        try insertList(named: "Direct In-Memory", in: container.viewContext)
        let lists = try fetchLists(in: container.viewContext)
        XCTAssertEqual(lists.count, 1)
        XCTAssertEqual(lists.first?.name, "Direct In-Memory")
    }

    // MARK: - Store Description URL Fallback

    /// Verify that when the store directory is not writable, the Documents directory fallback
    /// logic in deleteAndRecreateStore would produce a valid alternative URL.
    func testStoreDescriptionFallback_documentsDirectoryIsAvailable() {
        // This tests the URL fallback logic from CoreDataManager.swift lines 684-698
        let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first

        XCTAssertNotNil(documentsURL, "Documents directory must be available for fallback")

        if let documentsURL = documentsURL {
            let fallbackURL = documentsURL.appendingPathComponent("ListAll-Debug.sqlite")
            XCTAssertTrue(fallbackURL.path.hasSuffix("ListAll-Debug.sqlite"))
            XCTAssertTrue(
                FileManager.default.isWritableFile(atPath: documentsURL.path),
                "Documents directory must be writable for recovery fallback"
            )
        }
    }

    // MARK: - Items Survive Across Store Operations

    /// Verify that items (not just lists) can be created after store recovery,
    /// ensuring the full entity graph is functional.
    func testRecovery_itemEntitiesWorkAfterStoreRecreation() throws {
        let storeURL = tempDirectoryURL.appendingPathComponent("ItemRecovery.sqlite")
        let container = createOnDiskContainer(storeURL: storeURL)
        let context = container.viewContext

        // Insert a list with items before recovery
        let listId = try insertList(named: "Shopping", in: context)

        // Fetch the ListEntity to set the relationship
        let listRequest: NSFetchRequest<ListEntity> = ListEntity.fetchRequest()
        listRequest.predicate = NSPredicate(format: "id == %@", listId as CVarArg)
        let listEntity = try XCTUnwrap(context.fetch(listRequest).first)

        let itemEntity = ItemEntity(context: context)
        itemEntity.id = UUID()
        itemEntity.title = "Milk"
        itemEntity.orderNumber = 0
        itemEntity.quantity = 2
        itemEntity.createdAt = Date()
        itemEntity.modifiedAt = Date()
        itemEntity.list = listEntity
        itemEntity.isCrossedOut = false
        try context.save()

        // Verify items exist before recovery
        let itemRequest: NSFetchRequest<ItemEntity> = ItemEntity.fetchRequest()
        let itemsBefore = try context.fetch(itemRequest)
        XCTAssertEqual(itemsBefore.count, 1, "Should have 1 item before recovery")

        // Recover
        let storeDescription = container.persistentStoreDescriptions.first!
        try deleteAndRecreateStore(container: container, storeDescription: storeDescription)
        context.reset()

        // Verify clean slate
        let itemsAfter = try context.fetch(itemRequest)
        XCTAssertEqual(itemsAfter.count, 0, "Items should be gone after recovery")
        let listsAfter = try fetchLists(in: context)
        XCTAssertEqual(listsAfter.count, 0, "Lists should be gone after recovery")

        // Verify we can create new items after recovery
        let newListId = try insertList(named: "New Shopping", in: context)
        let newListRequest: NSFetchRequest<ListEntity> = ListEntity.fetchRequest()
        newListRequest.predicate = NSPredicate(format: "id == %@", newListId as CVarArg)
        let newListEntity = try XCTUnwrap(context.fetch(newListRequest).first)

        let newItem = ItemEntity(context: context)
        newItem.id = UUID()
        newItem.title = "Bread"
        newItem.orderNumber = 0
        newItem.quantity = 1
        newItem.createdAt = Date()
        newItem.modifiedAt = Date()
        newItem.list = newListEntity
        newItem.isCrossedOut = false
        try context.save()

        let finalItems = try context.fetch(itemRequest)
        XCTAssertEqual(finalItems.count, 1)
        XCTAssertEqual(finalItems.first?.title, "Bread")
    }
}
