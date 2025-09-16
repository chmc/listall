import Foundation
// import CoreData // Removed CoreData import

class ExportService: ObservableObject {
    private let dataManager = DataManager.shared // Changed from coreDataManager
    // private let viewContext: NSManagedObjectContext // Removed viewContext
    
    init() {
        // self.viewContext = coreDataManager.container.viewContext // Removed CoreData initialization
    }
    
    func exportToJSON() -> Data? {
        // Simulate fetching from DataManager
        let lists = dataManager.lists
        
        do {
            let exportData = ExportData(lists: lists.map { ListExportData(from: $0) })
            return try JSONEncoder().encode(exportData)
        } catch {
            print("Failed to export to JSON: \(error)")
            return nil
        }
    }
    
    func exportToCSV() -> String? {
        // Simulate fetching from DataManager
        let lists = dataManager.lists
        var csvContent = "List Name,Item Title,Description,Quantity,Crossed Out,Created Date\n"
        
        for list in lists {
            let items = dataManager.getItems(forListId: list.id)
            for item in items {
                let row = [
                    list.name,
                    item.title,
                    item.itemDescription ?? "",
                    String(item.quantity),
                    item.isCrossedOut ? "Yes" : "No",
                    item.createdAt.formatted()
                ].joined(separator: ",")
                csvContent += row + "\n"
            }
        }
        
        return csvContent
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
        self.id = list.id
        self.name = list.name
        self.orderNumber = Int32(list.orderNumber)
        self.createdAt = list.createdAt
        self.modifiedAt = list.modifiedAt
        self.items = list.items.map { ItemExportData(from: $0) }
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
        self.id = item.id
        self.title = item.title
        self.description = item.itemDescription ?? ""
        self.quantity = Int32(item.quantity)
        self.orderNumber = Int32(item.orderNumber)
        self.isCrossedOut = item.isCrossedOut
        self.createdAt = item.createdAt
        self.modifiedAt = item.modifiedAt
    }
}
