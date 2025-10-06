import SwiftUI

// MARK: - Alert Type Enum
enum ListRowAlert: Identifiable {
    case delete
    case duplicate
    case shareError(String)
    
    var id: String {
        switch self {
        case .delete: return "delete"
        case .duplicate: return "duplicate"
        case .shareError: return "shareError"
        }
    }
}

struct ListRowView: View {
    let list: List
    @ObservedObject var mainViewModel: MainViewModel
    @StateObject private var sharingService = SharingService()
    @State private var showingEditSheet = false
    @State private var activeAlert: ListRowAlert?
    @State private var showingShareFormatPicker = false
    @State private var showingShareSheet = false
    @State private var selectedShareFormat: ShareFormat = .plainText
    @State private var shareOptions: ShareOptions = .default
    @State private var shareFileURL: URL?
    @State private var shareItems: [Any] = []
    
    private var listContent: some View {
        HStack {
            VStack(alignment: .leading, spacing: 1) {
                Text(list.name)
                    .font(Theme.Typography.headline)
                    .foregroundColor(.primary)
                
                Text("\(list.activeItemCount) (\(list.itemCount)) items")
                    .font(Theme.Typography.caption)
                    .foregroundColor(Theme.Colors.secondary)
            }
            
            Spacer()
        }
        .padding(.vertical, 8)
        .contentShape(Rectangle())
    }
    
    var body: some View {
        HStack {
            // Selection indicator
            if mainViewModel.isInSelectionMode {
                Button(action: {
                    mainViewModel.toggleSelection(for: list.id)
                }) {
                    Image(systemName: mainViewModel.selectedLists.contains(list.id) ? "checkmark.circle.fill" : "circle")
                        .foregroundColor(mainViewModel.selectedLists.contains(list.id) ? .blue : .gray)
                        .imageScale(.large)
                }
                .buttonStyle(BorderlessButtonStyle())
            }
            
            // List content
            if mainViewModel.isInSelectionMode {
                // In selection mode: Make entire row tappable for selection
                Button(action: {
                    mainViewModel.toggleSelection(for: list.id)
                }) {
                    listContent
                }
                .buttonStyle(PlainButtonStyle())
            } else {
                // Normal mode: Use NavigationLink
                NavigationLink(destination: ListView(list: list, mainViewModel: mainViewModel)) {
                    listContent
                }
            }
        }
        .padding(.horizontal, Theme.Spacing.md)
        .if(!mainViewModel.isInSelectionMode) { view in
            view.contextMenu {
                Button(action: {
                    showingShareFormatPicker = true
                }) {
                    Label("Share", systemImage: "square.and.arrow.up")
                }
                
                Button(action: {
                    showingEditSheet = true
                }) {
                    Label("Edit", systemImage: "pencil")
                }
                
                Button(action: {
                    activeAlert = .duplicate
                }) {
                    Label("Duplicate", systemImage: "doc.on.doc")
                }
                
                Button(role: .destructive, action: {
                    activeAlert = .delete
                }) {
                    Label("Delete", systemImage: "trash")
                }
            }
        }
        .if(!mainViewModel.isInSelectionMode) { view in
            view.swipeActions(edge: .trailing) {
                Button(role: .destructive, action: {
                    activeAlert = .delete
                }) {
                    Label("Delete", systemImage: "trash")
                }
            }
        }
        .if(!mainViewModel.isInSelectionMode) { view in
            view.swipeActions(edge: .leading) {
                Button(action: {
                    showingShareFormatPicker = true
                }) {
                    Label("Share", systemImage: "square.and.arrow.up")
                }
                .tint(.orange)
                
                Button(action: {
                    activeAlert = .duplicate
                }) {
                    Label("Duplicate", systemImage: "doc.on.doc")
                }
                .tint(.green)
                
                Button(action: {
                    showingEditSheet = true
                }) {
                    Label("Edit", systemImage: "pencil")
                }
                .tint(.blue)
            }
        }
        .sheet(isPresented: $showingEditSheet) {
            EditListView(list: list, mainViewModel: mainViewModel)
        }
        .sheet(isPresented: $showingShareFormatPicker) {
            ShareFormatPickerView(
                selectedFormat: $selectedShareFormat,
                shareOptions: $shareOptions,
                onShare: { format, options in
                    handleShare(format: format, options: options)
                }
            )
        }
        .background(
            Group {
                if showingShareSheet && !shareItems.isEmpty {
                    ActivityViewController(activityItems: shareItems) {
                        showingShareSheet = false
                        shareItems = []
                    }
                }
            }
        )
        .alert(item: $activeAlert) { alertType in
            switch alertType {
            case .delete:
                return Alert(
                    title: Text("Delete List"),
                    message: Text("Are you sure you want to delete \"\(list.name)\"? This action cannot be undone."),
                    primaryButton: .destructive(Text("Delete")) {
                        mainViewModel.deleteList(list)
                    },
                    secondaryButton: .cancel()
                )
            case .duplicate:
                return Alert(
                    title: Text("Duplicate List"),
                    message: Text("This will create a copy of \"\(list.name)\" with all its items."),
                    primaryButton: .default(Text("Duplicate")) {
                        do {
                            try mainViewModel.duplicateList(list)
                        } catch {
                            // Handle error (could add error alert here if needed)
                            print("Error duplicating list: \(error)")
                        }
                    },
                    secondaryButton: .cancel()
                )
            case .shareError(let errorMessage):
                return Alert(
                    title: Text("Share Error"),
                    message: Text(errorMessage),
                    dismissButton: .default(Text("OK")) {
                        sharingService.clearError()
                    }
                )
            }
        }
        .onChange(of: sharingService.shareError) { error in
            if let error = error {
                activeAlert = .shareError(error)
            }
        }
    }
    
    private func handleShare(format: ShareFormat, options: ShareOptions) {
        // Create share content asynchronously
        DispatchQueue.global(qos: .userInitiated).async { [weak sharingService] in
            guard let shareResult = sharingService?.shareList(list, format: format, options: options) else {
                return
            }
            
            // Update UI on main thread
            DispatchQueue.main.async {
                // Use UIActivityItemSource for proper iOS sharing
                if let fileURL = shareResult.content as? URL {
                    // File-based sharing (JSON)
                    let filename = shareResult.fileName ?? "export.json"
                    let itemSource = FileActivityItemSource(fileURL: fileURL, filename: filename)
                    self.shareFileURL = nil
                    self.shareItems = [itemSource]
                } else if let text = shareResult.content as? String {
                    // Text-based sharing (Plain Text)
                    let itemSource = TextActivityItemSource(text: text, subject: list.name)
                    self.shareFileURL = nil
                    self.shareItems = [itemSource]
                }
                
                // Present immediately - no delay needed with direct presentation
                self.showingShareSheet = true
            }
        }
    }
}

#Preview {
    SwiftUI.List {
        ListRowView(list: List(name: "Sample List"), mainViewModel: MainViewModel())
    }
}

// MARK: - View Extension for Conditional Modifiers
extension View {
    @ViewBuilder
    func `if`<Transform: View>(_ condition: Bool, transform: (Self) -> Transform) -> some View {
        if condition {
            transform(self)
        } else {
            self
        }
    }
}
