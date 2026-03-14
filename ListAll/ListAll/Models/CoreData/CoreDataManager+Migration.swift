import Foundation
import CoreData

// MARK: - Data Migration

extension CoreDataManager {

    /// Migrates Core Data store from old location (app's Documents) to App Groups shared container
    /// This is only needed once when upgrading from pre-App Groups version
    func migrateToAppGroupsIfNeeded(newStoreURL: URL) {
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

    func deleteAndRecreateStore(container: NSPersistentContainer, storeDescription: NSPersistentStoreDescription) {
        guard var storeURL = storeDescription.url else {
            print("⚠️ CoreDataManager: No store URL to delete")
            return
        }

        // Check if we can write to the store directory - if not, use Documents fallback
        let storeDirectory = storeURL.deletingLastPathComponent()
        if !FileManager.default.isWritableFile(atPath: storeDirectory.path) {
            print("⚠️ CoreDataManager: No write permission to \(storeDirectory.path)")
            print("⚠️ CoreDataManager: Using Documents directory fallback")

            if let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first {
                #if DEBUG
                storeURL = documentsURL.appendingPathComponent("ListAll-Debug.sqlite")
                #else
                storeURL = documentsURL.appendingPathComponent("ListAll.sqlite")
                #endif
                storeDescription.url = storeURL
            }
        }

        print("🗑️ CoreDataManager: Deleting and recreating store at \(storeURL.path)")

        do {
            // Delete the existing store files
            let fileManager = FileManager.default
            let storeDirectory = storeURL.deletingLastPathComponent()

            // Find all store-related files and directories
            let storeFiles = try fileManager.contentsOfDirectory(at: storeDirectory, includingPropertiesForKeys: nil)
            let storeFileExtensions = ["sqlite", "sqlite-wal", "sqlite-shm"]
            let storeName = storeURL.deletingPathExtension().lastPathComponent

            for file in storeFiles {
                let fileName = file.lastPathComponent
                let fileExtension = file.pathExtension

                // Delete SQLite files
                if storeFileExtensions.contains(fileExtension) && fileName.hasPrefix(storeName) {
                    print("🗑️ CoreDataManager: Deleting \(fileName)")
                    try fileManager.removeItem(at: file)
                }

                // Also delete CloudKit cache directory if it exists (e.g., "ListAll_ckAssets")
                if fileName.hasPrefix(storeName) && fileName.hasSuffix("_ckAssets") {
                    print("🗑️ CoreDataManager: Deleting CloudKit cache \(fileName)")
                    try fileManager.removeItem(at: file)
                }
            }

            // Reload the store with proper options
            let options: [String: Any] = [
                NSMigratePersistentStoresAutomaticallyOption: true,
                NSInferMappingModelAutomaticallyOption: true,
                NSPersistentHistoryTrackingKey: true
            ]

            print("🔄 CoreDataManager: Recreating store...")
            try container.persistentStoreCoordinator.addPersistentStore(
                ofType: NSSQLiteStoreType,
                configurationName: nil,
                at: storeURL,
                options: options
            )
            print("✅ CoreDataManager: Store recreated successfully")

        } catch {
            print("❌ CoreDataManager: Failed to delete and recreate store: \(error)")
            // If we still can't create the store, use in-memory store as fallback
            do {
                print("⚠️ CoreDataManager: Falling back to in-memory store")
                try container.persistentStoreCoordinator.addPersistentStore(
                    ofType: NSInMemoryStoreType,
                    configurationName: nil,
                    at: nil,
                    options: nil
                )
                print("✅ CoreDataManager: In-memory store created (data will not persist)")
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

    func migrateFromUserDefaults() {
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
