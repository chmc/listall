import Foundation
import Combine
#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
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
    // Lazy initialization to avoid accessing Core Data during unit tests
    // On unsigned macOS builds, eager DataRepository access crashes
    // because App Groups require sandbox permissions
    private lazy var dataRepository: DataRepository = DataRepository()

    // Test-injected repository (overrides lazy default if provided)
    private var testRepository: DataRepository?

    init(dataRepository: DataRepository? = nil) {
        self.testRepository = dataRepository
    }

    // MARK: - Data Repository Access

    /// Get the appropriate data repository (test or production)
    private var repository: DataRepository {
        return testRepository ?? dataRepository
    }
    
    // MARK: - JSON Export
    
    /// Exports all lists and items to JSON format
    /// - Parameter options: Export options for customization
    /// - Returns: JSON data if successful, nil if export fails
    func exportToJSON(options: ExportOptions = .default) -> Data? {
        let allLists = repository.getAllLists()
        let lists = filterLists(allLists, options: options)

        do {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]

            let exportData = ExportData(lists: lists.map { list in
                var items = repository.getItems(for: list)
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
        let allLists = repository.getAllLists()
        let lists = filterLists(allLists, options: options)
        
        var csvContent = "List Name,Item Title,Description,Quantity,Crossed Out,Created Date,Modified Date,Order\n"
        
        for list in lists {
            var items = repository.getItems(for: list)
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
        let allLists = repository.getAllLists()
        let lists = filterLists(allLists, options: options)
        
        var textContent = "ListAll Export\n"
        textContent += "=" + String(repeating: "=", count: 50) + "\n"
        textContent += "Exported: \(formatDateForPlainText(Date()))\n"
        textContent += String(repeating: "=", count: 52) + "\n\n"
        
        for list in lists {
            var items = repository.getItems(for: list)
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
        let stringToCopy: String?

        switch format {
        case .json:
            guard let jsonData = exportToJSON(options: options),
                  let jsonString = String(data: jsonData, encoding: .utf8) else {
                return false
            }
            stringToCopy = jsonString

        case .csv:
            stringToCopy = exportToCSV(options: options)

        case .plainText:
            stringToCopy = exportToPlainText(options: options)
        }

        guard let string = stringToCopy else {
            return false
        }

        #if canImport(UIKit)
        UIPasteboard.general.string = string
        return true
        #elseif canImport(AppKit)
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        return pasteboard.setString(string, forType: .string)
        #else
        return false
        #endif
    }
    
    // MARK: - File Export

    /// Returns the default export directory URL
    /// On macOS, uses the Documents directory within the sandbox
    /// On iOS, uses the Documents directory
    var defaultExportDirectory: URL {
        #if os(macOS)
        // Use sandbox-friendly Documents directory on macOS
        if let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first {
            return documentsURL
        }
        return FileManager.default.temporaryDirectory
        #else
        // iOS/watchOS uses Documents directory
        if let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first {
            return documentsURL
        }
        return FileManager.default.temporaryDirectory
        #endif
    }

    /// Exports data to a file in the specified format
    /// - Parameters:
    ///   - format: The export format
    ///   - directory: The directory to save to (defaults to Documents)
    ///   - options: Export options for customization
    /// - Returns: URL of the exported file if successful, nil otherwise
    func exportToFile(format: ExportFormat, directory: URL? = nil, options: ExportOptions = .default) -> URL? {
        let targetDirectory = directory ?? defaultExportDirectory
        let timestamp = formatDateForFilename(Date())
        let fileName: String
        let data: Data?

        switch format {
        case .json:
            fileName = "ListAll-Export-\(timestamp).json"
            data = exportToJSON(options: options)
        case .csv:
            fileName = "ListAll-Export-\(timestamp).csv"
            data = exportToCSV(options: options)?.data(using: .utf8)
        case .plainText:
            fileName = "ListAll-Export-\(timestamp).txt"
            data = exportToPlainText(options: options)?.data(using: .utf8)
        }

        guard let exportData = data else {
            return nil
        }

        let fileURL = targetDirectory.appendingPathComponent(fileName)

        do {
            try exportData.write(to: fileURL)
            return fileURL
        } catch {
            return nil
        }
    }

    /// Formats date for use in filename
    private func formatDateForFilename(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd-HHmmss"
        return formatter.string(from: date)
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
