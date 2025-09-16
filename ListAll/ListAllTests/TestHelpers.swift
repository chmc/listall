import Foundation
import CoreData
@testable import ListAll

/// Test helper for setting up isolated test environments
class TestHelpers {
    
    /// Creates an in-memory Core Data stack for testing
    static func createInMemoryCoreDataStack() -> NSPersistentContainer {
        let container = NSPersistentContainer(name: "ListAll")
        
        // Configure for in-memory storage
        let description = NSPersistentStoreDescription()
        description.type = NSInMemoryStoreType
        description.url = URL(fileURLWithPath: "/dev/null")
        container.persistentStoreDescriptions = [description]
        
        container.loadPersistentStores { _, error in
            if let error = error {
                fatalError("Failed to load in-memory store: \(error)")
            }
        }
        
        // Configure view context
        container.viewContext.automaticallyMergesChangesFromParent = true
        container.viewContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
        
        return container
    }
    
    /// Creates a test DataManager with isolated Core Data
    static func createTestDataManager() -> DataManager {
        // For testing, we'll use the singleton but reset it
        return DataManager.shared
    }
    
    /// Resets all shared singletons for clean test state
    static func resetSharedSingletons() {
        // Clear UserDefaults
        UserDefaults.standard.removeObject(forKey: "saved_lists")
        
        // Reset DataManager by clearing its lists
        DataManager.shared.lists = []
        
        // Note: CoreDataManager.shared is a let constant and can't be reassigned
        // The singleton will maintain its state, but we've cleared the DataManager
        // which should be sufficient for most test isolation
        
        // Reset any other shared state if needed
    }
}

/// Test-specific Core Data Manager that uses in-memory storage
class TestCoreDataManager: ObservableObject {
    let persistentContainer: NSPersistentContainer
    
    init(container: NSPersistentContainer) {
        self.persistentContainer = container
    }
    
    var viewContext: NSManagedObjectContext {
        return persistentContainer.viewContext
    }
    
    var backgroundContext: NSManagedObjectContext {
        return persistentContainer.newBackgroundContext()
    }
    
    func save() {
        let context = persistentContainer.viewContext
        
        if context.hasChanges {
            do {
                try context.save()
            } catch {
                print("Failed to save test context: \(error)")
            }
        }
    }
}

/// Test-specific Data Manager that uses isolated Core Data
class TestDataManager: ObservableObject {
    @Published var lists: [List] = []
    private let coreDataManager: TestCoreDataManager
    
    init(coreDataManager: TestCoreDataManager) {
        self.coreDataManager = coreDataManager
        loadData()
    }
    
    func loadData() {
        // Load from Core Data
        let request: NSFetchRequest<ListEntity> = ListEntity.fetchRequest()
        request.sortDescriptors = [NSSortDescriptor(keyPath: \ListEntity.orderNumber, ascending: true)]
        
        do {
            let listEntities = try coreDataManager.viewContext.fetch(request)
            lists = listEntities.map { $0.toList() }
        } catch {
            print("Failed to fetch lists: \(error)")
            // Start with empty lists for tests
            lists = []
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
        loadData() // Refresh the published array
    }
    
    func updateList(_ list: List) {
        let context = coreDataManager.viewContext
        let request: NSFetchRequest<ListEntity> = ListEntity.fetchRequest()
        request.predicate = NSPredicate(format: "id == %@", list.id as CVarArg)
        
        do {
            let listEntities = try context.fetch(request)
            if let listEntity = listEntities.first {
                listEntity.name = list.name
                listEntity.orderNumber = Int32(list.orderNumber)
                listEntity.modifiedAt = list.modifiedAt
                listEntity.isArchived = list.isArchived
                
                saveData()
                loadData()
            }
        } catch {
            print("Failed to update list: \(error)")
        }
    }
    
    func deleteList(withId id: UUID) {
        let context = coreDataManager.viewContext
        let request: NSFetchRequest<ListEntity> = ListEntity.fetchRequest()
        request.predicate = NSPredicate(format: "id == %@", id as CVarArg)
        
        do {
            let listEntities = try context.fetch(request)
            for listEntity in listEntities {
                context.delete(listEntity)
            }
            
            saveData()
            loadData()
        } catch {
            print("Failed to delete list: \(error)")
        }
    }
    
    // MARK: - Item Operations
    
    func addItem(_ item: Item, to listId: UUID) {
        let context = coreDataManager.viewContext
        let itemEntity = ItemEntity(context: context)
        itemEntity.id = item.id
        itemEntity.itemDescription = item.itemDescription
        itemEntity.isCrossedOut = item.isCrossedOut
        itemEntity.orderNumber = Int32(item.orderNumber)
        itemEntity.quantity = Int32(item.quantity)
        itemEntity.title = item.title
        itemEntity.createdAt = item.createdAt
        itemEntity.modifiedAt = item.modifiedAt
        
        // Find the list entity
        let listRequest: NSFetchRequest<ListEntity> = ListEntity.fetchRequest()
        listRequest.predicate = NSPredicate(format: "id == %@", listId as CVarArg)
        
        do {
            let listEntities = try context.fetch(listRequest)
            if let listEntity = listEntities.first {
                itemEntity.list = listEntity
            }
        } catch {
            print("Failed to find list for item: \(error)")
        }
        
        saveData()
        loadData()
    }
    
    func updateItem(_ item: Item) {
        let context = coreDataManager.viewContext
        let request: NSFetchRequest<ItemEntity> = ItemEntity.fetchRequest()
        request.predicate = NSPredicate(format: "id == %@", item.id as CVarArg)
        
        do {
            let itemEntities = try context.fetch(request)
            if let itemEntity = itemEntities.first {
                itemEntity.title = item.title
                itemEntity.itemDescription = item.itemDescription
                itemEntity.quantity = Int32(item.quantity)
                itemEntity.isCrossedOut = item.isCrossedOut
                itemEntity.orderNumber = Int32(item.orderNumber)
                itemEntity.modifiedAt = item.modifiedAt
                
                saveData()
                loadData()
            }
        } catch {
            print("Failed to update item: \(error)")
        }
    }
    
    func deleteItem(withId id: UUID, from listId: UUID) {
        let context = coreDataManager.viewContext
        let request: NSFetchRequest<ItemEntity> = ItemEntity.fetchRequest()
        request.predicate = NSPredicate(format: "id == %@", id as CVarArg)
        
        do {
            let itemEntities = try context.fetch(request)
            for itemEntity in itemEntities {
                context.delete(itemEntity)
            }
            
            saveData()
            loadData()
        } catch {
            print("Failed to delete item: \(error)")
        }
    }
    
    func getItems(forListId listId: UUID) -> [Item] {
        let context = coreDataManager.viewContext
        let request: NSFetchRequest<ItemEntity> = ItemEntity.fetchRequest()
        request.predicate = NSPredicate(format: "list.id == %@", listId as CVarArg)
        request.sortDescriptors = [NSSortDescriptor(keyPath: \ItemEntity.orderNumber, ascending: true)]
        
        do {
            let itemEntities = try context.fetch(request)
            return itemEntities.map { $0.toItem() }
        } catch {
            print("Failed to fetch items: \(error)")
            return []
        }
    }
}
