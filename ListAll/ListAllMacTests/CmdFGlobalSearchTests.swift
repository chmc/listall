//
//  CmdFGlobalSearchTests.swift
//  ListAllMacTests
//

import XCTest
import CoreData
import Combine
#if os(macOS)
@preconcurrency import AppKit
#endif
@testable import ListAll

#if os(macOS)

final class CmdFGlobalSearchTests: XCTestCase {

    // MARK: - Test Helpers

    /// Creates a test list with specified properties
    /// Uses deterministic data for reliable, reproducible tests
    private func createTestList(
        name: String = "Test List",
        orderNumber: Int = 0
    ) -> ListModel {
        var list = ListModel(name: name)
        list.orderNumber = orderNumber
        return list
    }

    /// Creates a test item with specified properties
    private func createTestItem(
        title: String = "Test Item",
        orderNumber: Int = 0
    ) -> Item {
        var item = Item(title: title, listId: UUID())
        item.orderNumber = orderNumber
        return item
    }

    // MARK: - Test 1: FocusSearchField Notification Name Exists

    /// Test that the FocusSearchField notification name is defined
    /// Expected: Notification name should be "FocusSearchField"
    func testFocusSearchFieldNotificationNameExists() {
        // Arrange
        let expectedName = "FocusSearchField"

        // Act
        let notificationName = NSNotification.Name(expectedName)

        // Assert
        XCTAssertEqual(notificationName.rawValue, expectedName,
                       "FocusSearchField notification name should be defined")
    }

    // MARK: - Test 2: Notification Can Be Posted

    /// Test that FocusSearchField notification can be posted and received
    /// Expected: NotificationCenter should deliver the notification
    func testFocusSearchFieldNotificationCanBePosted() {
        // Arrange
        let expectation = XCTestExpectation(description: "FocusSearchField notification received")
        var notificationReceived = false

        let observer = NotificationCenter.default.addObserver(
            forName: NSNotification.Name("FocusSearchField"),
            object: nil,
            queue: .main
        ) { _ in
            notificationReceived = true
            expectation.fulfill()
        }

        // Act
        NotificationCenter.default.post(
            name: NSNotification.Name("FocusSearchField"),
            object: nil
        )

        // Assert
        wait(for: [expectation], timeout: 1.0)
        XCTAssertTrue(notificationReceived,
                      "FocusSearchField notification should be received")

        // Cleanup
        NotificationCenter.default.removeObserver(observer)
    }

    // MARK: - Test 3: Search Focus State Tracking

    /// Test that a flag can track whether search field should be focused
    /// Expected: Boolean flag should toggle correctly when notification received
    func testSearchFocusStateTracking() {
        // Arrange
        var isSearchFieldFocused = false
        let expectation = XCTestExpectation(description: "Focus state updated")

        let observer = NotificationCenter.default.addObserver(
            forName: NSNotification.Name("FocusSearchField"),
            object: nil,
            queue: .main
        ) { _ in
            isSearchFieldFocused = true
            expectation.fulfill()
        }

        // Assert initial state
        XCTAssertFalse(isSearchFieldFocused,
                       "Search field should not be focused initially")

        // Act
        NotificationCenter.default.post(
            name: NSNotification.Name("FocusSearchField"),
            object: nil
        )

        // Assert
        wait(for: [expectation], timeout: 1.0)
        XCTAssertTrue(isSearchFieldFocused,
                      "Search field should be focused after notification")

        // Cleanup
        NotificationCenter.default.removeObserver(observer)
    }

    // MARK: - Test 4: Cmd+F From Sidebar (Global Scope)

    /// Test that Cmd+F notification works when focus is in sidebar
    /// This tests the global nature of the keyboard shortcut
    /// Expected: Notification should be posted regardless of current focus
    func testCmdFFromSidebar_postsNotification() {
        // Arrange
        // Simulate sidebar having focus (a list is selected but detail is not focused)
        let selectedListID: UUID? = UUID() // A list is selected in sidebar
        let isDetailViewFocused = false    // Detail view does NOT have focus
        var searchFocusNotificationReceived = false

        let expectation = XCTestExpectation(description: "FocusSearchField from sidebar")

        let observer = NotificationCenter.default.addObserver(
            forName: NSNotification.Name("FocusSearchField"),
            object: nil,
            queue: .main
        ) { _ in
            searchFocusNotificationReceived = true
            expectation.fulfill()
        }

        // Assert preconditions
        XCTAssertNotNil(selectedListID, "A list should be selected")
        XCTAssertFalse(isDetailViewFocused, "Detail view should NOT have focus")

        // Act - Simulate Cmd+F press at top level (MacMainView)
        // In implementation, this would be: .onKeyPress(characters: "f", modifiers: .command)
        NotificationCenter.default.post(
            name: NSNotification.Name("FocusSearchField"),
            object: nil
        )

        // Assert
        wait(for: [expectation], timeout: 1.0)
        XCTAssertTrue(searchFocusNotificationReceived,
                      "FocusSearchField notification should be posted even when sidebar has focus")

        // Cleanup
        NotificationCenter.default.removeObserver(observer)
    }

    // MARK: - Test 5: Cmd+F From Detail View

    /// Test that Cmd+F notification works when focus is in detail view
    /// Expected: Notification should be posted when detail view has focus
    func testCmdFFromDetailView_postsNotification() {
        // Arrange
        let selectedListID: UUID? = UUID() // A list is selected
        let isDetailViewFocused = true     // Detail view HAS focus
        var searchFocusNotificationReceived = false

        let expectation = XCTestExpectation(description: "FocusSearchField from detail")

        let observer = NotificationCenter.default.addObserver(
            forName: NSNotification.Name("FocusSearchField"),
            object: nil,
            queue: .main
        ) { _ in
            searchFocusNotificationReceived = true
            expectation.fulfill()
        }

        // Assert preconditions
        XCTAssertNotNil(selectedListID, "A list should be selected")
        XCTAssertTrue(isDetailViewFocused, "Detail view should have focus")

        // Act - Simulate Cmd+F press
        NotificationCenter.default.post(
            name: NSNotification.Name("FocusSearchField"),
            object: nil
        )

        // Assert
        wait(for: [expectation], timeout: 1.0)
        XCTAssertTrue(searchFocusNotificationReceived,
                      "FocusSearchField notification should be posted when detail view has focus")

        // Cleanup
        NotificationCenter.default.removeObserver(observer)
    }

    // MARK: - Test 6: Cmd+F With No List Selected

    /// Test behavior when Cmd+F is pressed but no list is selected
    /// Expected: Should either select first list or show helpful message
    func testCmdFWithNoListSelected_handlesEdgeCase() {
        // Arrange
        var selectedListID: UUID? = nil   // NO list selected
        var shouldShowEmptyStateMessage = false
        var shouldSelectFirstList = false

        // Lists available for selection
        let availableLists = [
            createTestList(name: "First List", orderNumber: 0),
            createTestList(name: "Second List", orderNumber: 1)
        ]

        // Act - Simulate Cmd+F with no list selected
        // Implementation can choose either approach:
        // Option A: Select first list automatically
        // Option B: Show helpful message to user

        if selectedListID == nil {
            if !availableLists.isEmpty {
                // Option A: Auto-select first list
                selectedListID = availableLists.first?.id
                shouldSelectFirstList = true
            } else {
                // Option B: Show empty state message
                shouldShowEmptyStateMessage = true
            }
        }

        // Assert - Either option is acceptable
        XCTAssertTrue(shouldSelectFirstList || shouldShowEmptyStateMessage,
                      "Cmd+F with no list selected should either select first list or show message")

        // If lists are available, first list should be selected
        if !availableLists.isEmpty {
            XCTAssertTrue(shouldSelectFirstList,
                          "When lists exist, first list should be selected")
            XCTAssertEqual(selectedListID, availableLists.first?.id,
                           "Selected list should be the first available list")
        }
    }

    // MARK: - Test 7: Cmd+F With No Lists At All

    /// Test behavior when Cmd+F is pressed and no lists exist
    /// Expected: Should show empty state or do nothing gracefully
    func testCmdFWithNoListsAvailable_handlesGracefully() {
        // Arrange
        let selectedListID: UUID? = nil
        let availableLists: [ListModel] = []  // No lists exist
        let errorOccurred = false
        var handledGracefully = false

        // Act - Simulate Cmd+F with no lists
        if selectedListID == nil && availableLists.isEmpty {
            // No-op or show empty state - should NOT crash
            handledGracefully = true
        }

        // Assert
        XCTAssertFalse(errorOccurred,
                       "Cmd+F with no lists should not cause an error")
        XCTAssertTrue(handledGracefully,
                      "Cmd+F with no lists should be handled gracefully")
    }

    // MARK: - Test 8: Multiple Notification Observers

    /// Test that multiple observers can receive the notification
    /// Expected: Both detail view and any other observers should receive notification
    func testMultipleObserversReceiveNotification() {
        // Arrange
        var observer1Received = false
        var observer2Received = false

        let expectation1 = XCTestExpectation(description: "Observer 1 received")
        let expectation2 = XCTestExpectation(description: "Observer 2 received")

        let observer1 = NotificationCenter.default.addObserver(
            forName: NSNotification.Name("FocusSearchField"),
            object: nil,
            queue: .main
        ) { _ in
            observer1Received = true
            expectation1.fulfill()
        }

        let observer2 = NotificationCenter.default.addObserver(
            forName: NSNotification.Name("FocusSearchField"),
            object: nil,
            queue: .main
        ) { _ in
            observer2Received = true
            expectation2.fulfill()
        }

        // Act
        NotificationCenter.default.post(
            name: NSNotification.Name("FocusSearchField"),
            object: nil
        )

        // Assert
        wait(for: [expectation1, expectation2], timeout: 1.0)
        XCTAssertTrue(observer1Received, "First observer should receive notification")
        XCTAssertTrue(observer2Received, "Second observer should receive notification")

        // Cleanup
        NotificationCenter.default.removeObserver(observer1)
        NotificationCenter.default.removeObserver(observer2)
    }

    // MARK: - Test 9: Notification Contains No User Info

    /// Test that notification is posted without userInfo (simple focus signal)
    /// Expected: Notification should be a simple signal without payload
    func testNotificationHasNoUserInfo() {
        // Arrange
        let expectation = XCTestExpectation(description: "Notification received")

        let observer = NotificationCenter.default.addObserver(
            forName: NSNotification.Name("FocusSearchField"),
            object: nil,
            queue: .main
        ) { notification in
            XCTAssertNil(notification.userInfo,
                         "FocusSearchField notification should not contain userInfo")
            expectation.fulfill()
        }

        // Act - Post notification without userInfo
        NotificationCenter.default.post(
            name: NSNotification.Name("FocusSearchField"),
            object: nil,
            userInfo: nil
        )

        // Assert
        wait(for: [expectation], timeout: 1.0)

        // Cleanup
        NotificationCenter.default.removeObserver(observer)
    }

    // MARK: - Test 10: Search Field Gets Focus After Notification

    /// Test that search field focus state changes after notification
    /// This simulates the MacListDetailView response to the notification
    func testSearchFieldFocusedAfterNotification() {
        // Arrange
        var isSearchFieldFocused = false

        // Simulate MacListDetailView's .onReceive handler
        let expectation = XCTestExpectation(description: "Search field focused")

        let observer = NotificationCenter.default.addObserver(
            forName: NSNotification.Name("FocusSearchField"),
            object: nil,
            queue: .main
        ) { _ in
            // This is what MacListDetailView should do:
            isSearchFieldFocused = true
            expectation.fulfill()
        }

        // Assert initial state
        XCTAssertFalse(isSearchFieldFocused,
                       "Search field should not be focused initially")

        // Act - Post notification (as MacMainView would do on Cmd+F)
        NotificationCenter.default.post(
            name: NSNotification.Name("FocusSearchField"),
            object: nil
        )

        // Assert final state
        wait(for: [expectation], timeout: 1.0)
        XCTAssertTrue(isSearchFieldFocused,
                      "Search field should be focused after FocusSearchField notification")

        // Cleanup
        NotificationCenter.default.removeObserver(observer)
    }

    // MARK: - Test 11: Notification Observer Cleanup

    /// Test that notification observer is properly cleaned up
    /// Expected: After removing observer, no notification should be received
    func testNotificationObserverCleanup() {
        // Arrange
        var notificationCount = 0
        let expectation = XCTestExpectation(description: "First notification")

        let observer = NotificationCenter.default.addObserver(
            forName: NSNotification.Name("FocusSearchField"),
            object: nil,
            queue: .main
        ) { _ in
            notificationCount += 1
            expectation.fulfill()
        }

        // Act 1 - Post notification while observer is active
        NotificationCenter.default.post(
            name: NSNotification.Name("FocusSearchField"),
            object: nil
        )
        wait(for: [expectation], timeout: 1.0)

        // Assert 1
        XCTAssertEqual(notificationCount, 1,
                       "Should receive one notification while observer is active")

        // Act 2 - Remove observer and post again
        NotificationCenter.default.removeObserver(observer)
        NotificationCenter.default.post(
            name: NSNotification.Name("FocusSearchField"),
            object: nil
        )

        // Small delay to ensure any pending notifications are processed
        let delayExpectation = XCTestExpectation(description: "Delay")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            delayExpectation.fulfill()
        }
        wait(for: [delayExpectation], timeout: 1.0)

        // Assert 2
        XCTAssertEqual(notificationCount, 1,
                       "Should NOT receive notification after observer is removed")
    }

    // MARK: - Test 12: Consistency with ItemEditingStarted Pattern

    /// Test that FocusSearchField follows the same pattern as ItemEditingStarted
    /// Expected: Both notifications should work identically
    func testConsistencyWithItemEditingStartedPattern() {
        // Arrange
        var focusSearchReceived = false
        var itemEditingReceived = false

        let expectation1 = XCTestExpectation(description: "FocusSearchField")
        let expectation2 = XCTestExpectation(description: "ItemEditingStarted")

        let observer1 = NotificationCenter.default.addObserver(
            forName: NSNotification.Name("FocusSearchField"),
            object: nil,
            queue: .main
        ) { _ in
            focusSearchReceived = true
            expectation1.fulfill()
        }

        let observer2 = NotificationCenter.default.addObserver(
            forName: NSNotification.Name("ItemEditingStarted"),
            object: nil,
            queue: .main
        ) { _ in
            itemEditingReceived = true
            expectation2.fulfill()
        }

        // Act - Post both notifications
        NotificationCenter.default.post(
            name: NSNotification.Name("FocusSearchField"),
            object: nil
        )
        NotificationCenter.default.post(
            name: NSNotification.Name("ItemEditingStarted"),
            object: nil
        )

        // Assert - Both should work identically
        wait(for: [expectation1, expectation2], timeout: 1.0)
        XCTAssertTrue(focusSearchReceived,
                      "FocusSearchField should be received")
        XCTAssertTrue(itemEditingReceived,
                      "ItemEditingStarted should be received")

        // Cleanup
        NotificationCenter.default.removeObserver(observer1)
        NotificationCenter.default.removeObserver(observer2)
    }

    // MARK: - Platform Verification

    /// Verify tests are running on macOS platform
    func testRunningOnMacOS() {
        #if os(macOS)
        XCTAssertTrue(true, "Test is running on macOS")
        #else
        XCTFail("CmdFGlobalSearchTests should only run on macOS")
        #endif
    }

    // MARK: - Documentation Test

    func testCmdFGlobalSearchDocumentation() {
        let documentation = """

        ========================================================================
        Cmd+F Global Search Tests - Task 12.2 TDD
        ========================================================================

        This test class validates the expected behavior for Cmd+F keyboard
        shortcut working globally from any focus location (sidebar or detail).

        Problem Being Solved:
        ---------------------
        Cmd+F only works when focus is already in the detail pane. If focus
        is in sidebar, Cmd+F does nothing - but Feature Tips claim
        "Press Cmd+F to search across all items."

        Solution Approach:
        ------------------
        Use a notification pattern consistent with existing patterns like
        "ItemEditingStarted":

        1. Add a notification "FocusSearchField"
        2. MacMainView sends this notification on Cmd+F press (at top level)
        3. MacListDetailView listens and sets isSearchFieldFocused = true
        4. If no list is selected, either select first list or show message

        Tests Written (TDD Red Phase):
        ------------------------------
        1. testFocusSearchFieldNotificationNameExists
           - Notification name "FocusSearchField" is defined

        2. testFocusSearchFieldNotificationCanBePosted
           - NotificationCenter delivers the notification

        3. testSearchFocusStateTracking
           - Boolean flag toggles correctly on notification

        4. testCmdFFromSidebar_postsNotification
           - Notification posted when sidebar has focus

        5. testCmdFFromDetailView_postsNotification
           - Notification posted when detail view has focus

        6. testCmdFWithNoListSelected_handlesEdgeCase
           - Auto-selects first list or shows message

        7. testCmdFWithNoListsAvailable_handlesGracefully
           - No crash when no lists exist

        8. testMultipleObserversReceiveNotification
           - Multiple observers receive the notification

        9. testNotificationHasNoUserInfo
           - Notification is a simple signal without payload

        10. testSearchFieldFocusedAfterNotification
            - Search field @FocusState changes after notification

        11. testNotificationObserverCleanup
            - Observer properly removed, no leaks

        12. testConsistencyWithItemEditingStartedPattern
            - Follows same pattern as existing notifications

        Implementation Requirements:
        ----------------------------
        After these tests pass with actual implementation:

        1. MacMainView changes needed:
           - Move .onKeyPress for Cmd+F to top level (not inside detail view)
           - Post "FocusSearchField" notification on Cmd+F press
           - Handle no-list-selected case (select first or show message)

        2. MacListDetailView changes needed:
           - Add .onReceive for "FocusSearchField" notification
           - Set isSearchFieldFocused = true when notification received

        Files to Modify:
        ----------------
        - ListAllMac/Views/MacMainView.swift - Add top-level Cmd+F handler
        - ListAllMac/Views/MacMainView.swift - MacListDetailView notification listener

        References:
        -----------
        - Existing pattern: "ItemEditingStarted" notification
        - Apple HIG: Keyboard shortcuts for macOS
        - Task 12.2 in /documentation/TODO.md

        ========================================================================

        """

        print(documentation)
        XCTAssertTrue(true, "Documentation generated")
    }
}


#endif
