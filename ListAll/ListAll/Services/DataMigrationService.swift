import Foundation
import CoreData
import Combine

class DataMigrationService {
    /// Lazy initialization to prevent App Groups access dialog on unsigned test builds
    private lazy var coreDataManager = CoreDataManager.shared
    
    // MARK: - Migration Status
    
    enum MigrationStatus {
        case notNeeded
        case inProgress
        case completed
        case failed(Error)
    }
    
    @Published var migrationStatus: MigrationStatus = .notNeeded
    
    // MARK: - Migration Operations
    
    func performMigrationIfNeeded() async {
        await MainActor.run {
            migrationStatus = .inProgress
        }
        
        do {
            // Check if migration is needed
            if await isMigrationNeeded() {
                try await performMigration()
            }
            
            await MainActor.run {
                migrationStatus = .completed
            }
        } catch {
            await MainActor.run {
                migrationStatus = .failed(error)
            }
        }
    }
    
    private func isMigrationNeeded() async -> Bool {
        // Check if we have UserDefaults data that needs migration
        return UserDefaults.standard.object(forKey: "saved_lists") != nil
    }
    
    private func performMigration() async throws {
        // Migrate from UserDefaults to Core Data
        guard let data = UserDefaults.standard.data(forKey: "saved_lists"),
              let lists = try? JSONDecoder().decode([List].self, from: data) else {
            return
        }
        
        let context = coreDataManager.backgroundContext
        
        try await context.perform {
            // Create user data first
            let userData = UserData(userID: "default_user")
            let userEntity = UserDataEntity.fromUserData(userData, context: context)
            
            // Migrate lists
            for listData in lists {
                let listEntity = ListEntity.fromList(listData, context: context)
                listEntity.owner = userEntity
                
                // Migrate items
                for itemData in listData.items {
                    let itemEntity = ItemEntity.fromItem(itemData, context: context)
                    itemEntity.list = listEntity
                    
                    // Migrate images
                    for imageData in itemData.images {
                        let imageEntity = ItemImageEntity.fromItemImage(imageData, context: context)
                        imageEntity.item = itemEntity
                    }
                }
            }
            
            // Save the context
            try context.save()
        }
        
        // Clear UserDefaults data after successful migration
        await MainActor.run {
            UserDefaults.standard.removeObject(forKey: "saved_lists")
        }
    }
    
    // MARK: - Schema Migration
    
    func migrateSchemaIfNeeded() async throws {
        // This would handle Core Data model version migrations
        // For now, we're using a simple model without versioning
    }
    
    // MARK: - Data Cleanup
    
    func cleanupOrphanedData() async {
        let context = coreDataManager.backgroundContext
        
        await context.perform {
            // Clean up orphaned items
            let orphanedItemsRequest: NSFetchRequest<ItemEntity> = ItemEntity.fetchRequest()
            orphanedItemsRequest.predicate = NSPredicate(format: "list == nil")
            
            do {
                let orphanedItems = try context.fetch(orphanedItemsRequest)
                for item in orphanedItems {
                    context.delete(item)
                }
            } catch {
            }
            
            // Clean up orphaned images
            let orphanedImagesRequest: NSFetchRequest<ItemImageEntity> = ItemImageEntity.fetchRequest()
            orphanedImagesRequest.predicate = NSPredicate(format: "item == nil")
            
            do {
                let orphanedImages = try context.fetch(orphanedImagesRequest)
                for image in orphanedImages {
                    context.delete(image)
                }
            } catch {
            }
            
            // Save changes
            do {
                try context.save()
            } catch {
            }
        }
    }
    
    // MARK: - Data Validation
    
    func validateMigratedData() async -> [String] {
        var issues: [String] = []
        
        let context = coreDataManager.viewContext
        
        // Check for data integrity issues
        let listsRequest: NSFetchRequest<ListEntity> = ListEntity.fetchRequest()
        
        do {
            let lists = try context.fetch(listsRequest)
            
            for list in lists {
                // Check for empty list names
                if list.name?.isEmpty == true {
                    issues.append("List with ID \(list.id?.uuidString ?? "unknown") has empty name")
                }
                
                // Check for items
                if let items = list.items as? Set<ItemEntity> {
                    for item in items {
                        // Check for empty item titles
                        if item.title?.isEmpty == true {
                            issues.append("Item in list '\(list.name ?? "unknown")' has empty title")
                        }
                        
                        // Check for invalid quantities
                        if item.quantity < 1 {
                            issues.append("Item '\(item.title ?? "unknown")' has invalid quantity: \(item.quantity)")
                        }
                    }
                }
            }
        } catch {
            issues.append("Failed to validate data: \(error.localizedDescription)")
        }
        
        return issues
    }
    
    // MARK: - Backup and Restore
    
    func createBackup() async -> Data? {
        let context = coreDataManager.viewContext
        
        return await context.perform {
            let listsRequest: NSFetchRequest<ListEntity> = ListEntity.fetchRequest()
            
            do {
                let listEntities = try context.fetch(listsRequest)
                let lists = listEntities.map { $0.toList() }
                
                return try JSONEncoder().encode(lists)
            } catch {
                return nil
            }
        }
    }
    
    func restoreFromBackup(_ data: Data) async throws {
        let lists = try JSONDecoder().decode([List].self, from: data)
        
        let context = coreDataManager.backgroundContext
        
        try await context.perform {
            // Clear existing data
            let listsRequest: NSFetchRequest<ListEntity> = ListEntity.fetchRequest()
            let existingLists = try context.fetch(listsRequest)
            
            for list in existingLists {
                context.delete(list)
            }
            
            // Restore from backup
            let userData = UserData(userID: "default_user")
            let userEntity = UserDataEntity.fromUserData(userData, context: context)
            
            for listData in lists {
                let listEntity = ListEntity.fromList(listData, context: context)
                listEntity.owner = userEntity
                
                for itemData in listData.items {
                    let itemEntity = ItemEntity.fromItem(itemData, context: context)
                    itemEntity.list = listEntity
                    
                    for imageData in itemData.images {
                        let imageEntity = ItemImageEntity.fromItemImage(imageData, context: context)
                        imageEntity.item = itemEntity
                    }
                }
            }
            
            try context.save()
        }
    }
}
