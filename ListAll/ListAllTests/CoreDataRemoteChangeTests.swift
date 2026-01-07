import XCTest
import CoreData
import Combine
@testable import ListAll

final class CoreDataRemoteChangeTests: XCTestCase {
    
    override func setUp() {
        super.setUp()
        // Reset Core Data for clean test state
        let context = CoreDataManager.shared.viewContext
        context.reset()
    }
    
    override func tearDown() {
        super.tearDown()
    }
    
    // MARK: - Test 1: Remote Change Notification Posted
    
    func testRemoteChangeNotificationPosted() throws {
        let expectation = XCTestExpectation(description: "CoreData remote change notification posted")
        
        // Observe the custom notification
        let observer = NotificationCenter.default.addObserver(
            forName: .coreDataRemoteChange,
            object: nil,
            queue: .main
        ) { _ in
            expectation.fulfill()
        }
        
        // Simulate remote change by posting NSPersistentStoreRemoteChange
        NotificationCenter.default.post(
            name: .NSPersistentStoreRemoteChange,
            object: CoreDataManager.shared.persistentContainer.persistentStoreCoordinator
        )
        
        // Wait for debounced notification (500ms + buffer)
        wait(for: [expectation], timeout: 2.0)
        
        // Cleanup
        NotificationCenter.default.removeObserver(observer)
    }
    
    // MARK: - Test 2: DataManager Reloads on Remote Change
    
    func testDataManagerReloadsOnRemoteChange() throws {
        let dataManager = DataManager.shared
        
        // Get initial count
        let initialCount = dataManager.lists.count
        
        // Add a list directly to Core Data (simulating change from other process)
        let context = CoreDataManager.shared.viewContext
        let listEntity = ListEntity(context: context)
        listEntity.id = UUID()
        listEntity.name = "Test Remote List"
        listEntity.orderNumber = Int32(initialCount)
        listEntity.createdAt = Date()
        listEntity.modifiedAt = Date()
        listEntity.isArchived = false
        
        try context.save()
        
        // Create expectation
        let expectation = XCTestExpectation(description: "DataManager reloaded data")
        
        // Observe lists change
        var cancellable: AnyCancellable?
        cancellable = dataManager.$lists.dropFirst().sink { lists in
            if lists.count > initialCount {
                expectation.fulfill()
            }
        }
        
        // Trigger remote change notification
        NotificationCenter.default.post(
            name: .coreDataRemoteChange,
            object: nil
        )
        
        // Wait for reload
        wait(for: [expectation], timeout: 2.0)
        
        // Verify data was reloaded
        XCTAssertGreaterThan(dataManager.lists.count, initialCount)
        
        // Cleanup
        _ = cancellable // Keep reference until test ends
        
        // Delete test list
        dataManager.deleteList(withId: listEntity.id!)
    }
    
    // MARK: - Test 3: Debouncing Prevents Excessive Reloads
    
    func testDebouncingPreventsExcessiveReloads() throws {
        var notificationCount = 0
        let expectation = XCTestExpectation(description: "Debounced notification received once")
        expectation.assertForOverFulfill = true
        
        // Observe the custom notification
        let observer = NotificationCenter.default.addObserver(
            forName: .coreDataRemoteChange,
            object: nil,
            queue: .main
        ) { _ in
            notificationCount += 1
            expectation.fulfill()
        }
        
        // Post multiple rapid remote changes (should be debounced to single notification)
        for _ in 0..<5 {
            NotificationCenter.default.post(
                name: .NSPersistentStoreRemoteChange,
                object: CoreDataManager.shared.persistentContainer.persistentStoreCoordinator
            )
        }
        
        // Wait for debounced notification (500ms + buffer)
        wait(for: [expectation], timeout: 2.0)
        
        // Verify only one notification was sent despite 5 rapid changes
        XCTAssertEqual(notificationCount, 1)
        
        // Cleanup
        NotificationCenter.default.removeObserver(observer)
    }
    
    // MARK: - Test 4: Thread Safety - Main Thread Execution
    
    func testRemoteChangeThreadSafety() throws {
        let expectation = XCTestExpectation(description: "Notification handled on main thread")
        var wasMainThread = false
        
        // Observe the custom notification
        let observer = NotificationCenter.default.addObserver(
            forName: .coreDataRemoteChange,
            object: nil,
            queue: .main
        ) { _ in
            wasMainThread = Thread.isMainThread
            expectation.fulfill()
        }
        
        // Post notification from background thread
        DispatchQueue.global(qos: .background).async {
            NotificationCenter.default.post(
                name: .NSPersistentStoreRemoteChange,
                object: CoreDataManager.shared.persistentContainer.persistentStoreCoordinator
            )
        }
        
        // Wait for notification (increased timeout for debounce + async dispatch)
        wait(for: [expectation], timeout: 5.0)
        
        // Verify it was handled on main thread
        XCTAssertTrue(wasMainThread)
        
        // Cleanup
        NotificationCenter.default.removeObserver(observer)
    }
}
