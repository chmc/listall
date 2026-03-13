//
//  MacImportUIComponentsTests.swift
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

final class MacImportUIComponentsTests: XCTestCase {

    // MARK: - Platform Verification

    func testRunningOnMacOS() {
        #if os(macOS)
        XCTAssertTrue(true, "Import UI tests are running on macOS")
        #else
        XCTFail("These tests should only run on macOS")
        #endif
    }

    // MARK: - ImportPreview Model Tests (used by MacImportPreviewSheet)

    func testImportPreviewTotalChanges() {
        // Test totalChanges computation
        let preview = ImportPreview(
            listsToCreate: 3,
            listsToUpdate: 2,
            itemsToCreate: 15,
            itemsToUpdate: 5,
            conflicts: [],
            errors: []
        )

        XCTAssertEqual(preview.totalChanges, 25, "Total changes should be sum of all list/item operations")
    }

    func testImportPreviewEmptyChanges() {
        // Test with no changes
        let preview = ImportPreview(
            listsToCreate: 0,
            listsToUpdate: 0,
            itemsToCreate: 0,
            itemsToUpdate: 0,
            conflicts: [],
            errors: []
        )

        XCTAssertEqual(preview.totalChanges, 0, "Total changes should be 0")
        XCTAssertFalse(preview.hasConflicts, "Should have no conflicts")
        XCTAssertTrue(preview.isValid, "Preview should be valid with no errors")
    }

    func testImportPreviewWithConflicts() {
        // Test with conflicts
        let conflicts = [
            ConflictDetail(
                type: .listModified,
                entityName: "Shopping List",
                entityId: UUID(),
                currentValue: "Shopping List",
                incomingValue: "Groceries",
                message: "List name will change"
            ),
            ConflictDetail(
                type: .itemModified,
                entityName: "Milk",
                entityId: UUID(),
                currentValue: "Milk (qty: 1)",
                incomingValue: "Milk (qty: 2)",
                message: "Item will be updated"
            )
        ]

        let preview = ImportPreview(
            listsToCreate: 1,
            listsToUpdate: 1,
            itemsToCreate: 5,
            itemsToUpdate: 2,
            conflicts: conflicts,
            errors: []
        )

        XCTAssertTrue(preview.hasConflicts, "Should have conflicts")
        XCTAssertEqual(preview.conflicts.count, 2, "Should have 2 conflicts")
    }

    func testImportPreviewWithErrors() {
        // Test with validation errors
        let preview = ImportPreview(
            listsToCreate: 0,
            listsToUpdate: 0,
            itemsToCreate: 0,
            itemsToUpdate: 0,
            conflicts: [],
            errors: ["Invalid format", "Missing required field"]
        )

        XCTAssertFalse(preview.isValid, "Preview should be invalid with errors")
        XCTAssertEqual(preview.errors.count, 2, "Should have 2 errors")
    }

    // MARK: - ImportProgress Model Tests (used by MacImportProgressView)

    func testImportProgressPercentage() {
        // Test percentage calculation at various stages
        let progress50 = ImportProgress(
            totalLists: 4,
            processedLists: 2,
            totalItems: 20,
            processedItems: 10,
            currentOperation: "Processing..."
        )

        XCTAssertEqual(progress50.progressPercentage, 50, "Should be 50%")
        XCTAssertEqual(progress50.overallProgress, 0.5, accuracy: 0.001, "Overall progress should be 0.5")
    }

    func testImportProgressZero() {
        // Test at start
        let progress = ImportProgress(
            totalLists: 5,
            processedLists: 0,
            totalItems: 25,
            processedItems: 0,
            currentOperation: "Starting import..."
        )

        XCTAssertEqual(progress.progressPercentage, 0, "Should be 0%")
        XCTAssertEqual(progress.overallProgress, 0.0, accuracy: 0.001, "Overall progress should be 0")
    }

    func testImportProgressComplete() {
        // Test at completion
        let progress = ImportProgress(
            totalLists: 5,
            processedLists: 5,
            totalItems: 25,
            processedItems: 25,
            currentOperation: "Import complete"
        )

        XCTAssertEqual(progress.progressPercentage, 100, "Should be 100%")
        XCTAssertEqual(progress.overallProgress, 1.0, accuracy: 0.001, "Overall progress should be 1.0")
    }

    func testImportProgressEmptyTotal() {
        // Test edge case with no items to process
        let progress = ImportProgress(
            totalLists: 0,
            processedLists: 0,
            totalItems: 0,
            processedItems: 0,
            currentOperation: "Nothing to import"
        )

        XCTAssertEqual(progress.progressPercentage, 0, "Should be 0% when nothing to import")
        XCTAssertEqual(progress.overallProgress, 0.0, accuracy: 0.001, "Overall progress should be 0")
    }

    func testImportProgressPartial() {
        // Test partial progress with different list/item ratios
        let progress = ImportProgress(
            totalLists: 2,
            processedLists: 1,
            totalItems: 8,
            processedItems: 4,
            currentOperation: "Importing items..."
        )

        // (1 + 4) / (2 + 8) = 5/10 = 50%
        XCTAssertEqual(progress.progressPercentage, 50, "Should be 50%")
    }

    // MARK: - ConflictDetail Type Tests

    func testConflictDetailTypes() {
        // Test all conflict types
        let listModifiedConflict = ConflictDetail(
            type: .listModified,
            entityName: "Test List",
            entityId: UUID(),
            currentValue: "Old Name",
            incomingValue: "New Name",
            message: "Name changed"
        )
        XCTAssertEqual(listModifiedConflict.entityName, "Test List")

        let itemModifiedConflict = ConflictDetail(
            type: .itemModified,
            entityName: "Test Item",
            entityId: UUID(),
            currentValue: "Old Title",
            incomingValue: "New Title",
            message: "Title changed"
        )
        XCTAssertEqual(itemModifiedConflict.entityName, "Test Item")

        let listDeletedConflict = ConflictDetail(
            type: .listDeleted,
            entityName: "Deleted List",
            entityId: UUID(),
            currentValue: "List Name",
            incomingValue: nil,
            message: "List will be deleted"
        )
        XCTAssertNil(listDeletedConflict.incomingValue)

        let itemDeletedConflict = ConflictDetail(
            type: .itemDeleted,
            entityName: "Deleted Item",
            entityId: UUID(),
            currentValue: "Item Title",
            incomingValue: nil,
            message: "Item will be deleted"
        )
        XCTAssertNil(itemDeletedConflict.incomingValue)
    }

    // MARK: - ImportViewModel Strategy Tests (used by MacImportPreviewSheet)

    func testImportViewModelStrategyOptions() {
        // Verify all three strategies are available
        let viewModel = ImportViewModel()
        let strategies = viewModel.strategyOptions

        XCTAssertEqual(strategies.count, 3, "Should have 3 strategy options")
        XCTAssertTrue(strategies.contains(.merge), "Should include merge")
        XCTAssertTrue(strategies.contains(.replace), "Should include replace")
        XCTAssertTrue(strategies.contains(.append), "Should include append")
    }

    func testImportViewModelStrategyNames() {
        let viewModel = ImportViewModel()

        // Test strategy names
        XCTAssertFalse(viewModel.strategyName(.merge).isEmpty, "Merge should have a name")
        XCTAssertFalse(viewModel.strategyName(.replace).isEmpty, "Replace should have a name")
        XCTAssertFalse(viewModel.strategyName(.append).isEmpty, "Append should have a name")
    }

    func testImportViewModelStrategyDescriptions() {
        let viewModel = ImportViewModel()

        // Test strategy descriptions
        XCTAssertFalse(viewModel.strategyDescription(.merge).isEmpty, "Merge should have description")
        XCTAssertFalse(viewModel.strategyDescription(.replace).isEmpty, "Replace should have description")
        XCTAssertFalse(viewModel.strategyDescription(.append).isEmpty, "Append should have description")
    }

    func testImportViewModelStrategyIcons() {
        let viewModel = ImportViewModel()

        // Test strategy icons (SF Symbol names)
        XCTAssertFalse(viewModel.strategyIcon(.merge).isEmpty, "Merge should have icon")
        XCTAssertFalse(viewModel.strategyIcon(.replace).isEmpty, "Replace should have icon")
        XCTAssertFalse(viewModel.strategyIcon(.append).isEmpty, "Append should have icon")
    }

    // MARK: - ImportViewModel State Tests

    func testImportViewModelInitialState() {
        let viewModel = ImportViewModel()

        // Verify initial state
        XCTAssertFalse(viewModel.isImporting, "Should not be importing initially")
        XCTAssertFalse(viewModel.showPreview, "Should not show preview initially")
        XCTAssertNil(viewModel.importPreview, "Import preview should be nil initially")
        XCTAssertNil(viewModel.importProgress, "Import progress should be nil initially")
        XCTAssertNil(viewModel.errorMessage, "Error message should be nil initially")
        XCTAssertNil(viewModel.successMessage, "Success message should be nil initially")
    }

    func testImportViewModelCleanup() {
        let viewModel = ImportViewModel()

        // Simulate some state
        viewModel.errorMessage = "Test error"
        viewModel.successMessage = "Test success"
        viewModel.importText = "Test text"

        // Cleanup
        viewModel.cleanup()

        // Verify cleanup
        XCTAssertNil(viewModel.errorMessage, "Error message should be cleared")
        XCTAssertNil(viewModel.successMessage, "Success message should be cleared")
        XCTAssertTrue(viewModel.importText.isEmpty, "Import text should be cleared")
        XCTAssertFalse(viewModel.showPreview, "Show preview should be false")
        XCTAssertNil(viewModel.importPreview, "Import preview should be nil")
    }

    func testImportViewModelClearMessages() {
        let viewModel = ImportViewModel()

        // Set messages
        viewModel.errorMessage = "Test error"
        viewModel.successMessage = "Test success"

        // Clear messages
        viewModel.clearMessages()

        // Verify cleared
        XCTAssertNil(viewModel.errorMessage, "Error message should be cleared")
        XCTAssertNil(viewModel.successMessage, "Success message should be cleared")
    }

    // MARK: - Documentation Tests

    func testDocumentMacImportUIComponents() {
        // This test documents the macOS import UI components

        let documentation = """

        ========================================================================
        macOS Import UI Components Documentation
        ========================================================================

        This test documents the macOS-specific import UI components.

        Components:
        -----------
        1. MacImportPreviewSheet
           - Displays import summary before confirmation
           - Shows lists/items to create/update counts
           - Displays conflicts (up to 5 with "and more" indicator)
           - Shows selected import strategy info
           - Confirm Import and Cancel buttons
           - Uses native AppKit sheet presentation via MacNativeSheetPresenter

        2. MacImportProgressView
           - Linear progress bar with percentage
           - Current operation text
           - Lists and items processed counts
           - macOS-native styling with proper spacing

        3. MacImportProgressSimpleView
           - Simple indeterminate spinner for when detailed progress unavailable
           - "Importing..." text

        Integration:
        -----------
        - DataSettingsTab in MacSettingsView.swift integrates these components
        - Uses @StateObject ImportViewModel for state management
        - File picker via SwiftUI .fileImporter modifier
        - Native sheet presentation via MacNativeSheetPresenter for preview

        Data Models (shared with iOS):
        -----------------------------
        - ImportPreview: Summary of what will be imported
        - ImportProgress: Current progress during import
        - ImportViewModel: Manages import state and operations
        - ConflictDetail: Information about conflicts

        ========================================================================

        """

        print(documentation)
        XCTAssertTrue(true, "Documentation generated")
    }
}


#endif
