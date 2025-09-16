//
//  DataRepository.swift
//  ListAll
//
//  Created by Sutela Aleksi on 15.9.2025.
//

import Foundation
import CoreData

class DataRepository: ObservableObject {
    private let coreDataManager = CoreDataManager.shared
    private let viewContext: NSManagedObjectContext
    
    init() {
        self.viewContext = coreDataManager.container.viewContext
    }
    
    // MARK: - List Operations
    
    func createList(name: String) -> List {
        let newList = List(context: viewContext)
        newList.id = UUID()
        newList.name = name
        newList.orderNumber = Int32(Date().timeIntervalSince1970)
        newList.createdAt = Date()
        newList.modifiedAt = Date()
        
        save()
        return newList
    }
    
    func deleteList(_ list: List) {
        viewContext.delete(list)
        save()
    }
    
    func updateList(_ list: List, name: String) {
        list.name = name
        list.modifiedAt = Date()
        save()
    }
    
    // MARK: - Item Operations
    
    func createItem(in list: List, title: String, description: String = "", quantity: Int32 = 1) -> Item {
        let newItem = Item(context: viewContext)
        newItem.id = UUID()
        newItem.title = title
        newItem.itemDescription = description
        newItem.quantity = quantity
        newItem.orderNumber = Int32(Date().timeIntervalSince1970)
        newItem.isCrossedOut = false
        newItem.createdAt = Date()
        newItem.modifiedAt = Date()
        newItem.list = list
        
        save()
        return newItem
    }
    
    func deleteItem(_ item: Item) {
        viewContext.delete(item)
        save()
    }
    
    func updateItem(_ item: Item, title: String, description: String, quantity: Int32) {
        item.title = title
        item.itemDescription = description
        item.quantity = quantity
        item.modifiedAt = Date()
        save()
    }
    
    func toggleItemCrossedOut(_ item: Item) {
        item.isCrossedOut.toggle()
        item.modifiedAt = Date()
        save()
    }
    
    // MARK: - Private Methods
    
    private func save() {
        coreDataManager.save()
    }
}
