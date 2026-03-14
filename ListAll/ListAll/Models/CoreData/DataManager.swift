import Foundation
import CoreData
import CloudKit
import Combine

// MARK: - Legacy Data Manager (for backward compatibility)
class DataManager: ObservableObject {
    static let shared = DataManager()

    @Published var lists: [List] = []
    @Published var archivedLists: [List] = []
    let coreDataManager = CoreDataManager.shared

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

    // MARK: - Test Support

    #if DEBUG
    /// Reset singleton state for test isolation
    /// WARNING: Only call from test tearDown() - NOT safe for production use
    static func resetForTesting() {
        // Only reset in test environment
        guard ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil else {
            print("⚠️ DataManager.resetForTesting() called outside test environment - ignoring")
            return
        }

        // Remove notification observers
        NotificationCenter.default.removeObserver(shared)

        // Clear cached data
        shared.lists = []
        shared.archivedLists = []

        // Reset underlying Core Data manager
        CoreDataManager.resetForTesting()

        // Re-register for notifications
        NotificationCenter.default.addObserver(
            shared,
            selector: #selector(shared.handleRemoteChange(_:)),
            name: .coreDataRemoteChange,
            object: nil
        )

        print("🧪 DataManager: Reset for testing completed")
    }
    #endif

    // MARK: - Remote Change Handling

    @objc private func handleRemoteChange(_ notification: Notification) {
        // CRITICAL: @objc selectors can be called from any thread - ensure main thread
        // WITHOUT this guard, loadData() may attempt @Published updates from background thread,
        // causing SwiftUI to silently ignore changes (iOS CloudKit sync appears "delayed")
        guard Thread.isMainThread else {
            DispatchQueue.main.async { [weak self] in
                self?.handleRemoteChange(notification)
            }
            return
        }

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
        // Also prefetch items.images to prevent N+1 query when loading images
        request.relationshipKeyPathsForPrefetching = ["items", "items.images"]

        do {
            let listEntities = try coreDataManager.viewContext.fetch(request)
            let newLists = listEntities.map { $0.toList() }

            // CRITICAL FIX: Update @Published property SYNCHRONOUSLY on main thread
            // Using DispatchQueue.main.async with [weak self] BREAKS SwiftUI observation on macOS!
            // The async dispatch causes the change to happen in a deferred RunLoop cycle,
            // which SwiftUI's change detection may miss entirely.
            //
            // Solution: If on main thread, update synchronously. If not, dispatch and update synchronously.
            // Also: Call objectWillChange.send() explicitly BEFORE the change for reliable observation.
            let updateLists = { [self] in
                // Explicitly notify SwiftUI BEFORE the change (required for reliable observation)
                self.objectWillChange.send()
                self.lists = newLists
                print("📱 DataManager: Updated lists array with \(newLists.count) lists (synchronous)")
            }

            if Thread.isMainThread {
                updateLists()
            } else {
                DispatchQueue.main.sync {
                    updateLists()
                }
            }
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
        // Prefetch items and their images to prevent N+1 query problems
        request.relationshipKeyPathsForPrefetching = ["items", "items.images"]

        do {
            let listEntities = try coreDataManager.viewContext.fetch(request)
            return listEntities.map { $0.toList() }
        } catch {
            print("❌ Failed to fetch lists: \(error)")
            return []
        }
    }

    // MARK: - Sample Data

    func createSampleData() {
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

    // MARK: - DataManaging Publisher Support

    /// Publisher for observing list changes (required for DataManaging protocol)
    var listsPublisher: AnyPublisher<[List], Never> {
        $lists.eraseToAnyPublisher()
    }
}

// MARK: - Protocol Conformance

/// DataManager conforms to DataManaging protocol
/// All required methods are already implemented in the class
extension DataManager: DataManaging { }
