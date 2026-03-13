//
//  TestMainViewModel.swift
//  ListAllMacTests
//
//  Test-specific MainViewModel extracted from TestHelpers.swift
//

import Foundation
import CoreData
@testable import ListAll

/// Test-specific MainViewModel that uses isolated DataManager
class TestMainViewModel: ObservableObject {
    @Published var lists: [ListModel] = []
    @Published var archivedLists: [ListModel] = []
    @Published var selectedLists: Set<UUID> = []
    @Published var isInSelectionMode = false

    // Archive notification properties
    @Published var recentlyArchivedList: ListModel?
    @Published var showArchivedNotification = false

    private let dataManager: TestDataManager
    private var archiveNotificationTimer: Timer?
    private let archiveNotificationTimeout: TimeInterval = 5.0

    init(dataManager: TestDataManager) {
        self.dataManager = dataManager
        loadLists()
    }

    deinit {
        archiveNotificationTimer?.invalidate()
    }

    private func loadLists() {
        // FIX: Sort by orderNumber to ensure correct ordering after reorder operations
        lists = dataManager.lists.sorted { $0.orderNumber < $1.orderNumber }
    }

    func loadArchivedLists() {
        // Load archived lists from the test data manager
        let request: NSFetchRequest<ListEntity> = ListEntity.fetchRequest()
        request.predicate = NSPredicate(format: "isArchived == YES")
        request.sortDescriptors = [NSSortDescriptor(keyPath: \ListEntity.modifiedAt, ascending: false)]

        do {
            let listEntities = try dataManager.coreDataManager.viewContext.fetch(request)
            archivedLists = listEntities.map { $0.toList() }
        } catch {
            print("Failed to fetch archived lists: \(error)")
            archivedLists = []
        }
    }

    func addList(name: String) throws {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !trimmedName.isEmpty else {
            throw ValidationError.emptyName
        }

        guard trimmedName.count <= 100 else {
            throw ValidationError.nameTooLong
        }

        let newList = ListAll.List(name: trimmedName)
        dataManager.addList(newList)

        // Refresh lists from dataManager (which already added the list)
        lists = dataManager.lists.sorted { $0.orderNumber < $1.orderNumber }
    }

    func updateList(_ list: ListModel, name: String) throws {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !trimmedName.isEmpty else {
            throw ValidationError.emptyName
        }

        guard trimmedName.count <= 100 else {
            throw ValidationError.nameTooLong
        }

        var updatedList = list
        updatedList.name = trimmedName
        updatedList.updateModifiedDate()
        dataManager.updateList(updatedList)
        if let index = lists.firstIndex(where: { $0.id == list.id }) {
            lists[index] = updatedList
        }
    }

    func deleteList(_ list: ListModel) {
        dataManager.deleteList(withId: list.id)
        lists.removeAll { $0.id == list.id }
    }

    func archiveList(_ list: ListModel) {
        // Archive the list (mark as archived in Core Data)
        let context = dataManager.coreDataManager.viewContext
        let request: NSFetchRequest<ListEntity> = ListEntity.fetchRequest()
        request.predicate = NSPredicate(format: "id == %@", list.id as CVarArg)

        do {
            let results = try context.fetch(request)
            if let listEntity = results.first {
                listEntity.isArchived = true
                listEntity.modifiedAt = Date()
                dataManager.saveData()
            }
        } catch {
            print("Failed to archive list: \(error)")
        }

        // Remove from active lists
        lists.removeAll { $0.id == list.id }

        // Show archive notification
        showArchiveNotification(for: list)
    }

    func restoreList(_ list: ListModel) {
        // Restore an archived list
        let context = dataManager.coreDataManager.viewContext
        let request: NSFetchRequest<ListEntity> = ListEntity.fetchRequest()
        request.predicate = NSPredicate(format: "id == %@", list.id as CVarArg)

        do {
            let results = try context.fetch(request)
            if let listEntity = results.first {
                listEntity.isArchived = false
                listEntity.modifiedAt = Date()
                dataManager.saveData()
                // Reload data to include the restored list
                dataManager.loadData()
            }
        } catch {
            print("Failed to restore list: \(error)")
        }

        // Remove from archived lists
        archivedLists.removeAll { $0.id == list.id }
        // Reload active lists
        lists = dataManager.lists.sorted { $0.orderNumber < $1.orderNumber }
    }

    func permanentlyDeleteList(_ list: ListModel) {
        // Permanently delete a list and all its associated items
        let context = dataManager.coreDataManager.viewContext
        let listRequest: NSFetchRequest<ListEntity> = ListEntity.fetchRequest()
        listRequest.predicate = NSPredicate(format: "id == %@", list.id as CVarArg)

        do {
            let results = try context.fetch(listRequest)
            if let listEntity = results.first {
                // Delete all items in the list first
                if let items = listEntity.items as? Set<ItemEntity> {
                    for itemEntity in items {
                        // Delete all images in the item
                        if let images = itemEntity.images as? Set<ItemImageEntity> {
                            for imageEntity in images {
                                context.delete(imageEntity)
                            }
                        }
                        // Delete the item
                        context.delete(itemEntity)
                    }
                }
                // Delete the list itself
                context.delete(listEntity)
                dataManager.saveData()
            }
        } catch {
            print("Failed to permanently delete list: \(error)")
        }

        // Remove from archived lists
        archivedLists.removeAll { $0.id == list.id }
    }

    private func showArchiveNotification(for list: ListModel) {
        // Cancel any existing timer
        archiveNotificationTimer?.invalidate()

        // Store the archived list
        recentlyArchivedList = list
        showArchivedNotification = true

        // Set up timer to hide notification after timeout
        archiveNotificationTimer = Timer.scheduledTimer(withTimeInterval: archiveNotificationTimeout, repeats: false) { [weak self] _ in
            self?.hideArchiveNotification()
        }
    }

    func undoArchive() {
        guard let list = recentlyArchivedList else { return }

        // Restore the list
        let context = dataManager.coreDataManager.viewContext
        let request: NSFetchRequest<ListEntity> = ListEntity.fetchRequest()
        request.predicate = NSPredicate(format: "id == %@", list.id as CVarArg)

        do {
            let results = try context.fetch(request)
            if let listEntity = results.first {
                listEntity.isArchived = false
                listEntity.modifiedAt = Date()
                dataManager.saveData()
                dataManager.loadData()
            }
        } catch {
            print("Failed to undo archive: \(error)")
        }

        // Hide notification immediately BEFORE reloading lists
        hideArchiveNotification()

        // Reload active lists to include restored list
        lists = dataManager.lists.sorted { $0.orderNumber < $1.orderNumber }
    }

    private func hideArchiveNotification() {
        archiveNotificationTimer?.invalidate()
        archiveNotificationTimer = nil
        showArchivedNotification = false
        recentlyArchivedList = nil
    }

    func duplicateList(_ list: ListModel) throws {
        // Create a duplicate name with "Copy" suffix
        let duplicateName = generateDuplicateName(for: list.name)

        guard duplicateName.count <= 100 else {
            throw ValidationError.nameTooLong
        }

        // Create new list with duplicate name
        let duplicatedList = ListAll.List(name: duplicateName)

        // Get items from the original list
        let originalItems = dataManager.getItems(forListId: list.id)

        // Add the duplicated list first
        dataManager.addList(duplicatedList)

        // Duplicate all items from the original list
        for originalItem in originalItems {
            var duplicatedItem = originalItem
            duplicatedItem.id = UUID() // Generate new ID
            duplicatedItem.listId = duplicatedList.id // Associate with new list
            duplicatedItem.createdAt = Date()
            duplicatedItem.modifiedAt = Date()

            dataManager.addItem(duplicatedItem, to: duplicatedList.id)
        }

        // Refresh lists from dataManager (which already added the list)
        lists = dataManager.lists.sorted { $0.orderNumber < $1.orderNumber }
    }

    private func generateDuplicateName(for originalName: String) -> String {
        let baseName = originalName
        var duplicateNumber = 1
        var candidateName = "\(baseName) Copy"

        // Check if a list with this name already exists
        while lists.contains(where: { $0.name == candidateName }) {
            duplicateNumber += 1
            candidateName = "\(baseName) Copy \(duplicateNumber)"
        }

        return candidateName
    }

    func moveList(from source: IndexSet, to destination: Int) {
        lists.move(fromOffsets: source, toOffset: destination)

        // Update order numbers AND modifiedAt for proper sync
        for (index, list) in lists.enumerated() {
            var updatedList = list
            let oldOrderNumber = updatedList.orderNumber
            updatedList.orderNumber = index
            // FIX: Only update modifiedAt for lists whose order actually changed
            if oldOrderNumber != index {
                updatedList.updateModifiedDate()
            }
            dataManager.updateList(updatedList)
            lists[index] = updatedList
        }
    }

    // MARK: - Multi-Selection Methods

    func toggleSelection(for listId: UUID) {
        if selectedLists.contains(listId) {
            selectedLists.remove(listId)
        } else {
            selectedLists.insert(listId)
        }
    }

    func selectAll() {
        selectedLists = Set(lists.map { $0.id })
    }

    func deselectAll() {
        selectedLists.removeAll()
    }

    func deleteSelectedLists() {
        for listId in selectedLists {
            dataManager.deleteList(withId: listId)
        }
        lists.removeAll { selectedLists.contains($0.id) }
        selectedLists.removeAll()
    }

    func enterSelectionMode() {
        isInSelectionMode = true
        selectedLists.removeAll()
    }

    func exitSelectionMode() {
        isInSelectionMode = false
        selectedLists.removeAll()
    }
}
