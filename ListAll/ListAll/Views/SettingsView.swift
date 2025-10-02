import SwiftUI

struct SettingsView: View {
    @State private var showCrossedOutItems = true
    @State private var enableCloudSync = true
    @State private var showingExportSheet = false
    @State private var showingImportSheet = false
    
    var body: some View {
        NavigationView {
            SwiftUI.List {
                Section("Display") {
                    Toggle("Show Crossed Out Items", isOn: $showCrossedOutItems)
                }
                
                Section("Sync") {
                    Toggle("iCloud Sync", isOn: $enableCloudSync)
                }
                
                Section("Data") {
                    Button("Export Data") {
                        showingExportSheet = true
                    }
                    
                    Button("Import Data") {
                        showingImportSheet = true
                    }
                }
                
                Section("About") {
                    HStack {
                        Text("Version")
                        Spacer()
                        Text("1.0.0")
                            .foregroundColor(.secondary)
                    }
                    
                    HStack {
                        Text("Build")
                        Spacer()
                        Text("1")
                            .foregroundColor(.secondary)
                    }
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.large)
        }
        .sheet(isPresented: $showingExportSheet) {
            ExportView()
        }
        .sheet(isPresented: $showingImportSheet) {
            ImportView()
        }
    }
}

struct ExportView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel = ExportViewModel()
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                if viewModel.isExporting {
                    VStack(spacing: 12) {
                        ProgressView("Exporting...")
                            .progressViewStyle(CircularProgressViewStyle())
                        Text("Preparing your data...")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                } else {
                    VStack(spacing: 16) {
                        // Export format description
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Export your lists and items")
                                .font(.headline)
                            Text("Choose a format to share or backup your data")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.bottom, 8)
                        
                        // Export options button
                        Button(action: {
                            viewModel.showOptionsSheet = true
                        }) {
                            HStack {
                                Image(systemName: "gearshape")
                                Text("Export Options")
                                    .font(.headline)
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .foregroundColor(.secondary)
                            }
                            .padding()
                            .background(Color.gray.opacity(0.1))
                            .cornerRadius(10)
                        }
                        .buttonStyle(.plain)
                        
                        // Export format buttons
                        Text("Export to File")
                            .font(.headline)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.top, 8)
                        
                        Button(action: {
                            viewModel.exportToJSON()
                        }) {
                            HStack {
                                Image(systemName: "doc.text")
                                VStack(alignment: .leading) {
                                    Text("Export to JSON")
                                        .font(.headline)
                                    Text("Complete data with all details")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                Spacer()
                                Image(systemName: "square.and.arrow.up")
                                    .foregroundColor(.secondary)
                            }
                            .padding()
                            .background(Color.blue.opacity(0.1))
                            .cornerRadius(10)
                        }
                        .buttonStyle(.plain)
                        
                        Button(action: {
                            viewModel.exportToCSV()
                        }) {
                            HStack {
                                Image(systemName: "tablecells")
                                VStack(alignment: .leading) {
                                    Text("Export to CSV")
                                        .font(.headline)
                                    Text("Spreadsheet-compatible format")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                Spacer()
                                Image(systemName: "square.and.arrow.up")
                                    .foregroundColor(.secondary)
                            }
                            .padding()
                            .background(Color.green.opacity(0.1))
                            .cornerRadius(10)
                        }
                        .buttonStyle(.plain)
                        
                        Button(action: {
                            viewModel.exportToPlainText()
                        }) {
                            HStack {
                                Image(systemName: "text.alignleft")
                                VStack(alignment: .leading) {
                                    Text("Export to Plain Text")
                                        .font(.headline)
                                    Text("Simple readable text format")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                Spacer()
                                Image(systemName: "square.and.arrow.up")
                                    .foregroundColor(.secondary)
                            }
                            .padding()
                            .background(Color.orange.opacity(0.1))
                            .cornerRadius(10)
                        }
                        .buttonStyle(.plain)
                        
                        // Copy to clipboard buttons
                        Text("Copy to Clipboard")
                            .font(.headline)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.top, 8)
                        
                        HStack(spacing: 12) {
                            Button(action: {
                                viewModel.copyToClipboard(format: .json)
                            }) {
                                VStack {
                                    Image(systemName: "doc.on.clipboard")
                                        .font(.title2)
                                    Text("JSON")
                                        .font(.caption)
                                }
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.blue.opacity(0.1))
                                .cornerRadius(10)
                            }
                            .buttonStyle(.plain)
                            
                            Button(action: {
                                viewModel.copyToClipboard(format: .csv)
                            }) {
                                VStack {
                                    Image(systemName: "doc.on.clipboard")
                                        .font(.title2)
                                    Text("CSV")
                                        .font(.caption)
                                }
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.green.opacity(0.1))
                                .cornerRadius(10)
                            }
                            .buttonStyle(.plain)
                            
                            Button(action: {
                                viewModel.copyToClipboard(format: .plainText)
                            }) {
                                VStack {
                                    Image(systemName: "doc.on.clipboard")
                                        .font(.title2)
                                    Text("Text")
                                        .font(.caption)
                                }
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.orange.opacity(0.1))
                                .cornerRadius(10)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    
                    // Status messages
                    if let errorMessage = viewModel.errorMessage {
                        Text(errorMessage)
                            .font(.caption)
                            .foregroundColor(.red)
                            .padding(.top, 8)
                    }
                    
                    if let successMessage = viewModel.successMessage {
                        HStack {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                            Text(successMessage)
                                .font(.caption)
                                .foregroundColor(.green)
                        }
                        .padding(.top, 8)
                    }
                }
                
                Spacer()
            }
            .padding()
            .navigationTitle("Export Data")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        viewModel.cleanup()
                        dismiss()
                    }
                }
            }
            .sheet(isPresented: $viewModel.showShareSheet) {
                if let fileURL = viewModel.exportedFileURL {
                    ShareSheet(items: [fileURL])
                }
            }
            .sheet(isPresented: $viewModel.showOptionsSheet) {
                ExportOptionsView(options: $viewModel.exportOptions)
            }
            .onDisappear {
                viewModel.cleanup()
            }
        }
    }
}

// MARK: - Export Options View

struct ExportOptionsView: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var options: ExportOptions
    
    var body: some View {
        NavigationView {
            Form {
                Section("Include in Export") {
                    Toggle("Crossed Out Items", isOn: $options.includeCrossedOutItems)
                    Toggle("Item Descriptions", isOn: $options.includeDescriptions)
                    Toggle("Item Quantities", isOn: $options.includeQuantities)
                    Toggle("Dates", isOn: $options.includeDates)
                    Toggle("Archived Lists", isOn: $options.includeArchivedLists)
                }
                
                Section {
                    Button("Reset to Default") {
                        options = .default
                    }
                    
                    Button("Use Minimal Options") {
                        options = .minimal
                    }
                }
                
                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("About Export Options")
                            .font(.headline)
                        Text("Customize what data to include in your export. Default includes everything, while minimal exports only essential information.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .navigationTitle("Export Options")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

// MARK: - Share Sheet

struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]
    
    func makeUIViewController(context: Context) -> UIActivityViewController {
        let controller = UIActivityViewController(activityItems: items, applicationActivities: nil)
        return controller
    }
    
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {
        // No updates needed
    }
}

struct ImportView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel = ImportViewModel()
    @FocusState private var isTextFieldFocused: Bool
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    // Import Source Selection
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Import Source")
                            .font(.headline)
                        
                        Picker("Import Source", selection: $viewModel.importSource) {
                            Text("From File").tag(ImportSource.file)
                            Text("From Text").tag(ImportSource.text)
                        }
                        .pickerStyle(SegmentedPickerStyle())
                    }
                    
                    // Merge Strategy Selection
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Import Strategy")
                            .font(.headline)
                        
                        ForEach(viewModel.strategyOptions, id: \.self) { strategy in
                            Button(action: {
                                viewModel.selectedStrategy = strategy
                            }) {
                                HStack(spacing: 12) {
                                    Image(systemName: viewModel.strategyIcon(strategy))
                                        .font(.title2)
                                        .foregroundColor(viewModel.selectedStrategy == strategy ? .blue : .gray)
                                        .frame(width: 30)
                                    
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(viewModel.strategyName(strategy))
                                            .font(.body)
                                            .fontWeight(.medium)
                                            .foregroundColor(.primary)
                                        
                                        Text(viewModel.strategyDescription(strategy))
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                    
                                    Spacer()
                                    
                                    if viewModel.selectedStrategy == strategy {
                                        Image(systemName: "checkmark.circle.fill")
                                            .foregroundColor(.blue)
                                    }
                                }
                                .padding()
                                .background(
                                    RoundedRectangle(cornerRadius: 12)
                                        .fill(viewModel.selectedStrategy == strategy ? Color.blue.opacity(0.1) : Color.gray.opacity(0.05))
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(viewModel.selectedStrategy == strategy ? Color.blue : Color.clear, lineWidth: 2)
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    
                    // Import Source-Specific UI
                    if viewModel.importSource == .file {
                        // File Import Button
                        Button(action: {
                            viewModel.showFilePicker = true
                        }) {
                            HStack {
                                Image(systemName: "square.and.arrow.down")
                                Text("Select File to Import")
                            }
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.blue)
                            .foregroundColor(.white)
                            .cornerRadius(12)
                        }
                        .disabled(viewModel.isImporting)
                    } else {
                        // Text Import UI
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Paste Data")
                                .font(.headline)
                            
                            Text("Supports JSON or plain text (one item per line)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            
                            ZStack(alignment: .topLeading) {
                                if viewModel.importText.isEmpty {
                                    Text("Paste your data here...\n\nExamples:\n• JSON export format\n• Plain text lists\n• One item per line\n• Markdown checkboxes")
                                        .foregroundColor(.gray.opacity(0.5))
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 12)
                                }
                                
                                TextEditor(text: $viewModel.importText)
                                    .frame(minHeight: 200, maxHeight: 300)
                                    .focused($isTextFieldFocused)
                                    .font(.system(.body, design: .monospaced))
                                    .autocapitalization(.none)
                                    .disableAutocorrection(true)
                            }
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                            )
                            
                            HStack {
                                Button(action: {
                                    viewModel.importText = ""
                                }) {
                                    HStack {
                                        Image(systemName: "trash")
                                        Text("Clear")
                                    }
                                    .foregroundColor(.red)
                                }
                                .disabled(viewModel.importText.isEmpty)
                                
                                Spacer()
                                
                                Button(action: {
                                    // Paste from clipboard
                                    if let clipboardText = UIPasteboard.general.string {
                                        viewModel.importText = clipboardText
                                    }
                                }) {
                                    HStack {
                                        Image(systemName: "doc.on.clipboard")
                                        Text("Paste")
                                    }
                                }
                            }
                            .font(.subheadline)
                            
                            Button(action: {
                                isTextFieldFocused = false
                                viewModel.showPreviewForText()
                            }) {
                                HStack {
                                    Image(systemName: "square.and.arrow.down")
                                    Text("Import from Text")
                                }
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.blue)
                                .foregroundColor(.white)
                                .cornerRadius(12)
                            }
                            .disabled(viewModel.isImporting || viewModel.importText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                        }
                    }
                    
                    // Status Messages
                    if let errorMessage = viewModel.errorMessage {
                        HStack(alignment: .top, spacing: 12) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundColor(.red)
                            Text(errorMessage)
                                .font(.caption)
                                .foregroundColor(.red)
                        }
                        .padding()
                        .background(Color.red.opacity(0.1))
                        .cornerRadius(8)
                    }
                    
                    if let successMessage = viewModel.successMessage {
                        HStack(alignment: .top, spacing: 12) {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                            Text(successMessage)
                                .font(.caption)
                                .foregroundColor(.green)
                        }
                        .padding()
                        .background(Color.green.opacity(0.1))
                        .cornerRadius(8)
                    }
                    
                    if viewModel.isImporting {
                        VStack(spacing: 12) {
                            if let progress = viewModel.importProgress {
                                // Detailed progress
                                VStack(spacing: 8) {
                                    HStack {
                                        Text("Importing...")
                                            .font(.headline)
                                        Spacer()
                                        Text("\(progress.progressPercentage)%")
                                            .font(.subheadline)
                                            .foregroundColor(.secondary)
                                    }
                                    
                                    ProgressView(value: progress.overallProgress)
                                        .progressViewStyle(LinearProgressViewStyle())
                                    
                                    Text(progress.currentOperation)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                    
                                    HStack {
                                        Text("Lists: \(progress.processedLists)/\(progress.totalLists)")
                                            .font(.caption2)
                                        Spacer()
                                        Text("Items: \(progress.processedItems)/\(progress.totalItems)")
                                            .font(.caption2)
                                    }
                                    .foregroundColor(.secondary)
                                }
                            } else {
                                // Simple progress
                                HStack(spacing: 12) {
                                    ProgressView()
                                    Text("Importing...")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(Color.blue.opacity(0.1))
                        .cornerRadius(8)
                    }
                    
                    Spacer()
                }
                .padding()
            }
            .navigationTitle("Import Data")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        viewModel.cleanup()
                        dismiss()
                    }
                }
            }
            .fileImporter(
                isPresented: $viewModel.showFilePicker,
                allowedContentTypes: [.json],
                allowsMultipleSelection: false
            ) { result in
                switch result {
                case .success(let urls):
                    if let url = urls.first {
                        viewModel.showPreviewForFile(url)
                    }
                case .failure(let error):
                    viewModel.errorMessage = "Failed to select file: \(error.localizedDescription)"
                }
            }
            .sheet(isPresented: $viewModel.showPreview) {
                if let preview = viewModel.importPreview {
                    ImportPreviewView(preview: preview, viewModel: viewModel)
                }
            }
            .onChange(of: viewModel.shouldDismiss) { shouldDismiss in
                if shouldDismiss {
                    dismiss()
                }
            }
            .onDisappear {
                viewModel.cleanup()
            }
        }
    }
}

// MARK: - Import Preview View

struct ImportPreviewView: View {
    let preview: ImportPreview
    @ObservedObject var viewModel: ImportViewModel
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Summary Card
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Import Summary")
                            .font(.headline)
                        
                        if preview.listsToCreate > 0 {
                            HStack {
                                Image(systemName: "plus.circle.fill")
                                    .foregroundColor(.green)
                                Text("\(preview.listsToCreate) new \(preview.listsToCreate == 1 ? "list" : "lists")")
                            }
                        }
                        
                        if preview.listsToUpdate > 0 {
                            HStack {
                                Image(systemName: "arrow.triangle.2.circlepath")
                                    .foregroundColor(.orange)
                                Text("\(preview.listsToUpdate) \(preview.listsToUpdate == 1 ? "list" : "lists") to update")
                            }
                        }
                        
                        if preview.itemsToCreate > 0 {
                            HStack {
                                Image(systemName: "plus.circle.fill")
                                    .foregroundColor(.green)
                                Text("\(preview.itemsToCreate) new \(preview.itemsToCreate == 1 ? "item" : "items")")
                            }
                        }
                        
                        if preview.itemsToUpdate > 0 {
                            HStack {
                                Image(systemName: "arrow.triangle.2.circlepath")
                                    .foregroundColor(.orange)
                                Text("\(preview.itemsToUpdate) \(preview.itemsToUpdate == 1 ? "item" : "items") to update")
                            }
                        }
                    }
                    .padding()
                    .background(Color.blue.opacity(0.1))
                    .cornerRadius(12)
                    
                    // Conflicts Section
                    if preview.hasConflicts {
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .foregroundColor(.orange)
                                Text("Conflicts (\(preview.conflicts.count))")
                                    .font(.headline)
                            }
                            
                            ForEach(Array(preview.conflicts.prefix(5).enumerated()), id: \.offset) { _, conflict in
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(conflict.entityName)
                                        .font(.subheadline)
                                        .fontWeight(.medium)
                                    Text(conflict.message)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                .padding(.vertical, 4)
                            }
                            
                            if preview.conflicts.count > 5 {
                                Text("And \(preview.conflicts.count - 5) more...")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                        .padding()
                        .background(Color.orange.opacity(0.1))
                        .cornerRadius(12)
                    }
                    
                    // Strategy Info
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Import Strategy")
                            .font(.headline)
                        HStack {
                            Image(systemName: viewModel.strategyIcon(viewModel.selectedStrategy))
                            Text(viewModel.strategyName(viewModel.selectedStrategy))
                                .font(.subheadline)
                        }
                        Text(viewModel.strategyDescription(viewModel.selectedStrategy))
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding()
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(12)
                    
                    // Action Buttons
                    VStack(spacing: 12) {
                        Button(action: {
                            dismiss()
                            viewModel.confirmImport()
                        }) {
                            HStack {
                                Image(systemName: "checkmark.circle.fill")
                                Text("Confirm Import")
                            }
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.blue)
                            .foregroundColor(.white)
                            .cornerRadius(12)
                        }
                        
                        Button(action: {
                            dismiss()
                            viewModel.cancelPreview()
                        }) {
                            Text("Cancel")
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.gray.opacity(0.2))
                                .foregroundColor(.primary)
                                .cornerRadius(12)
                        }
                    }
                }
                .padding()
            }
            .navigationTitle("Import Preview")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

#Preview {
    SettingsView()
}
