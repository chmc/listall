//
//  MainViewModel.swift
//  ListAll
//
//  Created by Sutela Aleksi on 15.9.2025.
//

import Foundation
import SwiftUI

class MainViewModel: ObservableObject {
    @Published var lists: [List] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    private let dataManager = DataManager.shared
    
    init() {
        loadLists()
    }
    
    func loadLists() {
        isLoading = true
        errorMessage = nil
        
        // Get lists from DataManager
        lists = dataManager.lists.sorted { $0.orderNumber < $1.orderNumber }
        
        isLoading = false
    }
    
    func addList(name: String) {
        let newList = List(name: name)
        dataManager.addList(newList)
        lists.append(newList)
    }
    
    func deleteList(_ list: List) {
        dataManager.deleteList(withId: list.id)
        lists.removeAll { $0.id == list.id }
    }
    
    func updateList(_ list: List, name: String) {
        var updatedList = list
        updatedList.name = name
        updatedList.updateModifiedDate()
        dataManager.updateList(updatedList)
        if let index = lists.firstIndex(where: { $0.id == list.id }) {
            lists[index] = updatedList
        }
    }
}