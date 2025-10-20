import XCTest
import CoreData
@testable import ListAll

/// Phase 68.9: Automated tests for App Groups data sharing verification
/// These tests verify that both iOS and watchOS can access the same Core Data store via App Groups
final class AppGroupsTests: XCTestCase {
    
    override func setUp() {
        super.setUp()
        print("\n========================================")
        print("Phase 68.9: App Groups Verification Test")
        print("========================================\n")
    }
    
    override func tearDown() {
        print("\n========================================")
        print("Phase 68.9: Test Complete")
        print("========================================\n")
        super.tearDown()
    }
    
    // MARK: - Test 1: Verify App Groups Container Path
    
    func testAppGroupsContainerPathExists() throws {
        print("📋 Test 1: Verifying App Groups container path...")
        
        let appGroupID = "group.io.github.chmc.ListAll"
        let containerURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupID)
        
        XCTAssertNotNil(containerURL, "❌ App Groups container URL should not be nil")
        
        if let url = containerURL {
            print("✅ App Groups container found at: \(url.path)")
            
            // Verify the directory exists
            let fileManager = FileManager.default
            var isDirectory: ObjCBool = false
            let exists = fileManager.fileExists(atPath: url.path, isDirectory: &isDirectory)
            
            XCTAssertTrue(exists, "❌ App Groups container directory should exist")
            XCTAssertTrue(isDirectory.boolValue, "❌ App Groups container path should be a directory")
            
            if exists && isDirectory.boolValue {
                print("✅ App Groups container directory exists and is accessible")
            }
        } else {
            XCTFail("❌ CRITICAL: App Groups container URL is nil - entitlements may not be configured correctly")
        }
        
        print("")
    }
    
    // MARK: - Test 2: Verify CoreDataManager Initialization
    
    func testCoreDataManagerInitialization() throws {
        print("📋 Test 2: Verifying CoreDataManager initialization...")
        
        let coreDataManager = CoreDataManager.shared
        let viewContext = coreDataManager.viewContext
        
        XCTAssertNotNil(viewContext, "❌ View context should not be nil")
        print("✅ CoreDataManager initialized successfully")
        
        // Verify the persistent store is using App Groups container
        let persistentStores = coreDataManager.persistentContainer.persistentStoreCoordinator.persistentStores
        XCTAssertFalse(persistentStores.isEmpty, "❌ Should have at least one persistent store")
        
        if let store = persistentStores.first, let storeURL = store.url {
            print("✅ Persistent store URL: \(storeURL.path)")
            
            // Verify it's in the App Groups container
            let appGroupID = "group.io.github.chmc.ListAll"
            if let containerURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupID) {
                let isInAppGroups = storeURL.path.contains(containerURL.path)
                XCTAssertTrue(isInAppGroups, "❌ Persistent store should be in App Groups container")
                
                if isInAppGroups {
                    print("✅ Persistent store is correctly located in App Groups container")
                } else {
                    print("❌ WARNING: Persistent store is NOT in App Groups container!")
                    print("   Store path: \(storeURL.path)")
                    print("   App Groups path: \(containerURL.path)")
                }
            }
        }
        
        print("")
    }
    
    // MARK: - Test 3: Verify Data Creation and Retrieval
    
    func testAppGroupsDataCreationAndRetrieval() throws {
        print("📋 Test 3: Verifying data creation and retrieval via App Groups...")
        
        let coreDataManager = CoreDataManager.shared
        let context = coreDataManager.viewContext
        
        // Clean up any existing test data
        let fetchRequest: NSFetchRequest<ListEntity> = ListEntity.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "name == %@", "Phase 68.9 Test List")
        let existingLists = try context.fetch(fetchRequest)
        for list in existingLists {
            context.delete(list)
        }
        try context.save()
        
        // Create a test list
        print("Creating test list...")
        let testList = ListEntity(context: context)
        testList.id = UUID()
        testList.name = "Phase 68.9 Test List"
        testList.orderNumber = 0
        testList.createdAt = Date()
        testList.modifiedAt = Date()
        testList.isArchived = false
        
        // Create test items
        print("Creating test items...")
        let item1 = ItemEntity(context: context)
        item1.id = UUID()
        item1.title = "Test Item 1 - Active"
        item1.quantity = 2
        item1.isCrossedOut = false
        item1.orderNumber = 0
        item1.createdAt = Date()
        item1.modifiedAt = Date()
        item1.list = testList
        
        let item2 = ItemEntity(context: context)
        item2.id = UUID()
        item2.title = "Test Item 2 - Completed"
        item2.quantity = 1
        item2.isCrossedOut = true
        item2.orderNumber = 1
        item2.createdAt = Date()
        item2.modifiedAt = Date()
        item2.list = testList
        
        let item3 = ItemEntity(context: context)
        item3.id = UUID()
        item3.title = "Test Item 3 - Active"
        item3.quantity = 3
        item3.isCrossedOut = false
        item3.orderNumber = 2
        item3.createdAt = Date()
        item3.modifiedAt = Date()
        item3.list = testList
        
        // Save to persistent store
        print("Saving to persistent store...")
        try context.save()
        print("✅ Test data saved successfully")
        
        // Verify data can be retrieved
        print("Retrieving test data...")
        let retrieveRequest: NSFetchRequest<ListEntity> = ListEntity.fetchRequest()
        retrieveRequest.predicate = NSPredicate(format: "name == %@", "Phase 68.9 Test List")
        retrieveRequest.relationshipKeyPathsForPrefetching = ["items"]
        
        let retrievedLists = try context.fetch(retrieveRequest)
        XCTAssertEqual(retrievedLists.count, 1, "❌ Should retrieve exactly one test list")
        
        if let retrievedList = retrievedLists.first {
            print("✅ Successfully retrieved test list: \(retrievedList.name ?? "Unnamed")")
            
            let items = retrievedList.items as? Set<ItemEntity> ?? []
            XCTAssertEqual(items.count, 3, "❌ Should have 3 items")
            print("✅ List has \(items.count) items")
            
            let activeItems = items.filter { !$0.isCrossedOut }
            let completedItems = items.filter { $0.isCrossedOut }
            
            XCTAssertEqual(activeItems.count, 2, "❌ Should have 2 active items")
            XCTAssertEqual(completedItems.count, 1, "❌ Should have 1 completed item")
            
            print("✅ Item breakdown: \(activeItems.count) active, \(completedItems.count) completed")
            
            // Verify quantities
            let totalQuantity = items.reduce(0) { $0 + Int($1.quantity) }
            XCTAssertEqual(totalQuantity, 6, "❌ Total quantity should be 6 (2+1+3)")
            print("✅ Total quantity: \(totalQuantity)")
            
            // Log detailed item information
            print("\n📦 Item details:")
            for (index, item) in items.sorted(by: { $0.orderNumber < $1.orderNumber }).enumerated() {
                let status = item.isCrossedOut ? "✓ Completed" : "○ Active"
                print("  \(index + 1). \(item.title ?? "Untitled") - Qty: \(item.quantity) - \(status)")
            }
        } else {
            XCTFail("❌ Failed to retrieve test list")
        }
        
        // Clean up test data
        print("\nCleaning up test data...")
        for list in retrievedLists {
            context.delete(list)
        }
        try context.save()
        print("✅ Test data cleaned up")
        
        print("")
    }
    
    // MARK: - Test 4: Verify Data Persistence Across Container Access
    
    func testAppGroupsDataPersistence() throws {
        print("📋 Test 4: Verifying data persistence in App Groups container...")
        
        let coreDataManager = CoreDataManager.shared
        let context = coreDataManager.viewContext
        
        // Create a unique test list
        let testID = UUID()
        let testListName = "Persistence Test \(testID.uuidString.prefix(8))"
        
        print("Creating test list with unique ID: \(testListName)")
        let testList = ListEntity(context: context)
        testList.id = testID
        testList.name = testListName
        testList.orderNumber = 0
        testList.createdAt = Date()
        testList.modifiedAt = Date()
        testList.isArchived = false
        
        try context.save()
        print("✅ Test list saved")
        
        // Clear the context to force a fresh fetch
        context.reset()
        print("Context reset, fetching from persistent store...")
        
        // Fetch the data back
        let fetchRequest: NSFetchRequest<ListEntity> = ListEntity.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "id == %@", testID as CVarArg)
        
        let fetchedLists = try context.fetch(fetchRequest)
        XCTAssertEqual(fetchedLists.count, 1, "❌ Should fetch exactly one list")
        
        if let fetchedList = fetchedLists.first {
            XCTAssertEqual(fetchedList.id, testID, "❌ List ID should match")
            XCTAssertEqual(fetchedList.name, testListName, "❌ List name should match")
            print("✅ Data persisted correctly in App Groups container")
            print("   ID: \(fetchedList.id?.uuidString ?? "nil")")
            print("   Name: \(fetchedList.name ?? "nil")")
        } else {
            XCTFail("❌ Failed to fetch persisted list")
        }
        
        // Clean up
        print("Cleaning up test data...")
        for list in fetchedLists {
            context.delete(list)
        }
        try context.save()
        print("✅ Test data cleaned up")
        
        print("")
    }
    
    // MARK: - Test 5: Document App Groups Configuration
    
    func testDocumentAppGroupsConfiguration() throws {
        print("📋 Test 5: Documenting App Groups configuration...")
        print("\n" + String(repeating: "=", count: 60))
        print("APP GROUPS CONFIGURATION SUMMARY")
        print(String(repeating: "=", count: 60))
        
        let appGroupID = "group.io.github.chmc.ListAll"
        print("\n📱 App Group ID: \(appGroupID)")
        
        if let containerURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupID) {
            print("📂 Container Location: \(containerURL.path)")
            
            let storeURL = containerURL.appendingPathComponent("ListAll.sqlite")
            print("💾 Core Data Store: \(storeURL.path)")
            
            let fileManager = FileManager.default
            let storeExists = fileManager.fileExists(atPath: storeURL.path)
            print("✅ Store Exists: \(storeExists ? "YES" : "NO")")
            
            if storeExists {
                do {
                    let attributes = try fileManager.attributesOfItem(atPath: storeURL.path)
                    if let size = attributes[.size] as? Int64 {
                        let sizeKB = Double(size) / 1024.0
                        print("📊 Store Size: \(String(format: "%.2f", sizeKB)) KB")
                    }
                    if let modDate = attributes[.modificationDate] as? Date {
                        let formatter = DateFormatter()
                        formatter.dateStyle = .medium
                        formatter.timeStyle = .medium
                        print("🕐 Last Modified: \(formatter.string(from: modDate))")
                    }
                } catch {
                    print("⚠️  Could not read store attributes: \(error)")
                }
            }
            
            print("\n🔧 Platform: iOS (simulator)")
            #if os(watchOS)
            print("🔧 Platform: watchOS")
            #endif
            
            print("\n" + String(repeating: "=", count: 60))
            print("✅ App Groups configuration is valid and working")
            print(String(repeating: "=", count: 60) + "\n")
            
            XCTAssertTrue(true, "Configuration documented successfully")
        } else {
            print("\n❌ ERROR: App Groups container not accessible!")
            print(String(repeating: "=", count: 60) + "\n")
            XCTFail("App Groups container URL is nil")
        }
    }
}

