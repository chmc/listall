import Foundation
#if os(iOS)
import UIKit
#elseif os(macOS)
import AppKit
#endif

/// HandoffService manages NSUserActivity for seamless Handoff between iOS and macOS.
///
/// **What is Handoff?**
/// Handoff allows users to start an activity on one Apple device and continue it on another.
/// For example, a user viewing a list on their iPhone can pick up their Mac and continue
/// working with the same list immediately.
///
/// **Requirements:**
/// - Same iCloud account signed in on both devices
/// - Bluetooth and Wi-Fi enabled on both devices
/// - Handoff enabled in System Settings
/// - Same bundle identifier on both platforms
///
/// **Usage:**
/// ```swift
/// // Start an activity when user views a list
/// HandoffService.shared.startViewingListActivity(list: myList)
///
/// // Invalidate when user navigates away
/// HandoffService.shared.invalidateCurrentActivity()
///
/// // Handle incoming activity (in App/Scene delegate)
/// if let target = HandoffService.extractNavigationTarget(from: activity) {
///     switch target {
///     case .list(let id, _):
///         // Navigate to list with id
///     case .item(let itemId, let listId, _):
///         // Navigate to item
///     case .mainLists:
///         // Show main lists view
///     }
/// }
/// ```
@MainActor
class HandoffService {

    // MARK: - Singleton

    static let shared = HandoffService()

    // MARK: - Activity Types

    /// Activity type for browsing the main lists view
    nonisolated static let browsingListsActivityType = "io.github.chmc.ListAll.browsing-lists"

    /// Activity type for viewing a specific list
    nonisolated static let viewingListActivityType = "io.github.chmc.ListAll.viewing-list"

    /// Activity type for viewing a specific item detail
    nonisolated static let viewingItemActivityType = "io.github.chmc.ListAll.viewing-item"

    // MARK: - UserInfo Keys

    /// Key for list UUID string in userInfo dictionary
    nonisolated static let listIdKey = "listId"

    /// Key for item UUID string in userInfo dictionary
    nonisolated static let itemIdKey = "itemId"

    /// Key for list name string in userInfo dictionary
    nonisolated static let listNameKey = "listName"

    /// Key for item title string in userInfo dictionary
    nonisolated static let itemTitleKey = "itemTitle"

    // MARK: - Properties

    /// The current active NSUserActivity (weak to avoid retain cycles)
    private weak var currentActivity: NSUserActivity?

    // MARK: - Initialization

    private init() {
        // Private initializer for singleton
    }

    // MARK: - Public API

    /// Start a Handoff activity for browsing the main lists view
    func startBrowsingListsActivity() {
        invalidateCurrentActivity()

        let activity = NSUserActivity(activityType: Self.browsingListsActivityType)
        activity.title = "Browsing Lists"
        activity.isEligibleForHandoff = true
        activity.needsSave = true

        setCurrentActivity(activity)
    }

    /// Start a Handoff activity for viewing a specific list
    /// - Parameter list: The list being viewed
    func startViewingListActivity(list: List) {
        invalidateCurrentActivity()

        let activity = NSUserActivity(activityType: Self.viewingListActivityType)
        activity.title = "Viewing \(list.name)"
        activity.isEligibleForHandoff = true
        activity.userInfo = [
            Self.listIdKey: list.id.uuidString,
            Self.listNameKey: list.name
        ]
        activity.needsSave = true

        setCurrentActivity(activity)
    }

    /// Start a Handoff activity for viewing a specific item detail
    /// - Parameters:
    ///   - item: The item being viewed
    ///   - list: The list containing the item
    func startViewingItemActivity(item: Item, inList list: List) {
        invalidateCurrentActivity()

        let activity = NSUserActivity(activityType: Self.viewingItemActivityType)
        activity.title = "Viewing \(item.title)"
        activity.isEligibleForHandoff = true
        activity.userInfo = [
            Self.itemIdKey: item.id.uuidString,
            Self.listIdKey: list.id.uuidString,
            Self.itemTitleKey: item.title,
            Self.listNameKey: list.name
        ]
        activity.needsSave = true

        setCurrentActivity(activity)
    }

    /// Invalidate the current Handoff activity
    func invalidateCurrentActivity() {
        currentActivity?.invalidate()
        currentActivity = nil
    }

    // MARK: - Activity Continuation

    /// Navigation target extracted from an incoming NSUserActivity
    enum NavigationTarget {
        /// Navigate to main lists view
        case mainLists

        /// Navigate to a specific list
        /// - Parameters:
        ///   - id: UUID of the list
        ///   - name: Optional name of the list for display purposes
        case list(id: UUID, name: String?)

        /// Navigate to a specific item detail
        /// - Parameters:
        ///   - id: UUID of the item
        ///   - listId: UUID of the containing list
        ///   - title: Optional title of the item for display purposes
        case item(id: UUID, listId: UUID, title: String?)
    }

    /// Extract navigation target from an incoming NSUserActivity
    /// - Parameter activity: The NSUserActivity to parse
    /// - Returns: NavigationTarget if the activity is recognized, nil otherwise
    /// - Note: This method is nonisolated because it only reads static constants and doesn't access mutable state
    nonisolated static func extractNavigationTarget(from activity: NSUserActivity) -> NavigationTarget? {
        switch activity.activityType {
        case browsingListsActivityType:
            return .mainLists

        case viewingListActivityType:
            guard let userInfo = activity.userInfo,
                  let listIdString = userInfo[listIdKey] as? String,
                  let listId = UUID(uuidString: listIdString) else {
                return nil
            }
            let listName = userInfo[listNameKey] as? String
            return .list(id: listId, name: listName)

        case viewingItemActivityType:
            guard let userInfo = activity.userInfo,
                  let itemIdString = userInfo[itemIdKey] as? String,
                  let itemId = UUID(uuidString: itemIdString),
                  let listIdString = userInfo[listIdKey] as? String,
                  let listId = UUID(uuidString: listIdString) else {
                return nil
            }
            let itemTitle = userInfo[itemTitleKey] as? String
            return .item(id: itemId, listId: listId, title: itemTitle)

        default:
            return nil
        }
    }

    // MARK: - Private Helpers

    /// Set the current activity and make it the user activity for the app
    /// - Parameter activity: The NSUserActivity to set as current
    private func setCurrentActivity(_ activity: NSUserActivity) {
        currentActivity = activity

        #if os(iOS)
        // On iOS, set the user activity on the current scene
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene {
            windowScene.userActivity = activity
        }
        #elseif os(macOS)
        // On macOS, set the user activity on the main window
        if let window = NSApplication.shared.mainWindow {
            window.userActivity = activity
        }
        #endif
    }
}

// MARK: - Equatable Support for NavigationTarget

extension HandoffService.NavigationTarget: Equatable {
    static func == (lhs: HandoffService.NavigationTarget, rhs: HandoffService.NavigationTarget) -> Bool {
        switch (lhs, rhs) {
        case (.mainLists, .mainLists):
            return true
        case (.list(let lhsId, _), .list(let rhsId, _)):
            return lhsId == rhsId
        case (.item(let lhsId, let lhsListId, _), .item(let rhsId, let rhsListId, _)):
            return lhsId == rhsId && lhsListId == rhsListId
        default:
            return false
        }
    }
}

// MARK: - CustomStringConvertible Support for NavigationTarget

extension HandoffService.NavigationTarget: CustomStringConvertible {
    var description: String {
        switch self {
        case .mainLists:
            return "MainLists"
        case .list(let id, let name):
            if let name = name {
                return "List(\(id), \"\(name)\")"
            }
            return "List(\(id))"
        case .item(let id, let listId, let title):
            if let title = title {
                return "Item(\(id), listId: \(listId), \"\(title)\")"
            }
            return "Item(\(id), listId: \(listId))"
        }
    }
}
