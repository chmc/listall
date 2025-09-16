//
//  CoreDataManager.swift
//  ListAll
//
//  Created by Sutela Aleksi on 15.9.2025.
//

import Foundation
import CloudKit

// MARK: - Data Manager
class DataManager: ObservableObject {
    static let shared = DataManager()
    
    @Published var lists: [List] = []
    
    private init() {
        loadData()
    }
    
    // MARK: - Data Operations
    
    func loadData() {
        // For now, load sample data
        // In the future, this will load from Core Data + CloudKit
        if lists.isEmpty {
            createSampleData()
        }
    }
    
    func saveData() {
        // For now, just save to UserDefaults as a temporary solution
        // In the future, this will save to Core Data + CloudKit
        if let encoded = try? JSONEncoder().encode(lists) {
            UserDefaults.standard.set(encoded, forKey: "saved_lists")
        }
    }
    
    // MARK: - List Operations
    
    func addList(_ list: List) {
        lists.append(list)
        saveData()
    }
    
    func updateList(_ list: List) {
        if let index = lists.firstIndex(where: { $0.id == list.id }) {
            lists[index] = list
            saveData()
        }
    }
    
    func deleteList(withId id: UUID) {
        lists.removeAll { $0.id == id }
        saveData()
    }
    
    // MARK: - Item Operations
    
    func addItem(_ item: Item, to listId: UUID) {
        if let index = lists.firstIndex(where: { $0.id == listId }) {
            lists[index].addItem(item)
            saveData()
        }
    }
    
    func updateItem(_ item: Item) {
        if let listIndex = lists.firstIndex(where: { $0.id == item.listId }) {
            lists[listIndex].updateItem(item)
            saveData()
        }
    }
    
    func deleteItem(withId id: UUID, from listId: UUID) {
        if let listIndex = lists.firstIndex(where: { $0.id == listId }) {
            lists[listIndex].removeItem(withId: id)
            saveData()
        }
    }
    
    func getItems(forListId listId: UUID) -> [Item] {
        if let list = lists.first(where: { $0.id == listId }) {
            return list.items
        }
        return []
    }
    
    // MARK: - Sample Data
    
    private func createSampleData() {
        let sampleList1 = List(name: "Grocery Shopping")
        let sampleList2 = List(name: "Home Improvement")
        
        var list1 = sampleList1
        list1.addItem(Item(title: "Milk"))
        list1.addItem(Item(title: "Bread"))
        list1.addItem(Item(title: "Eggs"))
        
        var list2 = sampleList2
        list2.addItem(Item(title: "Paint"))
        list2.addItem(Item(title: "Brushes"))
        
        lists = [list1, list2]
        saveData()
    }
    
    // MARK: - CloudKit Status (Placeholder)
    
    func checkCloudKitStatus() async -> CKAccountStatus {
        return await withCheckedContinuation { continuation in
            CKContainer.default().accountStatus { status, error in
                if let error = error {
                    print("CloudKit account status error: \(error)")
                }
                continuation.resume(returning: status)
            }
        }
    }
}