//
//  SuggestionService.swift
//  ListAll
//
//  Created by Sutela Aleksi on 15.9.2025.
//

import Foundation
import CoreData

class SuggestionService: ObservableObject {
    @Published var suggestions: [String] = []
    
    private let coreDataManager = CoreDataManager.shared
    private let viewContext: NSManagedObjectContext
    
    init() {
        self.viewContext = coreDataManager.container.viewContext
    }
    
    func getSuggestions(for searchText: String) {
        guard !searchText.isEmpty else {
            suggestions = []
            return
        }
        
        let request = NSFetchRequest<Item>(entityName: "Item")
        request.predicate = NSPredicate(format: "title CONTAINS[cd] %@", searchText)
        request.propertiesToFetch = ["title"]
        request.returnsDistinctResults = true
        request.fetchLimit = 10
        
        do {
            let items = try viewContext.fetch(request)
            suggestions = items.compactMap { $0.title }.filter { !$0.isEmpty }
        } catch {
            print("Failed to fetch suggestions: \(error)")
            suggestions = []
        }
    }
    
    func getRecentItems() -> [String] {
        let request = NSFetchRequest<Item>(entityName: "Item")
        request.sortDescriptors = [NSSortDescriptor(keyPath: \Item.createdAt, ascending: false)]
        request.fetchLimit = 20
        
        do {
            let items = try viewContext.fetch(request)
            return items.compactMap { $0.title }.filter { !$0.isEmpty }
        } catch {
            print("Failed to fetch recent items: \(error)")
            return []
        }
    }
}
