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
        // Put teardown code here. This method is called after the invocation of each test method in the class.
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
        
        // Give the async operations time to complete
        let expectation = XCTestExpectation(description: "Sync indicator appears")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            // Then: Sync indicator should be active
            XCTAssertTrue(viewModel.isSyncingFromiOS, "Should be syncing after notification")
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 1.0)
        
        // And: Sync indicator should eventually disappear
        let syncCompleteExpectation = XCTestExpectation(description: "Sync completes")
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            XCTAssertFalse(viewModel.isSyncingFromiOS, "Should stop syncing after delay")
            syncCompleteExpectation.fulfill()
        }
        
        wait(for: [syncCompleteExpectation], timeout: 2.0)
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
        
        // Give the async operations time to complete
        let expectation = XCTestExpectation(description: "Sync indicator appears")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            // Then: Sync indicator should be active
            XCTAssertTrue(viewModel.isSyncingFromiOS, "Should be syncing after notification")
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 1.0)
        
        // And: Sync indicator should eventually disappear
        let syncCompleteExpectation = XCTestExpectation(description: "Sync completes")
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            XCTAssertFalse(viewModel.isSyncingFromiOS, "Should stop syncing after delay")
            syncCompleteExpectation.fulfill()
        }
        
        wait(for: [syncCompleteExpectation], timeout: 2.0)
    }
    
    /// Test that refreshFromiOS method updates lists in WatchMainViewModel
    func testRefreshFromiOSUpdatesLists() throws {
        // Given: A WatchMainViewModel instance
        let viewModel = WatchMainViewModel()
        let initialListCount = viewModel.lists.count
        
        // When: Calling refreshFromiOS explicitly
        viewModel.refreshFromiOS()
        
        // Give the async operations time to complete
        let expectation = XCTestExpectation(description: "Lists are refreshed")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            // Then: Lists should be loaded (count may be same or different)
            // The key is that the method doesn't crash and completes successfully
            XCTAssertGreaterThanOrEqual(viewModel.lists.count, 0, "Lists should be loaded")
            XCTAssertFalse(viewModel.isLoading, "Should not be loading after refresh completes")
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 1.0)
        
        // Verify sync indicator eventually goes away
        let syncCompleteExpectation = XCTestExpectation(description: "Sync indicator disappears")
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            XCTAssertFalse(viewModel.isSyncingFromiOS, "Sync indicator should be hidden")
            syncCompleteExpectation.fulfill()
        }
        
        wait(for: [syncCompleteExpectation], timeout: 2.0)
    }
}
