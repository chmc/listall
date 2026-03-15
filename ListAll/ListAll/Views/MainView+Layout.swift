import SwiftUI

// MARK: - MainView Layout Bodies

extension MainView {

    // MARK: - iPad Body (NavigationSplitView)

    /// iPad layout using NavigationSplitView with sidebar + detail columns
    var iPadBody: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
            // CRITICAL FIX: Wrap sidebar in NavigationStack with animated path
            // This restores SwiftUI's animation system that NavigationSplitView breaks
            NavigationStack(path: $navigationPath.animation(.linear(duration: 0))) {
                sidebarContent
            }
            .navigationTitle(viewModel.isInSelectionMode ? "\(viewModel.selectedLists.count) Selected" : (viewModel.showingArchivedLists ? "Archived Lists" : "Lists"))
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    leadingToolbarContent
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    trailingToolbarContent
                }
            }
            .navigationSplitViewColumnWidth(min: 280, ideal: 320, max: 420)
        } detail: {
            NavigationStack {
                detailContent
            }
        }
        .navigationSplitViewStyle(.balanced)
        .tint(Theme.Colors.primary)
        .overlay {
            archiveBannerOverlay
        }
        .overlay {
            syncErrorBannerOverlay
        }
    }

    // MARK: - iPhone Body (NavigationView with stack)

    /// iPhone layout using NavigationView with stack navigation
    var iPhoneBody: some View {
        NavigationView {
            ZStack {
                VStack(spacing: 0) {
                    mainListContent
                }
                .background(
                    // NavigationView requires NavigationLink(isActive:) for programmatic navigation.
                    // navigationDestination(isPresented:) is NavigationStack-only and silently no-ops here.
                    DeprecatedNavigationLink(
                        isActive: isNavigatingToList,
                        destination: { navigationDestinationView }
                    )
                )
                .navigationTitle(viewModel.isInSelectionMode ? "\(viewModel.selectedLists.count) Selected" : (viewModel.showingArchivedLists ? "Archived Lists" : "Lists"))
                .navigationBarTitleDisplayMode(.large)
                .toolbar {
                    ToolbarItem(placement: .navigationBarLeading) {
                        leadingToolbarContent
                    }

                    ToolbarItem(placement: .navigationBarTrailing) {
                        trailingToolbarContent
                    }
                }

                archiveBannerOverlay

                syncErrorBannerOverlay

                bottomToolbarOverlay
            }
        }
        .navigationViewStyle(.stack)
    }

    // MARK: - Share Handler

    func handleShareAllData(format: ShareFormat) {
        // Create share content asynchronously
        DispatchQueue.global(qos: .userInitiated).async { [weak sharingService] in
            guard let shareResult = sharingService?.shareAllData(format: format) else {
                return
            }

            // Update UI on main thread
            DispatchQueue.main.async {
                // Use UIActivityItemSource for proper iOS sharing
                if let fileURL = shareResult.content as? URL {
                    // File-based sharing (JSON)
                    let filename = shareResult.fileName ?? "ListAll-Export.json"
                    let itemSource = FileActivityItemSource(fileURL: fileURL, filename: filename)
                    self.shareFileURL = nil
                    self.shareItems = [itemSource]
                } else if let text = shareResult.content as? String {
                    // Text-based sharing (Plain Text)
                    let itemSource = TextActivityItemSource(text: text, subject: "ListAll Export")
                    self.shareFileURL = nil
                    self.shareItems = [itemSource]
                }

                // Present immediately - no delay needed with direct presentation
                self.showingShareSheet = true
            }
        }
    }
}
