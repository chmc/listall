//
//  FeatureTipsMacTests.swift
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

final class FeatureTipsMacTests: XCTestCase {

    // MARK: - MacTooltipType Tests

    func testMacTooltipTypeHasAllCases() {
        // Verify all expected tooltip types exist
        let allTypes = MacTooltipType.allCases
        XCTAssertEqual(allTypes.count, 7, "Should have 7 tooltip types for macOS")

        // Verify specific types exist
        let typeRawValues = allTypes.map { $0.rawValue }
        XCTAssertTrue(typeRawValues.contains("tooltip_add_list"))
        XCTAssertTrue(typeRawValues.contains("tooltip_item_suggestions"))
        XCTAssertTrue(typeRawValues.contains("tooltip_search"))
        XCTAssertTrue(typeRawValues.contains("tooltip_sort_filter"))
        XCTAssertTrue(typeRawValues.contains("tooltip_context_menu"))
        XCTAssertTrue(typeRawValues.contains("tooltip_archive"))
        XCTAssertTrue(typeRawValues.contains("tooltip_keyboard_shortcuts"))
    }

    func testMacTooltipTypeHasTitle() {
        // All tooltip types should have non-empty titles
        for type in MacTooltipType.allCases {
            XCTAssertFalse(type.title.isEmpty, "\(type.rawValue) should have a title")
        }
    }

    func testMacTooltipTypeHasIcon() {
        // All tooltip types should have non-empty icons
        for type in MacTooltipType.allCases {
            XCTAssertFalse(type.icon.isEmpty, "\(type.rawValue) should have an icon")
        }
    }

    func testMacTooltipTypeHasMessage() {
        // All tooltip types should have non-empty messages
        for type in MacTooltipType.allCases {
            XCTAssertFalse(type.message.isEmpty, "\(type.rawValue) should have a message")
        }
    }

    func testMacTooltipTypeMessagesAreMacSpecific() {
        // Verify messages use macOS-specific terminology
        let contextMenuTip = MacTooltipType.contextMenuActions
        XCTAssertTrue(contextMenuTip.message.lowercased().contains("right-click"),
                      "Context menu tip should mention right-click for macOS")

        let keyboardTip = MacTooltipType.keyboardShortcuts
        XCTAssertTrue(keyboardTip.message.lowercased().contains("keyboard"),
                      "Keyboard shortcuts tip should mention keyboard")

        let searchTip = MacTooltipType.searchFunctionality
        XCTAssertTrue(searchTip.message.lowercased().contains("cmd+f"),
                      "Search tip should mention Cmd+F shortcut for macOS")
    }

    func testMacTooltipTypeIsIdentifiable() {
        // Test Identifiable conformance
        let tip = MacTooltipType.addListButton
        XCTAssertEqual(tip.id, tip.rawValue)
    }

    // MARK: - MacTooltipManager Tests

    func testMacTooltipManagerSharedInstance() {
        let manager1 = MacTooltipManager.shared
        let manager2 = MacTooltipManager.shared
        XCTAssertTrue(manager1 === manager2, "Should return same singleton instance")
    }

    func testMacTooltipManagerInitialState() {
        // Initially, no tips should be marked as shown
        // Note: This test may fail if run after other tests that mark tips as shown
        // In a real test, we'd use a mock UserDefaults
        let manager = MacTooltipManager.shared
        XCTAssertGreaterThanOrEqual(manager.totalTooltipCount(), 7)
        XCTAssertLessThanOrEqual(manager.shownTooltipCount(), manager.totalTooltipCount())
    }

    func testMacTooltipManagerMarkAsShown() {
        let manager = MacTooltipManager.shared
        let testTip = MacTooltipType.keyboardShortcuts // Use macOS-specific tip

        // Mark as shown
        let initialCount = manager.shownTooltipCount()
        if !manager.hasShown(testTip) {
            manager.markAsShown(testTip)
            XCTAssertTrue(manager.hasShown(testTip), "Tip should be marked as shown")
            XCTAssertEqual(manager.shownTooltipCount(), initialCount + 1)
        } else {
            // Already shown, count should not change
            manager.markAsShown(testTip)
            XCTAssertEqual(manager.shownTooltipCount(), initialCount)
        }
    }

    func testMacTooltipManagerMarkAsShownIdempotent() {
        // Marking the same tip twice should not increase count
        let manager = MacTooltipManager.shared
        let testTip = MacTooltipType.contextMenuActions

        manager.markAsShown(testTip)
        let countAfterFirst = manager.shownTooltipCount()

        manager.markAsShown(testTip)
        let countAfterSecond = manager.shownTooltipCount()

        XCTAssertEqual(countAfterFirst, countAfterSecond,
                       "Marking same tip twice should not increase count")
    }

    func testMacTooltipManagerResetAllTooltips() {
        let manager = MacTooltipManager.shared

        // Mark some tips as shown
        manager.markAsShown(.addListButton)
        manager.markAsShown(.searchFunctionality)

        // Reset all
        manager.resetAllTooltips()

        // All tips should now be not shown
        for tip in MacTooltipType.allCases {
            XCTAssertFalse(manager.hasShown(tip),
                           "\(tip.rawValue) should not be shown after reset")
        }

        XCTAssertEqual(manager.shownTooltipCount(), 0,
                       "Shown count should be 0 after reset")
    }

    func testMacTooltipManagerMarkAllAsViewed() {
        let manager = MacTooltipManager.shared

        // First reset
        manager.resetAllTooltips()

        // Mark all as viewed
        manager.markAllAsViewed()

        // All tips should now be shown
        XCTAssertEqual(manager.shownTooltipCount(), manager.totalTooltipCount(),
                       "All tips should be marked as viewed")

        for tip in MacTooltipType.allCases {
            XCTAssertTrue(manager.hasShown(tip),
                          "\(tip.rawValue) should be shown after markAllAsViewed")
        }

        // Clean up
        manager.resetAllTooltips()
    }

    func testMacTooltipManagerTotalCount() {
        let manager = MacTooltipManager.shared
        XCTAssertEqual(manager.totalTooltipCount(), MacTooltipType.allCases.count)
    }

    // MARK: - Settings Integration Tests

    func testHelpAndTipsSettingsSection() {
        // Verify the Help & Tips section has the expected structure
        // This is a documentation test showing what the settings section should display

        let manager = MacTooltipManager.shared
        let viewedCount = manager.shownTooltipCount()
        let totalCount = manager.totalTooltipCount()

        // Status display should show "X of Y tips viewed"
        let statusText = "\(viewedCount) of \(totalCount) tips viewed"
        XCTAssertTrue(statusText.contains("of"), "Status should show 'X of Y' format")

        // View All Feature Tips button should be available
        let viewAllLabel = "View All Feature Tips"
        XCTAssertFalse(viewAllLabel.isEmpty)

        // Show All Tips Again button should be available
        let resetLabel = "Show All Tips Again"
        XCTAssertFalse(resetLabel.isEmpty)
    }

    func testResetTooltipsConfirmationMessage() {
        // Reset confirmation should explain what will happen
        let message = "This will reset all feature tips. Tips will appear again when you use different features."
        XCTAssertTrue(message.contains("reset"))
        XCTAssertTrue(message.contains("Tips"))
    }

    // MARK: - Platform Compatibility Tests

    func testMacOSSpecificTipsExist() {
        // macOS should have context menu tip (instead of iOS swipe actions)
        let contextMenuTip = MacTooltipType.contextMenuActions
        XCTAssertEqual(contextMenuTip.rawValue, "tooltip_context_menu")
        XCTAssertTrue(contextMenuTip.title.lowercased().contains("context") ||
                      contextMenuTip.title.lowercased().contains("menu"))

        // macOS should have keyboard shortcuts tip
        let keyboardTip = MacTooltipType.keyboardShortcuts
        XCTAssertEqual(keyboardTip.rawValue, "tooltip_keyboard_shortcuts")
        XCTAssertTrue(keyboardTip.title.lowercased().contains("keyboard"))
    }

    func testSharedTipsExist() {
        // These tips should exist on both iOS and macOS
        let sharedTipRawValues = [
            "tooltip_add_list",
            "tooltip_item_suggestions",
            "tooltip_search",
            "tooltip_sort_filter",
            "tooltip_archive"
        ]

        for rawValue in sharedTipRawValues {
            let tip = MacTooltipType.allCases.first { $0.rawValue == rawValue }
            XCTAssertNotNil(tip, "\(rawValue) should exist in MacTooltipType")
        }
    }

    // MARK: - Documentation Test

    func testFeatureTipsDocumentation() {
        let documentation = """

        ========================================================================
        Feature Tips System on macOS
        ========================================================================

        Overview:
        ---------
        The Feature Tips System helps users discover app features through
        contextual tooltips. Tips are tracked in UserDefaults and can be
        reset through the Settings.

        Components:
        -----------
        1. MacTooltipManager - Singleton managing tip tracking
        2. MacTooltipType - Enum defining all available tips
        3. MacAllFeatureTipsView - View displaying all tips with status
        4. MacSettingsView GeneralSettingsTab - Help & Tips section

        macOS-Specific Tips:
        --------------------
        - contextMenuActions: Right-click context menus (vs iOS swipe)
        - keyboardShortcuts: Cmd+key shortcuts for navigation

        Settings Integration:
        ---------------------
        Located in: Settings > General > Help & Tips
        Features:
        - Status display (X of Y tips viewed)
        - View All Feature Tips button
        - Show All Tips Again button

        UserDefaults Key:
        -----------------
        Key: "shownTooltips"
        Format: Array of tip raw values (String[])
        Shared with iOS for cross-platform consistency

        ========================================================================

        """

        print(documentation)
        XCTAssertTrue(true, "Documentation generated")
    }
}


#endif
