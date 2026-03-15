import SwiftUI

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
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    /// Whether this row is the selected row in iPad sidebar
    private var isSelectedInSidebar: Bool {
        horizontalSizeClass == .regular && mainViewModel.selectedListForNavigation?.id == list.id
    }

    private var listContent: some View {
        HStack {
            VStack(alignment: .leading, spacing: 1) {
                Text(list.name)
                    .font(Theme.Typography.headline)
                    .foregroundColor(.primary)
                
                HStack(spacing: 2) {
                    Text("\(list.activeItemCount)/\(list.itemCount)")
                        .font(Theme.Typography.monoDigitCaption)
                        .foregroundColor(Theme.Colors.primary)
                        .numericContentTransition()
                    Text("items")
                        .font(Theme.Typography.caption)
                        .foregroundColor(Theme.Colors.secondary)
                    
                    if mainViewModel.showingArchivedLists {
                        Image(systemName: "archivebox")
                            .font(Theme.Typography.caption)
                            .foregroundColor(Theme.Colors.secondary)
                    }
                }
            }
            
            Spacer()
            
            // Add restore and delete buttons for archived lists
            if mainViewModel.showingArchivedLists {
                HStack(spacing: 8) {
                    // Restore button
                    Button(action: {
                        mainViewModel.restoreList(list)
                    }) {
                        HStack(spacing: 4) {
                            Image(systemName: "arrow.uturn.backward")
                            Text("Restore")
                        }
                        .font(Theme.Typography.caption)
                        .foregroundColor(.accentColor)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color.accentColor.opacity(0.1))
                        .cornerRadius(8)
                    }
                    .buttonStyle(BorderlessButtonStyle())
                    
                    // Delete button
                    Button(action: {
                        activeAlert = .permanentDelete
                    }) {
                        Image(systemName: "trash")
                            .font(Theme.Typography.caption)
                            .foregroundColor(.red)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(Color.red.opacity(0.1))
                            .cornerRadius(8)
                    }
                    .buttonStyle(BorderlessButtonStyle())
                }
            }
        }
        .padding(.vertical, 8)
        .contentShape(Rectangle())
    }

    /// iPad sidebar row content with teal selection styling
    @ViewBuilder
    private var iPadSidebarRowContent: some View {
        if isSelectedInSidebar {
            HStack(spacing: 0) {
                // Teal left accent bar
                RoundedRectangle(cornerRadius: iPadSidebarSelectionSpec.borderCornerRadius)
                    .fill(Theme.Colors.primary)
                    .frame(width: iPadSidebarSelectionSpec.borderWidth)

                // Row content with teal text
                HStack {
                    VStack(alignment: .leading, spacing: 1) {
                        Text(list.name)
                            .font(Theme.Typography.headline)
                            .foregroundColor(Theme.Colors.primary)

                        HStack(spacing: 2) {
                            Text("\(list.activeItemCount)/\(list.itemCount)")
                                .font(Theme.Typography.monoDigitCaption)
                                .foregroundColor(Theme.Colors.primary)
                                .numericContentTransition()
                            Text("items")
                                .font(Theme.Typography.caption)
                                .foregroundColor(Theme.Colors.primary.opacity(0.5))
                        }
                    }

                    Spacer()

                    Image(systemName: Constants.UI.chevronIcon)
                        .foregroundColor(Theme.Colors.primary.opacity(0.4))
                        .font(.system(size: 14, weight: .semibold))
                }
                .padding(.vertical, 8)
                .padding(.horizontal, iPadSidebarSelectionSpec.contentHorizontalPadding)
            }
            .background(Theme.Colors.primary.opacity(iPadSidebarSelectionSpec.backgroundOpacity))
            .clipShape(RoundedRectangle(cornerRadius: iPadSidebarSelectionSpec.cornerRadius))
        } else {
            HStack {
                VStack(alignment: .leading, spacing: 1) {
                    Text(list.name)
                        .font(Theme.Typography.headline)
                        .foregroundColor(.primary)

                    HStack(spacing: 2) {
                        Text("\(list.activeItemCount)/\(list.itemCount)")
                            .font(Theme.Typography.monoDigitCaption)
                            .foregroundColor(Theme.Colors.primary)
                            .numericContentTransition()
                        Text("items")
                            .font(Theme.Typography.caption)
                            .foregroundColor(Theme.Colors.secondary)
                    }
                }

                Spacer()

                Image(systemName: Constants.UI.chevronIcon)
                    .foregroundColor(Color(.tertiaryLabel))
                    .font(.system(size: 14, weight: .semibold))
            }
            .padding(.vertical, 8)
            .padding(.leading, iPadSidebarSelectionSpec.borderWidth + iPadSidebarSelectionSpec.contentHorizontalPadding)
            .padding(.trailing, iPadSidebarSelectionSpec.contentHorizontalPadding)
        }
    }

    var body: some View {
        HStack {
            // Selection indicator
            if mainViewModel.isInSelectionMode {
                Button(action: {
                    mainViewModel.toggleSelection(for: list.id)
                }) {
                    Image(systemName: mainViewModel.selectedLists.contains(list.id) ? "checkmark.circle.fill" : "circle")
                        .foregroundColor(mainViewModel.selectedLists.contains(list.id) ? Theme.Colors.primary : .gray)
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
            } else if mainViewModel.showingArchivedLists {
                if horizontalSizeClass == .regular {
                    // iPad: Set selection, NavigationSplitView detail handles presentation
                    Button(action: {
                        mainViewModel.selectedListForNavigation = list
                    }) {
                        listContent
                    }
                    .buttonStyle(PlainButtonStyle())
                } else {
                    // iPhone: Use NavigationLink for stack navigation
                    NavigationLink(destination: ArchivedListView(list: list, mainViewModel: mainViewModel)) {
                        listContent
                    }
                }
            } else if horizontalSizeClass == .regular {
                // iPad normal mode: Custom selection styling
                Button(action: {
                    mainViewModel.selectedListForNavigation = list
                }) {
                    iPadSidebarRowContent
                }
                .buttonStyle(PlainButtonStyle())
            } else {
                // iPhone normal mode: Use programmatic navigation for state restoration support
                Button(action: {
                    mainViewModel.selectedListForNavigation = list
                }) {
                    HStack {
                        listContent
                        Image(systemName: Constants.UI.chevronIcon)
                            .foregroundColor(Color(.tertiaryLabel))
                            .font(.system(size: 14, weight: .semibold))
                    }
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
        .padding(.horizontal, horizontalSizeClass == .regular && !mainViewModel.isInSelectionMode && !mainViewModel.showingArchivedLists ? 0 : Theme.Spacing.md)
        .hoverEffect(.lift)  // Task 16.16: iPad trackpad hover effect
        .if(!mainViewModel.isInSelectionMode && !mainViewModel.showingArchivedLists) { view in
            view.contextMenu {
                Button(action: { showingEditSheet = true }) {
                    Label("Edit", systemImage: "pencil")
                }
                Button(action: { showingShareFormatPicker = true }) {
                    Label("Share", systemImage: "square.and.arrow.up")
                }
                Button(action: { activeAlert = .duplicate }) {
                    Label("Duplicate", systemImage: "doc.on.doc")
                }
                Button(action: { activeAlert = .archive }) {
                    Label("Archive", systemImage: "archivebox")
                }
            }
        }
        .if(!mainViewModel.isInSelectionMode && !mainViewModel.showingArchivedLists) { view in
            view.swipeActions(edge: .trailing) {
                // Active list: Show archive
                Button(action: {
                    activeAlert = .archive
                }) {
                    Label("Archive", systemImage: "archivebox")
                }
                .tint(.orange)
            }
        }
        .if(!mainViewModel.isInSelectionMode && !mainViewModel.showingArchivedLists) { view in
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
            case .archive:
                return Alert(
                    title: Text("Archive List"),
                    message: Text("Archive \"\(list.name)\"? You can restore it later from the archived lists."),
                    primaryButton: .default(Text("Archive")) {
                        mainViewModel.archiveList(list)
                    },
                    secondaryButton: .cancel()
                )
            case .permanentDelete:
                return Alert(
                    title: Text("Delete Permanently"),
                    message: Text("Are you sure you want to permanently delete \"\(list.name)\"? This action cannot be undone. All items and images will be permanently deleted."),
                    primaryButton: .destructive(Text("Delete Permanently")) {
                        mainViewModel.permanentlyDeleteList(list)
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
