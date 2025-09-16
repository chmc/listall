//
//  ExportService.swift
//  ListAll
//
//  Created by Sutela Aleksi on 15.9.2025.
//

import Foundation
import CoreData

class ExportService: ObservableObject {
    private let coreDataManager = CoreDataManager.shared
    private let viewContext: NSManagedObjectContext
    
    init() {
        self.viewContext = coreDataManager.container.viewContext
    }
    
    func exportToJSON() -> Data? {
        let request = NSFetchRequest<List>(entityName: "List")
        request.relationshipKeyPathsForPrefetching = ["items", "items.images"]
        
        do {
            let lists = try viewContext.fetch(request)
            let exportData = ExportData(lists: lists.map { ListExportData(from: $0) })
            return try JSONEncoder().encode(exportData)
        } catch {
            print("Failed to export to JSON: \(error)")
            return nil
        }
    }
    
    func exportToCSV() -> String? {
        let request = NSFetchRequest<List>(entityName: "List")
        request.relationshipKeyPathsForPrefetching = ["items"]
        
        do {
            let lists = try viewContext.fetch(request)
            var csvContent = "List Name,Item Title,Description,Quantity,Crossed Out,Created Date\n"
            
            for list in lists {
                let items = list.items?.allObjects as? [Item] ?? []
                for item in items {
                    let row = [
                        list.name ?? "",
                        item.title ?? "",
                        item.itemDescription ?? "",
                        String(item.quantity),
                        item.isCrossedOut ? "Yes" : "No",
                        item.createdAt?.formatted() ?? ""
                    ].joined(separator: ",")
                    csvContent += row + "\n"
                }
            }
            
            return csvContent
        } catch {
            print("Failed to export to CSV: \(error)")
            return nil
        }
    }
}

// MARK: - Export Data Models

struct ExportData: Codable {
    let lists: [ListExportData]
    let exportDate: Date
    let version: String
    
    init(lists: [ListExportData]) {
        self.lists = lists
        self.exportDate = Date()
        self.version = "1.0"
    }
}

struct ListExportData: Codable {
    let id: UUID
    let name: String
    let orderNumber: Int32
    let createdAt: Date
    let modifiedAt: Date
    let items: [ItemExportData]
    
    init(from list: List) {
        self.id = list.id ?? UUID()
        self.name = list.name ?? ""
        self.orderNumber = list.orderNumber
        self.createdAt = list.createdAt ?? Date()
        self.modifiedAt = list.modifiedAt ?? Date()
        self.items = (list.items?.allObjects as? [Item] ?? []).map { ItemExportData(from: $0) }
    }
}

struct ItemExportData: Codable {
    let id: UUID
    let title: String
    let description: String
    let quantity: Int32
    let orderNumber: Int32
    let isCrossedOut: Bool
    let createdAt: Date
    let modifiedAt: Date
    
    init(from item: Item) {
        self.id = item.id ?? UUID()
        self.title = item.title ?? ""
        self.description = item.itemDescription ?? ""
        self.quantity = item.quantity
        self.orderNumber = item.orderNumber
        self.isCrossedOut = item.isCrossedOut
        self.createdAt = item.createdAt ?? Date()
        self.modifiedAt = item.modifiedAt ?? Date()
    }
}
