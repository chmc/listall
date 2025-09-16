//
//  DataRepository.swift
//  ListAll
//
//  Created by Sutela Aleksi on 15.9.2025.
//

import Foundation

class DataRepository: ObservableObject {
    private let dataManager = DataManager.shared
    
    // MARK: - List Operations
    
    func createList(name: String) -> List {
        let newList = List(name: name)
        dataManager.addList(newList)
        return newList
    }
    
    func deleteList(_ list: List) {
        dataManager.deleteList(withId: list.id)
    }
    
    func updateList(_ list: List, name: String) {
        var updatedList = list
        updatedList.name = name
        updatedList.updateModifiedDate()
        dataManager.updateList(updatedList)
    }
    
    func getAllLists() -> [List] {
        return dataManager.lists
    }
    
    // MARK: - Item Operations
    
    func createItem(in list: List, title: String, description: String = "", quantity: Int = 1) -> Item {
        var newItem = Item(title: title)
        newItem.itemDescription = description.isEmpty ? nil : description
        newItem.quantity = quantity
        newItem.listId = list.id
        dataManager.addItem(newItem, to: list.id)
        return newItem
    }
    
    func deleteItem(_ item: Item) {
        if let listId = item.listId {
            dataManager.deleteItem(withId: item.id, from: listId)
        }
    }
    
    func updateItem(_ item: Item, title: String, description: String, quantity: Int) {
        var updatedItem = item
        updatedItem.title = title
        updatedItem.itemDescription = description.isEmpty ? nil : description
        updatedItem.quantity = quantity
        updatedItem.updateModifiedDate()
        dataManager.updateItem(updatedItem)
    }
    
    func toggleItemCrossedOut(_ item: Item) {
        var updatedItem = item
        updatedItem.toggleCrossedOut()
        dataManager.updateItem(updatedItem)
    }
    
    func getItems(for list: List) -> [Item] {
        return list.sortedItems
    }
}