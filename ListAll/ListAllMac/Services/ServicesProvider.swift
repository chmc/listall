//
//  ServicesProvider.swift
//  ListAllMac
//
//  Handles macOS Services menu integration for creating items from selected text.
//

import AppKit
import Foundation

/// Provides macOS system-wide services for ListAll.
/// This class handles text selected in other applications and creates items/lists from it.
///
/// Services appear in the Services menu (right-click context menu) when text is selected
/// in any macOS application. Users can add selected text as items to ListAll.
///
/// CRITICAL: Only ONE service provider can be registered per app.
/// All service methods must be marked @objc and have the exact signature:
/// `(NSPasteboard, String?, AutoreleasingUnsafeMutablePointer<NSString>) -> Void`
class ServicesProvider: NSObject {

    // MARK: - Singleton

    /// Shared instance for services provider
    static let shared = ServicesProvider()

    // MARK: - User Defaults Keys

    /// Key for storing the default list ID for services
    private static let defaultListIdKey = "ServicesDefaultListId"

    /// Key for storing whether to show notifications after adding items
    private static let showNotificationsKey = "ServicesShowNotifications"

    /// Key for storing whether to bring app to front after adding items
    private static let bringToFrontKey = "ServicesBringToFront"

    // MARK: - Configuration Properties

    /// Get or set the default list ID for services
    var defaultListId: UUID? {
        get {
            guard let uuidString = UserDefaults.standard.string(forKey: Self.defaultListIdKey),
                  let uuid = UUID(uuidString: uuidString) else {
                return nil
            }
            return uuid
        }
        set {
            if let uuid = newValue {
                UserDefaults.standard.set(uuid.uuidString, forKey: Self.defaultListIdKey)
            } else {
                UserDefaults.standard.removeObject(forKey: Self.defaultListIdKey)
            }
        }
    }

    /// Whether to show notifications after adding items via services
    var showNotifications: Bool {
        get { UserDefaults.standard.bool(forKey: Self.showNotificationsKey) }
        set { UserDefaults.standard.set(newValue, forKey: Self.showNotificationsKey) }
    }

    /// Whether to bring the app to front after adding items
    var bringToFront: Bool {
        get {
            // Default to true if not set
            if UserDefaults.standard.object(forKey: Self.bringToFrontKey) == nil {
                return true
            }
            return UserDefaults.standard.bool(forKey: Self.bringToFrontKey)
        }
        set { UserDefaults.standard.set(newValue, forKey: Self.bringToFrontKey) }
    }

    // MARK: - Initialization

    override init() {
        super.init()
        print("📋 ServicesProvider: Initialized")
    }

    // MARK: - Service Methods

    /// Creates a single item from the selected text.
    /// This service appears as "Add to ListAll" in the Services menu.
    ///
    /// Method signature requirements:
    /// - Must be @objc for Objective-C runtime dispatch
    /// - Must accept NSPasteboard, userData, and error pointer
    /// - Method name must match NSMessage in Info.plist (without colons)
    @objc func createItemFromText(
        _ pasteboard: NSPasteboard,
        userData: String?,
        error: AutoreleasingUnsafeMutablePointer<NSString>
    ) {
        print("📋 Services: createItemFromText called")

        // Extract text from pasteboard
        guard let text = pasteboard.string(forType: .string) else {
            error.pointee = "No text found on pasteboard" as NSString
            print("⚠️ Services: No text found on pasteboard")
            return
        }

        let trimmedText = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedText.isEmpty else {
            error.pointee = "Text is empty" as NSString
            print("⚠️ Services: Text is empty after trimming")
            return
        }

        print("📋 Services: Creating item from text: '\(trimmedText.prefix(50))...'")

        // CRITICAL: Dispatch to main thread for UI/Core Data operations
        DispatchQueue.main.async { [weak self] in
            self?.addItemToList(title: trimmedText)
        }
    }

    /// Creates multiple items from lines of selected text.
    /// This service appears as "Add Lines to ListAll" in the Services menu.
    /// Each non-empty line becomes a separate item.
    @objc func createItemsFromLines(
        _ pasteboard: NSPasteboard,
        userData: String?,
        error: AutoreleasingUnsafeMutablePointer<NSString>
    ) {
        print("📋 Services: createItemsFromLines called")

        // Extract text from pasteboard
        guard let text = pasteboard.string(forType: .string) else {
            error.pointee = "No text found on pasteboard" as NSString
            print("⚠️ Services: No text found on pasteboard")
            return
        }

        // Split into lines and filter empty ones
        let lines = Self.parseTextIntoItems(text)

        guard !lines.isEmpty else {
            error.pointee = "No valid lines found in text" as NSString
            print("⚠️ Services: No valid lines found")
            return
        }

        print("📋 Services: Creating \(lines.count) items from lines")

        // CRITICAL: Dispatch to main thread for UI/Core Data operations
        DispatchQueue.main.async { [weak self] in
            self?.addItemsToList(titles: lines)
        }
    }

    /// Creates a new list with the selected text as the name, optionally with items.
    /// This service appears as "Create ListAll List" in the Services menu.
    @objc func createListFromText(
        _ pasteboard: NSPasteboard,
        userData: String?,
        error: AutoreleasingUnsafeMutablePointer<NSString>
    ) {
        print("📋 Services: createListFromText called")

        // Extract text from pasteboard
        guard let text = pasteboard.string(forType: .string) else {
            error.pointee = "No text found on pasteboard" as NSString
            print("⚠️ Services: No text found on pasteboard")
            return
        }

        let trimmedText = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedText.isEmpty else {
            error.pointee = "Text is empty" as NSString
            print("⚠️ Services: Text is empty after trimming")
            return
        }

        // Parse text: first line is list name, remaining lines are items
        let lines = trimmedText.components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }

        let listName = lines.first ?? "New List"
        let itemTitles = lines.count > 1 ? Self.parseTextIntoItems(lines.dropFirst().joined(separator: "\n")) : []

        print("📋 Services: Creating list '\(listName)' with \(itemTitles.count) items")

        // CRITICAL: Dispatch to main thread for UI/Core Data operations
        DispatchQueue.main.async { [weak self] in
            self?.createNewList(name: listName, items: itemTitles)
        }
    }

    // MARK: - Text Parsing

    /// Parses text into item titles, handling bullet points, numbers, and formatting
    /// - Parameter text: Raw text to parse
    /// - Returns: Array of cleaned item titles
    static func parseTextIntoItems(_ text: String) -> [String] {
        return text.components(separatedBy: .newlines)
            .map { line in
                var cleaned = line.trimmingCharacters(in: .whitespacesAndNewlines)

                // Remove common bullet point prefixes
                let bulletPrefixes = ["•", "-", "*", "✓", "✔", "☐", "☑", "▪", "▸", "→"]
                for prefix in bulletPrefixes {
                    if cleaned.hasPrefix(prefix) {
                        cleaned = String(cleaned.dropFirst(prefix.count))
                            .trimmingCharacters(in: .whitespacesAndNewlines)
                        break
                    }
                }

                // Remove numbered list prefixes (1., 2), 1:, etc.)
                if let match = cleaned.firstMatch(of: /^\d+[\.\)\:]?\s*/) {
                    cleaned = String(cleaned[match.range.upperBound...])
                        .trimmingCharacters(in: .whitespacesAndNewlines)
                }

                // Remove checkbox prefixes [ ], [x], [X]
                if let match = cleaned.firstMatch(of: /^\[[ xX✓]?\]\s*/) {
                    cleaned = String(cleaned[match.range.upperBound...])
                        .trimmingCharacters(in: .whitespacesAndNewlines)
                }

                return cleaned
            }
            .filter { !$0.isEmpty }
    }

    // MARK: - Data Operations

    /// Adds a single item to the target list
    private func addItemToList(title: String) {
        let dataManager = DataManager.shared

        // Ensure data is loaded
        dataManager.loadData()

        guard let targetList = getTargetList(dataManager: dataManager) else {
            showNoListAlert()
            return
        }

        // Create and add the item
        var newItem = Item(title: title)
        newItem.listId = targetList.id

        // Get next order number
        let existingItems = dataManager.getItems(forListId: targetList.id)
        let maxOrderNumber = existingItems.map { $0.orderNumber }.max() ?? -1
        newItem.orderNumber = maxOrderNumber + 1

        dataManager.addItem(newItem, to: targetList.id)
        dataManager.loadData() // Refresh UI

        print("✅ Services: Added item '\(title.prefix(30))...' to list '\(targetList.name)'")

        // Post-add actions
        performPostAddActions(message: "Added to \(targetList.name)", detail: title)
    }

    /// Adds multiple items to the target list
    private func addItemsToList(titles: [String]) {
        let dataManager = DataManager.shared

        // Ensure data is loaded
        dataManager.loadData()

        guard let targetList = getTargetList(dataManager: dataManager) else {
            showNoListAlert()
            return
        }

        // Get starting order number
        let existingItems = dataManager.getItems(forListId: targetList.id)
        var nextOrderNumber = (existingItems.map { $0.orderNumber }.max() ?? -1) + 1

        // Add each item
        for title in titles {
            var newItem = Item(title: title)
            newItem.listId = targetList.id
            newItem.orderNumber = nextOrderNumber
            nextOrderNumber += 1

            dataManager.addItem(newItem, to: targetList.id)
        }

        dataManager.loadData() // Refresh UI once after all items added

        print("✅ Services: Added \(titles.count) items to list '\(targetList.name)'")

        // Post-add actions
        performPostAddActions(message: "Added to \(targetList.name)", detail: "\(titles.count) items")
    }

    /// Creates a new list with optional items
    private func createNewList(name: String, items: [String]) {
        let dataManager = DataManager.shared

        // Ensure data is loaded
        dataManager.loadData()

        // Create the list
        let newList = List(name: name)
        dataManager.addList(newList)

        // Add items if any
        var nextOrderNumber = 0
        for title in items {
            var newItem = Item(title: title)
            newItem.listId = newList.id
            newItem.orderNumber = nextOrderNumber
            nextOrderNumber += 1

            dataManager.addItem(newItem, to: newList.id)
        }

        dataManager.loadData() // Refresh UI

        print("✅ Services: Created list '\(name)' with \(items.count) items")

        // Post-add actions
        let detail = items.isEmpty ? "Empty list created" : "\(items.count) items added"
        performPostAddActions(message: "Created \(name)", detail: detail)
    }

    // MARK: - Helper Methods

    /// Returns the target list for adding items.
    /// Priority: 1) User-configured default list, 2) First non-archived list
    private func getTargetList(dataManager: DataManager) -> List? {
        let activeLists = dataManager.lists.filter { !$0.isArchived }

        // Try to use configured default list
        if let defaultId = defaultListId,
           let defaultList = activeLists.first(where: { $0.id == defaultId }) {
            return defaultList
        }

        // Fall back to first non-archived list (sorted by orderNumber)
        return activeLists.sorted { $0.orderNumber < $1.orderNumber }.first
    }

    /// Performs post-add actions like notifications and bringing app to front
    private func performPostAddActions(message: String, detail: String) {
        // Bring app to front if configured
        if bringToFront {
            NSApp.activate(ignoringOtherApps: true)
        }

        // Show notification if configured
        if showNotifications {
            showNotification(title: message, body: detail)
        }
    }

    /// Shows a macOS notification using UserNotifications framework
    private func showNotification(title: String, body: String) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: nil // Deliver immediately
        )

        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("⚠️ Services: Failed to show notification: \(error)")
            }
        }
    }

    /// Shows an alert when no list is available
    private func showNoListAlert() {
        let alert = NSAlert()
        alert.messageText = "No List Available"
        alert.informativeText = "Please create a list in ListAll before using this service."
        alert.alertStyle = .warning
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }
}

// MARK: - UserNotifications Import

import UserNotifications
