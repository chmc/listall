import Foundation
import UIKit
import SwiftUI

// MARK: - Share Format

/// Supported share formats for list sharing
enum ShareFormat {
    case plainText
    case json
    case url
}

// MARK: - Share Options

/// Configuration options for sharing operations
struct ShareOptions {
    /// Whether to include crossed out items in share
    var includeCrossedOutItems: Bool
    
    /// Whether to include item descriptions
    var includeDescriptions: Bool
    
    /// Whether to include item quantities
    var includeQuantities: Bool
    
    /// Whether to include dates (created/modified)
    var includeDates: Bool
    
    /// Default share options with essential fields
    static var `default`: ShareOptions {
        ShareOptions(
            includeCrossedOutItems: true,
            includeDescriptions: true,
            includeQuantities: true,
            includeDates: false
        )
    }
    
    /// Minimal share options (only item titles)
    static var minimal: ShareOptions {
        ShareOptions(
            includeCrossedOutItems: false,
            includeDescriptions: false,
            includeQuantities: false,
            includeDates: false
        )
    }
}

// MARK: - Share Result

/// Result of a share operation containing the shareable content
struct ShareResult {
    let format: ShareFormat
    let content: Any
    let fileName: String?
    
    init(format: ShareFormat, content: Any, fileName: String? = nil) {
        self.format = format
        self.content = content
        self.fileName = fileName
    }
}

/// Service responsible for creating shareable content from lists and items
class SharingService: ObservableObject {
    @Published var isSharing = false
    @Published var shareError: String?
    
    private let dataRepository: DataRepository
    private let exportService: ExportService
    
    init(dataRepository: DataRepository = DataRepository(), exportService: ExportService = ExportService()) {
        self.dataRepository = dataRepository
        self.exportService = exportService
    }
    
    // MARK: - Share Single List
    
    /// Creates shareable content for a single list
    /// - Parameters:
    ///   - list: The list to share
    ///   - format: The format to share in (plainText, json, url)
    ///   - options: Share options for customization
    /// - Returns: ShareResult containing the shareable content, or nil if sharing fails
    func shareList(_ list: List, format: ShareFormat = .plainText, options: ShareOptions = .default) -> ShareResult? {
        guard list.validate() else {
            shareError = "Invalid list data"
            return nil
        }
        
        switch format {
        case .plainText:
            return shareListAsPlainText(list, options: options)
        case .json:
            return shareListAsJSON(list, options: options)
        case .url:
            return shareListAsURL(list)
        }
    }
    
    /// Creates shareable plain text content for a list
    private func shareListAsPlainText(_ list: List, options: ShareOptions) -> ShareResult? {
        // Get fresh list with items from repository
        guard let freshList = dataRepository.getAllLists().first(where: { $0.id == list.id }) else {
            shareError = "List not found"
            return nil
        }
        
        var items = freshList.sortedItems
        
        // Filter items based on options
        if !options.includeCrossedOutItems {
            items = items.filter { !$0.isCrossedOut }
        }
        
        var textContent = "\(list.name)\n"
        textContent += String(repeating: "=", count: list.name.count) + "\n"
        
        if options.includeDates {
            textContent += "Created: \(formatDateForPlainText(list.createdAt))\n"
        }
        
        textContent += "\n"
        
        if items.isEmpty {
            textContent += "(No items)\n"
        } else {
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
                
                if index < items.count - 1 {
                    textContent += "\n"
                }
            }
        }
        
        textContent += "\n---\n"
        textContent += "Shared from ListAll\n"
        
        return ShareResult(format: .plainText, content: textContent)
    }
    
    /// Creates shareable JSON content for a list
    private func shareListAsJSON(_ list: List, options: ShareOptions) -> ShareResult? {
        // Get fresh list with items from repository
        guard let freshList = dataRepository.getAllLists().first(where: { $0.id == list.id }) else {
            shareError = "List not found"
            return nil
        }
        
        var items = freshList.sortedItems
        
        // Filter items based on options
        if !options.includeCrossedOutItems {
            items = items.filter { !$0.isCrossedOut }
        }
        
        let listExportData = ListExportData(from: list, items: items)
        
        do {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            
            let jsonData = try encoder.encode(listExportData)
            
            // Create temporary file
            let fileName = "\(list.name)-\(formatDateForFilename(Date())).json"
            if let fileURL = createTemporaryFile(data: jsonData, fileName: fileName) {
                return ShareResult(format: .json, content: fileURL, fileName: fileName)
            } else {
                shareError = "Failed to create temporary file"
                return nil
            }
        } catch {
            shareError = "Failed to encode JSON: \(error.localizedDescription)"
            return nil
        }
    }
    
    /// Creates shareable URL for a list (deep link)
    private func shareListAsURL(_ list: List) -> ShareResult? {
        // Create a deep link URL using custom URL scheme
        let urlString = "listall://list/\(list.id.uuidString)?name=\(list.name.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")"
        
        guard let url = URL(string: urlString) else {
            shareError = "Failed to create URL"
            return nil
        }
        
        return ShareResult(format: .url, content: url)
    }
    
    // MARK: - Share All Data
    
    /// Creates shareable content for all lists and items
    /// - Parameters:
    ///   - format: The format to share in (plainText or json)
    ///   - exportOptions: Export options for customization
    /// - Returns: ShareResult containing the shareable content, or nil if sharing fails
    func shareAllData(format: ShareFormat = .json, exportOptions: ExportOptions = .default) -> ShareResult? {
        switch format {
        case .plainText:
            guard let plainText = exportService.exportToPlainText(options: exportOptions) else {
                shareError = "Failed to export to plain text"
                return nil
            }
            return ShareResult(format: .plainText, content: plainText)
            
        case .json:
            guard let jsonData = exportService.exportToJSON(options: exportOptions) else {
                shareError = "Failed to export to JSON"
                return nil
            }
            
            // Create temporary file
            let fileName = "ListAll-Export-\(formatDateForFilename(Date())).json"
            if let fileURL = createTemporaryFile(data: jsonData, fileName: fileName) {
                return ShareResult(format: .json, content: fileURL, fileName: fileName)
            } else {
                shareError = "Failed to create temporary file"
                return nil
            }
            
        case .url:
            shareError = "URL format not supported for all data"
            return nil
        }
    }
    
    // MARK: - URL Scheme Handling
    
    /// Parses a ListAll deep link URL and extracts list information
    /// - Parameter url: The URL to parse
    /// - Returns: Tuple of (listId, listName) if parsing succeeds, nil otherwise
    func parseListURL(_ url: URL) -> (listId: UUID, listName: String)? {
        // Validate URL scheme
        guard url.scheme == "listall",
              url.host == "list" else {
            return nil
        }
        
        // Extract list ID from path
        let pathComponents = url.pathComponents.filter { $0 != "/" }
        guard let listIdString = pathComponents.first,
              let listId = UUID(uuidString: listIdString) else {
            return nil
        }
        
        // Extract list name from query parameters
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              let queryItems = components.queryItems,
              let nameItem = queryItems.first(where: { $0.name == "name" }),
              let listName = nameItem.value?.removingPercentEncoding else {
            return nil
        }
        
        return (listId: listId, listName: listName)
    }
    
    /// Validates that a list can be shared
    /// - Parameter list: The list to validate
    /// - Returns: True if the list is valid for sharing, false otherwise
    func validateListForSharing(_ list: List) -> Bool {
        guard list.validate() else {
            shareError = "List name cannot be empty"
            return false
        }
        
        return true
    }
    
    // MARK: - Helper Methods
    
    /// Creates a temporary file with the given data
    private func createTemporaryFile(data: Data, fileName: String) -> URL? {
        let tempDir = FileManager.default.temporaryDirectory
        let fileURL = tempDir.appendingPathComponent(fileName)
        
        do {
            try data.write(to: fileURL)
            return fileURL
        } catch {
            print("Failed to write temporary file: \(error)")
            return nil
        }
    }
    
    /// Formats date for plain text sharing (human-readable)
    private func formatDateForPlainText(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
    
    /// Formats date for filename (filesystem-safe)
    private func formatDateForFilename(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd-HHmmss"
        return formatter.string(from: date)
    }
    
    /// Clears any error messages
    func clearError() {
        shareError = nil
    }
}
