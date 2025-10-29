import Foundation
#if canImport(UIKit)
import UIKit
#endif

// MARK: - Export Format

/// Supported export formats
enum ExportFormat {
    case json
    case csv
    case plainText
}

// MARK: - Export Options

/// Configuration options for export operations
struct ExportOptions {
    /// Whether to include crossed out items in export
    var includeCrossedOutItems: Bool
    
    /// Whether to include item descriptions
    var includeDescriptions: Bool
    
    /// Whether to include item quantities
    var includeQuantities: Bool
    
    /// Whether to include dates (created/modified)
    var includeDates: Bool
    
    /// Whether to include archived lists
    var includeArchivedLists: Bool
    
    /// Whether to include item images (base64 encoded)
    var includeImages: Bool
    
    /// Default export options with all fields included
    static var `default`: ExportOptions {
        ExportOptions(
            includeCrossedOutItems: true,
            includeDescriptions: true,
            includeQuantities: true,
            includeDates: true,
            includeArchivedLists: false,
            includeImages: true
        )
    }
    
    /// Minimal export options (only essential fields)
    static var minimal: ExportOptions {
        ExportOptions(
            includeCrossedOutItems: false,
            includeDescriptions: false,
            includeQuantities: false,
            includeDates: false,
            includeArchivedLists: false,
            includeImages: false
        )
    }
}

/// Service responsible for exporting app data to various formats
class ExportService: ObservableObject {
    private let dataRepository: DataRepository
    
    init(dataRepository: DataRepository = DataRepository()) {
        self.dataRepository = dataRepository
    }
    
    // MARK: - JSON Export
    
    /// Exports all lists and items to JSON format
    /// - Parameter options: Export options for customization
    /// - Returns: JSON data if successful, nil if export fails
    func exportToJSON(options: ExportOptions = .default) -> Data? {
        let allLists = dataRepository.getAllLists()
        let lists = filterLists(allLists, options: options)
        
        do {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            
            let exportData = ExportData(lists: lists.map { list in
                var items = dataRepository.getItems(for: list)
                items = filterItems(items, options: options)
                return ListExportData(from: list, items: items, includeImages: options.includeImages)
            })
            
            return try encoder.encode(exportData)
        } catch {
            return nil
        }
    }
    
    // MARK: - CSV Export
    
    /// Exports all lists and items to CSV format
    /// - Parameter options: Export options for customization
    /// - Returns: CSV string if successful, nil if export fails
    func exportToCSV(options: ExportOptions = .default) -> String? {
        let allLists = dataRepository.getAllLists()
        let lists = filterLists(allLists, options: options)
        
        var csvContent = "List Name,Item Title,Description,Quantity,Crossed Out,Created Date,Modified Date,Order\n"
        
        for list in lists {
            var items = dataRepository.getItems(for: list)
            items = filterItems(items, options: options)
            
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
    
    // MARK: - Plain Text Export
    
    /// Exports all lists and items to plain text format
    /// - Parameter options: Export options for customization
    /// - Returns: Plain text string if successful, nil if export fails
    func exportToPlainText(options: ExportOptions = .default) -> String? {
        let allLists = dataRepository.getAllLists()
        let lists = filterLists(allLists, options: options)
        
        var textContent = "ListAll Export\n"
        textContent += "=" + String(repeating: "=", count: 50) + "\n"
        textContent += "Exported: \(formatDateForPlainText(Date()))\n"
        textContent += String(repeating: "=", count: 52) + "\n\n"
        
        for list in lists {
            var items = dataRepository.getItems(for: list)
            items = filterItems(items, options: options)
            
            // List header
            textContent += "\(list.name)\n"
            textContent += String(repeating: "-", count: list.name.count) + "\n"
            
            if options.includeDates {
                textContent += "Created: \(formatDateForPlainText(list.createdAt))\n"
            }
            
            // List items
            if items.isEmpty {
                textContent += "(No items)\n"
            } else {
                textContent += "\n"
                for (index, item) in items.enumerated() {
                    let itemNumber = index + 1
                    let crossMark = item.isCrossedOut ? "[✓] " : "[ ] "
                    
                    textContent += "\(itemNumber). \(crossMark)\(item.title)"
                    
                    if options.includeQuantities && item.quantity > 1 {
                        textContent += " (×\(item.quantity))"
                    }
                    
                    textContent += "\n"
                    
                    if options.includeDescriptions, let description = item.itemDescription, !description.isEmpty {
                        textContent += "   \(description)\n"
                    }
                    
                    if options.includeDates {
                        textContent += "   Created: \(formatDateForPlainText(item.createdAt))\n"
                    }
                    
                    textContent += "\n"
                }
            }
            
            textContent += "\n"
        }
        
        return textContent
    }
    
    // MARK: - Clipboard Export
    
    /// Copies export data to clipboard
    /// - Parameters:
    ///   - format: The export format (json, csv, plainText)
    ///   - options: Export options for customization
    /// - Returns: True if copy was successful, false otherwise
    func copyToClipboard(format: ExportFormat, options: ExportOptions = .default) -> Bool {
        #if canImport(UIKit)
        let pasteboard = UIPasteboard.general
        
        switch format {
        case .json:
            guard let jsonData = exportToJSON(options: options),
                  let jsonString = String(data: jsonData, encoding: .utf8) else {
                return false
            }
            pasteboard.string = jsonString
            return true
            
        case .csv:
            guard let csvString = exportToCSV(options: options) else {
                return false
            }
            pasteboard.string = csvString
            return true
            
        case .plainText:
            guard let plainText = exportToPlainText(options: options) else {
                return false
            }
            pasteboard.string = plainText
            return true
        }
        #else
        // For macOS or other platforms without UIKit
        return false
        #endif
    }
    
    // MARK: - Helper Methods
    
    /// Filters lists based on export options
    private func filterLists(_ lists: [List], options: ExportOptions) -> [List] {
        if options.includeArchivedLists {
            return lists
        } else {
            return lists.filter { !$0.isArchived }
        }
    }
    
    /// Filters items based on export options
    private func filterItems(_ items: [Item], options: ExportOptions) -> [Item] {
        if options.includeCrossedOutItems {
            return items
        } else {
            return items.filter { !$0.isCrossedOut }
        }
    }
    
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
    
    /// Formats date for plain text export (human-readable)
    private func formatDateForPlainText(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
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
    
    init(from list: List, items: [Item], includeImages: Bool = true) {
        self.id = list.id
        self.name = list.name
        self.orderNumber = list.orderNumber
        self.isArchived = list.isArchived
        self.createdAt = list.createdAt
        self.modifiedAt = list.modifiedAt
        self.items = items.map { ItemExportData(from: $0, includeImages: includeImages) }
    }
    
    // Manual initializer for import parsing
    init(id: UUID = UUID(), name: String, orderNumber: Int = 0, isArchived: Bool = false,
         items: [ItemExportData] = [], createdAt: Date = Date(), modifiedAt: Date = Date()) {
        self.id = id
        self.name = name
        self.orderNumber = orderNumber
        self.isArchived = isArchived
        self.createdAt = createdAt
        self.modifiedAt = modifiedAt
        self.items = items
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
    let images: [ItemImageExportData]
    
    init(from item: Item, includeImages: Bool = true) {
        self.id = item.id
        self.title = item.title
        self.description = item.itemDescription ?? ""
        self.quantity = item.quantity
        self.orderNumber = item.orderNumber
        self.isCrossedOut = item.isCrossedOut
        self.createdAt = item.createdAt
        self.modifiedAt = item.modifiedAt
        self.images = includeImages ? item.sortedImages.map { ItemImageExportData(from: $0) } : []
    }
    
    // Manual initializer for import parsing
    init(id: UUID = UUID(), title: String, description: String = "", quantity: Int = 1, 
         orderNumber: Int = 0, isCrossedOut: Bool = false, 
         createdAt: Date = Date(), modifiedAt: Date = Date(), images: [ItemImageExportData] = []) {
        self.id = id
        self.title = title
        self.description = description
        self.quantity = quantity
        self.orderNumber = orderNumber
        self.isCrossedOut = isCrossedOut
        self.createdAt = createdAt
        self.modifiedAt = modifiedAt
        self.images = images
    }
}

// MARK: - ItemImage Export Data

struct ItemImageExportData: Codable {
    let id: UUID
    let imageData: String // Base64 encoded
    let orderNumber: Int
    let createdAt: Date
    
    init(from itemImage: ItemImage) {
        self.id = itemImage.id
        self.imageData = itemImage.imageData?.base64EncodedString() ?? ""
        self.orderNumber = itemImage.orderNumber
        self.createdAt = itemImage.createdAt
    }
    
    // Manual initializer for import parsing
    init(id: UUID = UUID(), imageData: String = "", orderNumber: Int = 0, createdAt: Date = Date()) {
        self.id = id
        self.imageData = imageData
        self.orderNumber = orderNumber
        self.createdAt = createdAt
    }
}
