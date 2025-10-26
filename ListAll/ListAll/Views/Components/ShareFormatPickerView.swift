import SwiftUI

/// View for selecting share format and options
struct ShareFormatPickerView: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var selectedFormat: ShareFormat
    @Binding var shareOptions: ShareOptions
    @State private var showingOptionsSheet = false
    let onShare: (ShareFormat, ShareOptions) -> Void
    
    init(
        selectedFormat: Binding<ShareFormat>,
        shareOptions: Binding<ShareOptions>,
        onShare: @escaping (ShareFormat, ShareOptions) -> Void
    ) {
        self._selectedFormat = selectedFormat
        self._shareOptions = shareOptions
        self.onShare = onShare
    }
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text(String(localized: "Select Format"))) {
                    FormatOptionRow(
                        title: String(localized: "Plain Text"),
                        description: String(localized: "Simple text format, easy to read"),
                        icon: "doc.text",
                        isSelected: selectedFormat == .plainText,
                        onTap: { selectedFormat = .plainText }
                    )
                    
                    FormatOptionRow(
                        title: String(localized: "JSON"),
                        description: String(localized: "Structured data format"),
                        icon: "doc.badge.gearshape",
                        isSelected: selectedFormat == .json,
                        onTap: { selectedFormat = .json }
                    )
                }
                
                Section(header: Text(String(localized: "Share Options"))) {
                    Toggle(String(localized: "Include Crossed Out Items"), isOn: $shareOptions.includeCrossedOutItems)
                    Toggle(String(localized: "Include Descriptions"), isOn: $shareOptions.includeDescriptions)
                    Toggle(String(localized: "Include Quantities"), isOn: $shareOptions.includeQuantities)
                    Toggle(String(localized: "Include Dates"), isOn: $shareOptions.includeDates)
                    
                    if selectedFormat == .json {
                        Toggle(String(localized: "Include Images"), isOn: $shareOptions.includeImages)
                            .help(String(localized: "Images will be embedded as base64 in JSON"))
                    }
                }
                
                Section {
                    Button(String(localized: "Use Default Options")) {
                        shareOptions = .default
                    }
                    
                    Button(String(localized: "Use Minimal Options")) {
                        shareOptions = .minimal
                    }
                }
            }
            .navigationTitle(String(localized: "Share"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(String(localized: "Cancel")) {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(String(localized: "Share")) {
                        onShare(selectedFormat, shareOptions)
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
        }
    }
}

/// Row component for format selection
struct FormatOptionRow: View {
    let title: String
    let description: String
    let icon: String
    let isSelected: Bool
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: Theme.Spacing.md) {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundColor(isSelected ? Theme.Colors.primary : Theme.Colors.secondary)
                    .frame(width: 32)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(Theme.Typography.body)
                        .foregroundColor(.primary)
                    
                    Text(description)
                        .font(Theme.Typography.caption)
                        .foregroundColor(Theme.Colors.secondary)
                }
                
                Spacer()
                
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(Theme.Colors.primary)
                }
            }
            .padding(.vertical, 4)
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    ShareFormatPickerView(
        selectedFormat: .constant(.plainText),
        shareOptions: .constant(.default),
        onShare: { _, _ in }
    )
}

