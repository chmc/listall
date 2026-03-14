//
//  MacSettingsDataTab.swift
//  ListAllMac
//
//  Data import/export settings tab for macOS preferences.
//

import SwiftUI
import UniformTypeIdentifiers

struct MacSettingsDataTab: View {
    @StateObject private var importViewModel = ImportViewModel()
    @State private var showingFilePicker = false

    var body: some View {
        Form {
            Section {
                Button("Export Data...") {
                    NotificationCenter.default.post(
                        name: NSNotification.Name("ExportData"),
                        object: nil
                    )
                }
                .foregroundColor(Theme.Colors.primary)
                .accessibilityHint("Opens export options")

                Button("Import Data...") {
                    showingFilePicker = true
                }
                .foregroundColor(Theme.Colors.primary)
                .accessibilityHint("Opens file picker to import data")
                .disabled(importViewModel.isImporting)
            } header: {
                Text("Import / Export")
                    .accessibilityAddTraits(.isHeader)
            }

            // Import Progress Section
            if importViewModel.isImporting {
                Section {
                    if let progress = importViewModel.importProgress {
                        MacImportProgressView(progress: progress)
                    } else {
                        MacImportProgressSimpleView()
                    }
                }
            }

            // Status Messages
            if let errorMessage = importViewModel.errorMessage {
                Section {
                    HStack(alignment: .top, spacing: 8) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(.red)
                            .accessibilityHidden(true)
                        Text(errorMessage)
                            .font(.caption)
                            .foregroundColor(.red)
                    }
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel("Error: \(errorMessage)")
                }
            }

            if let successMessage = importViewModel.successMessage {
                Section {
                    HStack(alignment: .top, spacing: 8) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                            .accessibilityHidden(true)
                        Text(successMessage)
                            .font(.caption)
                            .foregroundColor(.green)
                    }
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel("Success: \(successMessage)")
                }
            }
        }
        .formStyle(.grouped)
        .padding(.horizontal, -20)
        .fileImporter(
            isPresented: $showingFilePicker,
            allowedContentTypes: [.json],
            allowsMultipleSelection: false
        ) { result in
            handleFileImportResult(result)
        }
        .onChange(of: importViewModel.showPreview) {
            if importViewModel.showPreview, let preview = importViewModel.importPreview {
                presentImportPreview(preview)
            }
        }
    }

    // MARK: - Private Methods

    private func handleFileImportResult(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            if let url = urls.first {
                importViewModel.showPreviewForFile(url)
            }
        case .failure(let error):
            importViewModel.errorMessage = "Failed to select file: \(error.localizedDescription)"
        }
    }

    private func presentImportPreview(_ preview: ImportPreview) {
        // Use native sheet presenter for reliable presentation
        let previewSheet = MacImportPreviewSheet(
            preview: preview,
            viewModel: importViewModel,
            onDismiss: {
                MacNativeSheetPresenter.shared.dismissSheet()
            }
        )

        MacNativeSheetPresenter.shared.presentSheet(
            previewSheet,
            onCancel: {
                MacNativeSheetPresenter.shared.dismissSheet()
                importViewModel.cancelPreview()
            }
        )
    }
}
