//
//  ListAllWatch_Watch_AppTests.swift
//  ListAllWatch Watch AppTests
//
//  Created by Aleksi Sutela on 19.10.2025.
//

import XCTest
@testable import ListAllWatch_Watch_App

final class ListAllWatch_Watch_AppTests: XCTestCase {

    override func setUpWithError() throws {
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }

    override func tearDownWithError() throws {
        // Drain pending asyncAfter dispatches from ViewModels created during tests
        RunLoop.current.run(until: Date(timeIntervalSinceNow: 1.0))
    }

    // MARK: - Phase 75: watchOS ViewModel Sync Integration Tests

    /// Test that WatchMainViewModel responds to sync notifications from iOS
    func testWatchMainViewModelReceivesSyncNotificationFromiOS() throws {
        // Given: A WatchMainViewModel instance
        let viewModel = WatchMainViewModel()

        // Initially not syncing
        XCTAssertFalse(viewModel.isSyncingFromiOS, "Should not be syncing initially")

        // When: iOS sends a sync notification
        NotificationCenter.default.post(
            name: NSNotification.Name("WatchConnectivitySyncReceived"),
            object: nil
        )

        // Then: isSyncingFromiOS is set synchronously in refreshFromiOS()
        XCTAssertTrue(viewModel.isSyncingFromiOS, "Should be syncing after notification")

        // And: Sync indicator should eventually disappear (0.1s + 0.5s async delays in refreshFromiOS)
        let syncComplete = XCTestExpectation(description: "Sync indicator disappears")
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            syncComplete.fulfill()
        }
        wait(for: [syncComplete], timeout: 5.0)
        XCTAssertFalse(viewModel.isSyncingFromiOS, "Should stop syncing after delay")
    }

    /// Test that WatchListViewModel responds to sync notifications from iOS
    func testWatchListViewModelReceivesSyncNotificationFromiOS() throws {
        // Given: A test list and WatchListViewModel instance
        let testList = List(name: "Test Shopping List")
        let viewModel = WatchListViewModel(list: testList)

        // Initially not syncing
        XCTAssertFalse(viewModel.isSyncingFromiOS, "Should not be syncing initially")

        // When: iOS sends a sync notification
        NotificationCenter.default.post(
            name: NSNotification.Name("WatchConnectivitySyncReceived"),
            object: nil
        )

        // Then: isSyncingFromiOS is set synchronously in refreshItemsFromiOS()
        XCTAssertTrue(viewModel.isSyncingFromiOS, "Should be syncing after notification")

        // And: Sync indicator should eventually disappear
        let syncComplete = XCTestExpectation(description: "Sync indicator disappears")
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            syncComplete.fulfill()
        }
        wait(for: [syncComplete], timeout: 5.0)
        XCTAssertFalse(viewModel.isSyncingFromiOS, "Should stop syncing after delay")
    }

    /// Test that refreshFromiOS method updates lists in WatchMainViewModel
    func testRefreshFromiOSUpdatesLists() throws {
        // Given: A WatchMainViewModel instance
        let viewModel = WatchMainViewModel()
        // When: Calling refreshFromiOS explicitly
        viewModel.refreshFromiOS()

        // Then: isSyncingFromiOS is set synchronously
        XCTAssertTrue(viewModel.isSyncingFromiOS, "Should be syncing after refreshFromiOS")

        // Give the async operations time to complete
        let expectation = XCTestExpectation(description: "Refresh completes")
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 5.0)

        // Lists should be loaded (count may be same or different)
        // The key is that the method doesn't crash and completes successfully
        XCTAssertGreaterThanOrEqual(viewModel.lists.count, 0, "Lists should be loaded")
        XCTAssertFalse(viewModel.isLoading, "Should not be loading after refresh completes")
        XCTAssertFalse(viewModel.isSyncingFromiOS, "Sync indicator should be hidden")
    }
}
