import Foundation
import SwiftUI
import UniformTypeIdentifiers

/// ViewModel for handling import operations
class ImportViewModel: ObservableObject {
    @Published var selectedStrategy: ImportOptions.MergeStrategy = .merge
    @Published var showFilePicker = false
    @Published var isImporting = false
    @Published var successMessage: String?
    @Published var errorMessage: String?
    
    private let importService: ImportService
    private let dataRepository: DataRepository
    
    init(importService: ImportService = ImportService(), dataRepository: DataRepository = DataRepository()) {
        self.importService = importService
        self.dataRepository = dataRepository
    }
    
    // MARK: - Strategy Selection
    
    var strategyOptions: [ImportOptions.MergeStrategy] {
        [.merge, .replace, .append]
    }
    
    func strategyName(_ strategy: ImportOptions.MergeStrategy) -> String {
        switch strategy {
        case .merge:
            return "Merge"
        case .replace:
            return "Replace All"
        case .append:
            return "Append as New"
        }
    }
    
    func strategyDescription(_ strategy: ImportOptions.MergeStrategy) -> String {
        switch strategy {
        case .merge:
            return "Update existing items and add new ones"
        case .replace:
            return "Delete all data and import fresh"
        case .append:
            return "Create duplicates with new IDs"
        }
    }
    
    func strategyIcon(_ strategy: ImportOptions.MergeStrategy) -> String {
        switch strategy {
        case .merge:
            return "arrow.triangle.merge"
        case .replace:
            return "arrow.clockwise"
        case .append:
            return "plus.circle"
        }
    }
    
    // MARK: - Import Operations
    
    func importFromFile(_ url: URL) {
        clearMessages()
        isImporting = true
        
        // Ensure we have access to security-scoped resource
        guard url.startAccessingSecurityScopedResource() else {
            errorMessage = "Unable to access selected file"
            isImporting = false
            return
        }
        
        defer {
            url.stopAccessingSecurityScopedResource()
        }
        
        do {
            // Read file data
            let data = try Data(contentsOf: url)
            
            // Create import options based on selected strategy
            let options = ImportOptions(
                mergeStrategy: selectedStrategy,
                validateData: true
            )
            
            // Perform import
            let result = try importService.importFromJSON(data, options: options)
            
            // Handle result
            if result.wasSuccessful {
                let listsText = result.listsCreated == 1 ? "list" : "lists"
                let itemsText = result.itemsCreated == 1 ? "item" : "items"
                
                var message = "Successfully imported \(result.listsCreated) \(listsText) and \(result.itemsCreated) \(itemsText)"
                
                if result.listsUpdated > 0 || result.itemsUpdated > 0 {
                    message += " (updated \(result.listsUpdated + result.itemsUpdated) existing)"
                }
                
                successMessage = message
                
                // Auto-dismiss success message after 5 seconds
                DispatchQueue.main.asyncAfter(deadline: .now() + 5) { [weak self] in
                    self?.successMessage = nil
                }
            } else {
                let errorList = result.errors.joined(separator: "\n")
                errorMessage = "Import completed with errors:\n\(errorList)"
            }
        } catch let error as ImportError {
            errorMessage = error.localizedDescription
        } catch {
            errorMessage = "Failed to import: \(error.localizedDescription)"
        }
        
        isImporting = false
    }
    
    func clearMessages() {
        successMessage = nil
        errorMessage = nil
    }
    
    func cleanup() {
        clearMessages()
    }
}

