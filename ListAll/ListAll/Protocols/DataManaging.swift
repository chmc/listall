//
//  DataManaging.swift
//  ListAll
//
//  Protocol abstraction for DataManager to enable dependency injection and testing.
//

import Foundation
import Combine
import CloudKit

/// Protocol defining the interface for data management operations.
/// This abstraction allows tests to use mock implementations without triggering App Groups permission dialogs.
protocol DataManaging: AnyObject, ObservableObject {
    // MARK: - Properties

    /// All active (non-archived) lists
    var lists: [List] { get }

    /// Publisher for observing list changes
    var listsPublisher: AnyPublisher<[List], Never> { get }

    // MARK: - Data Loading

    /// Reload all lists from the persistent store
    func loadData()

    /// Get a fresh fetch of all active lists
    /// - Returns: Array of active lists
    func getLists() -> [List]

    /// Save the current state to the persistent store
    func saveData()

    // MARK: - List Operations

    /// Add a new list
    /// - Parameter list: The list to add
    func addList(_ list: List)

    /// Update an existing list
    /// - Parameter list: The list with updated properties
    func updateList(_ list: List)

    /// Archive (soft delete) a list
    /// - Parameter id: The ID of the list to archive
    func deleteList(withId id: UUID)

    /// Update the order of multiple lists
    /// - Parameter newOrder: The lists in their new order
    func updateListsOrder(_ newOrder: [List])

    /// Synchronize the internal lists array with the provided order
    /// - Parameter newOrder: The lists in their desired order
    func synchronizeLists(_ newOrder: [List])

    // MARK: - Archived Lists

    /// Load all archived lists
    /// - Returns: Array of archived lists
    func loadArchivedLists() -> [List]

    /// Restore a previously archived list
    /// - Parameter id: The ID of the list to restore
    func restoreList(withId id: UUID)

    /// Permanently delete a list (cannot be undone)
    /// - Parameter id: The ID of the list to permanently delete
    func permanentlyDeleteList(withId id: UUID)

    // MARK: - Item Operations

    /// Add an item to a specific list
    /// - Parameters:
    ///   - item: The item to add
    ///   - listId: The ID of the list to add the item to
    func addItem(_ item: Item, to listId: UUID)

    /// Update an existing item
    /// - Parameter item: The item with updated properties
    func updateItem(_ item: Item)

    /// Delete an item from a list
    /// - Parameters:
    ///   - id: The ID of the item to delete
    ///   - listId: The ID of the list containing the item
    func deleteItem(withId id: UUID, from listId: UUID)

    /// Get all items for a specific list
    /// - Parameter listId: The ID of the list
    /// - Returns: Array of items in the list
    func getItems(forListId listId: UUID) -> [Item]

    // MARK: - CloudKit

    /// Check the current iCloud account status
    /// - Returns: The current CloudKit account status
    func checkCloudKitStatus() async -> CKAccountStatus

    // MARK: - Data Cleanup

    /// Remove duplicate lists (CloudKit sync artifact cleanup)
    func removeDuplicateLists()

    /// Remove duplicate items (CloudKit sync artifact cleanup)
    func removeDuplicateItems()
}

// MARK: - Default Implementations

extension DataManaging {
    /// Default listsPublisher that returns empty publisher (override in concrete implementations)
    var listsPublisher: AnyPublisher<[List], Never> {
        Just([]).eraseToAnyPublisher()
    }

    /// Default implementation for duplicate removal
    func removeDuplicateLists() {
        // Default: no-op for test implementations
    }

    /// Default implementation for duplicate removal
    func removeDuplicateItems() {
        // Default: no-op for test implementations
    }
}
