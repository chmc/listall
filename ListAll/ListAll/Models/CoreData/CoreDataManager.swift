import Foundation
import CoreData
import CloudKit
import Combine

// MARK: - Core Data Manager
class CoreDataManager: ObservableObject {
    static let shared = CoreDataManager()
    
    // MARK: - Core Data Stack
    lazy var persistentContainer: NSPersistentContainer = {
        // Note: Using NSPersistentContainer instead of NSPersistentCloudKitContainer
        // CloudKit sync will be enabled when developer account is available
        let container = NSPersistentContainer(name: "ListAll")
        
        // Configure store description for migration
        guard let storeDescription = container.persistentStoreDescriptions.first else {
            fatalError("Failed to retrieve a persistent store description.")
        }
        
        // Configure App Groups shared container URL
        let appGroupID = "group.io.github.chmc.ListAll"
        if let containerURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupID) {
            let storeURL = containerURL.appendingPathComponent("ListAll.sqlite")
            storeDescription.url = storeURL
            #if os(watchOS)
            print("✅ [watchOS] Core Data: Using App Groups container at \(storeURL.path)")
            #else
            print("✅ [iOS] Core Data: Using App Groups container at \(storeURL.path)")
            #endif
        } else {
            #if os(watchOS)
            print("⚠️ [watchOS] Core Data: Warning - App Groups container not available, using default location")
            #else
            print("⚠️ [iOS] Core Data: Warning - App Groups container not available, using default location")
            #endif
        }
        
        // Enable automatic migration
        storeDescription.shouldMigrateStoreAutomatically = true
        storeDescription.shouldInferMappingModelAutomatically = true
        
        // Note: CloudKit configuration commented out - requires paid developer account
        // Uncomment when ready to enable CloudKit sync:
        // let cloudKitContainerOptions = NSPersistentCloudKitContainerOptions(containerIdentifier: "iCloud.io.github.chmc.ListAll")
        // storeDescription.cloudKitContainerOptions = cloudKitContainerOptions
        
        container.loadPersistentStores { [weak self] storeDescription, error in
            if let error = error as NSError? {
                #if os(watchOS)
                print("❌ [watchOS] Core Data error: \(error), \(error.userInfo)")
                #else
                print("❌ [iOS] Core Data error: \(error), \(error.userInfo)")
                #endif
                
                // If migration fails, try to delete and recreate the store
                if error.code == 134110 { // Migration error
                    print("Migration failed, attempting to delete and recreate store...")
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
        #if os(watchOS)
        print("🔵 [watchOS] CoreDataManager initializing...")
        #else
        print("🔵 [iOS] CoreDataManager initializing...")
        #endif
        
        // Force load of persistent container
        _ = persistentContainer
        
        #if os(watchOS)
        print("🔵 [watchOS] CoreDataManager initialized successfully")
        #else
        print("🔵 [iOS] CoreDataManager initialized successfully")
        #endif
    }
    
    // MARK: - Core Data Operations
    
    func save() {
        let context = persistentContainer.viewContext
        
        if context.hasChanges {
            do {
                try context.save()
            } catch {
                print("Failed to save context: \(error)")
            }
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
    
    private func deleteAndRecreateStore(container: NSPersistentContainer, storeDescription: NSPersistentStoreDescription) {
        guard let storeURL = storeDescription.url else {
            print("No store URL available")
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
                    print("Deleted store file: \(file.lastPathComponent)")
                }
            }
            
            // Reload the store
            try container.persistentStoreCoordinator.addPersistentStore(ofType: NSSQLiteStoreType, configurationName: nil, at: storeURL, options: nil)
            print("Successfully recreated store")
            
        } catch {
            print("Failed to delete and recreate store: \(error)")
            // If we still can't create the store, use in-memory store as fallback
            do {
                try container.persistentStoreCoordinator.addPersistentStore(ofType: NSInMemoryStoreType, configurationName: nil, at: nil, options: nil)
                print("Using in-memory store as fallback")
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
    }
    
    // MARK: - Data Operations
    
    func loadData() {
        // Load from Core Data, excluding archived lists
        let request: NSFetchRequest<ListEntity> = ListEntity.fetchRequest()
        request.predicate = NSPredicate(format: "isArchived == NO OR isArchived == nil")
        request.sortDescriptors = [NSSortDescriptor(keyPath: \ListEntity.orderNumber, ascending: true)]
        
        do {
            let listEntities = try coreDataManager.viewContext.fetch(request)
            lists = listEntities.map { $0.toList() }
        } catch {
            print("Failed to fetch lists: \(error)")
            // Fallback to sample data
            if lists.isEmpty {
                createSampleData()
            }
        }
    }
    
    func saveData() {
        coreDataManager.save()
    }
    
    // MARK: - List Operations
    
    func addList(_ list: List) {
        let context = coreDataManager.viewContext
        let listEntity = ListEntity(context: context)
        listEntity.id = list.id
        listEntity.name = list.name
        listEntity.orderNumber = Int32(list.orderNumber)
        listEntity.createdAt = list.createdAt
        listEntity.modifiedAt = list.modifiedAt
        listEntity.isArchived = false
        
        saveData()
        // Add to local array and sort instead of reloading
        lists.append(list)
        lists.sort { $0.orderNumber < $1.orderNumber }
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
        // Batch update all list order numbers in a single operation
        // This is more efficient than calling updateList() for each list separately
        let context = coreDataManager.viewContext
        
        for list in newOrder {
            let request: NSFetchRequest<ListEntity> = ListEntity.fetchRequest()
            request.predicate = NSPredicate(format: "id == %@", list.id as CVarArg)
            
            do {
                let results = try context.fetch(request)
                if let listEntity = results.first {
                    listEntity.orderNumber = Int32(list.orderNumber)
                    listEntity.modifiedAt = list.modifiedAt
                }
            } catch {
                print("Failed to update list order for \(list.name): \(error)")
            }
        }
        
        // Save once after all updates
        saveData()
        
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
                for itemImage in item.images {
                    let imageEntity = ItemImageEntity.fromItemImage(itemImage, context: context)
                    imageEntity.item = itemEntity
                }
                
                saveData()
                loadData()
                
                // Notify after data is fully loaded
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
}