import Foundation
import SwiftUI

enum ValidationError: LocalizedError {
    case emptyName
    case nameTooLong
    
    var errorDescription: String? {
        switch self {
        case .emptyName:
            return "Please enter a list name"
        case .nameTooLong:
            return "List name must be 100 characters or less"
        }
    }
}

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
    
    func addList(name: String) throws {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        
        guard !trimmedName.isEmpty else {
            throw ValidationError.emptyName
        }
        
        guard trimmedName.count <= 100 else {
            throw ValidationError.nameTooLong
        }
        
        let newList = List(name: trimmedName)
        dataManager.addList(newList)
        lists.append(newList)
        lists.sort { $0.orderNumber < $1.orderNumber }
    }
    
    func deleteList(_ list: List) {
        dataManager.deleteList(withId: list.id)
        lists.removeAll { $0.id == list.id }
    }
    
    func updateList(_ list: List, name: String) throws {
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
}