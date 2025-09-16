//
//  ItemViewModel.swift
//  ListAll
//
//  Created by Sutela Aleksi on 15.9.2025.
//

import Foundation
import CoreData
import SwiftUI

class ItemViewModel: ObservableObject {
    @Published var item: Item
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    private let coreDataManager = CoreDataManager.shared
    private let viewContext: NSManagedObjectContext
    
    init(item: Item) {
        self.item = item
        self.viewContext = coreDataManager.container.viewContext
    }
    
    func save() {
        coreDataManager.save()
    }
    
    func toggleCrossedOut() {
        item.isCrossedOut.toggle()
        item.modifiedAt = Date()
        save()
    }
}
