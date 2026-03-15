import SwiftUI

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

