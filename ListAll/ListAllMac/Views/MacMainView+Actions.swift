//
//  MacMainView+Actions.swift
//  ListAllMac
//
//  CRUD actions for MacMainView (create, delete, duplicate lists; update items).
//

import SwiftUI

extension MacMainView {
    func createList(name: String) {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else { return }

        let newList = List(name: trimmedName)
        dataManager.addList(newList)
        dataManager.loadData()

        // Select the newly created list
        if let createdList = dataManager.lists.first(where: { $0.name == trimmedName }) {
            selectedList = createdList
        }
    }

    func createSampleList(from template: SampleDataService.SampleListTemplate) {
        // Use SampleDataService to create and populate the list
        let createdList = SampleDataService.saveTemplateList(template, using: dataManager)

        // Select the newly created list
        selectedList = createdList
    }

    func deleteList(_ list: List) {
        if selectedList?.id == list.id {
            selectedList = nil
        }
        dataManager.deleteList(withId: list.id)
        dataManager.loadData()
    }

    // MARK: - Duplicate List (Task 16.9)
    /// Duplicates a list and all its items
    func duplicateList(_ list: List) {
        // Generate duplicate name
        let baseName = list.name
        var duplicateNumber = 1
        var candidateName = "\(baseName) Copy"

        // Check if a list with this name already exists
        while dataManager.lists.contains(where: { $0.name == candidateName }) {
            duplicateNumber += 1
            candidateName = "\(baseName) Copy \(duplicateNumber)"
        }

        // Create new list with duplicate name
        var duplicatedList = List(name: candidateName)
        duplicatedList.orderNumber = (dataManager.lists.map { $0.orderNumber }.max() ?? -1) + 1

        // Get items from the original list
        let originalItems = dataManager.getItems(forListId: list.id)

        // Add the duplicated list first
        dataManager.addList(duplicatedList)

        // Duplicate all items from the original list
        for originalItem in originalItems {
            var duplicatedItem = originalItem
            duplicatedItem.id = UUID()
            duplicatedItem.listId = duplicatedList.id
            duplicatedItem.createdAt = Date()
            duplicatedItem.modifiedAt = Date()
            dataManager.addItem(duplicatedItem, to: duplicatedList.id)
        }

        // Refresh data to show the new list
        dataManager.loadData()

        // Select the new duplicated list
        selectedList = dataManager.lists.first { $0.name == candidateName }
    }

    /// Update an item from the edit sheet (called from MacMainView-level sheet)
    func updateEditedItem(_ item: Item, title: String, quantity: Int, description: String?, images: [ItemImage]? = nil) {
        var updatedItem = item
        updatedItem.title = title
        updatedItem.quantity = quantity
        updatedItem.itemDescription = description
        if let images = images {
            updatedItem.images = images
        }
        updatedItem.modifiedAt = Date()
        dataManager.updateItem(updatedItem)
    }
}
