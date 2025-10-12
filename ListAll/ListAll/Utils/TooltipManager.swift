//
//  TooltipManager.swift
//  ListAll
//
//  Created by AI Assistant on 10/12/25.
//  Manages contextual tooltip display and completion tracking
//

import Foundation

/// Enum representing all available tooltips in the app
enum TooltipType: String, CaseIterable {
    case addListButton = "tooltip_add_list"
    case itemSuggestions = "tooltip_item_suggestions"
    case searchFunctionality = "tooltip_search"
    case sortFilterOptions = "tooltip_sort_filter"
    case swipeActions = "tooltip_swipe_actions"
    case archiveFunctionality = "tooltip_archive"
    
    var title: String {
        switch self {
        case .addListButton:
            return "Create Lists"
        case .itemSuggestions:
            return "Smart Suggestions"
        case .searchFunctionality:
            return "Search Items"
        case .sortFilterOptions:
            return "Sort & Filter"
        case .swipeActions:
            return "Swipe Actions"
        case .archiveFunctionality:
            return "Archive Lists"
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
        case .swipeActions:
            return "hand.point.left.fill"
        case .archiveFunctionality:
            return "archivebox.fill"
        }
    }
    
    var message: String {
        switch self {
        case .addListButton:
            return "Tap + to create your first list"
        case .itemSuggestions:
            return "💡 Suggestions appear based on your previous items"
        case .searchFunctionality:
            return "Search across all items in this list"
        case .sortFilterOptions:
            return "Sort and filter items to organize your view"
        case .swipeActions:
            return "Swipe left on items for quick actions like delete and duplicate"
        case .archiveFunctionality:
            return "Archive completed lists to keep your workspace clean"
        }
    }
    
    var dismissAfterSeconds: TimeInterval? {
        // Auto-dismiss most tooltips after 8 seconds
        // Return nil for tooltips that should only be manually dismissed
        switch self {
        case .addListButton, .itemSuggestions, .swipeActions:
            return 8.0
        case .searchFunctionality, .sortFilterOptions, .archiveFunctionality:
            return 10.0
        }
    }
}

/// Manager for contextual tooltips throughout the app
class TooltipManager: ObservableObject {
    static let shared = TooltipManager()
    
    @Published var currentTooltip: TooltipType?
    @Published var isShowingTooltip = false
    
    private let userDefaults = UserDefaults.standard
    private let shownTooltipsKey = "shownTooltips"
    
    private init() {}
    
    /// Check if a tooltip has been shown before
    func hasShown(_ type: TooltipType) -> Bool {
        let shownTooltips = userDefaults.stringArray(forKey: shownTooltipsKey) ?? []
        return shownTooltips.contains(type.rawValue)
    }
    
    /// Mark a tooltip as shown
    func markAsShown(_ type: TooltipType) {
        var shownTooltips = userDefaults.stringArray(forKey: shownTooltipsKey) ?? []
        if !shownTooltips.contains(type.rawValue) {
            shownTooltips.append(type.rawValue)
            userDefaults.set(shownTooltips, forKey: shownTooltipsKey)
        }
    }
    
    /// Show a tooltip if it hasn't been shown before
    /// Returns true if the tooltip will be shown, false if it has already been shown
    @discardableResult
    func showIfNeeded(_ type: TooltipType) -> Bool {
        // Don't show if already shown before
        guard !hasShown(type) else { return false }
        
        // Don't show if another tooltip is currently visible
        guard !isShowingTooltip else { return false }
        
        // Show the tooltip
        currentTooltip = type
        isShowingTooltip = true
        
        // Auto-dismiss if configured
        if let dismissDelay = type.dismissAfterSeconds {
            DispatchQueue.main.asyncAfter(deadline: .now() + dismissDelay) { [weak self] in
                self?.dismissCurrentTooltip()
            }
        }
        
        return true
    }
    
    /// Manually dismiss the current tooltip
    func dismissCurrentTooltip() {
        guard let tooltip = currentTooltip else { return }
        
        // Mark as shown
        markAsShown(tooltip)
        
        // Clear current state
        isShowingTooltip = false
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
            self?.currentTooltip = nil
        }
    }
    
    /// Reset all tooltips (for "Show All Tips" feature)
    func resetAllTooltips() {
        userDefaults.removeObject(forKey: shownTooltipsKey)
        currentTooltip = nil
        isShowingTooltip = false
    }
    
    /// Get the count of tooltips that have been shown
    func shownTooltipCount() -> Int {
        let shownTooltips = userDefaults.stringArray(forKey: shownTooltipsKey) ?? []
        return shownTooltips.count
    }
    
    /// Get the total count of available tooltips
    func totalTooltipCount() -> Int {
        return TooltipType.allCases.count
    }
}

