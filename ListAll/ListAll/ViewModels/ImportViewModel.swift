import Foundation
import SwiftUI
import UniformTypeIdentifiers

/// Import source type
enum ImportSource {
    case file
    case text
}

/// ViewModel for handling import operations
class ImportViewModel: ObservableObject {
    @Published var selectedStrategy: ImportOptions.MergeStrategy = .merge
    @Published var showFilePicker = false
    @Published var isImporting = false
    @Published var successMessage: String?
    @Published var errorMessage: String?
    @Published var shouldDismiss = false
    
    // Import source selection
    @Published var importSource: ImportSource = .file
    @Published var importText: String = ""
    
    // Preview functionality
    @Published var showPreview = false
    @Published var importPreview: ImportPreview?
    @Published var previewFileURL: URL?
    @Published var previewText: String?
    
    // Progress tracking
    @Published var importProgress: ImportProgress?
    
    private let importService: ImportService
    private let dataRepository: DataRepository
    
    init(importService: ImportService = ImportService(), dataRepository: DataRepository = DataRepository()) {
        self.importService = importService
        self.dataRepository = dataRepository
        
        // Set up progress handler
        self.importService.progressHandler = { [weak self] progress in
            DispatchQueue.main.async {
                self?.importProgress = progress
            }
        }
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
    
    func showPreviewForFile(_ url: URL) {
        clearMessages()
        previewFileURL = url
        
        // Ensure we have access to security-scoped resource
        guard url.startAccessingSecurityScopedResource() else {
            errorMessage = "Unable to access selected file"
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
            
            // Generate preview
            let preview = try importService.previewImport(data, options: options)
            importPreview = preview
            
            // Show preview if valid
            if preview.isValid {
                showPreview = true
            } else {
                let errorList = preview.errors.joined(separator: "\n")
                errorMessage = "Preview failed:\n\(errorList)"
            }
        } catch let error as ImportError {
            errorMessage = error.localizedDescription
        } catch {
            errorMessage = "Failed to preview: \(error.localizedDescription)"
        }
    }
    
    func showPreviewForText() {
        clearMessages()
        
        // Validate text is not empty
        guard !importText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            errorMessage = "Please enter JSON data to import"
            return
        }
        
        previewText = importText
        
        do {
            // Convert text to data
            guard let data = importText.data(using: .utf8) else {
                errorMessage = "Unable to process text data"
                return
            }
            
            // Create import options based on selected strategy
            let options = ImportOptions(
                mergeStrategy: selectedStrategy,
                validateData: true
            )
            
            // Generate preview
            let preview = try importService.previewImport(data, options: options)
            importPreview = preview
            
            // Show preview if valid
            if preview.isValid {
                showPreview = true
            } else {
                let errorList = preview.errors.joined(separator: "\n")
                errorMessage = "Preview failed:\n\(errorList)"
            }
        } catch let error as ImportError {
            errorMessage = error.localizedDescription
        } catch {
            errorMessage = "Failed to preview: \(error.localizedDescription)"
        }
    }
    
    func confirmImport() {
        showPreview = false
        
        if let url = previewFileURL {
            importFromFile(url)
        } else if let text = previewText {
            importFromText(text)
        } else {
            errorMessage = "No data selected for import"
        }
    }
    
    func importFromFile(_ url: URL) {
        clearMessages()
        isImporting = true
        importProgress = nil
        
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
            
            // Perform import with auto-detect format
            let result = try importService.importData(data, options: options)
            
            // Handle result
            if result.wasSuccessful {
                let listsText = result.listsCreated == 1 ? "list" : "lists"
                let itemsText = result.itemsCreated == 1 ? "item" : "items"
                
                var message = "Successfully imported \(result.listsCreated) \(listsText) and \(result.itemsCreated) \(itemsText)"
                
                if result.listsUpdated > 0 || result.itemsUpdated > 0 {
                    message += " (updated \(result.listsUpdated + result.itemsUpdated) existing)"
                }
                
                if result.hasConflicts {
                    message += "\n\(result.conflicts.count) conflicts resolved"
                }
                
                successMessage = message
                
                // Post notification to refresh lists
                NotificationCenter.default.post(name: .dataImported, object: nil)
                
                // Dismiss after successful import
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { [weak self] in
                    self?.shouldDismiss = true
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
        importProgress = nil
        previewFileURL = nil
    }
    
    func importFromText(_ text: String) {
        clearMessages()
        isImporting = true
        importProgress = nil
        
        do {
            // Convert text to data
            guard let data = text.data(using: .utf8) else {
                errorMessage = "Unable to process text data"
                isImporting = false
                return
            }
            
            // Create import options based on selected strategy
            let options = ImportOptions(
                mergeStrategy: selectedStrategy,
                validateData: true
            )
            
            // Perform import with auto-detect format
            let result = try importService.importData(data, options: options)
            
            // Handle result
            if result.wasSuccessful {
                let listsText = result.listsCreated == 1 ? "list" : "lists"
                let itemsText = result.itemsCreated == 1 ? "item" : "items"
                
                var message = "Successfully imported \(result.listsCreated) \(listsText) and \(result.itemsCreated) \(itemsText)"
                
                if result.listsUpdated > 0 || result.itemsUpdated > 0 {
                    message += " (updated \(result.listsUpdated + result.itemsUpdated) existing)"
                }
                
                if result.hasConflicts {
                    message += "\n\(result.conflicts.count) conflicts resolved"
                }
                
                successMessage = message
                
                // Clear the text field on success
                importText = ""
                
                // Post notification to refresh lists
                NotificationCenter.default.post(name: .dataImported, object: nil)
                
                // Dismiss after successful import
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { [weak self] in
                    self?.shouldDismiss = true
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
        importProgress = nil
        previewText = nil
    }
    
    func cancelPreview() {
        showPreview = false
        importPreview = nil
        previewFileURL = nil
        previewText = nil
    }
    
    func clearMessages() {
        successMessage = nil
        errorMessage = nil
    }
    
    func cleanup() {
        clearMessages()
        cancelPreview()
        importProgress = nil
        importText = ""
    }
}

