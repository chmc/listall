//
//  ImportViewModelMacTests.swift
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

final class ImportViewModelMacTests: XCTestCase {

    // MARK: - Platform Verification

    func testRunningOnMacOS() {
        #if os(macOS)
        XCTAssertTrue(true, "Running on macOS")
        #else
        XCTFail("This test should only run on macOS")
        #endif
    }

    // MARK: - ImportViewModel Class Verification

    func testImportViewModelClassExists() {
        // Verify ImportViewModel class exists and can be instantiated
        let vm = ImportViewModel()
        XCTAssertNotNil(vm, "ImportViewModel should be instantiable on macOS")
    }

    func testImportViewModelIsObservableObject() {
        // Verify ImportViewModel conforms to ObservableObject
        let vm = ImportViewModel()
        let _: any ObservableObject = vm // Compile-time check: ImportViewModel conforms to ObservableObject
    }

    // MARK: - Published Properties Tests

    func testSelectedStrategyDefault() {
        let vm = ImportViewModel()
        XCTAssertEqual(vm.selectedStrategy, .merge, "Default strategy should be merge")
    }

    func testShowFilePickerDefault() {
        let vm = ImportViewModel()
        XCTAssertFalse(vm.showFilePicker, "showFilePicker should default to false")
    }

    func testIsImportingDefault() {
        let vm = ImportViewModel()
        XCTAssertFalse(vm.isImporting, "isImporting should default to false")
    }

    func testMessagesDefaultToNil() {
        let vm = ImportViewModel()
        XCTAssertNil(vm.successMessage, "successMessage should default to nil")
        XCTAssertNil(vm.errorMessage, "errorMessage should default to nil")
    }

    func testShouldDismissDefault() {
        let vm = ImportViewModel()
        XCTAssertFalse(vm.shouldDismiss, "shouldDismiss should default to false")
    }

    func testImportSourceDefault() {
        let vm = ImportViewModel()
        XCTAssertEqual(vm.importSource, .file, "Default import source should be file")
    }

    func testImportTextDefault() {
        let vm = ImportViewModel()
        XCTAssertTrue(vm.importText.isEmpty, "importText should default to empty")
    }

    func testShowPreviewDefault() {
        let vm = ImportViewModel()
        XCTAssertFalse(vm.showPreview, "showPreview should default to false")
    }

    func testImportPreviewDefault() {
        let vm = ImportViewModel()
        XCTAssertNil(vm.importPreview, "importPreview should default to nil")
    }

    func testImportProgressDefault() {
        let vm = ImportViewModel()
        XCTAssertNil(vm.importProgress, "importProgress should default to nil")
    }

    // MARK: - Strategy Options Tests

    func testStrategyOptionsContainsAllStrategies() {
        let vm = ImportViewModel()
        let options = vm.strategyOptions

        XCTAssertTrue(options.contains(.merge), "Options should contain merge")
        XCTAssertTrue(options.contains(.replace), "Options should contain replace")
        XCTAssertTrue(options.contains(.append), "Options should contain append")
        XCTAssertEqual(options.count, 3, "Should have exactly 3 strategy options")
    }

    func testStrategyNameForMerge() {
        let vm = ImportViewModel()
        let name = vm.strategyName(.merge)
        XCTAssertFalse(name.isEmpty, "Strategy name for merge should not be empty")
    }

    func testStrategyNameForReplace() {
        let vm = ImportViewModel()
        let name = vm.strategyName(.replace)
        XCTAssertFalse(name.isEmpty, "Strategy name for replace should not be empty")
    }

    func testStrategyNameForAppend() {
        let vm = ImportViewModel()
        let name = vm.strategyName(.append)
        XCTAssertFalse(name.isEmpty, "Strategy name for append should not be empty")
    }

    func testStrategyDescriptionForMerge() {
        let vm = ImportViewModel()
        let desc = vm.strategyDescription(.merge)
        XCTAssertFalse(desc.isEmpty, "Strategy description for merge should not be empty")
    }

    func testStrategyDescriptionForReplace() {
        let vm = ImportViewModel()
        let desc = vm.strategyDescription(.replace)
        XCTAssertFalse(desc.isEmpty, "Strategy description for replace should not be empty")
    }

    func testStrategyDescriptionForAppend() {
        let vm = ImportViewModel()
        let desc = vm.strategyDescription(.append)
        XCTAssertFalse(desc.isEmpty, "Strategy description for append should not be empty")
    }

    func testStrategyIconForMerge() {
        let vm = ImportViewModel()
        let icon = vm.strategyIcon(.merge)
        XCTAssertEqual(icon, "arrow.triangle.merge", "Merge icon should be arrow.triangle.merge")
    }

    func testStrategyIconForReplace() {
        let vm = ImportViewModel()
        let icon = vm.strategyIcon(.replace)
        XCTAssertEqual(icon, "arrow.clockwise", "Replace icon should be arrow.clockwise")
    }

    func testStrategyIconForAppend() {
        let vm = ImportViewModel()
        let icon = vm.strategyIcon(.append)
        XCTAssertEqual(icon, "plus.circle", "Append icon should be plus.circle")
    }

    // MARK: - ImportSource Enum Tests

    func testImportSourceFileCase() {
        let source = ImportSource.file
        XCTAssertTrue(source == .file, "ImportSource should have file case")
    }

    func testImportSourceTextCase() {
        let source = ImportSource.text
        XCTAssertTrue(source == .text, "ImportSource should have text case")
    }

    // MARK: - State Management Tests

    func testClearMessagesResetsSuccessMessage() {
        let vm = ImportViewModel()
        vm.successMessage = "Test success"
        vm.clearMessages()
        XCTAssertNil(vm.successMessage, "clearMessages should reset successMessage")
    }

    func testClearMessagesResetsErrorMessage() {
        let vm = ImportViewModel()
        vm.errorMessage = "Test error"
        vm.clearMessages()
        XCTAssertNil(vm.errorMessage, "clearMessages should reset errorMessage")
    }

    func testCancelPreviewResetsState() {
        let vm = ImportViewModel()
        vm.showPreview = true
        vm.cancelPreview()
        XCTAssertFalse(vm.showPreview, "cancelPreview should set showPreview to false")
        XCTAssertNil(vm.importPreview, "cancelPreview should reset importPreview")
        XCTAssertNil(vm.previewFileURL, "cancelPreview should reset previewFileURL")
        XCTAssertNil(vm.previewText, "cancelPreview should reset previewText")
    }

    func testCleanupResetsAllState() {
        let vm = ImportViewModel()
        vm.successMessage = "Test"
        vm.importText = "Some JSON"
        vm.showPreview = true

        vm.cleanup()

        XCTAssertNil(vm.successMessage, "cleanup should reset successMessage")
        XCTAssertNil(vm.errorMessage, "cleanup should reset errorMessage")
        XCTAssertFalse(vm.showPreview, "cleanup should reset showPreview")
        XCTAssertNil(vm.importProgress, "cleanup should reset importProgress")
        XCTAssertTrue(vm.importText.isEmpty, "cleanup should reset importText")
    }

    // MARK: - Text Import Validation Tests

    func testShowPreviewForTextWithEmptyText() {
        let vm = ImportViewModel()
        vm.importText = ""
        vm.showPreviewForText()
        XCTAssertNotNil(vm.errorMessage, "Should show error for empty text")
    }

    func testShowPreviewForTextWithWhitespaceOnly() {
        let vm = ImportViewModel()
        vm.importText = "   \n  \t  "
        vm.showPreviewForText()
        XCTAssertNotNil(vm.errorMessage, "Should show error for whitespace-only text")
    }

    func testShowPreviewForTextWithInvalidJSON() {
        let vm = ImportViewModel()
        vm.importText = "not valid json"
        vm.showPreviewForText()
        XCTAssertNotNil(vm.errorMessage, "Should show error for invalid JSON")
    }

    // MARK: - Strategy Selection Tests

    func testChangeSelectedStrategy() {
        let vm = ImportViewModel()
        XCTAssertEqual(vm.selectedStrategy, .merge, "Default should be merge")

        vm.selectedStrategy = .replace
        XCTAssertEqual(vm.selectedStrategy, .replace, "Should update to replace")

        vm.selectedStrategy = .append
        XCTAssertEqual(vm.selectedStrategy, .append, "Should update to append")
    }

    // MARK: - Import Source Selection Tests

    func testChangeImportSource() {
        let vm = ImportViewModel()
        XCTAssertEqual(vm.importSource, .file, "Default should be file")

        vm.importSource = .text
        XCTAssertEqual(vm.importSource, .text, "Should update to text")

        vm.importSource = .file
        XCTAssertEqual(vm.importSource, .file, "Should update back to file")
    }

    // MARK: - macOS Platform Compatibility Tests

    func testImportViewModelWorksonMacOS() {
        // Verify no iOS-specific dependencies
        let vm = ImportViewModel()

        // All properties should be accessible on macOS
        _ = vm.selectedStrategy
        _ = vm.showFilePicker
        _ = vm.isImporting
        _ = vm.successMessage
        _ = vm.errorMessage
        _ = vm.shouldDismiss
        _ = vm.importSource
        _ = vm.importText
        _ = vm.showPreview
        _ = vm.importPreview
        _ = vm.previewFileURL
        _ = vm.previewText
        _ = vm.importProgress
        _ = vm.strategyOptions

        XCTAssertTrue(true, "ImportViewModel works on macOS without iOS dependencies")
    }

    // MARK: - Documentation Test

    func testDocumentImportViewModelForMacOS() {
        // This test documents the ImportViewModel capabilities on macOS
        XCTAssertTrue(true, """

        ImportViewModel macOS Compatibility Test Documentation
        ======================================================

        ImportViewModel Features on macOS:
        1. ✅ ImportViewModel class is available and instantiable
        2. ✅ ObservableObject conformance works
        3. ✅ All @Published properties are accessible
        4. ✅ Strategy options (merge, replace, append) work
        5. ✅ Import source selection (file, text) works
        6. ✅ State management (clearMessages, cancelPreview, cleanup) works
        7. ✅ Input validation (empty text, invalid JSON) works

        Strategy Configuration:
        - merge: Update existing items and add new ones
        - replace: Delete all data and import fresh
        - append: Create duplicates with new IDs

        Import Sources:
        - file: Import from file picker (uses NSOpenPanel on macOS)
        - text: Import from pasted JSON text

        Note: File picker integration uses NSOpenPanel on macOS
        instead of UIDocumentPickerViewController (iOS).

        """)
    }
}


#endif
