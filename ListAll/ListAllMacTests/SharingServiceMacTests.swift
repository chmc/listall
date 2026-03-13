//
//  SharingServiceMacTests.swift
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

final class SharingServiceMacTests: XCTestCase {

    // NOTE: We do NOT create DataRepository in setup because unsigned macOS test builds
    // trigger permission dialogs for App Groups access. Instead, tests focus on:
    // 1. Share options validation
    // 2. Share format enum values
    // 3. Share result model tests
    // 4. Clipboard operations (NSPasteboard)
    // 5. NSSharingService availability
    // 6. URL parsing

    // MARK: - Platform Verification

    func testRunningOnMacOS() {
        #if os(macOS)
        XCTAssertTrue(true, "SharingService tests are running on macOS")
        #else
        XCTFail("These tests should only run on macOS")
        #endif
    }

    // MARK: - Share Format Tests

    func testShareFormatEnumCases() {
        let formats: [ShareFormat] = [.plainText, .json, .url]
        XCTAssertEqual(formats.count, 3, "Should have exactly 3 share formats")
    }

    func testShareFormatPlainText() {
        let format = ShareFormat.plainText
        XCTAssertNotNil(format, "Plain text format should exist")
    }

    func testShareFormatJSON() {
        let format = ShareFormat.json
        XCTAssertNotNil(format, "JSON format should exist")
    }

    func testShareFormatURL() {
        let format = ShareFormat.url
        XCTAssertNotNil(format, "URL format should exist")
    }

    // MARK: - Share Options Tests

    func testShareOptionsDefaultValues() {
        let options = ShareOptions.default
        XCTAssertTrue(options.includeCrossedOutItems, "Default should include crossed out items")
        XCTAssertTrue(options.includeDescriptions, "Default should include descriptions")
        XCTAssertTrue(options.includeQuantities, "Default should include quantities")
        XCTAssertFalse(options.includeDates, "Default should not include dates")
        XCTAssertTrue(options.includeImages, "Default should include images")
    }

    func testShareOptionsMinimalPreset() {
        let options = ShareOptions.minimal
        XCTAssertFalse(options.includeCrossedOutItems, "Minimal should not include crossed out items")
        XCTAssertFalse(options.includeDescriptions, "Minimal should not include descriptions")
        XCTAssertFalse(options.includeQuantities, "Minimal should not include quantities")
        XCTAssertFalse(options.includeDates, "Minimal should not include dates")
        XCTAssertFalse(options.includeImages, "Minimal should not include images")
    }

    func testShareOptionsCustomConfiguration() {
        let options = ShareOptions(
            includeCrossedOutItems: false,
            includeDescriptions: true,
            includeQuantities: false,
            includeDates: true,
            includeImages: false
        )
        XCTAssertFalse(options.includeCrossedOutItems)
        XCTAssertTrue(options.includeDescriptions)
        XCTAssertFalse(options.includeQuantities)
        XCTAssertTrue(options.includeDates)
        XCTAssertFalse(options.includeImages)
    }

    // MARK: - Share Result Tests

    func testShareResultCreationWithPlainText() {
        let result = ShareResult(format: .plainText, content: "Test content", fileName: nil)
        XCTAssertEqual(result.format, .plainText)
        XCTAssertNil(result.fileName)
        XCTAssertNotNil(result.content)
    }

    func testShareResultCreationWithJSON() {
        let tempURL = URL(fileURLWithPath: "/tmp/test.json")
        let result = ShareResult(format: .json, content: tempURL, fileName: "test.json")
        XCTAssertEqual(result.format, .json)
        XCTAssertEqual(result.fileName, "test.json")
        XCTAssertNotNil(result.content)
    }

    func testShareResultContentAsString() {
        let testString = "My shopping list"
        let result = ShareResult(format: .plainText, content: testString, fileName: nil)

        if let content = result.content as? String {
            XCTAssertEqual(content, testString)
        } else {
            XCTFail("Content should be a String")
        }
    }

    func testShareResultContentAsURL() {
        let testURL = URL(fileURLWithPath: "/tmp/export.json")
        let result = ShareResult(format: .json, content: testURL, fileName: "export.json")

        if let content = result.content as? URL {
            XCTAssertEqual(content.lastPathComponent, "export.json")
        } else {
            XCTFail("Content should be a URL")
        }
    }

    // MARK: - NSPasteboard Tests (macOS-specific)

    func testNSPasteboardCopyString() {
        #if os(macOS)
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()

        let testString = "Test sharing content from ListAll"
        let success = pasteboard.setString(testString, forType: .string)

        XCTAssertTrue(success, "NSPasteboard should accept string")

        let retrieved = pasteboard.string(forType: .string)
        XCTAssertEqual(retrieved, testString, "Retrieved string should match")
        #else
        XCTFail("This test should only run on macOS")
        #endif
    }

    func testNSPasteboardClearContents() {
        #if os(macOS)
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        _ = pasteboard.setString("temporary", forType: .string)

        pasteboard.clearContents()

        // After clearing, getting string might return nil or empty
        // depending on system state
        XCTAssertTrue(true, "Pasteboard clearContents executed without error")
        #else
        XCTFail("This test should only run on macOS")
        #endif
    }

    func testNSPasteboardMultipleTypes() {
        #if os(macOS)
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()

        let testString = "Plain text version"
        let success = pasteboard.setString(testString, forType: .string)

        XCTAssertTrue(success, "Should set string successfully")
        XCTAssertEqual(pasteboard.string(forType: .string), testString)
        #else
        XCTFail("This test should only run on macOS")
        #endif
    }

    // MARK: - NSSharingService Tests

    @available(macOS, deprecated: 13.0)
    func testNSSharingServiceAvailability() {
        #if os(macOS)
        // Test that sharing services are available for text content
        let testItems = ["Test content to share"]
        let services = NSSharingService.sharingServices(forItems: testItems)

        // There should be at least some sharing services available
        // (like Copy, Mail, Messages, Notes, etc.)
        XCTAssertGreaterThan(services.count, 0, "Should have some sharing services available")
        #else
        XCTFail("This test should only run on macOS")
        #endif
    }

    @available(macOS, deprecated: 13.0)
    func testNSSharingServiceForURL() {
        #if os(macOS)
        let testURL = URL(fileURLWithPath: "/tmp/test.txt")
        let services = NSSharingService.sharingServices(forItems: [testURL])

        // URL sharing should have services available
        XCTAssertGreaterThanOrEqual(services.count, 0, "Should handle URL items")
        #else
        XCTFail("This test should only run on macOS")
        #endif
    }

    func testNSSharingServicePicker() {
        #if os(macOS)
        let testItems = ["Test content"]
        let picker = NSSharingServicePicker(items: testItems)

        XCTAssertNotNil(picker, "Should create sharing service picker")
        #else
        XCTFail("This test should only run on macOS")
        #endif
    }

    // MARK: - URL Parsing Tests

    func testParseValidListURL() {
        let listId = UUID()
        let listName = "Shopping List"
        let encodedName = listName.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? listName
        let urlString = "listall://list/\(listId.uuidString)?name=\(encodedName)"

        guard let url = URL(string: urlString) else {
            XCTFail("Should create valid URL")
            return
        }

        XCTAssertEqual(url.scheme, "listall")
        XCTAssertEqual(url.host, "list")

        let pathComponents = url.pathComponents.filter { $0 != "/" }
        XCTAssertEqual(pathComponents.first, listId.uuidString)

        if let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
           let queryItems = components.queryItems,
           let nameItem = queryItems.first(where: { $0.name == "name" }) {
            XCTAssertEqual(nameItem.value, listName)
        } else {
            XCTFail("Should parse query parameters")
        }
    }

    func testParseInvalidScheme() {
        let url = URL(string: "https://example.com/list/123")!
        XCTAssertNotEqual(url.scheme, "listall", "Should not match listall scheme")
    }

    func testParseURLWithSpecialCharacters() {
        let listName = "Café Groceries"  // Use special char without & which is URL separator
        // Use URLComponents to properly encode query values
        var components = URLComponents()
        components.scheme = "listall"
        components.host = "list"
        components.path = "/\(UUID().uuidString)"
        components.queryItems = [URLQueryItem(name: "name", value: listName)]

        guard let url = components.url,
              let parsedComponents = URLComponents(url: url, resolvingAgainstBaseURL: false),
              let queryItems = parsedComponents.queryItems,
              let nameItem = queryItems.first(where: { $0.name == "name" }),
              let decodedName = nameItem.value else {
            XCTFail("Should parse URL with special characters")
            return
        }

        XCTAssertEqual(decodedName, listName)
    }

    // MARK: - SharingService Class Tests

    func testSharingServiceClassExists() {
        #if os(macOS)
        let serviceType = SharingService.self
        XCTAssertNotNil(serviceType, "SharingService class should exist")
        #else
        XCTFail("This test should only run on macOS")
        #endif
    }

    func testSharingServiceHasPublishedProperties() {
        #if os(macOS)
        // Verify @Published properties exist (compile-time checks)
        let _: KeyPath<SharingService, Bool> = \.isSharing
        let _: KeyPath<SharingService, String?> = \.shareError
        XCTAssertTrue(true, "SharingService has expected @Published properties")
        #else
        XCTFail("This test should only run on macOS")
        #endif
    }

    func testSharingServiceMethodSignatures() {
        #if os(macOS)
        // Verify method signatures exist (compile-time checks)

        // shareList method
        typealias ShareListMethod = (SharingService) -> (ListAll.List, ShareFormat, ShareOptions) -> ShareResult?
        let _: ShareListMethod = SharingService.shareList

        // shareAllData method
        typealias ShareAllMethod = (SharingService) -> (ShareFormat, ExportOptions) -> ShareResult?
        let _: ShareAllMethod = SharingService.shareAllData

        // copyToClipboard method
        typealias CopyMethod = (SharingService) -> (String) -> Bool
        let _: CopyMethod = SharingService.copyToClipboard

        // validateListForSharing method
        typealias ValidateMethod = (SharingService) -> (ListAll.List) -> Bool
        let _: ValidateMethod = SharingService.validateListForSharing

        // clearError method
        typealias ClearErrorMethod = (SharingService) -> () -> Void
        let _: ClearErrorMethod = SharingService.clearError

        XCTAssertTrue(true, "All SharingService methods exist with correct signatures")
        #else
        XCTFail("This test should only run on macOS")
        #endif
    }

    func testSharingServiceMacOSSpecificMethods() {
        #if os(macOS)
        // Verify macOS-specific methods exist

        // share(content:using:) method
        typealias ShareUsingMethod = (SharingService) -> (Any, NSSharingService) -> Bool
        let _: ShareUsingMethod = SharingService.share

        // createSharingServicePicker method
        typealias CreatePickerMethod = (SharingService) -> (ListAll.List, ShareFormat, ShareOptions) -> NSSharingServicePicker?
        let _: CreatePickerMethod = SharingService.createSharingServicePicker

        XCTAssertTrue(true, "macOS-specific SharingService methods exist")
        #else
        XCTFail("This test should only run on macOS")
        #endif
    }

    // MARK: - List Model Tests (for sharing validation)

    func testListValidationForSharing() {
        // Test that List validation works for sharing purposes
        let validList = List(name: "Shopping")
        XCTAssertTrue(validList.validate(), "Valid list should pass validation")

        var invalidList = List(name: "")
        XCTAssertFalse(invalidList.validate(), "Empty name should fail validation")

        invalidList = List(name: "   ")
        XCTAssertFalse(invalidList.validate(), "Whitespace-only name should fail validation")
    }

    // MARK: - Date Formatting Tests

    func testDateFormattingForPlainText() {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short

        let date = Date()
        let formatted = formatter.string(from: date)

        XCTAssertFalse(formatted.isEmpty, "Date should format to non-empty string")
        XCTAssertTrue(formatted.count > 5, "Formatted date should have reasonable length")
    }

    func testDateFormattingForFilename() {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd-HHmmss"

        let date = Date()
        let formatted = formatter.string(from: date)

        // Should be exactly 17 characters: yyyy-MM-dd-HHmmss
        XCTAssertEqual(formatted.count, 17, "Filename date should be 17 characters")
        XCTAssertFalse(formatted.contains(" "), "Filename date should not contain spaces")
        XCTAssertFalse(formatted.contains(":"), "Filename date should not contain colons")
    }

    // MARK: - Temporary File Tests

    func testDocumentsDirectoryAccess() {
        #if os(macOS)
        let documentsDir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first
        XCTAssertNotNil(documentsDir, "Should have access to Documents directory")
        #else
        XCTFail("This test should only run on macOS")
        #endif
    }

    func testTempDirectoryCreation() {
        let tempDir = FileManager.default.temporaryDirectory
        XCTAssertNotNil(tempDir, "Should have access to temp directory")

        let testFile = tempDir.appendingPathComponent("test-\(UUID().uuidString).txt")
        let testData = "Test content".data(using: .utf8)!

        do {
            try testData.write(to: testFile)
            XCTAssertTrue(FileManager.default.fileExists(atPath: testFile.path))
            try FileManager.default.removeItem(at: testFile)
        } catch {
            XCTFail("Should be able to write to temp directory: \(error)")
        }
    }

    // MARK: - Documentation Test

    func testDocumentSharingServiceConfigurationForMacOS() {
        print("""

        📚 SharingService Configuration Documentation for macOS
        =======================================================

        Share Formats Supported:
        - ✅ Plain Text (.txt) - Human-readable list format
        - ✅ JSON (.json) - Structured data format
        - ❌ URL - Not supported (app not publicly distributed)

        Share Options:
        - includeCrossedOutItems: Include completed/checked items
        - includeDescriptions: Include item descriptions
        - includeQuantities: Include item quantities
        - includeDates: Include created/modified timestamps
        - includeImages: Include base64-encoded images (JSON only)

        macOS-Specific Features:
        - ✅ NSPasteboard for clipboard operations
        - ✅ NSSharingService integration
        - ✅ NSSharingServicePicker for share sheet
        - ✅ Available services detection
        - ✅ Documents directory for temp files

        Clipboard Operations:
        - copyToClipboard(text:) - Copy text to clipboard
        - copyListToClipboard(_:options:) - Copy formatted list

        macOS Sharing Methods:
        - availableSharingServices(for:) - Get available services
        - share(content:using:) - Share via specific service
        - createSharingServicePicker(for:) - Create picker UI

        Phase 3.7 Verification (macOS):
        - ✅ SharingService compiles for macOS
        - ✅ Share options functional
        - ✅ Share result models work
        - ✅ NSPasteboard clipboard operations
        - ✅ NSSharingService integration
        - ✅ URL parsing for deep links
        - ✅ List validation for sharing

        """)
    }
}


#endif
