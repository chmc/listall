import Foundation
import CoreData
import CloudKit
import Combine

// MARK: - Notification Names
// Note: Also defined in Constants.swift for iOS target
// Duplicated here to support watchOS target without requiring Constants.swift
extension Notification.Name {
    static let coreDataRemoteChange = Notification.Name("CoreDataRemoteChange")
}

// MARK: - Core Data Manager
class CoreDataManager: ObservableObject {
    static let shared = CoreDataManager()
    
    // Debouncing timer for remote changes
    private var remoteChangeDebounceTimer: Timer?
    private let remoteChangeDebounceInterval: TimeInterval = 0.5 // 500ms debounce
    
    // MARK: - Core Data Stack
    lazy var persistentContainer: NSPersistentContainer = {
        // Using NSPersistentCloudKitContainer for CloudKit sync (activated with paid developer account)
        // Note: Temporarily disabled for watchOS due to persistent portal configuration issues
        // CRITICAL: Disable CloudKit for Debug builds (simulators) to prevent crashes
        // CloudKit requires proper code signing and credentials which aren't available in unsigned simulator builds
        #if os(watchOS)
        let container = NSPersistentContainer(name: "ListAll")
        print("📦 CoreDataManager: Using NSPersistentContainer (watchOS)")
        #elseif DEBUG
        // Use plain NSPersistentContainer for Debug builds (no CloudKit)
        let container = NSPersistentContainer(name: "ListAll")
        print("📦 CoreDataManager: Using NSPersistentContainer (Debug build - CloudKit DISABLED)")
        #else
        // Use CloudKit-enabled container for Release builds only
        let container = NSPersistentCloudKitContainer(name: "ListAll")
        print("📦 CoreDataManager: Using NSPersistentCloudKitContainer (Release build - CloudKit ENABLED)")
        #endif
        
        // Configure store description for migration
        guard let storeDescription = container.persistentStoreDescriptions.first else {
            fatalError("Failed to retrieve a persistent store description.")
        }
        
        // Configure App Groups shared container URL
        let appGroupID = "group.io.github.chmc.ListAll"
        if let containerURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupID) {
            let storeURL = containerURL.appendingPathComponent("ListAll.sqlite")
            print("📦 CoreDataManager: App Groups container accessible")
            print("📦 CoreDataManager: Store URL = \(storeURL.path)")

            // Migrate from old location if needed (iOS only - first time after App Groups was added)
            #if os(iOS)
            migrateToAppGroupsIfNeeded(newStoreURL: storeURL)
            #endif

            storeDescription.url = storeURL
        } else {
            // FALLBACK: When App Groups fails (e.g., Debug builds without proper entitlements),
            // use app's Documents directory as fallback to ensure data persists
            print("⚠️ CoreDataManager: App Groups container NOT accessible for '\(appGroupID)'")
            print("⚠️ CoreDataManager: Falling back to Documents directory (Debug builds only)")

            if let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first {
                let fallbackURL = documentsURL.appendingPathComponent("ListAll.sqlite")
                storeDescription.url = fallbackURL
                print("⚠️ CoreDataManager: Fallback store URL = \(fallbackURL.path)")
            } else {
                // Ultimate fallback: keep default URL but log error
                print("❌ CoreDataManager: CRITICAL - Could not access Documents directory!")
                if let defaultURL = storeDescription.url {
                    print("❌ CoreDataManager: Using default URL = \(defaultURL.path)")
                }
            }
        }
        
        // Enable automatic migration
        storeDescription.shouldMigrateStoreAutomatically = true
        storeDescription.shouldInferMappingModelAutomatically = true

        // CRITICAL: Enable persistent history tracking for ALL builds (Debug + Release)
        // This prevents "Read Only mode" error when switching between Debug and Release builds
        // NSPersistentCloudKitContainer automatically enables this, so Debug builds must match
        storeDescription.setOption(true as NSNumber, forKey: NSPersistentHistoryTrackingKey)

        // Enable CloudKit sync (activated with paid developer account)
        // Note: Only enable for iOS Release builds - watchOS and Debug builds don't support CloudKit
        // CRITICAL: CloudKit requires proper code signing which isn't available in Debug/simulator builds
        #if os(iOS) && !DEBUG
        let cloudKitContainerOptions = NSPersistentCloudKitContainerOptions(containerIdentifier: "iCloud.io.github.chmc.ListAll")
        storeDescription.cloudKitContainerOptions = cloudKitContainerOptions
        print("📦 CoreDataManager: CloudKit container options configured")
        #endif
        
        container.loadPersistentStores { [weak self] storeDescription, error in
            if let error = error as NSError? {
                // If migration fails, try to delete and recreate the store
                if error.code == 134110 { // Migration error
                    self?.deleteAndRecreateStore(container: container, storeDescription: storeDescription)
                } else {
                    fatalError("Unresolved error \(error), \(error.userInfo)")
                }
            }
        }
        
        // Configure view context
        container.viewContext.automaticallyMergesChangesFromParent = true
        container.viewContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
        
        return container
    }()
    
    // MARK: - Contexts
    var viewContext: NSManagedObjectContext {
        return persistentContainer.viewContext
    }
    
    var backgroundContext: NSManagedObjectContext {
        return persistentContainer.newBackgroundContext()
    }
    
    private init() {
        // Initialize Core Data stack
        // Force load of persistent container
        _ = persistentContainer
        
        // Setup remote change notification observer
        setupRemoteChangeNotifications()
    }
    
    deinit {
        // Clean up observers and timers
        NotificationCenter.default.removeObserver(self)
        remoteChangeDebounceTimer?.invalidate()
    }
    
    // MARK: - Remote Change Notifications
    
    private func setupRemoteChangeNotifications() {
        // Observe remote changes from other processes (e.g., watchOS app)
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handlePersistentStoreRemoteChange(_:)),
            name: .NSPersistentStoreRemoteChange,
            object: persistentContainer.persistentStoreCoordinator
        )
    }
    
    @objc private func handlePersistentStoreRemoteChange(_ notification: Notification) {
        
        // Ensure we're on the main thread for UI safety
        guard Thread.isMainThread else {
            DispatchQueue.main.async { [weak self] in
                self?.handlePersistentStoreRemoteChange(notification)
            }
            return
        }
        
        // Debounce rapid changes to prevent excessive reloads
        remoteChangeDebounceTimer?.invalidate()
        remoteChangeDebounceTimer = Timer.scheduledTimer(withTimeInterval: remoteChangeDebounceInterval, repeats: false) { [weak self] _ in
            self?.processRemoteChange()
        }
    }
    
    private func processRemoteChange() {
        // Refresh view context to pull in changes from other processes
        viewContext.perform {
            self.viewContext.refreshAllObjects()
        }
        
        // Post notification for DataManager and ViewModels to reload their data
        NotificationCenter.default.post(
            name: .coreDataRemoteChange,
            object: nil
        )
    }
    
    // MARK: - Core Data Operations
    
    func save() {
        let context = persistentContainer.viewContext

        if context.hasChanges {
            do {
                try context.save()
                print("💾 CoreDataManager: Context saved successfully")
            } catch {
                print("❌ CoreDataManager: Failed to save context: \(error)")
            }
        } else {
            print("💾 CoreDataManager: No changes to save")
        }
    }
    
    func saveContext(_ context: NSManagedObjectContext) {
        if context.hasChanges {
            do {
                try context.save()
            } catch {
                print("Failed to save context: \(error)")
            }
        }
    }
    
    // MARK: - CloudKit Status
    
    func checkCloudKitStatus() async -> CKAccountStatus {
        let container = CKContainer(identifier: "iCloud.io.github.chmc.ListAll")
        do {
            return try await container.accountStatus()
        } catch {
            print("Failed to check CloudKit status: \(error)")
            return .couldNotDetermine
        }
    }
    
    // MARK: - Data Migration
    
    /// Migrates Core Data store from old location (app's Documents) to App Groups shared container
    /// This is only needed once when upgrading from pre-App Groups version
    private func migrateToAppGroupsIfNeeded(newStoreURL: URL) {
        let fileManager = FileManager.default
        
        // Check if App Groups store already exists
        if fileManager.fileExists(atPath: newStoreURL.path) {
            return
        }
        
        // Check for old store in app's Documents directory
        guard let documentsURL = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first else {
            return
        }
        
        let oldStoreURL = documentsURL.appendingPathComponent("ListAll.sqlite")
        
        // If old store doesn't exist, nothing to migrate
        guard fileManager.fileExists(atPath: oldStoreURL.path) else {
            return
        }
        
        do {
            // Create App Groups directory if it doesn't exist
            let appGroupsDirectory = newStoreURL.deletingLastPathComponent()
            if !fileManager.fileExists(atPath: appGroupsDirectory.path) {
                try fileManager.createDirectory(at: appGroupsDirectory, withIntermediateDirectories: true, attributes: nil)
            }
            
            // Copy the main database file
            try fileManager.copyItem(at: oldStoreURL, to: newStoreURL)
            
            // Copy associated files (WAL and SHM) if they exist
            let walOldURL = documentsURL.appendingPathComponent("ListAll.sqlite-wal")
            let walNewURL = newStoreURL.deletingLastPathComponent().appendingPathComponent("ListAll.sqlite-wal")
            if fileManager.fileExists(atPath: walOldURL.path) {
                try? fileManager.copyItem(at: walOldURL, to: walNewURL)
            }
            
            let shmOldURL = documentsURL.appendingPathComponent("ListAll.sqlite-shm")
            let shmNewURL = newStoreURL.deletingLastPathComponent().appendingPathComponent("ListAll.sqlite-shm")
            if fileManager.fileExists(atPath: shmOldURL.path) {
                try? fileManager.copyItem(at: shmOldURL, to: shmNewURL)
            }
            
            // Delete old store files to prevent confusion
            try? fileManager.removeItem(at: oldStoreURL)
            try? fileManager.removeItem(at: walOldURL)
            try? fileManager.removeItem(at: shmOldURL)
            
        } catch {
            print("❌ [iOS] Failed to migrate store to App Groups: \(error)")
        }
    }
    
    private func deleteAndRecreateStore(container: NSPersistentContainer, storeDescription: NSPersistentStoreDescription) {
        guard let storeURL = storeDescription.url else {
            return
        }
        
        do {
            // Delete the existing store files
            let fileManager = FileManager.default
            let storeDirectory = storeURL.deletingLastPathComponent()
            
            // Find all store files
            let storeFiles = try fileManager.contentsOfDirectory(at: storeDirectory, includingPropertiesForKeys: nil)
            let storeFileExtensions = ["sqlite", "sqlite-wal", "sqlite-shm"]
            
            for file in storeFiles {
                if storeFileExtensions.contains(file.pathExtension) {
                    try fileManager.removeItem(at: file)
                }
            }
            
            // Reload the store
            try container.persistentStoreCoordinator.addPersistentStore(ofType: NSSQLiteStoreType, configurationName: nil, at: storeURL, options: nil)
            
        } catch {
            print("Failed to delete and recreate store: \(error)")
            // If we still can't create the store, use in-memory store as fallback
            do {
                try container.persistentStoreCoordinator.addPersistentStore(ofType: NSInMemoryStoreType, configurationName: nil, at: nil, options: nil)
            } catch {
                fatalError("Failed to create any persistent store: \(error)")
            }
        }
    }
    
    func migrateDataIfNeeded() {
        // Check if we need to migrate from UserDefaults to Core Data
        if UserDefaults.standard.object(forKey: "saved_lists") != nil {
            migrateFromUserDefaults()
        }
    }
    
    private func migrateFromUserDefaults() {
        guard let data = UserDefaults.standard.data(forKey: "saved_lists"),
              let lists = try? JSONDecoder().decode([List].self, from: data) else {
            return
        }
        
        let context = backgroundContext
        context.perform {
            for listData in lists {
                let list = ListEntity(context: context)
                list.id = listData.id
                list.name = listData.name
                list.orderNumber = Int32(listData.orderNumber)
                list.createdAt = listData.createdAt
                list.modifiedAt = listData.modifiedAt
                list.isArchived = false
                
                for itemData in listData.items {
                    let item = ItemEntity(context: context)
                    item.id = itemData.id
                    item.title = itemData.title
                    item.itemDescription = itemData.itemDescription
                    item.quantity = Int32(itemData.quantity)
                    item.orderNumber = Int32(itemData.orderNumber)
                    item.isCrossedOut = itemData.isCrossedOut
                    item.createdAt = itemData.createdAt
                    item.modifiedAt = itemData.modifiedAt
                    item.list = list
                    
                    for imageData in itemData.images {
                        let image = ItemImageEntity(context: context)
                        image.id = imageData.id
                        image.imageData = imageData.imageData
                        image.orderNumber = Int32(imageData.orderNumber)
                        image.createdAt = imageData.createdAt
                        image.item = item
                    }
                }
            }
            
            self.saveContext(context)
            
            // Clear UserDefaults data after migration
            DispatchQueue.main.async {
                UserDefaults.standard.removeObject(forKey: "saved_lists")
            }
        }
    }
}

// MARK: - Legacy Data Manager (for backward compatibility)
class DataManager: ObservableObject {
    static let shared = DataManager()

    @Published var lists: [List] = []
    private let coreDataManager = CoreDataManager.shared

    private init() {
        loadData()
        
        // Listen for remote changes from other processes (iOS/watchOS)
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleRemoteChange(_:)),
            name: .coreDataRemoteChange,
            object: nil
        )
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    // MARK: - Remote Change Handling

    @objc private func handleRemoteChange(_ notification: Notification) {
        // Reload data from Core Data to reflect changes made by other process
        loadData()
    }
    
    // MARK: - Data Operations
    
    func loadData() {
        // Load from Core Data, excluding archived lists
        let request: NSFetchRequest<ListEntity> = ListEntity.fetchRequest()
        request.predicate = NSPredicate(format: "isArchived == NO OR isArchived == nil")
        request.sortDescriptors = [NSSortDescriptor(keyPath: \ListEntity.orderNumber, ascending: true)]
        
        // CRITICAL: Eagerly fetch items relationship to avoid empty items arrays
        request.relationshipKeyPathsForPrefetching = ["items"]
        
        do {
            let listEntities = try coreDataManager.viewContext.fetch(request)
            
            lists = listEntities.map { $0.toList() }
        } catch {
            print("❌ Failed to fetch lists: \(error)")
            // Fallback to sample data
            if lists.isEmpty {
                createSampleData()
            }
        }
    }
    
    func saveData() {
        coreDataManager.save()
    }

    /// Fresh fetch of active lists from Core Data, sorted by orderNumber
    /// Use this after reordering to get the latest state without affecting the cached lists array
    /// This mirrors the getItems(forListId:) pattern for consistency (DRY)
    func getLists() -> [List] {
        let request: NSFetchRequest<ListEntity> = ListEntity.fetchRequest()
        request.predicate = NSPredicate(format: "isArchived == NO OR isArchived == nil")
        request.sortDescriptors = [NSSortDescriptor(keyPath: \ListEntity.orderNumber, ascending: true)]
        request.relationshipKeyPathsForPrefetching = ["items"]

        do {
            let listEntities = try coreDataManager.viewContext.fetch(request)
            return listEntities.map { $0.toList() }
        } catch {
            print("❌ Failed to fetch lists: \(error)")
            return []
        }
    }

    // MARK: - List Operations
    
    func addList(_ list: List) {
        let context = coreDataManager.viewContext
        let listEntity = ListEntity(context: context)
        listEntity.id = list.id
        listEntity.name = list.name

        // FIX: Calculate next orderNumber (max + 1) to ensure unique sequential ordering
        let maxOrderNumber = lists.map { $0.orderNumber }.max() ?? -1
        let nextOrderNumber = maxOrderNumber + 1
        listEntity.orderNumber = Int32(nextOrderNumber)

        listEntity.createdAt = list.createdAt
        listEntity.modifiedAt = list.modifiedAt
        listEntity.isArchived = false

        saveData()

        // Update the list struct with the assigned orderNumber before appending
        var updatedList = list
        updatedList.orderNumber = nextOrderNumber
        lists.append(updatedList)
        // No need to sort - new list goes to end with highest orderNumber
    }
    
    func updateList(_ list: List) {
        let request: NSFetchRequest<ListEntity> = ListEntity.fetchRequest()
        request.predicate = NSPredicate(format: "id == %@", list.id as CVarArg)
        
        do {
            let results = try coreDataManager.viewContext.fetch(request)
            if let listEntity = results.first {
                listEntity.name = list.name
                listEntity.orderNumber = Int32(list.orderNumber)
                listEntity.modifiedAt = list.modifiedAt
                listEntity.isArchived = list.isArchived
                saveData()
                // Update local array instead of reloading
                if let index = lists.firstIndex(where: { $0.id == list.id }) {
                    lists[index] = list
                }
            }
        } catch {
            print("Failed to update list: \(error)")
        }
    }
    
    func updateListsOrder(_ newOrder: [List]) {
        // FIX: Batch fetch all entities ONCE instead of N separate fetches (O(n) vs O(n²))
        let context = coreDataManager.viewContext

        // Fetch ALL list entities in a single query
        let request: NSFetchRequest<ListEntity> = ListEntity.fetchRequest()
        let listIds = newOrder.map { $0.id }
        request.predicate = NSPredicate(format: "id IN %@", listIds)

        do {
            let allEntities = try context.fetch(request)

            // Create lookup dictionary for O(1) access
            var entityById: [UUID: ListEntity] = [:]
            for entity in allEntities {
                if let id = entity.id {
                    entityById[id] = entity
                }
            }

            // Update all entities in memory (O(n))
            for list in newOrder {
                if let entity = entityById[list.id] {
                    entity.orderNumber = Int32(list.orderNumber)
                    entity.modifiedAt = list.modifiedAt
                }
            }
        } catch {
            print("Failed to batch update list order: \(error)")
        }

        // Save once after all updates
        saveData()

        // CRITICAL: Ensure Core Data has processed all changes before continuing
        context.processPendingChanges()

        // Update local array to match
        lists = newOrder
    }
    
    func synchronizeLists(_ newOrder: [List]) {
        // Synchronize internal lists array with the provided order
        // This ensures that subsequent reloads maintain the correct order
        lists = newOrder
    }
    
    func deleteList(withId id: UUID) {
        // Archive the list instead of permanently deleting it
        let request: NSFetchRequest<ListEntity> = ListEntity.fetchRequest()
        request.predicate = NSPredicate(format: "id == %@", id as CVarArg)
        
        do {
            let results = try coreDataManager.viewContext.fetch(request)
            if let listEntity = results.first {
                listEntity.isArchived = true
                listEntity.modifiedAt = Date()
                saveData()
                // Remove from local array (archived lists are filtered out)
                lists.removeAll { $0.id == id }
            }
        } catch {
            print("Failed to archive list: \(error)")
        }
    }
    
    func loadArchivedLists() -> [List] {
        // Load archived lists from Core Data
        let request: NSFetchRequest<ListEntity> = ListEntity.fetchRequest()
        request.predicate = NSPredicate(format: "isArchived == YES")
        request.sortDescriptors = [NSSortDescriptor(keyPath: \ListEntity.modifiedAt, ascending: false)]
        
        do {
            let listEntities = try coreDataManager.viewContext.fetch(request)
            return listEntities.map { $0.toList() }
        } catch {
            print("Failed to fetch archived lists: \(error)")
            return []
        }
    }
    
    func restoreList(withId id: UUID) {
        // Restore an archived list
        let request: NSFetchRequest<ListEntity> = ListEntity.fetchRequest()
        request.predicate = NSPredicate(format: "id == %@", id as CVarArg)
        
        do {
            let results = try coreDataManager.viewContext.fetch(request)
            if let listEntity = results.first {
                listEntity.isArchived = false
                listEntity.modifiedAt = Date()
                saveData()
                // Reload data to include the restored list
                loadData()
            }
        } catch {
            print("Failed to restore list: \(error)")
        }
    }
    
    func permanentlyDeleteList(withId id: UUID) {
        // Permanently delete a list and all its associated items
        let listRequest: NSFetchRequest<ListEntity> = ListEntity.fetchRequest()
        listRequest.predicate = NSPredicate(format: "id == %@", id as CVarArg)
        
        do {
            let results = try coreDataManager.viewContext.fetch(listRequest)
            if let listEntity = results.first {
                // Delete all items in the list first
                if let items = listEntity.items as? Set<ItemEntity> {
                    for itemEntity in items {
                        // Delete all images in the item
                        if let images = itemEntity.images as? Set<ItemImageEntity> {
                            for imageEntity in images {
                                coreDataManager.viewContext.delete(imageEntity)
                            }
                        }
                        // Delete the item
                        coreDataManager.viewContext.delete(itemEntity)
                    }
                }
                // Delete the list itself
                coreDataManager.viewContext.delete(listEntity)
                saveData()
            }
        } catch {
            print("Failed to permanently delete list: \(error)")
        }
    }
    
    // MARK: - Item Operations
    
    func addItem(_ item: Item, to listId: UUID) {
        let context = coreDataManager.viewContext
        
        // Check if item already exists (prevent duplicates during sync)
        let itemCheck: NSFetchRequest<ItemEntity> = ItemEntity.fetchRequest()
        itemCheck.predicate = NSPredicate(format: "id == %@", item.id as CVarArg)
        
        do {
            let existingItems = try context.fetch(itemCheck)
            if let existingItem = existingItems.first {
                // Item already exists, update it instead
                existingItem.title = item.title
                existingItem.itemDescription = item.itemDescription
                existingItem.quantity = Int32(item.quantity)
                existingItem.orderNumber = Int32(item.orderNumber)
                existingItem.isCrossedOut = item.isCrossedOut
                existingItem.modifiedAt = item.modifiedAt
                
                saveData()
                // Don't call loadData() here - let the caller handle batching
                return
            }
        } catch {
            print("Failed to check for existing item: \(error)")
        }
        
        // Find the list
        let listRequest: NSFetchRequest<ListEntity> = ListEntity.fetchRequest()
        listRequest.predicate = NSPredicate(format: "id == %@", listId as CVarArg)
        
        do {
            let listResults = try context.fetch(listRequest)
            if let listEntity = listResults.first {
                let itemEntity = ItemEntity(context: context)
                itemEntity.id = item.id
                itemEntity.title = item.title
                itemEntity.itemDescription = item.itemDescription
                itemEntity.quantity = Int32(item.quantity)
                itemEntity.orderNumber = Int32(item.orderNumber)
                itemEntity.isCrossedOut = item.isCrossedOut
                itemEntity.createdAt = item.createdAt
                itemEntity.modifiedAt = item.modifiedAt
                itemEntity.list = listEntity
                
                // Create image entities from the item's images
                // CRITICAL FIX: Check for duplicate image IDs to prevent Core Data conflicts
                for itemImage in item.images {
                    // Check if image entity with this ID already exists
                    let imageCheck: NSFetchRequest<ItemImageEntity> = ItemImageEntity.fetchRequest()
                    imageCheck.predicate = NSPredicate(format: "id == %@", itemImage.id as CVarArg)
                    
                    let existingImages = try context.fetch(imageCheck)
                    if let existingImage = existingImages.first {
                        // Image ID already exists - create a new one with a different ID
                        // This can happen if the same item is added to multiple lists
                        var newImageData = itemImage
                        newImageData.id = UUID() // Force new ID to avoid conflict
                        let imageEntity = ItemImageEntity.fromItemImage(newImageData, context: context)
                        imageEntity.item = itemEntity
                    } else {
                        // Normal case - create image entity with original ID
                        let imageEntity = ItemImageEntity.fromItemImage(itemImage, context: context)
                        imageEntity.item = itemEntity
                    }
                }
                
                saveData()
                // Don't call loadData() here - let the caller handle batching
                
                // Notify after data is saved (but don't reload yet to avoid excessive reloads)
                NotificationCenter.default.post(name: NSNotification.Name("ItemDataChanged"), object: nil)
            }
        } catch {
            print("Failed to add item: \(error)")
        }
    }
    
    func updateItem(_ item: Item) {
        let request: NSFetchRequest<ItemEntity> = ItemEntity.fetchRequest()
        request.predicate = NSPredicate(format: "id == %@", item.id as CVarArg)
        
        do {
            let results = try coreDataManager.viewContext.fetch(request)
            if let itemEntity = results.first {
                // Update basic properties
                itemEntity.title = item.title
                itemEntity.itemDescription = item.itemDescription
                itemEntity.quantity = Int32(item.quantity)
                itemEntity.orderNumber = Int32(item.orderNumber)
                itemEntity.isCrossedOut = item.isCrossedOut
                itemEntity.modifiedAt = item.modifiedAt
                
                // Update images: First delete existing image entities
                if let existingImages = itemEntity.images?.allObjects as? [ItemImageEntity] {
                    for imageEntity in existingImages {
                        coreDataManager.viewContext.delete(imageEntity)
                    }
                }
                
                // Create new image entities from the item's images
                for itemImage in item.images {
                    let imageEntity = ItemImageEntity.fromItemImage(itemImage, context: coreDataManager.viewContext)
                    imageEntity.item = itemEntity
                }
                
                saveData()
                loadData()
                
                // Notify after data is fully loaded
                NotificationCenter.default.post(name: NSNotification.Name("ItemDataChanged"), object: nil)
            }
        } catch {
            print("Failed to update item: \(error)")
        }
    }
    
    func deleteItem(withId id: UUID, from listId: UUID) {
        let request: NSFetchRequest<ItemEntity> = ItemEntity.fetchRequest()
        request.predicate = NSPredicate(format: "id == %@", id as CVarArg)
        
        do {
            let results = try coreDataManager.viewContext.fetch(request)
            for itemEntity in results {
                coreDataManager.viewContext.delete(itemEntity)
            }
            saveData()
            loadData()
            
            // Notify after data is fully loaded
            NotificationCenter.default.post(name: NSNotification.Name("ItemDataChanged"), object: nil)
        } catch {
            print("Failed to delete item: \(error)")
        }
    }
    
    func getItems(forListId listId: UUID) -> [Item] {
        let request: NSFetchRequest<ItemEntity> = ItemEntity.fetchRequest()
        request.predicate = NSPredicate(format: "list.id == %@", listId as CVarArg)
        // Sort by orderNumber to ensure consistent display order
        request.sortDescriptors = [NSSortDescriptor(keyPath: \ItemEntity.orderNumber, ascending: true)]
        
        do {
            let itemEntities = try coreDataManager.viewContext.fetch(request)
            return itemEntities.map { $0.toItem() }
        } catch {
            print("Failed to fetch items: \(error)")
            return []
        }
    }
    
    // MARK: - Sample Data
    
    private func createSampleData() {
        let sampleList1 = List(name: "Grocery Shopping")
        let sampleList2 = List(name: "Home Improvement")
        
        var list1 = sampleList1
        list1.addItem(Item(title: "Milk"))
        list1.addItem(Item(title: "Bread"))
        list1.addItem(Item(title: "Eggs"))
        
        var list2 = sampleList2
        list2.addItem(Item(title: "Paint"))
        list2.addItem(Item(title: "Brushes"))
        
        lists = [list1, list2]
        
        // Save sample data to Core Data
        for list in lists {
            addList(list)
        }
    }
    
    // MARK: - CloudKit Status (Delegated to Core Data Manager)
    
    func checkCloudKitStatus() async -> CKAccountStatus {
        return await coreDataManager.checkCloudKitStatus()
    }
    
    // MARK: - Data Cleanup
    
    /// Remove duplicate lists from Core Data (cleanup for CloudKit sync bug)
    /// This removes lists with duplicate IDs, keeping the most recently modified version
    func removeDuplicateLists() {
        let context = coreDataManager.viewContext
        let request: NSFetchRequest<ListEntity> = ListEntity.fetchRequest()
        
        do {
            let allLists = try context.fetch(request)
            
            // Group lists by ID
            var listsById: [UUID: [ListEntity]] = [:]
            for list in allLists {
                guard let id = list.id else { continue }
                if listsById[id] == nil {
                    listsById[id] = []
                }
                listsById[id]?.append(list)
            }
            
            // Find and remove duplicates
            var duplicatesRemoved = 0
            for (_, lists) in listsById {
                if lists.count > 1 {
                    // Sort by modifiedAt, keep most recent
                    let sorted = lists.sorted { ($0.modifiedAt ?? Date.distantPast) > ($1.modifiedAt ?? Date.distantPast) }
                    let toKeep = sorted.first!
                    let toRemove = sorted.dropFirst()
                    
                    for duplicate in toRemove {
                        // Delete items in duplicate list first
                        if let items = duplicate.items as? Set<ItemEntity> {
                            for item in items {
                                // Transfer items to the list we're keeping
                                item.list = toKeep
                            }
                        }
                        context.delete(duplicate)
                        duplicatesRemoved += 1
                    }
                }
            }
            
            if duplicatesRemoved > 0 {
                saveData()
                loadData() // Reload to reflect changes
            }
        } catch {
            print("❌ Failed to check for duplicate lists: \(error)")
        }
    }
    
    /// Remove duplicate items from Core Data (cleanup for sync bug)
    /// This removes items with duplicate IDs, keeping the most recently modified version
    func removeDuplicateItems() {
        let context = coreDataManager.viewContext
        let request: NSFetchRequest<ItemEntity> = ItemEntity.fetchRequest()
        
        do {
            let allItems = try context.fetch(request)
            
            // Group items by ID
            var itemsById: [UUID: [ItemEntity]] = [:]
            for item in allItems {
                guard let id = item.id else { continue }
                if itemsById[id] == nil {
                    itemsById[id] = []
                }
                itemsById[id]?.append(item)
            }
            
            // Find and remove duplicates
            var duplicatesRemoved = 0
            for (_, items) in itemsById {
                if items.count > 1 {
                    // Sort by modifiedAt, keep most recent
                    let sorted = items.sorted { ($0.modifiedAt ?? Date.distantPast) > ($1.modifiedAt ?? Date.distantPast) }
                    let toKeep = sorted.first!
                    let toRemove = sorted.dropFirst()
                    
                    for duplicate in toRemove {
                        context.delete(duplicate)
                        duplicatesRemoved += 1
                    }
                }
            }
            
            if duplicatesRemoved > 0 {
                saveData()
                loadData() // Reload to reflect changes
            }
        } catch {
            print("❌ Failed to check for duplicate items: \(error)")
        }
    }
}