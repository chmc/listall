import Foundation

/// Service responsible for exporting app data to various formats
class ExportService: ObservableObject {
    private let dataRepository: DataRepository
    
    init(dataRepository: DataRepository = DataRepository()) {
        self.dataRepository = dataRepository
    }
    
    // MARK: - JSON Export
    
    /// Exports all lists and items to JSON format
    /// - Returns: JSON data if successful, nil if export fails
    func exportToJSON() -> Data? {
        let lists = dataRepository.getAllLists()
        
        do {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            
            let exportData = ExportData(lists: lists.map { list in
                let items = dataRepository.getItems(for: list)
                return ListExportData(from: list, items: items)
            })
            
            return try encoder.encode(exportData)
        } catch {
            print("Failed to export to JSON: \(error)")
            return nil
        }
    }
    
    // MARK: - CSV Export
    
    /// Exports all lists and items to CSV format
    /// - Returns: CSV string if successful, nil if export fails
    func exportToCSV() -> String? {
        let lists = dataRepository.getAllLists()
        
        var csvContent = "List Name,Item Title,Description,Quantity,Crossed Out,Created Date,Modified Date,Order\n"
        
        for list in lists {
            let items = dataRepository.getItems(for: list)
            
            // If list has no items, still add a row for the list itself
            if items.isEmpty {
                let row = [
                    escapeCSV(list.name),
                    "",
                    "",
                    "",
                    "",
                    formatDate(list.createdAt),
                    formatDate(list.modifiedAt),
                    "\(list.orderNumber)"
                ].joined(separator: ",")
                csvContent += row + "\n"
            } else {
                // Add a row for each item
                for item in items {
                    let row = [
                        escapeCSV(list.name),
                        escapeCSV(item.title),
                        escapeCSV(item.itemDescription ?? ""),
                        "\(item.quantity)",
                        item.isCrossedOut ? "Yes" : "No",
                        formatDate(item.createdAt),
                        formatDate(item.modifiedAt),
                        "\(item.orderNumber)"
                    ].joined(separator: ",")
                    csvContent += row + "\n"
                }
            }
        }
        
        return csvContent
    }
    
    // MARK: - Helper Methods
    
    /// Escapes special characters in CSV fields
    private func escapeCSV(_ field: String) -> String {
        // If field contains comma, quote, or newline, wrap in quotes and escape quotes
        if field.contains(",") || field.contains("\"") || field.contains("\n") {
            return "\"\(field.replacingOccurrences(of: "\"", with: "\"\""))\""
        }
        return field
    }
    
    /// Formats date consistently for CSV export
    private func formatDate(_ date: Date) -> String {
        let formatter = ISO8601DateFormatter()
        return formatter.string(from: date)
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
    let orderNumber: Int
    let isArchived: Bool
    let createdAt: Date
    let modifiedAt: Date
    let items: [ItemExportData]
    
    init(from list: List, items: [Item]) {
        self.id = list.id
        self.name = list.name
        self.orderNumber = list.orderNumber
        self.isArchived = list.isArchived
        self.createdAt = list.createdAt
        self.modifiedAt = list.modifiedAt
        self.items = items.map { ItemExportData(from: $0) }
    }
}

struct ItemExportData: Codable {
    let id: UUID
    let title: String
    let description: String
    let quantity: Int
    let orderNumber: Int
    let isCrossedOut: Bool
    let createdAt: Date
    let modifiedAt: Date
    
    init(from item: Item) {
        self.id = item.id
        self.title = item.title
        self.description = item.itemDescription ?? ""
        self.quantity = item.quantity
        self.orderNumber = item.orderNumber
        self.isCrossedOut = item.isCrossedOut
        self.createdAt = item.createdAt
        self.modifiedAt = item.modifiedAt
    }
}
