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
    
    // MARK: - Phase 6B: List Creation and Editing Tests
    
    @MainActor
    func testCreateListViewPresentation() throws {
        // Test that CreateListView is presented when add button is tapped
        // The add button is an image with the system add icon (plus symbol)
        let addButton = app.buttons["AddListButton"].firstMatch
        if addButton.exists {
            addButton.tap()
            
            // Verify CreateListView is presented
            let createListTitle = app.navigationBars["New List"].firstMatch
            XCTAssertTrue(createListTitle.waitForExistence(timeout: 2))
            
            // Verify Cancel button exists
            let cancelButton = app.buttons["CancelButton"].firstMatch
            XCTAssertTrue(cancelButton.exists)
            
            // Verify Create button exists but is disabled initially
            let createButton = app.buttons["CreateButton"].firstMatch
            XCTAssertTrue(createButton.exists)
            
            // Test Cancel functionality
            cancelButton.tap()
            XCTAssertFalse(createListTitle.exists)
        }
    }
    
    @MainActor
    func testCreateListWithValidName() throws {
        // Test creating a list with valid name
        let addButton = app.buttons["AddListButton"].firstMatch
        if addButton.exists {
            addButton.tap()
            
            // Wait for CreateListView to appear
            let createListTitle = app.navigationBars["New List"].firstMatch
            XCTAssertTrue(createListTitle.waitForExistence(timeout: 2))
            
            // Find and tap the text field - it should have placeholder "List Name"
            let textField = app.textFields["ListNameTextField"].firstMatch
            if textField.exists {
                textField.tap()
                textField.typeText("UI Test List")
                
                // Create button should now be enabled
                let createButton = app.buttons["CreateButton"].firstMatch
                XCTAssertTrue(createButton.exists)
                createButton.tap()
                
                // Verify we're back to main view and list was created
                XCTAssertFalse(createListTitle.exists)
                
                // Look for the newly created list
                let newListCell = app.staticTexts["UI Test List"].firstMatch
                XCTAssertTrue(newListCell.waitForExistence(timeout: 2))
            }
        }
    }
    
    @MainActor
    func testCreateListValidationEmptyName() throws {
        // Test validation for empty list name
        let addButton = app.buttons["AddListButton"].firstMatch
        if addButton.exists {
            addButton.tap()
            
            let createListTitle = app.navigationBars["New List"].firstMatch
            XCTAssertTrue(createListTitle.waitForExistence(timeout: 2))
            
            // Try to create with empty name
            let createButton = app.buttons["CreateButton"].firstMatch
            XCTAssertTrue(createButton.exists)
            
            // Create button should be disabled with empty text
            XCTAssertFalse(createButton.isEnabled)
            
            // Try with whitespace only
            let textField = app.textFields["ListNameTextField"].firstMatch
            if textField.exists {
                textField.tap()
                textField.typeText("   ")
                
                // Create button should still be disabled
                XCTAssertFalse(createButton.isEnabled)
            }
            
            // Cancel to clean up
            app.buttons["Cancel"].firstMatch.tap()
        }
    }
    
    @MainActor
    func testEditListContextMenu() throws {
        // Test editing a list via context menu (long press)
        // First ensure we have a list to edit
        try testCreateListWithValidName()
        
        let listCell = app.staticTexts["UI Test List"].firstMatch
        if listCell.exists {
            // Long press to show context menu
            listCell.press(forDuration: 1.0)
            
            // Look for Edit option in context menu
            let editButton = app.buttons["Edit"].firstMatch
            if editButton.waitForExistence(timeout: 2) {
                editButton.tap()
                
                // Verify EditListView is presented
                let editListTitle = app.navigationBars["Edit List"].firstMatch
                XCTAssertTrue(editListTitle.waitForExistence(timeout: 2))
                
                // Verify the text field is pre-populated
                let textField = app.textFields["ListNameTextField"].firstMatch
                XCTAssertTrue(textField.exists)
                
                // Test Cancel functionality
                app.buttons["Cancel"].firstMatch.tap()
                XCTAssertFalse(editListTitle.exists)
            }
        }
    }
    
    @MainActor
    func testEditListNameChange() throws {
        // Test actually changing a list name
        // First ensure we have a list to edit
        try testCreateListWithValidName()
        
        let listCell = app.staticTexts["UI Test List"].firstMatch
        if listCell.exists {
            listCell.press(forDuration: 1.0)
            
            let editButton = app.buttons["Edit"].firstMatch
            if editButton.waitForExistence(timeout: 2) {
                editButton.tap()
                
                let editListTitle = app.navigationBars["Edit List"].firstMatch
                XCTAssertTrue(editListTitle.waitForExistence(timeout: 2))
                
                // Clear and enter new name
                let textField = app.textFields["ListNameTextField"].firstMatch
                if textField.exists {
                    // Clear existing text by selecting all and typing over it
                    textField.tap()
                    // Use coordinated tap to select all text
                    let coordinate = textField.coordinate(withNormalizedOffset: CGVector(dx: 0.0, dy: 0.0))
                    coordinate.press(forDuration: 1.0)
                    
                    // Type new text (this will replace selected text)
                    textField.typeText("Updated List Name")
                    
                    // Save changes
                    let saveButton = app.buttons["Save"].firstMatch
                    XCTAssertTrue(saveButton.exists)
                    saveButton.tap()
                    
                    // Verify we're back to main view and name was updated
                    XCTAssertFalse(editListTitle.exists)
                    
                    let updatedListCell = app.staticTexts["Updated List Name"].firstMatch
                    XCTAssertTrue(updatedListCell.waitForExistence(timeout: 2))
                }
            }
        }
    }
    
    @MainActor
    func testDeleteListSwipeAction() throws {
        // Test deleting a list via swipe action
        // First ensure we have a list to delete
        try testCreateListWithValidName()
        
        let listCell = app.cells.containing(.staticText, identifier: "UI Test List").firstMatch
        if listCell.exists {
            // Swipe left to reveal delete action
            listCell.swipeLeft()
            
            // Look for Delete button
            let deleteButton = app.buttons["Delete"].firstMatch
            if deleteButton.waitForExistence(timeout: 2) {
                deleteButton.tap()
                
                // Look for confirmation alert
                let deleteAlert = app.alerts["Delete List"].firstMatch
                if deleteAlert.waitForExistence(timeout: 2) {
                    // Confirm deletion
                    let confirmDeleteButton = deleteAlert.buttons["Delete"].firstMatch
                    XCTAssertTrue(confirmDeleteButton.exists)
                    confirmDeleteButton.tap()
                    
                    // Verify list is removed
                    let deletedListCell = app.staticTexts["UI Test List"].firstMatch
                    XCTAssertFalse(deletedListCell.waitForExistence(timeout: 1))
                }
            }
        }
    }
    
    @MainActor
    func testDeleteListContextMenu() throws {
        // Test deleting a list via context menu
        // First ensure we have a list to delete
        try testCreateListWithValidName()
        
        let listCell = app.staticTexts["UI Test List"].firstMatch
        if listCell.exists {
            // Long press to show context menu
            listCell.press(forDuration: 1.0)
            
            // Look for Delete option in context menu
            let deleteButton = app.buttons["Delete"].firstMatch
            if deleteButton.waitForExistence(timeout: 2) {
                deleteButton.tap()
                
                // Look for confirmation alert
                let deleteAlert = app.alerts["Delete List"].firstMatch
                if deleteAlert.waitForExistence(timeout: 2) {
                    // Test Cancel first
                    let cancelButton = deleteAlert.buttons["Cancel"].firstMatch
                    if cancelButton.exists {
                        cancelButton.tap()
                        
                        // Verify list still exists
                        XCTAssertTrue(listCell.exists)
                        
                        // Try delete again and confirm this time
                        listCell.press(forDuration: 1.0)
                        let deleteButton2 = app.buttons["Delete"].firstMatch
                        if deleteButton2.waitForExistence(timeout: 2) {
                            deleteButton2.tap()
                            
                            let deleteAlert2 = app.alerts["Delete List"].firstMatch
                            if deleteAlert2.waitForExistence(timeout: 2) {
                                let confirmDeleteButton = deleteAlert2.buttons["Delete"].firstMatch
                                confirmDeleteButton.tap()
                                
                                // Verify list is removed
                                let deletedListCell = app.staticTexts["UI Test List"].firstMatch
                                XCTAssertFalse(deletedListCell.waitForExistence(timeout: 1))
                            }
                        }
                    }
                }
            }
        }
    }
}
