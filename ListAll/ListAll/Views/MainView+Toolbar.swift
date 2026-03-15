import SwiftUI

// MARK: - MainView Toolbar & Overlays

extension MainView {

    // MARK: - Task 16.11: Sync Status UI
    /// Sync button image with rotation animation on iOS 18+, fallback for older versions
    @ViewBuilder
    var syncButtonImage: some View {
        if #available(iOS 18.0, *) {
            Image(systemName: Constants.UI.syncIcon)
                .symbolEffect(.rotate, isActive: cloudKitService.isSyncing)
        } else {
            // Fallback for iOS 17: use rotationEffect with animation
            Image(systemName: Constants.UI.syncIcon)
                .rotationEffect(.degrees(cloudKitService.isSyncing ? 360 : 0))
                .animation(
                    cloudKitService.isSyncing
                        ? .linear(duration: 1.0).repeatForever(autoreverses: false)
                        : .default,
                    value: cloudKitService.isSyncing
                )
        }
    }

    /// Dynamic accessibility label for sync button showing current sync state
    var syncAccessibilityLabel: String {
        if cloudKitService.isSyncing {
            return String(localized: "Syncing with iCloud")
        } else if cloudKitService.syncError != nil {
            return String(localized: "Sync error. Tap to retry")
        } else {
            return String(localized: "Sync with iCloud")
        }
    }

    /// Leading toolbar: archive toggle, share, sync, edit/cancel buttons
    @ViewBuilder
    var leadingToolbarContent: some View {
        HStack(spacing: Theme.Spacing.md) {
            if !viewModel.isInSelectionMode {
                // Archive toggle button
                Button(action: {
                    withAnimation {
                        viewModel.toggleArchivedView()
                    }
                }) {
                    Image(systemName: viewModel.showingArchivedLists ? "tray" : "archivebox")
                }
                .hoverEffect(.highlight)  // Task 16.16: iPad trackpad hover effect
                .keyboardShortcut("a", modifiers: [.command, .shift])  // Task 15.8: iPad Cmd+Shift+A
                .help(viewModel.showingArchivedLists ? "Show Active Lists" : "Show Archived Lists")

                // Share all data button (only for active lists)
                if !viewModel.showingArchivedLists && !viewModel.lists.isEmpty {
                    Button(action: {
                        showingShareFormatPicker = true
                    }) {
                        Image(systemName: "square.and.arrow.up")
                    }
                    .hoverEffect(.highlight)  // Task 16.16: iPad trackpad hover effect
                    .help("Share all data")
                }

                // Sync button (only for active lists)
                // Syncs with both CloudKit and Apple Watch
                // Task 16.11: Enhanced with animation and status feedback
                if !viewModel.showingArchivedLists {
                    Button(action: {
                        // Sync with CloudKit
                        Task {
                            await cloudKitService.sync()
                        }
                        // Sync with Apple Watch
                        viewModel.manualSync()
                    }) {
                        syncButtonImage
                    }
                    .hoverEffect(.highlight)  // Task 16.16: iPad trackpad hover effect
                    .foregroundColor(cloudKitService.syncError != nil ? .red : nil)  // Red if error
                    .disabled(cloudKitService.isSyncing || viewModel.isSyncingFromWatch)
                    .keyboardShortcut("r", modifiers: .command)  // Task 15.8: iPad Cmd+R
                    .accessibilityLabel(syncAccessibilityLabel)
                    .help("Sync with iCloud and Apple Watch")
                }
            }

            if !viewModel.displayedLists.isEmpty {
                if viewModel.isInSelectionMode {
                    // Selection mode: Show Cancel button
                    Button("Cancel") {
                        withAnimation {
                            viewModel.exitSelectionMode()
                            editMode = .inactive
                        }
                    }
                } else {
                    // Normal mode: Show Edit button (only for active lists)
                    if !viewModel.showingArchivedLists {
                        Button(action: {
                            print("🟢 Edit button pressed in MainView")
                            print("   Current editMode: \(editMode)")
                            print("   Current isInSelectionMode: \(viewModel.isInSelectionMode)")
                            withAnimation {
                                viewModel.enterSelectionMode()
                                editMode = .active
                            }
                            print("   New editMode: \(editMode)")
                            print("   New isInSelectionMode: \(viewModel.isInSelectionMode)")
                        }) {
                            Image(systemName: "pencil")
                        }
                        .hoverEffect(.highlight)  // Task 16.16: iPad trackpad hover effect
                    }
                }
            }
        }
        .padding(.horizontal, Theme.Spacing.sm)
    }

    /// Trailing toolbar: selection mode actions menu or add button
    @ViewBuilder
    var trailingToolbarContent: some View {
        if viewModel.isInSelectionMode {
            // Selection mode: Show actions menu (always visible)
            Menu {
                Button(action: {
                    viewModel.selectAll()
                }) {
                    Label("Select All", systemImage: "checkmark.circle")
                }

                Button(action: {
                    viewModel.deselectAll()
                }) {
                    Label("Deselect All", systemImage: "circle")
                }
                .disabled(viewModel.selectedLists.isEmpty)

                Divider()

                Button(role: .destructive, action: {
                    showingDeleteConfirmation = true
                }) {
                    Label("Delete Lists", systemImage: "trash")
                }
                .disabled(viewModel.selectedLists.isEmpty)
            } label: {
                Image(systemName: "ellipsis.circle")
                    .foregroundColor(.primary)
            }
            .padding(.horizontal, Theme.Spacing.sm)
        } else if !viewModel.showingArchivedLists {
            // Normal mode: Show Add button (only for active lists)
            Button(action: {
                showingCreateList = true
            }) {
                Image(systemName: Constants.UI.addIcon)
                    .imageScale(.large)
                    .aspectRatio(1.0, contentMode: .fit)
                    .padding(.horizontal, -2)
            }
            .buttonStyle(.plain)
            .hoverEffect(.highlight)  // Task 16.16: iPad trackpad hover effect
            .accessibilityIdentifier("AddListButton")
            .keyboardShortcut("n", modifiers: .command)  // Task 15.8: iPad Cmd+N
            .padding(.horizontal, Theme.Spacing.sm)
        }
    }

    // MARK: - Overlays

    /// Archive notification banner overlay
    @ViewBuilder
    var archiveBannerOverlay: some View {
        if viewModel.showArchivedNotification, let list = viewModel.recentlyArchivedList {
            VStack {
                Spacer()
                ArchiveBanner(
                    listName: list.name,
                    onUndo: {
                        viewModel.undoArchive()
                    },
                    onDismiss: {
                        viewModel.hideArchiveNotification()
                    }
                )
                .padding(.horizontal, Theme.Spacing.md)
                .padding(.bottom, isRegularWidth ? 16 : 60) // Less padding on iPad (no bottom toolbar)
                .transition(.move(edge: .bottom).combined(with: .opacity))
                .animation(Theme.Animation.spring, value: viewModel.showArchivedNotification)
            }
        }
    }

    /// Sync error banner overlay
    @ViewBuilder
    var syncErrorBannerOverlay: some View {
        if cloudKitService.shouldShowSyncErrorBanner {
            VStack {
                SyncErrorBanner(onDismiss: {
                    cloudKitService.dismissSyncErrorBanner()
                })
                .padding(.horizontal, Theme.Spacing.md)
                .padding(.top, 8)
                .transition(.move(edge: .top).combined(with: .opacity))
                .animation(.spring(response: 0.3, dampingFraction: 0.7),
                           value: cloudKitService.shouldShowSyncErrorBanner)
                Spacer()
            }
        }
    }

    /// Custom bottom toolbar overlay (tab bar replacement) - iPhone only
    var bottomToolbarOverlay: some View {
        VStack {
            Spacer()
            CustomBottomToolbar(
                onListsTap: {
                    // Already on lists view - no action needed
                },
                onSettingsTap: {
                    showingSettings = true
                }
            )
            .background(Color(.systemBackground))
            .shadow(color: Color.black.opacity(0.1), radius: 8, x: 0, y: -2)
        }
        .edgesIgnoringSafeArea(.bottom)
    }
}
