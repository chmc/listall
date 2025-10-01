import Foundation
import SwiftUI
import UniformTypeIdentifiers

/// ViewModel responsible for managing export operations and UI state
class ExportViewModel: ObservableObject {
    @Published var isExporting = false
    @Published var showShareSheet = false
    @Published var exportedFileURL: URL?
    @Published var errorMessage: String?
    @Published var successMessage: String?
    
    private let exportService: ExportService
    
    init(exportService: ExportService = ExportService()) {
        self.exportService = exportService
    }
    
    // MARK: - Export Methods
    
    /// Exports data to JSON format and presents share sheet
    func exportToJSON() {
        isExporting = true
        errorMessage = nil
        successMessage = nil
        
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            guard let jsonData = self.exportService.exportToJSON() else {
                DispatchQueue.main.async {
                    self.errorMessage = "Failed to export data to JSON"
                    self.isExporting = false
                }
                return
            }
            
            // Create temporary file
            let fileName = "ListAll-Export-\(self.formatDateForFilename(Date())).json"
            let fileURL = self.createTemporaryFile(data: jsonData, fileName: fileName)
            
            DispatchQueue.main.async {
                if let fileURL = fileURL {
                    self.exportedFileURL = fileURL
                    self.showShareSheet = true
                    self.successMessage = "JSON export ready"
                } else {
                    self.errorMessage = "Failed to create export file"
                }
                self.isExporting = false
            }
        }
    }
    
    /// Exports data to CSV format and presents share sheet
    func exportToCSV() {
        isExporting = true
        errorMessage = nil
        successMessage = nil
        
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            guard let csvString = self.exportService.exportToCSV() else {
                DispatchQueue.main.async {
                    self.errorMessage = "Failed to export data to CSV"
                    self.isExporting = false
                }
                return
            }
            
            // Convert string to data
            guard let csvData = csvString.data(using: .utf8) else {
                DispatchQueue.main.async {
                    self.errorMessage = "Failed to encode CSV data"
                    self.isExporting = false
                }
                return
            }
            
            // Create temporary file
            let fileName = "ListAll-Export-\(self.formatDateForFilename(Date())).csv"
            let fileURL = self.createTemporaryFile(data: csvData, fileName: fileName)
            
            DispatchQueue.main.async {
                if let fileURL = fileURL {
                    self.exportedFileURL = fileURL
                    self.showShareSheet = true
                    self.successMessage = "CSV export ready"
                } else {
                    self.errorMessage = "Failed to create export file"
                }
                self.isExporting = false
            }
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
        if let fileURL = exportedFileURL {
            try? FileManager.default.removeItem(at: fileURL)
            exportedFileURL = nil
        }
    }
}
