//
//  MainViewModel.swift
//  ListAll
//
//  Created by Sutela Aleksi on 15.9.2025.
//

import Foundation
import CoreData
import SwiftUI

class MainViewModel: ObservableObject {
    @Published var lists: [List] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    private let coreDataManager = CoreDataManager.shared
    private let viewContext: NSManagedObjectContext
    
    init() {
        self.viewContext = coreDataManager.container.viewContext
        loadLists()
    }
    
    func loadLists() {
        isLoading = true
        errorMessage = nil
        
        let request = NSFetchRequest<List>(entityName: "List")
        request.sortDescriptors = [NSSortDescriptor(keyPath: \List.orderNumber, ascending: true)]
        
        do {
            lists = try viewContext.fetch(request)
        } catch {
            errorMessage = "Failed to load lists: \(error.localizedDescription)"
        }
        
        isLoading = false
    }
    
    func save() {
        coreDataManager.save()
    }
}
