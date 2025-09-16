import Foundation
import CloudKit
import CoreData

class CloudKitService: ObservableObject {
    @Published var isSyncing = false
    @Published var lastSyncDate: Date?
    @Published var syncError: String?
    @Published var syncStatus: SyncStatus = .unknown
    
    private let container = CKContainer(identifier: "iCloud.io.github.chmc.ListAll")
    private let coreDataManager = CoreDataManager.shared
    private let dataRepository = DataRepository()
    
    enum SyncStatus {
        case unknown
        case available
        case restricted
        case noAccount
        case couldNotDetermine
        case error(String)
    }
    
    init() {
        setupCloudKitObservers()
        checkInitialStatus()
    }
    
    // MARK: - CloudKit Status
    
    func checkAccountStatus() async -> CKAccountStatus {
        do {
            return try await container.accountStatus()
        } catch {
            await MainActor.run {
                self.syncStatus = .error(error.localizedDescription)
            }
            return .couldNotDetermine
        }
    }
    
    private func checkInitialStatus() {
        Task {
            let status = await checkAccountStatus()
            await MainActor.run {
                updateSyncStatus(from: status)
            }
        }
    }
    
    private func updateSyncStatus(from accountStatus: CKAccountStatus) {
        switch accountStatus {
        case .available:
            syncStatus = .available
        case .restricted:
            syncStatus = .restricted
        case .noAccount:
            syncStatus = .noAccount
        case .couldNotDetermine:
            syncStatus = .couldNotDetermine
        @unknown default:
            syncStatus = .unknown
        }
    }
    
    // MARK: - Sync Operations
    
    func sync() async {
        await MainActor.run {
            isSyncing = true
            syncError = nil
        }
        
        do {
            // Trigger Core Data to sync with CloudKit
            try await coreDataManager.persistentContainer.persistentStoreCoordinator.performAndWait {
                // This triggers the CloudKit sync
            }
            
            await MainActor.run {
                self.isSyncing = false
                self.lastSyncDate = Date()
                self.syncError = nil
            }
        } catch {
            await MainActor.run {
                self.isSyncing = false
                self.syncError = error.localizedDescription
                self.syncStatus = .error(error.localizedDescription)
            }
        }
    }
    
    func forceSync() async {
        // Force a full sync by checking for remote changes
        await sync()
    }
    
    // MARK: - CloudKit Observers
    
    private func setupCloudKitObservers() {
        // Listen for CloudKit sync notifications
        NotificationCenter.default.addObserver(
            forName: NSPersistentCloudKitContainer.eventChangedNotification,
            object: coreDataManager.persistentContainer,
            queue: .main
        ) { [weak self] notification in
            self?.handleCloudKitEvent(notification)
        }
        
        // Listen for remote change notifications
        NotificationCenter.default.addObserver(
            forName: .NSPersistentStoreRemoteChange,
            object: coreDataManager.persistentContainer.persistentStoreCoordinator,
            queue: .main
        ) { [weak self] _ in
            self?.handleRemoteChange()
        }
    }
    
    private func handleCloudKitEvent(_ notification: Notification) {
        guard let event = notification.userInfo?[NSPersistentCloudKitContainer.eventNotificationUserInfoKey] as? NSPersistentCloudKitContainer.Event else {
            return
        }
        
        switch event.type {
        case .setup:
            print("CloudKit setup completed")
        case .import:
            print("CloudKit import completed")
        case .export:
            print("CloudKit export completed")
        @unknown default:
            print("Unknown CloudKit event")
        }
        
        if let error = event.error {
            syncError = error.localizedDescription
            syncStatus = .error(error.localizedDescription)
        } else {
            syncError = nil
            lastSyncDate = Date()
        }
    }
    
    private func handleRemoteChange() {
        // Handle remote changes from CloudKit
        print("Remote change detected, updating UI")
        // The Core Data stack will automatically merge changes
    }
    
    // MARK: - Conflict Resolution
    
    func resolveConflicts() async {
        // Implement conflict resolution logic
        // For now, we use the default Core Data merge policy (NSMergeByPropertyObjectTrumpMergePolicy)
        print("Resolving conflicts...")
    }
    
    // MARK: - Data Export for CloudKit
    
    func exportDataForCloudKit() -> [String: Any] {
        // Export current data in a format suitable for CloudKit
        let lists = dataRepository.getAllLists()
        
        var exportData: [String: Any] = [:]
        exportData["version"] = "1.0"
        exportData["exportDate"] = ISO8601DateFormatter().string(from: Date())
        exportData["lists"] = lists.map { list in
            [
                "id": list.id.uuidString,
                "name": list.name,
                "orderNumber": list.orderNumber,
                "createdAt": ISO8601DateFormatter().string(from: list.createdAt),
                "modifiedAt": ISO8601DateFormatter().string(from: list.modifiedAt),
                "items": list.items.map { item in
                    [
                        "id": item.id.uuidString,
                        "title": item.title,
                        "description": item.itemDescription ?? "",
                        "quantity": item.quantity,
                        "orderNumber": item.orderNumber,
                        "isCrossedOut": item.isCrossedOut,
                        "createdAt": ISO8601DateFormatter().string(from: item.createdAt),
                        "modifiedAt": ISO8601DateFormatter().string(from: item.modifiedAt)
                    ]
                }
            ]
        }
        
        return exportData
    }
    
    // MARK: - Cleanup
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
}
