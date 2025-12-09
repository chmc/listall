//
//  MacShareFormatPickerView.swift
//  ListAllMac
//
//  macOS-specific share format picker UI component.
//  Reuses shared SharingService for all business logic (DRY principle).
//

import SwiftUI
import AppKit

/// macOS-specific share format picker view
/// This view provides UI for selecting share format and options before sharing a list.
/// All actual sharing logic is handled by the shared SharingService.
struct MacShareFormatPickerView: View {
    let list: List
    let onDismiss: () -> Void

    @State private var selectedFormat: ShareFormat = .plainText
    @State private var shareOptions: ShareOptions = .default
    @State private var isSharing = false
    @State private var shareError: String?

    // Use shared SharingService (reuses existing macOS support)
    private let sharingService = SharingService()

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header
            HStack {
                Text("Share List")
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

                FormatOptionRow(
                    format: .plainText,
                    title: "Plain Text",
                    description: "Simple text format, easy to paste anywhere",
                    icon: "doc.text",
                    isSelected: selectedFormat == .plainText,
                    onSelect: { selectedFormat = .plainText }
                )

                FormatOptionRow(
                    format: .json,
                    title: "JSON",
                    description: "Full data export with all details",
                    icon: "doc.badge.gearshape",
                    isSelected: selectedFormat == .json,
                    onSelect: { selectedFormat = .json }
                )
            }

            Divider()

            // Options Section
            VStack(alignment: .leading, spacing: 8) {
                Text("Options")
                    .font(.subheadline)
                    .foregroundColor(.secondary)

                Toggle("Include crossed-out items", isOn: $shareOptions.includeCrossedOutItems)
                Toggle("Include descriptions", isOn: $shareOptions.includeDescriptions)
                Toggle("Include quantities", isOn: $shareOptions.includeQuantities)
                Toggle("Include dates", isOn: $shareOptions.includeDates)

                if selectedFormat == .json {
                    Toggle("Include images", isOn: $shareOptions.includeImages)
                        .help("Images are base64 encoded in JSON format")
                }
            }

            Divider()

            // Presets
            HStack(spacing: 12) {
                Button("Default") {
                    shareOptions = .default
                }
                .buttonStyle(.bordered)

                Button("Minimal") {
                    shareOptions = .minimal
                }
                .buttonStyle(.bordered)
            }

            // Error display
            if let error = shareError {
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
                    copyToClipboard()
                }
                .buttonStyle(.bordered)
                .keyboardShortcut("c", modifiers: .command)
                .help("Copy list content to clipboard (⌘C)")

                Spacer()

                Button("Cancel") {
                    onDismiss()
                }
                .keyboardShortcut(.escape)

                Button("Share...") {
                    showSharePicker()
                }
                .keyboardShortcut(.return)
                .buttonStyle(.borderedProminent)
                .disabled(isSharing)
            }
        }
        .padding()
        .frame(width: 340)
    }

    // MARK: - Actions

    /// Copies list content to clipboard in selected format
    private func copyToClipboard() {
        shareError = nil

        guard let result = sharingService.shareList(list, format: selectedFormat, options: shareOptions) else {
            shareError = sharingService.shareError ?? "Failed to create share content"
            return
        }

        let success: Bool
        if let text = result.content as? String {
            success = sharingService.copyToClipboard(text: text)
        } else if let nsString = result.content as? NSString {
            success = sharingService.copyToClipboard(text: nsString as String)
        } else if let url = result.content as? URL {
            // For JSON files, read content and copy
            if let data = try? Data(contentsOf: url),
               let text = String(data: data, encoding: .utf8) {
                success = sharingService.copyToClipboard(text: text)
            } else {
                shareError = "Failed to read file content"
                return
            }
        } else {
            shareError = "Unknown content type"
            return
        }

        if success {
            onDismiss()
        } else {
            shareError = "Failed to copy to clipboard"
        }
    }

    /// Shows native macOS share picker
    private func showSharePicker() {
        shareError = nil
        isSharing = true

        guard let result = sharingService.shareList(list, format: selectedFormat, options: shareOptions) else {
            shareError = sharingService.shareError ?? "Failed to create share content"
            isSharing = false
            return
        }

        // Prepare items for sharing
        var items: [Any] = []
        if let text = result.content as? String {
            items.append(text)
        } else if let nsString = result.content as? NSString {
            items.append(nsString as String)
        } else if let url = result.content as? URL {
            items.append(url)
        }

        guard !items.isEmpty else {
            shareError = "No content to share"
            isSharing = false
            return
        }

        // Get the key window and its content view for picker positioning
        guard let window = NSApp.keyWindow,
              let contentView = window.contentView else {
            shareError = "Could not access window for sharing"
            isSharing = false
            return
        }

        // Create and show NSSharingServicePicker
        let picker = NSSharingServicePicker(items: items)
        picker.delegate = SharePickerDelegate.shared

        // Position picker at center-bottom of window
        let rect = NSRect(
            x: contentView.bounds.midX - 1,
            y: contentView.bounds.midY,
            width: 2,
            height: 2
        )

        picker.show(relativeTo: rect, of: contentView, preferredEdge: .minY)

        // Dismiss our popover after showing picker
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            isSharing = false
            onDismiss()
        }
    }
}

// MARK: - Format Option Row

private struct FormatOptionRow: View {
    let format: ShareFormat
    let title: String
    let description: String
    let icon: String
    let isSelected: Bool
    let onSelect: () -> Void

    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 12) {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundColor(isSelected ? .accentColor : .secondary)

                Image(systemName: icon)
                    .frame(width: 20)
                    .foregroundColor(.secondary)

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .fontWeight(isSelected ? .medium : .regular)
                    Text(description)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Spacer()
            }
            .padding(.vertical, 6)
            .padding(.horizontal, 8)
            .background(isSelected ? Color.accentColor.opacity(0.1) : Color.clear)
            .cornerRadius(6)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Share Picker Delegate

/// Delegate for NSSharingServicePicker to handle completion
private class SharePickerDelegate: NSObject, NSSharingServicePickerDelegate {
    static let shared = SharePickerDelegate()

    func sharingServicePicker(_ sharingServicePicker: NSSharingServicePicker, didChoose service: NSSharingService?) {
        // Service was chosen or picker was dismissed
        if service != nil {
            print("📤 Share service selected: \(service?.title ?? "unknown")")
        }
    }
}

// MARK: - Preview

#Preview {
    MacShareFormatPickerView(
        list: List(name: "Test List"),
        onDismiss: {}
    )
}
