//
//  ListViewModel.swift
//  ListAll
//
//  Created by Sutela Aleksi on 15.9.2025.
//

import Foundation
import CoreData
import SwiftUI

class ListViewModel: ObservableObject {
    @Published var items: [Item] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    private let coreDataManager = CoreDataManager.shared
    private let viewContext: NSManagedObjectContext
    private let list: List
    
    init(list: List) {
        self.list = list
        self.viewContext = coreDataManager.container.viewContext
        loadItems()
    }
    
    func loadItems() {
        isLoading = true
        errorMessage = nil
        
        let request = NSFetchRequest<Item>(entityName: "Item")
        request.predicate = NSPredicate(format: "list == %@", list)
        request.sortDescriptors = [NSSortDescriptor(keyPath: \Item.orderNumber, ascending: true)]
        
        do {
            items = try viewContext.fetch(request)
        } catch {
            errorMessage = "Failed to load items: \(error.localizedDescription)"
        }
        
        isLoading = false
    }
    
    func save() {
        coreDataManager.save()
    }
}
