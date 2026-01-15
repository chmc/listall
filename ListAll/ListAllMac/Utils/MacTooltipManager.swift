//
//  MacTooltipManager.swift
//  ListAllMac
//
//  Manages feature tip tracking for macOS settings.
//  Uses the same UserDefaults key as iOS for cross-platform consistency.
//

import Foundation

/// Enum representing all available feature tips in the macOS app
enum MacTooltipType: String, CaseIterable, Identifiable {
    case addListButton = "tooltip_add_list"
    case itemSuggestions = "tooltip_item_suggestions"
    case searchFunctionality = "tooltip_search"
    case sortFilterOptions = "tooltip_sort_filter"
    case contextMenuActions = "tooltip_context_menu"  // macOS equivalent of swipe actions
    case archiveFunctionality = "tooltip_archive"
    case keyboardShortcuts = "tooltip_keyboard_shortcuts"  // macOS-specific

    var id: String { rawValue }

    var title: String {
        switch self {
        case .addListButton:
            return String(localized: "Create Lists")
        case .itemSuggestions:
            return String(localized: "Smart Suggestions")
        case .searchFunctionality:
            return String(localized: "Search Items")
        case .sortFilterOptions:
            return String(localized: "Sort & Filter")
        case .contextMenuActions:
            return String(localized: "Context Menus")
        case .archiveFunctionality:
            return String(localized: "Archive Lists")
        case .keyboardShortcuts:
            return String(localized: "Keyboard Shortcuts")
        }
    }

    var icon: String {
        switch self {
        case .addListButton:
            return "plus.circle.fill"
        case .itemSuggestions:
            return "lightbulb.fill"
        case .searchFunctionality:
            return "magnifyingglass"
        case .sortFilterOptions:
            return "arrow.up.arrow.down"
        case .contextMenuActions:
            return "cursorarrow.click.2"
        case .archiveFunctionality:
            return "archivebox.fill"
        case .keyboardShortcuts:
            return "command"
        }
    }

    var message: String {
        switch self {
        case .addListButton:
            return String(localized: "Click + or press Cmd+Shift+N to create a new list")
        case .itemSuggestions:
            return String(localized: "Suggestions appear based on your previous items")
        case .searchFunctionality:
            return String(localized: "Press Cmd+F to search across all items in a list")
        case .sortFilterOptions:
            return String(localized: "Use the filter menu to sort and filter items")
        case .contextMenuActions:
            return String(localized: "Right-click on items for quick actions like delete and duplicate")
        case .archiveFunctionality:
            return String(localized: "Archive completed lists to keep your sidebar organized")
        case .keyboardShortcuts:
            return String(localized: "Use keyboard shortcuts for faster navigation: Cmd+N for new item, Delete to remove")
        }
    }
}

/// Manager for feature tip tracking in macOS
class MacTooltipManager: ObservableObject {
    static let shared = MacTooltipManager()

    private let userDefaults = UserDefaults.standard
    // Uses same key as iOS for cross-platform consistency
    private let shownTooltipsKey = "shownTooltips"

    // MARK: - Proactive Tip Display (Task 12.5)
    /// Currently displayed tooltip (for toast-style notification)
    @Published var currentTooltip: MacTooltipType?

    /// Whether a tooltip notification is currently visible
    @Published var isShowingTooltip = false

    private init() {}

    // MARK: - Proactive Tip Methods (Task 12.5)

    /// Shows a tooltip if it hasn't been shown before and no other tooltip is currently visible.
    /// - Parameter type: The tooltip type to show
    /// - Returns: True if the tooltip was shown, false if skipped (already shown or another is visible)
    @discardableResult
    func showIfNeeded(_ type: MacTooltipType) -> Bool {
        guard !hasShown(type) else { return false }
        guard !isShowingTooltip else { return false }

        currentTooltip = type
        isShowingTooltip = true
        objectWillChange.send()
        return true
    }

    /// Dismisses the currently visible tooltip and marks it as shown
    func dismissCurrentTooltip() {
        if let tooltip = currentTooltip {
            markAsShown(tooltip)
        }
        isShowingTooltip = false
        currentTooltip = nil
        objectWillChange.send()
    }

    /// Check if a tooltip has been shown before
    func hasShown(_ type: MacTooltipType) -> Bool {
        let shownTooltips = userDefaults.stringArray(forKey: shownTooltipsKey) ?? []
        return shownTooltips.contains(type.rawValue)
    }

    /// Mark a tooltip as shown
    func markAsShown(_ type: MacTooltipType) {
        var shownTooltips = userDefaults.stringArray(forKey: shownTooltipsKey) ?? []
        if !shownTooltips.contains(type.rawValue) {
            shownTooltips.append(type.rawValue)
            userDefaults.set(shownTooltips, forKey: shownTooltipsKey)
        }
    }

    /// Reset all tooltips (for "Show All Tips Again" feature)
    func resetAllTooltips() {
        userDefaults.removeObject(forKey: shownTooltipsKey)
        objectWillChange.send()
    }

    /// Get the count of tooltips that have been shown
    func shownTooltipCount() -> Int {
        let shownTooltips = userDefaults.stringArray(forKey: shownTooltipsKey) ?? []
        // Count only macOS-specific tips
        return MacTooltipType.allCases.filter { shownTooltips.contains($0.rawValue) }.count
    }

    /// Get the total count of available tooltips
    func totalTooltipCount() -> Int {
        return MacTooltipType.allCases.count
    }

    /// Mark all tips as viewed (for "Mark All as Viewed" feature)
    func markAllAsViewed() {
        var shownTooltips = userDefaults.stringArray(forKey: shownTooltipsKey) ?? []
        for tip in MacTooltipType.allCases {
            if !shownTooltips.contains(tip.rawValue) {
                shownTooltips.append(tip.rawValue)
            }
        }
        userDefaults.set(shownTooltips, forKey: shownTooltipsKey)
        objectWillChange.send()
    }
}
