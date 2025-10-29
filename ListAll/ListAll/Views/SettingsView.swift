import SwiftUI

struct SettingsView: View {
    @State private var showingExportSheet = false
    @State private var showingImportSheet = false
    @State private var showingResetTooltipsAlert = false
    @State private var showingAllTips = false
    @State private var showingLanguageRestartAlert = false
    @AppStorage(Constants.UserDefaultsKeys.addButtonPosition) private var addButtonPositionRaw: String = Constants.AddButtonPosition.right.rawValue
    @AppStorage(Constants.UserDefaultsKeys.requiresBiometricAuth) private var requiresBiometricAuth = false
    @AppStorage(Constants.UserDefaultsKeys.authTimeoutDuration) private var authTimeoutDurationRaw: Int = Constants.AuthTimeoutDuration.immediate.rawValue
    @StateObject private var biometricService = BiometricAuthService.shared
    @StateObject private var hapticManager = HapticManager.shared
    @StateObject private var tooltipManager = TooltipManager.shared
    @StateObject private var localizationManager = LocalizationManager.shared
    
    private var addButtonPosition: Binding<Constants.AddButtonPosition> {
        Binding(
            get: { Constants.AddButtonPosition(rawValue: addButtonPositionRaw) ?? .right },
            set: { addButtonPositionRaw = $0.rawValue }
        )
    }
    
    private var authTimeoutDuration: Binding<Constants.AuthTimeoutDuration> {
        Binding(
            get: { Constants.AuthTimeoutDuration(rawValue: authTimeoutDurationRaw) ?? .immediate },
            set: { authTimeoutDurationRaw = $0.rawValue }
        )
    }
    
    private var biometricType: BiometricType {
        biometricService.biometricType()
    }
    
    // MARK: - App Version Helper
    private var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "-"
    }
    var body: some View {
        NavigationView {
            SwiftUI.List {
                Section(header: Text("Language"), footer: Text("Change the app language. You may need to restart the app for all changes to take effect.")) {
                    Picker("App Language", selection: Binding(
                        get: { localizationManager.currentLanguage },
                        set: { newLanguage in
                            localizationManager.setLanguage(newLanguage)
                            showingLanguageRestartAlert = true
                        }
                    )) {
                        ForEach(LocalizationManager.AppLanguage.allCases) { language in
                            HStack {
                                Text(language.flagEmoji)
                                Text(language.nativeDisplayName)
                            }
                            .tag(language)
                        }
                    }
                    .pickerStyle(.navigationLink)
                }
                
                Section(header: Text("Display"), footer: Text("Haptic feedback provides tactile responses for app interactions")) {
                    Picker("Add item button position", selection: addButtonPosition) {
                        ForEach(Constants.AddButtonPosition.allCases) { position in
                            Text(position.displayName).tag(position)
                        }
                    }
                    
                    Toggle(isOn: $hapticManager.isEnabled) {
                        HStack {
                            Image(systemName: "waveform")
                                .foregroundColor(.purple)
                            Text("Haptic Feedback")
                        }
                    }
                }
                
                Section(header: Text("Help & Tips"), footer: helpFooterText) {
                    HStack {
                        Image(systemName: "lightbulb.fill")
                            .foregroundColor(.yellow)
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Feature Tips")
                                .font(.body)
                            Text("\(tooltipManager.shownTooltipCount()) of \(tooltipManager.totalTooltipCount()) tips viewed")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                    }
                    
                    Button(action: {
                        showingAllTips = true
                    }) {
                        HStack {
                            Image(systemName: "list.bullet")
                                .foregroundColor(.blue)
                            Text("View All Feature Tips")
                                .foregroundColor(.primary)
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    Button(action: {
                        showingResetTooltipsAlert = true
                    }) {
                        HStack {
                            Image(systemName: "arrow.counterclockwise")
                                .foregroundColor(.blue)
                            Text("Show All Tips Again")
                                .foregroundColor(.primary)
                        }
                    }
                }
                
                Section(header: Text("Security"), footer: securityFooterText) {
                    if biometricType != .none {
                        Toggle(isOn: $requiresBiometricAuth) {
                            HStack {
                                Image(systemName: biometricType.iconName)
                                    .foregroundColor(.blue)
                                Text("Require \(biometricType.displayName)")
                            }
                        }
                        
                        // Show timeout setting only when biometric auth is enabled
                        if requiresBiometricAuth {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Require Authentication")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                
                                Picker("Timeout Duration", selection: authTimeoutDuration) {
                                    ForEach(Constants.AuthTimeoutDuration.allCases) { duration in
                                        VStack(alignment: .leading) {
                                            Text(duration.displayName)
                                                .font(.body)
                                            Text(duration.description)
                                                .font(.caption)
                                                .foregroundColor(.secondary)
                                        }
                                        .tag(duration)
                                    }
                                }
                                .pickerStyle(.navigationLink)
                            }
                        }
                    } else {
                        HStack {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundColor(.orange)
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Biometric authentication not available")
                                    .font(.subheadline)
                                Text("Enable Face ID or Touch ID in Settings")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
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
                            Text(appVersion)
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
        .sheet(isPresented: $showingAllTips) {
            AllFeatureTipsView()
        }
        .alert("Reset All Tips", isPresented: $showingResetTooltipsAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Reset", role: .destructive) {
                tooltipManager.resetAllTooltips()
            }
        } message: {
            Text("This will show all feature tips again as if you're using the app for the first time. Tips will appear when you use different features.")
        }
        .alert("Language Changed", isPresented: $showingLanguageRestartAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text("The language has been changed. Some changes will take effect immediately, but you may need to restart the app for all text to update.")
        }
    }
    
    private var helpFooterText: Text {
        return Text(String(localized: "Feature tips help you discover app functionality. Reset to see all tips again."))
    }
    
    private var securityFooterText: Text {
        if biometricType != .none && requiresBiometricAuth {
            let timeoutDesc = authTimeoutDuration.wrappedValue.displayName.lowercased()
            let localizedString = String(format: String(localized: "Authentication will be required %@ when returning to the app. You can use %@ or your device passcode."), timeoutDesc, biometricType.displayName)
            return Text(localizedString)
        } else if biometricType != .none {
            return Text("When enabled, you'll need to authenticate with \(biometricType.displayName) or passcode to unlock the app.")
        } else {
            return Text("Biometric authentication is not set up on this device.")
        }
    }
}

struct ExportView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel = ExportViewModel()
    
    // MARK: - App Version Helpers
    private var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "-"
    }
    private var appBuild: String {
        Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "-"
    }
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                if viewModel.isExporting {
                    VStack(spacing: 20) {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle())
                            .scaleEffect(1.5)
                        
                        VStack(spacing: 8) {
                            Text("Exporting...")
                                .font(.headline)
                            
                            if !viewModel.exportProgress.isEmpty {
                                Text(viewModel.exportProgress)
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            }
                        }
                        
                        Button(action: {
                            viewModel.cancelExport()
                        }) {
                            HStack {
                                Image(systemName: "xmark.circle.fill")
                                Text("Cancel Export")
                            }
                            .font(.headline)
                            .foregroundColor(.red)
                            .padding()
                            .frame(maxWidth: .infinity)
                            .background(Color.red.opacity(0.1))
                            .cornerRadius(10)
                        }
                        .padding(.top, 8)
                    }
                    .padding()
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
                    Toggle("Item Images", isOn: $options.includeImages)
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
                        Text(String(localized: "Import Source"))
                            .font(.headline)
                        
                        Picker(String(localized: "Import Source"), selection: $viewModel.importSource) {
                            Text(String(localized: "From File")).tag(ImportSource.file)
                            Text(String(localized: "From Text")).tag(ImportSource.text)
                        }
                        .pickerStyle(SegmentedPickerStyle())
                    }
                    
                    // Merge Strategy Selection
                    VStack(alignment: .leading, spacing: 12) {
                        Text(String(localized: "Import Strategy"))
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
                                Text(String(localized: "Select File to Import"))
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
                            Text(String(localized: "Paste Data"))
                                .font(.headline)
                            
                            Text(String(localized: "Supports JSON or plain text (one item per line)"))
                                .font(.caption)
                                .foregroundColor(.secondary)
                            
                            ZStack(alignment: .topLeading) {
                                if viewModel.importText.isEmpty {
                                    Text(String(localized: "Paste your data here...\n\nExamples:\n• JSON export format\n• Plain text lists\n• One item per line\n• Markdown checkboxes"))
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
                                        Text(String(localized: "Clear"))
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
                                        Text(String(localized: "Paste"))
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
                                    Text(String(localized: "Import from Text"))
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
                                        Text(String(localized: "Importing..."))
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
                                        Text(String(localized: "Lists: \(progress.processedLists)/\(progress.totalLists)"))
                                            .font(.caption2)
                                        Spacer()
                                        Text(String(localized: "Items: \(progress.processedItems)/\(progress.totalItems)"))
                                            .font(.caption2)
                                    }
                                    .foregroundColor(.secondary)
                                }
                            } else {
                                // Simple progress
                                HStack(spacing: 12) {
                                    ProgressView()
                                    Text(String(localized: "Importing..."))
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
            .navigationTitle(String(localized: "Import Data"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(String(localized: "Done")) {
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
        .contentShape(Rectangle())
        .onTapGesture {
            // Dismiss keyboard when tapping outside text field
            isTextFieldFocused = false
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
                        Text(String(localized: "Import Summary"))
                            .font(.headline)
                        
                        if preview.listsToCreate > 0 {
                            HStack {
                                Image(systemName: "plus.circle.fill")
                                    .foregroundColor(.green)
                                if preview.listsToCreate == 1 {
                                    Text(String(localized: "1 new list"))
                                } else {
                                    Text(String(localized: "\(preview.listsToCreate) new lists"))
                                }
                            }
                        }
                        
                        if preview.listsToUpdate > 0 {
                            HStack {
                                Image(systemName: "arrow.triangle.2.circlepath")
                                    .foregroundColor(.orange)
                                if preview.listsToUpdate == 1 {
                                    Text(String(localized: "1 list to update"))
                                } else {
                                    Text(String(localized: "\(preview.listsToUpdate) lists to update"))
                                }
                            }
                        }
                        
                        if preview.itemsToCreate > 0 {
                            HStack {
                                Image(systemName: "plus.circle.fill")
                                    .foregroundColor(.green)
                                if preview.itemsToCreate == 1 {
                                    Text(String(localized: "1 new item"))
                                } else {
                                    Text(String(localized: "\(preview.itemsToCreate) new items"))
                                }
                            }
                        }
                        
                        if preview.itemsToUpdate > 0 {
                            HStack {
                                Image(systemName: "arrow.triangle.2.circlepath")
                                    .foregroundColor(.orange)
                                if preview.itemsToUpdate == 1 {
                                    Text(String(localized: "1 item to update"))
                                } else {
                                    Text(String(localized: "\(preview.itemsToUpdate) items to update"))
                                }
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
                                Text(String(localized: "Conflicts (\(preview.conflicts.count))"))
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
                                Text(String(localized: "And \(preview.conflicts.count - 5) more..."))
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
                        Text(String(localized: "Import Strategy"))
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
                                Text(String(localized: "Confirm Import"))
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
                            Text(String(localized: "Cancel"))
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
            .navigationTitle(String(localized: "Import Preview"))
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

// MARK: - All Feature Tips View

struct AllFeatureTipsView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var tooltipManager = TooltipManager.shared
    
    var body: some View {
        NavigationView {
            SwiftUI.List {
                Section {
                    ForEach(TooltipType.allCases, id: \.rawValue) { tipType in
                        HStack(alignment: .top, spacing: Theme.Spacing.md) {
                            // Icon
                            Image(systemName: tipType.icon)
                                .font(.title2)
                                .foregroundColor(.blue)
                                .frame(width: 40)
                            
                            // Content
                            VStack(alignment: .leading, spacing: 4) {
                                HStack {
                                    Text(tipType.title)
                                        .font(Theme.Typography.headline)
                                    
                                    Spacer()
                                    
                                    // Viewed indicator
                                    if tooltipManager.hasShown(tipType) {
                                        Image(systemName: "checkmark.circle.fill")
                                            .font(.body)
                                            .foregroundColor(.green)
                                    } else {
                                        Image(systemName: "circle")
                                            .font(.body)
                                            .foregroundColor(.secondary)
                                    }
                                }
                                
                                Text(tipType.message)
                                    .font(Theme.Typography.body)
                                    .foregroundColor(.secondary)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                        .padding(.vertical, Theme.Spacing.xs)
                    }
                } header: {
                    HStack {
                        Text("All Feature Tips")
                        Spacer()
                        Text("\(tooltipManager.shownTooltipCount())/\(tooltipManager.totalTooltipCount()) viewed")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .textCase(.none)
                    }
                } footer: {
                    Text(String(localized: "Tips marked with ✓ have been viewed. Tips will appear automatically when you use features, or you can reset them to see all tips again from Settings."))
                }
            }
            .navigationTitle(String(localized: "Feature Tips"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(String(localized: "Done")) {
                        dismiss()
                    }
                }
            }
        }
    }
}

#Preview {
    SettingsView()
}
