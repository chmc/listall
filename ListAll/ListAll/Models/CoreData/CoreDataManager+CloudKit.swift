import Foundation
import CoreData

// MARK: - Remote Change Notifications & CloudKit Sync

extension CoreDataManager {

    /// Setup remote change notification observers
    /// Note: Made internal (not private) to allow reset from test support methods
    func setupRemoteChangeNotifications() {
        // Observe remote changes from other processes (e.g., watchOS app, CloudKit sync)
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handlePersistentStoreRemoteChange(_:)),
            name: .NSPersistentStoreRemoteChange,
            object: persistentContainer.persistentStoreCoordinator
        )

        // Observe CloudKit sync events (iOS 14+, macOS 11+) for sync status/errors
        #if os(iOS) || os(macOS)
        if #available(iOS 14.0, macOS 11.0, *) {
            NotificationCenter.default.addObserver(
                self,
                selector: #selector(handleCloudKitEvent(_:)),
                name: NSPersistentCloudKitContainer.eventChangedNotification,
                object: persistentContainer
            )
            print("📦 CoreDataManager: CloudKit event notification observer added")
        }
        #endif

        // iOS + macOS: Observe background context saves (CloudKit imports happen on background context)
        // This catches CloudKit changes even when the app is frontmost and active
        // CRITICAL for iOS: Without this, iOS only receives NSPersistentStoreRemoteChange which may not
        // fire reliably when the app is foregrounded. Background context saves are more reliable.
        #if os(iOS) || os(macOS)
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleContextDidSave(_:)),
            name: .NSManagedObjectContextDidSave,
            object: nil  // Observe ALL contexts, not just viewContext
        )
        print("📦 CoreDataManager: Background context save observer added (CloudKit import detection)")
        #endif
    }

    @objc func handlePersistentStoreRemoteChange(_ notification: Notification) {

        // CRITICAL: Ignore local saves - only process true remote changes
        // Local saves (from drag-drop, item edits) should NOT trigger reload loops
        if isLocalSave {
            print("💾 CoreDataManager: Ignoring local save notification (not a remote change)")
            isLocalSave = false  // Reset flag
            return
        }

        // Ensure we're on the main thread for UI safety
        guard Thread.isMainThread else {
            DispatchQueue.main.async { [weak self] in
                self?.handlePersistentStoreRemoteChange(notification)
            }
            return
        }

        print("🌐 CoreDataManager: Detected REMOTE change from another process")

        // Debounce rapid changes to prevent excessive reloads
        remoteChangeDebounceTimer?.invalidate()
        remoteChangeDebounceTimer = Timer.scheduledTimer(withTimeInterval: remoteChangeDebounceInterval, repeats: false) { [weak self] _ in
            self?.processRemoteChange()
        }
    }

    func processRemoteChange() {
        // CRITICAL: We're already on the main thread (from handlePersistentStoreRemoteChange dispatch)
        // DO NOT use viewContext.perform { } here - it re-dispatches to background queue!
        // This would cause notifications to fire on background thread, breaking @Published updates.

        // Refresh view context synchronously on main thread
        viewContext.refreshAllObjects()

        // Post notification ON MAIN THREAD for DataManager and ViewModels to reload
        NotificationCenter.default.post(
            name: .coreDataRemoteChange,
            object: nil
        )
    }

    // MARK: - Background Context Handling (CloudKit Import Detection)

    #if os(iOS) || os(macOS)
    /// Handles saves from background contexts (including CloudKit import context)
    /// This ensures UI updates in real-time when CloudKit syncs changes from other devices
    /// CRITICAL: We deduplicate by checking if this is a CloudKit import context.
    /// CloudKit imports are better handled by handleCloudKitEvent which has more info about the event.
    @objc func handleContextDidSave(_ notification: Notification) {
        guard let savedContext = notification.object as? NSManagedObjectContext else { return }

        // Only process saves from OTHER contexts (background contexts)
        // Skip our own viewContext saves to avoid loops
        guard savedContext != viewContext else {
            print("💾 CoreDataManager: Ignoring viewContext save (local)")
            return
        }

        // CRITICAL: Detect CloudKit import contexts to prevent duplicate notifications
        // CloudKit import contexts typically have names like:
        // - "NSCloudKitMirroringDelegate.export" / "NSCloudKitMirroringDelegate.import"
        // - Or contain "CloudKit" in their name
        // Let handleCloudKitEvent handle these instead to prevent double-refresh
        if let contextName = savedContext.name {
            let isCloudKitContext = contextName.contains("CloudKit") ||
                                    contextName.contains("NSCloudKitMirroringDelegate") ||
                                    contextName.contains("import") ||
                                    contextName.contains("export")
            if isCloudKitContext {
                print("☁️ CoreDataManager: Skipping CloudKit context save (handled by eventChangedNotification): \(contextName)")
                return
            }
        }

        // This is a background context save from non-CloudKit source (e.g., watchOS, widget, app extension)
        print("🌐 CoreDataManager: Background context saved (non-CloudKit) - triggering UI refresh")

        // Ensure we're on main thread for UI updates
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }

            // CRITICAL: DO NOT use viewContext.perform { } here - we're already on main thread!
            // viewContext.perform re-dispatches to background queue, causing notifications
            // to fire on background thread, which breaks @Published property updates in SwiftUI.

            // Refresh view context synchronously on main thread
            self.viewContext.refreshAllObjects()

            // Post notification ON MAIN THREAD for DataManager and views to reload
            NotificationCenter.default.post(
                name: .coreDataRemoteChange,
                object: nil
            )
        }
    }
    #endif

    // MARK: - CloudKit Event Handling

    #if os(iOS) || os(macOS)
    @available(iOS 14.0, macOS 11.0, *)
    @objc func handleCloudKitEvent(_ notification: Notification) {
        guard let cloudEvent = notification.userInfo?[NSPersistentCloudKitContainer.eventNotificationUserInfoKey]
                as? NSPersistentCloudKitContainer.Event else {
            return
        }

        let eventType = cloudEvent.type
        #if os(iOS)
        let platform = "iOS"
        #elseif os(macOS)
        let platform = "macOS"
        #else
        let platform = "unknown"
        #endif

        if cloudEvent.endDate == nil {
            // Event just started
            print("☁️ [\(platform)] CloudKit event STARTED: \(eventType)")
        } else {
            // Event completed (endDate != nil)
            if cloudEvent.succeeded {
                print("✅ [\(platform)] CloudKit event SUCCEEDED: \(eventType)")

                // Update last sync timestamp for successful imports/exports
                if eventType == .import || eventType == .export {
                    DispatchQueue.main.async { [weak self] in
                        self?.lastSyncDate = Date()
                    }
                }

                // Post notification to trigger UI refresh after successful import
                if eventType == .import {
                    DispatchQueue.main.async { [weak self] in
                        guard let self = self else { return }

                        // CRITICAL: DO NOT use viewContext.perform { } here - we're already on main thread!
                        // viewContext.perform re-dispatches to background queue, causing notifications
                        // to fire on background thread, which breaks @Published property updates in SwiftUI.

                        // Reset query generation to ensure fetches see CloudKit-imported data
                        try? self.viewContext.setQueryGenerationFrom(.current)

                        // Refresh view context synchronously on main thread
                        self.viewContext.refreshAllObjects()

                        print("🔄 [\(platform)] CloudKit import complete - refreshed viewContext and posting notification")

                        // Post notification ON MAIN THREAD
                        NotificationCenter.default.post(name: .coreDataRemoteChange, object: nil)
                    }
                }
            } else if let error = cloudEvent.error {
                print("❌ [\(platform)] CloudKit event FAILED: \(eventType) - \(error.localizedDescription)")
            }
        }
    }
    #endif

    // MARK: - Manual Sync Trigger

    /// Force a sync refresh by refreshing the view context and reloading data
    /// Call this from UI when user taps manual refresh button
    func forceRefresh() {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }

            #if os(iOS)
            let platform = "iOS"
            #elseif os(macOS)
            let platform = "macOS"
            #else
            let platform = "unknown"
            #endif

            print("🔄 [\(platform)] Manual refresh triggered")

            // Trigger CloudKit sync engine to check for pending operations
            self.triggerCloudKitSync()

            // Reset query generation to ensure we see latest data
            try? self.viewContext.setQueryGenerationFrom(.current)

            // Refresh all objects in viewContext
            self.viewContext.refreshAllObjects()

            // Update last sync timestamp
            self.lastSyncDate = Date()

            // Post notification for UI to reload
            NotificationCenter.default.post(name: .coreDataRemoteChange, object: nil)
        }
    }

    /// Triggers CloudKit sync engine to wake up and check for pending operations
    /// NSPersistentCloudKitContainer sync is passive (push-notification based), but performing
    /// a background context operation can encourage the sync engine to process pending imports/exports.
    /// Note: This does NOT force CloudKit to fetch from server - that's controlled by Apple's infrastructure.
    /// However, it helps process any data that CloudKit has already received but not yet imported.
    func triggerCloudKitSync() {
        #if os(iOS)
        let platform = "iOS"
        #elseif os(macOS)
        let platform = "macOS"
        #else
        let platform = "unknown"
        #endif

        // Perform a lightweight background context operation
        // This wakes up NSPersistentCloudKitContainer's mirroring delegate which processes pending operations
        persistentContainer.performBackgroundTask { context in
            // Simply processing pending changes is enough to wake up the sync engine
            context.processPendingChanges()
            print("☁️ [\(platform)] Triggered CloudKit sync engine (processPendingChanges)")
        }
    }
}
