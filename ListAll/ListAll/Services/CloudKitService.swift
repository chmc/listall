import Foundation
import CloudKit
import CoreData
import Combine

class CloudKitService: ObservableObject {
    @Published var isSyncing = false
    @Published var lastSyncDate: Date?
    @Published var syncError: String?
    @Published var syncStatus: SyncStatus = .unknown
    @Published var syncProgress: Double = 0.0
    @Published var pendingOperations: Int = 0
    
    private let container: CKContainer?
    private let coreDataManager = CoreDataManager.shared
    private let dataRepository = DataRepository()
    private var syncQueue = DispatchQueue(label: "com.listall.cloudkit.sync", qos: .background)
    private var retryCount = 0
    private let maxRetries = 3
    
    init() {
        // Check if CloudKit is available by looking for entitlements
        if Bundle.main.object(forInfoDictionaryKey: "com.apple.developer.icloud-services") != nil {
            self.container = CKContainer(identifier: "iCloud.io.github.chmc.ListAll")
            self.syncStatus = .unknown
        } else {
            self.container = nil
            self.syncStatus = .offline
        }
        
        setupCloudKitObservers()
        checkInitialStatus()
    }
    
    enum SyncStatus: Equatable {
        case unknown
        case available
        case restricted
        case noAccount
        case couldNotDetermine
        case temporarilyUnavailable
        case error(String)
        case syncing
        case offline
    }
    
    enum ConflictResolutionStrategy {
        case lastWriteWins
        case userChoice
        case serverWins
        case clientWins
    }
    
    
    // MARK: - CloudKit Status
    
    func checkAccountStatus() async -> CKAccountStatus {
        guard let container = container else {
            return .couldNotDetermine
        }
        
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
        case .temporarilyUnavailable:
            syncStatus = .temporarilyUnavailable
        @unknown default:
            syncStatus = .unknown
        }
    }
    
    // MARK: - Sync Operations
    
    func sync() async {
        guard container != nil else {
            await MainActor.run {
                self.syncError = "CloudKit not configured"
                self.syncStatus = .offline
            }
            return
        }
        
        guard syncStatus == .available else {
            await MainActor.run {
                self.syncError = "CloudKit not available"
                self.syncStatus = .offline
            }
            return
        }
        
        await MainActor.run {
            isSyncing = true
            syncError = nil
            syncStatus = .syncing
            syncProgress = 0.0
        }
        
        // Check for remote changes first
        await checkForRemoteChanges()
        
        // Trigger Core Data to sync with CloudKit
        coreDataManager.persistentContainer.persistentStoreCoordinator.performAndWait {
            // This triggers the CloudKit sync
        }
        
        await MainActor.run {
            self.isSyncing = false
            self.lastSyncDate = Date()
            self.syncError = nil
            self.syncStatus = .available
            self.syncProgress = 1.0
            self.retryCount = 0
        }
    }
    
    func forceSync() async {
        // Force a full sync by checking for remote changes
        await sync()
    }
    
    private func checkForRemoteChanges() async {
        // This method can be expanded to check for specific remote changes
        // For now, we rely on Core Data's automatic CloudKit sync
    }
    
    private func handleSyncError(_ error: Error) async {
        let nsError = error as NSError
        
        // Check if it's a retryable error
        if isRetryableError(nsError) && retryCount < maxRetries {
            retryCount += 1
            let delay = pow(2.0, Double(retryCount)) // Exponential backoff
            
            await MainActor.run {
                self.syncError = "Sync failed, retrying in \(Int(delay)) seconds... (Attempt \(self.retryCount)/\(self.maxRetries))"
            }
            
            // Wait before retrying
            try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
            await sync()
        } else {
            await MainActor.run {
                self.isSyncing = false
                self.syncError = error.localizedDescription
                self.syncStatus = .error(error.localizedDescription)
                self.retryCount = 0
            }
        }
    }
    
    private func isRetryableError(_ error: NSError) -> Bool {
        // Check for common retryable CloudKit errors
        let retryableCodes = [
            CKError.networkUnavailable.rawValue,
            CKError.networkFailure.rawValue,
            CKError.serviceUnavailable.rawValue,
            CKError.requestRateLimited.rawValue,
            CKError.quotaExceeded.rawValue
        ]
        
        return retryableCodes.contains(error.code)
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
        print("Resolving conflicts...")
        
        // Get all entities with conflicts
        let context = coreDataManager.viewContext
        let entities = ["ListEntity", "ItemEntity", "ItemImageEntity", "UserDataEntity"]
        
        for entityName in entities {
            let request = NSFetchRequest<NSManagedObject>(entityName: entityName)
            request.predicate = NSPredicate(format: "ckServerChangeToken != nil")
            
            do {
                let objects = try context.fetch(request)
                for object in objects {
                    await resolveConflictForObject(object)
                }
            } catch {
                print("Failed to fetch \(entityName) for conflict resolution: \(error)")
            }
        }
    }
    
    private func resolveConflictForObject(_ object: NSManagedObject) async {
        // Implement specific conflict resolution logic
        // For now, we use the default Core Data merge policy
        // This can be enhanced to show user choice dialogs
        print("Resolving conflict for \(object.entity.name ?? "Unknown")")
    }
    
    func resolveConflictWithStrategy(_ strategy: ConflictResolutionStrategy, for object: NSManagedObject) async {
        switch strategy {
        case .lastWriteWins:
            // Use the object with the most recent modifiedAt date
            await resolveWithLastWriteWins(object)
        case .userChoice:
            // Show user choice dialog (to be implemented in UI)
            await showUserChoiceDialog(for: object)
        case .serverWins:
            // Use server version
            await resolveWithServerWins(object)
        case .clientWins:
            // Use client version
            await resolveWithClientWins(object)
        }
    }
    
    private func resolveWithLastWriteWins(_ object: NSManagedObject) async {
        // Implementation for last-write-wins strategy
        print("Resolving with last-write-wins for \(object.entity.name ?? "Unknown")")
    }
    
    private func resolveWithServerWins(_ object: NSManagedObject) async {
        // Implementation for server-wins strategy
        print("Resolving with server-wins for \(object.entity.name ?? "Unknown")")
    }
    
    private func resolveWithClientWins(_ object: NSManagedObject) async {
        // Implementation for client-wins strategy
        print("Resolving with client-wins for \(object.entity.name ?? "Unknown")")
    }
    
    private func showUserChoiceDialog(for object: NSManagedObject) async {
        // This would show a UI dialog for user choice
        // For now, default to last-write-wins
        await resolveWithLastWriteWins(object)
    }
    
    // MARK: - Offline Support
    
    func queueOperation(_ operation: @escaping () async throws -> Void) {
        syncQueue.async {
            Task {
                do {
                    try await operation()
                } catch {
                    await self.handleOfflineOperationError(error)
                }
            }
        }
    }
    
    private func handleOfflineOperationError(_ error: Error) async {
        // Store failed operations for retry when online
        print("Offline operation failed: \(error)")
        // This could be enhanced to store operations in a queue
    }
    
    func processPendingOperations() async {
        // Process any queued operations when back online
        print("Processing pending operations...")
        // Implementation would process stored operations
    }
    
    // MARK: - Sync Status Management
    
    func startPeriodicSync() {
        // Start periodic sync every 30 seconds when available
        Timer.scheduledTimer(withTimeInterval: 30.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                guard let self = self else { return }
                if self.syncStatus == .available && !self.isSyncing {
                    await self.sync()
                }
            }
        }
    }
    
    func stopPeriodicSync() {
        // Stop periodic sync
        // Timer would be stored and invalidated here
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
