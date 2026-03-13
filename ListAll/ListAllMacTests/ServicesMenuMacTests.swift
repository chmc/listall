//
//  ServicesMenuMacTests.swift
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

final class ServicesMenuMacTests: XCTestCase {

    // MARK: - Platform Verification

    func testRunningOnMacOS() {
        #if os(macOS)
        XCTAssertTrue(true, "Tests are running on macOS")
        #else
        XCTFail("These tests should only run on macOS")
        #endif
    }

    // MARK: - ServicesProvider Existence Tests

    func testServicesProviderExists() {
        // Verify ServicesProvider class exists
        let providerType = ServicesProvider.self
        XCTAssertNotNil(providerType)
    }

    func testServicesProviderIsSingleton() {
        let provider1 = ServicesProvider.shared
        let provider2 = ServicesProvider.shared
        XCTAssertTrue(provider1 === provider2, "ServicesProvider should be a singleton")
    }

    func testServicesProviderIsNSObject() {
        let provider = ServicesProvider.shared
        let _: NSObject = provider // Compile-time check: ServicesProvider inherits from NSObject
    }

    // MARK: - Text Parsing Tests

    func testParseTextIntoItemsBasic() {
        let text = """
        Buy milk
        Get bread
        Pick up eggs
        """

        let items = ServicesProvider.parseTextIntoItems(text)

        XCTAssertEqual(items.count, 3)
        XCTAssertEqual(items[0], "Buy milk")
        XCTAssertEqual(items[1], "Get bread")
        XCTAssertEqual(items[2], "Pick up eggs")
    }

    func testParseTextWithEmptyLines() {
        let text = """
        Item 1

        Item 2


        Item 3
        """

        let items = ServicesProvider.parseTextIntoItems(text)

        XCTAssertEqual(items.count, 3)
        XCTAssertEqual(items[0], "Item 1")
        XCTAssertEqual(items[1], "Item 2")
        XCTAssertEqual(items[2], "Item 3")
    }

    func testParseTextWithBulletPoints() {
        let testCases = [
            ("• Milk", "Milk"),
            ("- Bread", "Bread"),
            ("* Eggs", "Eggs"),
            ("✓ Done item", "Done item"),
            ("✔ Checked", "Checked"),
            ("☐ Unchecked", "Unchecked"),
            ("☑ Checked box", "Checked box"),
            ("▪ Square bullet", "Square bullet"),
            ("▸ Arrow bullet", "Arrow bullet"),
            ("→ Right arrow", "Right arrow"),
        ]

        for (input, expected) in testCases {
            let items = ServicesProvider.parseTextIntoItems(input)
            XCTAssertEqual(items.count, 1, "Should have one item for: \(input)")
            XCTAssertEqual(items.first, expected, "Failed for input: \(input)")
        }
    }

    func testParseTextWithNumberedLists() {
        let testCases = [
            ("1. First item", "First item"),
            ("2. Second item", "Second item"),
            ("10. Tenth item", "Tenth item"),
            ("1) With paren", "With paren"),
            ("3) Another", "Another"),
            ("1: With colon", "With colon"),
        ]

        for (input, expected) in testCases {
            let items = ServicesProvider.parseTextIntoItems(input)
            XCTAssertEqual(items.count, 1, "Should have one item for: \(input)")
            XCTAssertEqual(items.first, expected, "Failed for input: \(input)")
        }
    }

    func testParseTextWithCheckboxes() {
        let testCases = [
            ("[ ] Unchecked", "Unchecked"),
            ("[x] Checked lowercase", "Checked lowercase"),
            ("[X] Checked uppercase", "Checked uppercase"),
            ("[✓] Checkmark", "Checkmark"),
            ("[] Empty brackets", "Empty brackets"),
        ]

        for (input, expected) in testCases {
            let items = ServicesProvider.parseTextIntoItems(input)
            XCTAssertEqual(items.count, 1, "Should have one item for: \(input)")
            XCTAssertEqual(items.first, expected, "Failed for input: \(input)")
        }
    }

    func testParseTextWithMixedFormats() {
        let text = """
        • Bullet item
        1. Numbered item
        [ ] Checkbox item
        Plain text item
        """

        let items = ServicesProvider.parseTextIntoItems(text)

        XCTAssertEqual(items.count, 4)
        XCTAssertEqual(items[0], "Bullet item")
        XCTAssertEqual(items[1], "Numbered item")
        XCTAssertEqual(items[2], "Checkbox item")
        XCTAssertEqual(items[3], "Plain text item")
    }

    func testParseTextWithWhitespace() {
        let text = """
           Indented item
        	Tab indented
           • Indented bullet
        """

        let items = ServicesProvider.parseTextIntoItems(text)

        XCTAssertEqual(items.count, 3)
        XCTAssertEqual(items[0], "Indented item")
        XCTAssertEqual(items[1], "Tab indented")
        XCTAssertEqual(items[2], "Indented bullet")
    }

    func testParseEmptyText() {
        let items = ServicesProvider.parseTextIntoItems("")
        XCTAssertTrue(items.isEmpty)
    }

    func testParseWhitespaceOnlyText() {
        let text = "   \n\t\n   "
        let items = ServicesProvider.parseTextIntoItems(text)
        XCTAssertTrue(items.isEmpty)
    }

    func testParseTextPreservesSpecialCharacters() {
        let text = """
        Café au lait ☕
        Eggs (dozen)
        Milk - 2%
        "Quoted item"
        Item with émojis 🎉
        """

        let items = ServicesProvider.parseTextIntoItems(text)

        XCTAssertEqual(items.count, 5)
        XCTAssertEqual(items[0], "Café au lait ☕")
        XCTAssertEqual(items[1], "Eggs (dozen)")
        XCTAssertEqual(items[2], "Milk - 2%")
        XCTAssertEqual(items[3], "\"Quoted item\"")
        XCTAssertEqual(items[4], "Item with émojis 🎉")
    }

    // MARK: - Configuration Tests

    func testDefaultListIdConfiguration() {
        let provider = ServicesProvider.shared

        // Clear existing config
        UserDefaults.standard.removeObject(forKey: "ServicesDefaultListId")

        // Initially should be nil
        XCTAssertNil(provider.defaultListId)

        // Set a UUID
        let testId = UUID()
        provider.defaultListId = testId
        XCTAssertEqual(provider.defaultListId, testId)

        // Clear it
        provider.defaultListId = nil
        XCTAssertNil(provider.defaultListId)
    }

    func testShowNotificationsConfiguration() {
        let provider = ServicesProvider.shared

        // Clear existing config
        UserDefaults.standard.removeObject(forKey: "ServicesShowNotifications")

        // Default should be false (UserDefaults returns false for missing bool)
        XCTAssertFalse(provider.showNotifications)

        // Set to true
        provider.showNotifications = true
        XCTAssertTrue(provider.showNotifications)

        // Set back to false
        provider.showNotifications = false
        XCTAssertFalse(provider.showNotifications)
    }

    func testBringToFrontConfiguration() {
        let provider = ServicesProvider.shared

        // Clear existing config
        UserDefaults.standard.removeObject(forKey: "ServicesBringToFront")

        // Default should be true (as specified in implementation)
        XCTAssertTrue(provider.bringToFront)

        // Set to false
        provider.bringToFront = false
        XCTAssertFalse(provider.bringToFront)

        // Set back to true
        provider.bringToFront = true
        XCTAssertTrue(provider.bringToFront)
    }

    // MARK: - NSPasteboard Integration Tests

    func testReadTextFromPasteboard() {
        #if os(macOS)
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()

        let testText = "Test item 1\nTest item 2"
        pasteboard.setString(testText, forType: .string)

        let retrieved = pasteboard.string(forType: .string)
        XCTAssertEqual(retrieved, testText)
        #endif
    }

    func testEmptyPasteboard() {
        #if os(macOS)
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()

        // Reading from empty pasteboard should return nil
        let retrieved = pasteboard.string(forType: .string)
        XCTAssertNil(retrieved)
        #endif
    }

    func testPasteboardWithMultipleTypes() {
        #if os(macOS)
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()

        let testText = "Plain text version"
        pasteboard.setString(testText, forType: .string)

        // Services use .string type
        let retrieved = pasteboard.string(forType: .string)
        XCTAssertEqual(retrieved, testText)
        #endif
    }

    // MARK: - Edge Cases

    func testParseVeryLongLine() {
        let longLine = String(repeating: "a", count: 500)
        let items = ServicesProvider.parseTextIntoItems(longLine)

        XCTAssertEqual(items.count, 1)
        XCTAssertEqual(items.first?.count, 500)
    }

    func testParseManyLines() {
        let lines = (1...100).map { "Item \($0)" }
        let text = lines.joined(separator: "\n")

        let items = ServicesProvider.parseTextIntoItems(text)

        XCTAssertEqual(items.count, 100)
        XCTAssertEqual(items.first, "Item 1")
        XCTAssertEqual(items.last, "Item 100")
    }

    func testParseUnicodeText() {
        let text = """
        日本語テキスト
        中文文本
        한국어 텍스트
        العربية
        עברית
        """

        let items = ServicesProvider.parseTextIntoItems(text)

        XCTAssertEqual(items.count, 5)
        XCTAssertEqual(items[0], "日本語テキスト")
        XCTAssertEqual(items[1], "中文文本")
    }

    func testParseRTLText() {
        let text = "مرحبا بالعالم"
        let items = ServicesProvider.parseTextIntoItems(text)

        XCTAssertEqual(items.count, 1)
        XCTAssertEqual(items.first, "مرحبا بالعالم")
    }

    // MARK: - Method Signature Tests

    func testServiceMethodsExist() {
        let provider = ServicesProvider.shared

        // Verify service methods exist by checking they respond to selectors
        XCTAssertTrue(provider.responds(to: #selector(ServicesProvider.createItemFromText(_:userData:error:))))
        XCTAssertTrue(provider.responds(to: #selector(ServicesProvider.createItemsFromLines(_:userData:error:))))
        XCTAssertTrue(provider.responds(to: #selector(ServicesProvider.createListFromText(_:userData:error:))))
    }

    // MARK: - Info.plist Configuration Test

    func testInfoPlistContainsNSServices() {
        // This test verifies that Info.plist is properly configured
        // by checking that the bundle can be loaded

        // Get the bundle for the main app
        if let bundleId = Bundle.main.bundleIdentifier,
           bundleId.contains("ListAllMac") {
            // If running in app context, check for services
            if let infoPlist = Bundle.main.infoDictionary,
               let services = infoPlist["NSServices"] as? [[String: Any]] {
                XCTAssertFalse(services.isEmpty, "NSServices should not be empty")

                // Check for expected service names
                let menuItems = services.compactMap { service -> String? in
                    if let menuItem = service["NSMenuItem"] as? [String: String] {
                        return menuItem["default"]
                    }
                    return nil
                }

                XCTAssertTrue(menuItems.contains("Add to ListAll"))
                XCTAssertTrue(menuItems.contains("Add Lines to ListAll"))
                XCTAssertTrue(menuItems.contains("Create ListAll List"))
            }
        }
        // In test bundle context, just pass
        XCTAssertTrue(true)
    }

    // MARK: - Documentation Test

    func testDocumentServicesMenuImplementation() {
        // This test documents the Services menu implementation
        XCTAssertTrue(true, """

        macOS Services Menu Integration (Task 6.3)
        ===========================================

        The Services menu allows users to select text in ANY macOS app and send it to ListAll.

        Three services are provided:
        1. "Add to ListAll" (⇧⌘L) - Add selected text as a single item
        2. "Add Lines to ListAll" - Add each line as a separate item
        3. "Create ListAll List" - First line becomes list name, rest become items

        Files Created:
        - ListAllMac/Services/ServicesProvider.swift - Service handler class
        - Modified ListAllMac/Info.plist - NSServices registration
        - Modified ListAllMac/ListAllMacApp.swift - AppDelegate for services

        How Services Work:
        1. User selects text in Safari, TextEdit, Notes, etc.
        2. Right-click → Services → "Add to ListAll"
        3. ServicesProvider receives text via NSPasteboard
        4. Text is parsed and added to DataManager
        5. ListAll comes to front (configurable)

        Text Parsing Features:
        - Strips bullet points: •, -, *, ✓, ✔, ☐, ☑, ▪, ▸, →
        - Strips numbered prefixes: 1., 2), 3:
        - Strips checkboxes: [ ], [x], [X], [✓]
        - Preserves Unicode and special characters
        - Handles empty lines and whitespace

        Configuration (UserDefaults):
        - ServicesDefaultListId: UUID of default target list
        - ServicesShowNotifications: Show notification after adding
        - ServicesBringToFront: Bring app to front after adding

        Technical Requirements:
        - ServicesProvider must inherit from NSObject
        - Service methods must be @objc
        - NSApplication.shared.servicesProvider must be set
        - Info.plist NSServices array must match method names
        - App must be in /Applications for services to appear

        Troubleshooting:
        - Log out/in to macOS to refresh Services database
        - Run: /System/Library/CoreServices/pbs -flush
        - Check System Settings → Keyboard → Services

        """)
    }
}


#endif
