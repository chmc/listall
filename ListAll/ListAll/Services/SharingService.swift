import Foundation
import Combine
import SwiftUI
#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

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
    
    /// Whether to include item images (base64 encoded in JSON)
    var includeImages: Bool
    
    /// Default share options with essential fields
    static var `default`: ShareOptions {
        ShareOptions(
            includeCrossedOutItems: true,
            includeDescriptions: true,
            includeQuantities: true,
            includeDates: false,
            includeImages: true
        )
    }
    
    /// Minimal share options (only item titles)
    static var minimal: ShareOptions {
        ShareOptions(
            includeCrossedOutItems: false,
            includeDescriptions: false,
            includeQuantities: false,
            includeDates: false,
            includeImages: false
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

    private var dataRepository: DataRepository
    private var exportService: ExportService

    init() {
        self.dataRepository = DataRepository()
        self.exportService = ExportService()
    }

    /// Internal initializer for testing with custom dependencies
    init(dataRepository: DataRepository, exportService: ExportService) {
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
            shareError = "URL sharing is not supported (app is not publicly distributed)"
            return nil
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
        
        // Return raw text directly - UIActivityViewController handles it better than files
        // No LaunchServices indexing issues with raw strings
        return ShareResult(format: .plainText, content: textContent as NSString, fileName: nil)
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
        
        let listExportData = ListExportData(from: list, items: items, includeImages: options.includeImages)
        
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
            
            // Return raw text directly - UIActivityViewController handles it better than files
            // No LaunchServices indexing issues with raw strings
            return ShareResult(format: .plainText, content: plainText as NSString, fileName: nil)
            
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
    
    /// Creates a temporary file with the given data in Documents directory
    /// Using Documents instead of temp fixes LaunchServices indexing issues
    private func createTemporaryFile(data: Data, fileName: String) -> URL? {
        guard let documentsDir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
            return nil
        }
        
        // Create a temp subfolder
        let tempDir = documentsDir.appendingPathComponent("Temp", isDirectory: true)
        
        do {
            // Create temp directory if it doesn't exist
            try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true, attributes: nil)
            
            let fileURL = tempDir.appendingPathComponent(fileName)
            
            // Remove existing file if present
            if FileManager.default.fileExists(atPath: fileURL.path) {
                try FileManager.default.removeItem(at: fileURL)
            }
            
            // Write file with proper attributes
            try data.write(to: fileURL, options: [.atomic])
            
            // Set file attributes to make it more accessible
            try FileManager.default.setAttributes([.posixPermissions: 0o644], ofItemAtPath: fileURL.path)
            
            return fileURL
        } catch {
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

    // MARK: - Clipboard Operations

    /// Copies text content to the system clipboard
    /// - Parameter text: The text to copy
    /// - Returns: True if copy was successful, false otherwise
    func copyToClipboard(text: String) -> Bool {
        #if canImport(UIKit)
        UIPasteboard.general.string = text
        return true
        #elseif canImport(AppKit)
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        return pasteboard.setString(text, forType: .string)
        #else
        return false
        #endif
    }

    /// Copies a list's content to the clipboard in plain text format
    /// - Parameters:
    ///   - list: The list to copy
    ///   - options: Share options for customization
    /// - Returns: True if copy was successful, false otherwise
    func copyListToClipboard(_ list: List, options: ShareOptions = .default) -> Bool {
        guard let result = shareList(list, format: .plainText, options: options),
              let textContent = result.content as? NSString else {
            return false
        }
        return copyToClipboard(text: textContent as String)
    }

    #if canImport(AppKit)
    // MARK: - macOS-Specific Sharing

    /// Returns available sharing services for the given content
    /// - Parameter content: The content to share (String or URL)
    /// - Returns: Array of available NSSharingService instances
    func availableSharingServices(for content: Any) -> [NSSharingService] {
        var items: [Any] = []

        if let text = content as? String {
            items.append(text)
        } else if let url = content as? URL {
            items.append(url)
        } else if let nsString = content as? NSString {
            items.append(nsString)
        }

        guard !items.isEmpty else { return [] }

        return NSSharingService.sharingServices(forItems: items)
    }

    /// Shares content using a specific sharing service
    /// - Parameters:
    ///   - content: The content to share
    ///   - service: The sharing service to use
    /// - Returns: True if sharing was initiated, false otherwise
    func share(content: Any, using service: NSSharingService) -> Bool {
        var items: [Any] = []

        if let text = content as? String {
            items.append(text)
        } else if let url = content as? URL {
            items.append(url)
        } else if let nsString = content as? NSString {
            items.append(nsString)
        }

        guard !items.isEmpty else { return false }

        service.perform(withItems: items)
        return true
    }

    /// Creates a sharing service picker for the given list
    /// - Parameters:
    ///   - list: The list to share
    ///   - format: The format to share in
    ///   - options: Share options for customization
    /// - Returns: NSSharingServicePicker configured for the list, or nil if creation fails
    func createSharingServicePicker(for list: List, format: ShareFormat = .plainText, options: ShareOptions = .default) -> NSSharingServicePicker? {
        guard let result = shareList(list, format: format, options: options) else {
            return nil
        }

        var items: [Any] = []
        if let text = result.content as? String {
            items.append(text)
        } else if let nsString = result.content as? NSString {
            items.append(nsString as String)
        } else if let url = result.content as? URL {
            items.append(url)
        }

        guard !items.isEmpty else { return nil }

        return NSSharingServicePicker(items: items)
    }
    #endif
}
