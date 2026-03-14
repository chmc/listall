//
//  MacMainView+SyncPolling.swift
//  ListAllMac
//
//  Sync polling methods and sync status UI helpers for MacMainView.
//

import SwiftUI
import CoreData

extension MacMainView {
    // MARK: - Sync Status UI

    /// Sync button image with rotation animation on macOS 15+, fallback for older versions
    @ViewBuilder
    var syncButtonImage: some View {
        if #available(macOS 15.0, *) {
            Image(systemName: "arrow.triangle.2.circlepath")
                .symbolEffect(.rotate, isActive: cloudKitService.isSyncing)
        } else {
            // Fallback for macOS 14: use rotationEffect with animation
            Image(systemName: "arrow.triangle.2.circlepath")
                .rotationEffect(.degrees(cloudKitService.isSyncing ? 360 : 0))
                .animation(
                    cloudKitService.isSyncing
                        ? .linear(duration: 1.0).repeatForever(autoreverses: false)
                        : .default,
                    value: cloudKitService.isSyncing
                )
        }
    }

    /// Tooltip text for sync status button in toolbar
    /// Shows syncing state, last sync time, or error message
    var syncTooltipText: String {
        if cloudKitService.isSyncing {
            return "Syncing with iCloud..."
        } else if let error = cloudKitService.syncError {
            return "Sync error: \(error) - Click to retry"
        } else if let lastSync = coreDataManager.lastSyncDate {
            let formatter = RelativeDateTimeFormatter()
            formatter.unitsStyle = .short
            return "Last synced \(formatter.localizedString(for: lastSync, relativeTo: Date())) - Click to sync"
        } else {
            return "Click to sync with iCloud"
        }
    }

    // MARK: - Sync Polling Methods

    /// Enables the sync polling timer (when window becomes active)
    /// Timer.publish runs continuously but we control whether to act via isSyncPollingActive flag
    func startSyncPolling() {
        guard !isSyncPollingActive else { return }
        isSyncPollingActive = true
        print("🔄 macOS: Sync polling enabled (every 30s)")
    }

    /// Disables the sync polling timer (when app goes to background or view disappears)
    /// Timer continues publishing but the .onReceive handler will skip processing
    func stopSyncPolling() {
        isSyncPollingActive = false
        print("🔄 macOS: Sync polling disabled")
    }

    /// Performs the actual sync polling work (called from .onReceive modifier)
    func performSyncPoll() {
        // Skip polling if user is editing - prevents UI interruption during sheet presentation
        guard !isEditingAnyItem else {
            print("🛡️ macOS: Skipping poll - user is editing item")
            return
        }

        print("🔄 macOS: Polling for CloudKit changes (timer-based fallback)")

        // CRITICAL FIX: Use performAndWait (synchronous) to ensure refreshAllObjects()
        // completes BEFORE loadData() fetches. This prevents race conditions where
        // loadData() could fetch stale data before refreshAllObjects() completed.
        viewContext.performAndWait {
            viewContext.refreshAllObjects()
        }

        // ENHANCEMENT: Trigger a background context operation to encourage CloudKit
        // sync engine to wake up and check for pending operations
        CoreDataManager.shared.triggerCloudKitSync()

        // Now safe to load data - viewContext has been refreshed
        // Use async to prevent layout recursion if timer fires during layout pass
        DispatchQueue.main.async {
            dataManager.loadData()
        }
    }
}
