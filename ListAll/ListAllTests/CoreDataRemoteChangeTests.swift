import XCTest
import CoreData
import Combine
@testable import ListAll

final class CoreDataRemoteChangeTests: XCTestCase {

    override func setUp() {
        super.setUp()
        // CRITICAL: Reset singleton state to prevent cross-test contamination
        // This clears any pending debounce timers from previous tests
        CoreDataManager.resetForTesting()

        // Ensure Core Data stack is fully initialized before tests run
        // Access persistentStoreCoordinator to trigger lazy initialization
        _ = CoreDataManager.shared.persistentContainer.persistentStoreCoordinator

        // Drain the main run loop to process any pending dispatches/timers
        // from previous tests. Without this, leftover DispatchQueue.main.async
        // blocks or Timer callbacks can fire during the next test and interfere.
        RunLoop.current.run(until: Date(timeIntervalSinceNow: 0.2))
    }

    override func tearDown() {
        // Reset again after test to clean up any state changes
        CoreDataManager.resetForTesting()
        // Drain any pending timers/dispatches so they don't leak into the next test
        RunLoop.current.run(until: Date(timeIntervalSinceNow: 0.2))
        super.tearDown()
    }

    // MARK: - Test 1: Remote Change Notification Posted

    func testRemoteChangeNotificationPosted() throws {
        // Use XCTest's built-in expectation for notification - more reliable than manual observer
        let notificationExpectation = expectation(
            forNotification: .coreDataRemoteChange,
            object: nil,
            handler: nil
        )

        // Give the run loop a chance to process any pending work before posting
        RunLoop.current.run(until: Date(timeIntervalSinceNow: 0.1))

        // Simulate remote change by posting NSPersistentStoreRemoteChange
        // IMPORTANT: Post on main thread to ensure consistent timer scheduling
        DispatchQueue.main.async {
            NotificationCenter.default.post(
                name: .NSPersistentStoreRemoteChange,
                object: CoreDataManager.shared.persistentContainer.persistentStoreCoordinator
            )
        }

        // Wait for debounced notification
        // Timeout: 500ms debounce + 2.5s buffer for CI environments (slower runners)
        wait(for: [notificationExpectation], timeout: 3.0)
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

        // Give the run loop a chance to process any pending work
        RunLoop.current.run(until: Date(timeIntervalSinceNow: 0.1))

        // Post multiple rapid remote changes (should be debounced to single notification)
        // Post on main thread to ensure consistent timer scheduling
        DispatchQueue.main.async {
            for _ in 0..<5 {
                NotificationCenter.default.post(
                    name: .NSPersistentStoreRemoteChange,
                    object: CoreDataManager.shared.persistentContainer.persistentStoreCoordinator
                )
            }
        }

        // Wait for debounced notification (500ms + buffer for CI)
        wait(for: [expectation], timeout: 3.0)

        // Verify only one notification was sent despite 5 rapid changes
        XCTAssertEqual(notificationCount, 1)

        // Cleanup
        NotificationCenter.default.removeObserver(observer)
    }
    
    // MARK: - Test 4: Thread Safety - Main Thread Execution

    func testRemoteChangeThreadSafety() throws {
        var wasMainThread = false
        var notificationReceived = false

        // Observe the debounced notification
        let observer = NotificationCenter.default.addObserver(
            forName: .coreDataRemoteChange,
            object: nil,
            queue: nil  // Deliver on posting thread (should be main)
        ) { _ in
            wasMainThread = Thread.isMainThread
            notificationReceived = true
        }

        // Let the run loop fully settle before triggering async work.
        // This drains any pending DispatchQueue.main.async blocks and timers
        // left over from previous tests in the suite. 1.0s is necessary because
        // the debounce timer from previous tests is 500ms, and we need margin
        // for the timer callback + any resulting async work to complete.
        RunLoop.current.run(until: Date(timeIntervalSinceNow: 1.0))

        // Capture coordinator reference on main thread before dispatching to background.
        // This avoids any potential race accessing the singleton from background.
        let coordinator = CoreDataManager.shared.persistentContainer.persistentStoreCoordinator

        // Post notification from background thread — this exercises the
        // background→main dispatch path in handlePersistentStoreRemoteChange
        DispatchQueue.global(qos: .background).async {
            NotificationCenter.default.post(
                name: .NSPersistentStoreRemoteChange,
                object: coordinator
            )
        }

        // Manually pump the run loop to process:
        // 1. The DispatchQueue.main.async from handlePersistentStoreRemoteChange (background→main)
        // 2. The Timer.scheduledTimer (500ms debounce)
        // 3. The notification post from processRemoteChange
        // XCTest's wait(for:) does not reliably pump Timer events in all scenarios,
        // so we use explicit RunLoop pumping with a polling check.
        let deadline = Date(timeIntervalSinceNow: 10.0)
        while !notificationReceived && Date() < deadline {
            RunLoop.current.run(until: Date(timeIntervalSinceNow: 0.05))
        }

        // Verify the notification was received and handled on main thread
        XCTAssertTrue(notificationReceived, "Debounced .coreDataRemoteChange notification should have been posted")
        XCTAssertTrue(wasMainThread, "Notification should be handled on main thread")

        // Cleanup
        NotificationCenter.default.removeObserver(observer)
    }
}
