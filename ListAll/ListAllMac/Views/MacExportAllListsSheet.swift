//
//  MacExportAllListsSheet.swift
//  ListAllMac
//
//  Sheet for exporting all lists to file or clipboard.
//

import SwiftUI
import AppKit
import UniformTypeIdentifiers

struct MacExportAllListsSheet: View {
    let onDismiss: () -> Void

    @State private var selectedFormat: ShareFormat = .json
    @State private var exportOptions: ExportOptions = .default
    @State private var exportError: String?

    private let sharingService = SharingService()

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header
            HStack {
                Text("Export All Lists")
                    .font(.headline)
                Spacer()
                Button(action: onDismiss) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            }

            Divider()

            // Format Selection
            VStack(alignment: .leading, spacing: 8) {
                Text("Format")
                    .font(.subheadline)
                    .foregroundColor(.secondary)

                Picker("Format", selection: $selectedFormat) {
                    Text("JSON").tag(ShareFormat.json)
                    Text("Plain Text").tag(ShareFormat.plainText)
                }
                .pickerStyle(.radioGroup)
            }

            Divider()

            // Options
            VStack(alignment: .leading, spacing: 8) {
                Text("Options")
                    .font(.subheadline)
                    .foregroundColor(.secondary)

                Toggle("Include crossed-out items", isOn: $exportOptions.includeCrossedOutItems)
                Toggle("Include archived lists", isOn: $exportOptions.includeArchivedLists)
                Toggle("Include images", isOn: $exportOptions.includeImages)
                    .disabled(selectedFormat == .plainText)
                    .help(selectedFormat == .plainText ? "Images cannot be included in plain text format" : "Include item images in export")
            }

            // Error display
            if let error = exportError {
                HStack {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.orange)
                    Text(error)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            Divider()

            // Actions
            HStack {
                Button("Copy to Clipboard") {
                    copyAllToClipboard()
                }
                .buttonStyle(.bordered)

                Spacer()

                Button("Cancel") {
                    onDismiss()
                }
                .keyboardShortcut(.escape)

                Button("Export...") {
                    exportToFile()
                }
                .keyboardShortcut(.return)
                .buttonStyle(.borderedProminent)
            }
        }
        .padding()
        .frame(width: 360)
    }

    private func copyAllToClipboard() {
        exportError = nil

        guard let result = sharingService.shareAllData(format: selectedFormat, exportOptions: exportOptions) else {
            exportError = sharingService.shareError ?? "Failed to export data"
            return
        }

        let success: Bool
        if let text = result.content as? String {
            success = sharingService.copyToClipboard(text: text)
        } else if let nsString = result.content as? NSString {
            success = sharingService.copyToClipboard(text: nsString as String)
        } else if let url = result.content as? URL,
                  let data = try? Data(contentsOf: url),
                  let text = String(data: data, encoding: .utf8) {
            success = sharingService.copyToClipboard(text: text)
        } else {
            exportError = "Unknown content type"
            return
        }

        if success {
            onDismiss()
        } else {
            exportError = "Failed to copy to clipboard"
        }
    }

    private func exportToFile() {
        exportError = nil

        guard let result = sharingService.shareAllData(format: selectedFormat, exportOptions: exportOptions) else {
            exportError = sharingService.shareError ?? "Failed to export data"
            return
        }

        // Show save panel
        let savePanel = NSSavePanel()
        savePanel.allowedContentTypes = selectedFormat == .json ?
            [.json] : [.plainText]
        savePanel.nameFieldStringValue = result.fileName ?? "ListAll-Export"
        savePanel.canCreateDirectories = true

        savePanel.begin { response in
            guard response == .OK, let url = savePanel.url else { return }

            do {
                if let sourceURL = result.content as? URL {
                    try FileManager.default.copyItem(at: sourceURL, to: url)
                } else if let text = result.content as? String {
                    try text.write(to: url, atomically: true, encoding: .utf8)
                } else if let nsString = result.content as? NSString {
                    try (nsString as String).write(to: url, atomically: true, encoding: .utf8)
                }

                DispatchQueue.main.async {
                    onDismiss()
                }
            } catch {
                DispatchQueue.main.async {
                    exportError = "Failed to save file: \(error.localizedDescription)"
                }
            }
        }
    }
}
