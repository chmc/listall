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
                Section(header: Text("Select Format")) {
                    FormatOptionRow(
                        title: "Plain Text",
                        description: "Simple text format, easy to read",
                        icon: "doc.text",
                        isSelected: selectedFormat == .plainText,
                        onTap: { selectedFormat = .plainText }
                    )
                    
                    FormatOptionRow(
                        title: "JSON",
                        description: "Structured data format",
                        icon: "doc.badge.gearshape",
                        isSelected: selectedFormat == .json,
                        onTap: { selectedFormat = .json }
                    )
                }
                
                Section(header: Text("Share Options")) {
                    Toggle("Include Crossed Out Items", isOn: $shareOptions.includeCrossedOutItems)
                    Toggle("Include Descriptions", isOn: $shareOptions.includeDescriptions)
                    Toggle("Include Quantities", isOn: $shareOptions.includeQuantities)
                    Toggle("Include Dates", isOn: $shareOptions.includeDates)
                }
                
                Section {
                    Button("Use Default Options") {
                        shareOptions = .default
                    }
                    
                    Button("Use Minimal Options") {
                        shareOptions = .minimal
                    }
                }
            }
            .navigationTitle("Share")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Share") {
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

