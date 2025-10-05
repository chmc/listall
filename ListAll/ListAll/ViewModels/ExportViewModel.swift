import Foundation
import SwiftUI
import UniformTypeIdentifiers

/// ViewModel responsible for managing export operations and UI state
class ExportViewModel: ObservableObject {
    @Published var isExporting = false
    @Published var exportProgress: String = ""
    @Published var showShareSheet = false
    @Published var exportedFileURL: URL?
    @Published var errorMessage: String?
    @Published var successMessage: String?
    
    // Export options
    @Published var exportOptions = ExportOptions.default
    @Published var showOptionsSheet = false
    
    private let exportService: ExportService
    private var exportTask: Task<Void, Never>?
    
    init(exportService: ExportService = ExportService()) {
        self.exportService = exportService
    }
    
    /// Cancels the current export operation
    func cancelExport() {
        exportTask?.cancel()
        exportTask = nil
        isExporting = false
        exportProgress = ""
        errorMessage = "Export cancelled"
    }
    
    // MARK: - Export Methods
    
    /// Exports data to JSON format and presents share sheet
    func exportToJSON() {
        isExporting = true
        errorMessage = nil
        successMessage = nil
        exportProgress = "Preparing export..."
        
        exportTask = Task { @MainActor in
            do {
                // Check for cancellation
                try Task.checkCancellation()
                
                exportProgress = "Collecting data..."
                
                // Perform export on background thread
                let jsonData = try await Task.detached(priority: .userInitiated) { [weak self] in
                    guard let self = self else { throw ExportError.cancelled }
                    
                    // Check for cancellation periodically
                    try Task.checkCancellation()
                    
                    guard let data = self.exportService.exportToJSON(options: self.exportOptions) else {
                        throw ExportError.exportFailed("Failed to export data to JSON")
                    }
                    return data
                }.value
                
                try Task.checkCancellation()
                exportProgress = "Creating file..."
                
                // Create temporary file
                let fileName = "ListAll-Export-\(formatDateForFilename(Date())).json"
                guard let fileURL = createTemporaryFile(data: jsonData, fileName: fileName) else {
                    throw ExportError.exportFailed("Failed to create export file")
                }
                
                try Task.checkCancellation()
                exportProgress = "Export complete!"
                
                exportedFileURL = fileURL
                showShareSheet = true
                successMessage = "JSON export ready"
                isExporting = false
                exportProgress = ""
                
            } catch is CancellationError {
                // Task was cancelled
                isExporting = false
                exportProgress = ""
            } catch let error as ExportError {
                errorMessage = error.message
                isExporting = false
                exportProgress = ""
            } catch {
                errorMessage = "Export failed: \(error.localizedDescription)"
                isExporting = false
                exportProgress = ""
            }
        }
    }
    
    /// Exports data to CSV format and presents share sheet
    func exportToCSV() {
        isExporting = true
        errorMessage = nil
        successMessage = nil
        exportProgress = "Preparing export..."
        
        exportTask = Task { @MainActor in
            do {
                try Task.checkCancellation()
                exportProgress = "Collecting data..."
                
                let csvData = try await Task.detached(priority: .userInitiated) { [weak self] in
                    guard let self = self else { throw ExportError.cancelled }
                    try Task.checkCancellation()
                    
                    guard let csvString = self.exportService.exportToCSV(options: self.exportOptions) else {
                        throw ExportError.exportFailed("Failed to export data to CSV")
                    }
                    
                    guard let data = csvString.data(using: .utf8) else {
                        throw ExportError.exportFailed("Failed to encode CSV data")
                    }
                    return data
                }.value
                
                try Task.checkCancellation()
                exportProgress = "Creating file..."
                
                let fileName = "ListAll-Export-\(formatDateForFilename(Date())).csv"
                guard let fileURL = createTemporaryFile(data: csvData, fileName: fileName) else {
                    throw ExportError.exportFailed("Failed to create export file")
                }
                
                try Task.checkCancellation()
                exportProgress = "Export complete!"
                
                exportedFileURL = fileURL
                showShareSheet = true
                successMessage = "CSV export ready"
                isExporting = false
                exportProgress = ""
                
            } catch is CancellationError {
                isExporting = false
                exportProgress = ""
            } catch let error as ExportError {
                errorMessage = error.message
                isExporting = false
                exportProgress = ""
            } catch {
                errorMessage = "Export failed: \(error.localizedDescription)"
                isExporting = false
                exportProgress = ""
            }
        }
    }
    
    /// Exports data to plain text format and presents share sheet
    func exportToPlainText() {
        isExporting = true
        errorMessage = nil
        successMessage = nil
        exportProgress = "Preparing export..."
        
        exportTask = Task { @MainActor in
            do {
                try Task.checkCancellation()
                exportProgress = "Collecting data..."
                
                let textData = try await Task.detached(priority: .userInitiated) { [weak self] in
                    guard let self = self else { throw ExportError.cancelled }
                    try Task.checkCancellation()
                    
                    guard let plainText = self.exportService.exportToPlainText(options: self.exportOptions) else {
                        throw ExportError.exportFailed("Failed to export data to plain text")
                    }
                    
                    guard let data = plainText.data(using: .utf8) else {
                        throw ExportError.exportFailed("Failed to encode text data")
                    }
                    return data
                }.value
                
                try Task.checkCancellation()
                exportProgress = "Creating file..."
                
                let fileName = "ListAll-Export-\(formatDateForFilename(Date())).txt"
                guard let fileURL = createTemporaryFile(data: textData, fileName: fileName) else {
                    throw ExportError.exportFailed("Failed to create export file")
                }
                
                try Task.checkCancellation()
                exportProgress = "Export complete!"
                
                exportedFileURL = fileURL
                showShareSheet = true
                successMessage = "Plain text export ready"
                isExporting = false
                exportProgress = ""
                
            } catch is CancellationError {
                isExporting = false
                exportProgress = ""
            } catch let error as ExportError {
                errorMessage = error.message
                isExporting = false
                exportProgress = ""
            } catch {
                errorMessage = "Export failed: \(error.localizedDescription)"
                isExporting = false
                exportProgress = ""
            }
        }
    }
    
    // MARK: - Clipboard Export Methods
    
    /// Copies export data to clipboard in specified format
    func copyToClipboard(format: ExportFormat) {
        errorMessage = nil
        successMessage = nil
        
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            
            let success = self.exportService.copyToClipboard(format: format, options: self.exportOptions)
            
            DispatchQueue.main.async {
                if success {
                    let formatName = self.formatName(for: format)
                    self.successMessage = "Copied \(formatName) to clipboard"
                } else {
                    self.errorMessage = "Failed to copy to clipboard"
                }
            }
        }
    }
    
    /// Returns a human-readable name for the export format
    private func formatName(for format: ExportFormat) -> String {
        switch format {
        case .json:
            return "JSON"
        case .csv:
            return "CSV"
        case .plainText:
            return "text"
        }
    }
    
    // MARK: - Helper Methods
    
    /// Creates a temporary file with the given data
    private func createTemporaryFile(data: Data, fileName: String) -> URL? {
        let temporaryDirectoryURL = FileManager.default.temporaryDirectory
        let fileURL = temporaryDirectoryURL.appendingPathComponent(fileName)
        
        do {
            try data.write(to: fileURL)
            return fileURL
        } catch {
            print("Error creating temporary file: \(error)")
            return nil
        }
    }
    
    /// Formats date for use in filename
    private func formatDateForFilename(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd-HHmmss"
        return formatter.string(from: date)
    }
    
    /// Cleans up temporary export file
    func cleanup() {
        exportTask?.cancel()
        exportTask = nil
        if let fileURL = exportedFileURL {
            try? FileManager.default.removeItem(at: fileURL)
            exportedFileURL = nil
        }
    }
}

// MARK: - Export Error

enum ExportError: Error {
    case cancelled
    case exportFailed(String)
    
    var message: String {
        switch self {
        case .cancelled:
            return "Export cancelled"
        case .exportFailed(let msg):
            return msg
        }
    }
}
