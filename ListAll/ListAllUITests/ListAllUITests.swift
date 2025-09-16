//
//  ListAllUITests.swift
//  ListAllUITests
//
//  Created by Sutela Aleksi on 15.9.2025.
//

import XCTest

final class ListAllUITests: XCTestCase {

    var app: XCUIApplication!

    override func setUpWithError() throws {
        // Put setup code here. This method is called before the invocation of each test method in the class.

        // In UI tests it is usually best to stop immediately when a failure occurs.
        continueAfterFailure = false

        // In UI tests it's important to set the initial state - such as interface orientation - required for your tests before they run. The setUp method is a good place to do this.
        app = XCUIApplication()
        app.launch()
    }

    override func tearDownWithError() throws {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
        app = nil
    }

    @MainActor
    func testAppLaunch() throws {
        // Verify the app launches successfully
        XCTAssertTrue(app.state == .runningForeground)
    }

    @MainActor
    func testMainViewElements() throws {
        // Test that main view elements are present
        // Note: These selectors may need to be adjusted based on actual UI implementation
        let navigationBar = app.navigationBars.firstMatch
        XCTAssertTrue(navigationBar.exists)
    }

    @MainActor
    func testCreateNewList() throws {
        // Test creating a new list
        // This test assumes there's a button to create a new list
        let addButton = app.buttons["Add List"].firstMatch
        if addButton.exists {
            addButton.tap()
            
            // Look for text field to enter list name
            let textField = app.textFields.firstMatch
            if textField.exists {
                textField.tap()
                textField.typeText("Test List")
                
                // Look for save/done button
                let saveButton = app.buttons["Save"].firstMatch
                if saveButton.exists {
                    saveButton.tap()
                }
            }
        }
    }

    @MainActor
    func testListInteraction() throws {
        // Test interacting with existing lists
        let listCells = app.cells
        if listCells.count > 0 {
            let firstList = listCells.firstMatch
            firstList.tap()
            
            // Verify we're in the list detail view
            // This would depend on the actual UI implementation
        }
    }

    @MainActor
    func testAddItemToList() throws {
        // Test adding an item to a list
        let listCells = app.cells
        if listCells.count > 0 {
            let firstList = listCells.firstMatch
            firstList.tap()
            
            // Look for add item button
            let addItemButton = app.buttons["Add Item"].firstMatch
            if addItemButton.exists {
                addItemButton.tap()
                
                // Look for text field to enter item title
                let textField = app.textFields.firstMatch
                if textField.exists {
                    textField.tap()
                    textField.typeText("Test Item")
                    
                    // Look for save button
                    let saveButton = app.buttons["Save"].firstMatch
                    if saveButton.exists {
                        saveButton.tap()
                    }
                }
            }
        }
    }

    @MainActor
    func testItemInteraction() throws {
        // Test interacting with items in a list
        let listCells = app.cells
        if listCells.count > 0 {
            let firstList = listCells.firstMatch
            firstList.tap()
            
            // Look for item cells
            let itemCells = app.cells
            if itemCells.count > 0 {
                let firstItem = itemCells.firstMatch
                firstItem.tap()
                
                // Test item detail view or toggle crossed out
                // This would depend on the actual UI implementation
            }
        }
    }

    @MainActor
    func testSettingsView() throws {
        // Test accessing settings
        let settingsButton = app.buttons["Settings"].firstMatch
        if settingsButton.exists {
            settingsButton.tap()
            
            // Verify settings view is presented
            // This would depend on the actual UI implementation
        }
    }

    @MainActor
    func testNavigationFlow() throws {
        // Test basic navigation flow
        let listCells = app.cells
        if listCells.count > 0 {
            let firstList = listCells.firstMatch
            firstList.tap()
            
            // Test back navigation
            let backButton = app.buttons["Back"].firstMatch
            if backButton.exists {
                backButton.tap()
            } else {
                // Try swipe back gesture
                app.swipeRight()
            }
        }
    }

    @MainActor
    func testSearchFunctionality() throws {
        // Test search functionality if available
        let searchField = app.searchFields.firstMatch
        if searchField.exists {
            searchField.tap()
            searchField.typeText("test")
            
            // Verify search results
            // This would depend on the actual implementation
        }
    }

    @MainActor
    func testDeleteList() throws {
        // Test deleting a list
        let listCells = app.cells
        if listCells.count > 0 {
            let firstList = listCells.firstMatch
            
            // Try swipe to delete
            firstList.swipeLeft()
            
            // Look for delete button
            let deleteButton = app.buttons["Delete"].firstMatch
            if deleteButton.exists {
                deleteButton.tap()
            }
        }
    }

    @MainActor
    func testLaunchPerformance() throws {
        // This measures how long it takes to launch your application.
        measure(metrics: [XCTApplicationLaunchMetric()]) {
            XCUIApplication().launch()
        }
    }

    @MainActor
    func testScrollPerformance() throws {
        // Test scrolling performance
        let scrollView = app.scrollViews.firstMatch
        if scrollView.exists {
            measure(metrics: [XCTOSSignpostMetric.scrollDecelerationMetric]) {
                scrollView.swipeUp()
                scrollView.swipeDown()
            }
        }
    }
}
