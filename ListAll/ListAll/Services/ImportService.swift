import Foundation

// MARK: - Import Error

/// Errors that can occur during import operations
enum ImportError: Error, LocalizedError {
    case invalidData
    case invalidFormat
    case decodingFailed(String)
    case validationFailed(String)
    case repositoryError(String)
    
    var errorDescription: String? {
        switch self {
        case .invalidData:
            return "The provided data is invalid or corrupted"
        case .invalidFormat:
            return "The file format is not supported"
        case .decodingFailed(let message):
            return "Failed to decode data: \(message)"
        case .validationFailed(let message):
            return "Data validation failed: \(message)"
        case .repositoryError(let message):
            return "Failed to save data: \(message)"
        }
    }
}

// MARK: - Import Options

/// Configuration options for import operations
struct ImportOptions {
    /// Strategy for handling existing data
    enum MergeStrategy {
        case replace  // Replace all existing data
        case merge    // Merge with existing data (skip duplicates)
        case append   // Append as new items (ignore IDs)
    }
    
    /// The merge strategy to use
    var mergeStrategy: MergeStrategy
    
    /// Whether to validate imported data before saving
    var validateData: Bool
    
    /// Default import options
    static var `default`: ImportOptions {
        ImportOptions(
            mergeStrategy: .merge,
            validateData: true
        )
    }
    
    /// Replace all existing data
    static var replace: ImportOptions {
        ImportOptions(
            mergeStrategy: .replace,
            validateData: true
        )
    }
    
    /// Append as new data
    static var append: ImportOptions {
        ImportOptions(
            mergeStrategy: .append,
            validateData: true
        )
    }
}

// MARK: - Import Result

/// Result of an import operation
struct ImportResult {
    let listsCreated: Int
    let listsUpdated: Int
    let itemsCreated: Int
    let itemsUpdated: Int
    let errors: [String]
    
    var wasSuccessful: Bool {
        return errors.isEmpty
    }
    
    var totalChanges: Int {
        return listsCreated + listsUpdated + itemsCreated + itemsUpdated
    }
}

/// Service responsible for importing app data from various formats
class ImportService: ObservableObject {
    private let dataRepository: DataRepository
    
    init(dataRepository: DataRepository = DataRepository()) {
        self.dataRepository = dataRepository
    }
    
    // MARK: - JSON Import
    
    /// Imports lists and items from JSON data
    /// - Parameters:
    ///   - data: The JSON data to import
    ///   - options: Import options for customization
    /// - Returns: ImportResult with details of the import operation
    /// - Throws: ImportError if import fails
    func importFromJSON(_ data: Data, options: ImportOptions = .default) throws -> ImportResult {
        // Decode JSON data
        let exportData: ExportData
        do {
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            exportData = try decoder.decode(ExportData.self, from: data)
        } catch {
            throw ImportError.decodingFailed(error.localizedDescription)
        }
        
        // Validate data if requested
        if options.validateData {
            try validateExportData(exportData)
        }
        
        // Handle merge strategy
        switch options.mergeStrategy {
        case .replace:
            return try replaceAllData(with: exportData)
        case .merge:
            return try mergeData(with: exportData)
        case .append:
            return try appendData(from: exportData)
        }
    }
    
    // MARK: - Private Methods
    
    /// Validates the imported export data
    private func validateExportData(_ exportData: ExportData) throws {
        // Validate version compatibility
        guard exportData.version == "1.0" else {
            throw ImportError.validationFailed("Unsupported version: \(exportData.version)")
        }
        
        // Validate list data
        for listData in exportData.lists {
            // Check for empty list names
            guard !listData.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                throw ImportError.validationFailed("List name cannot be empty")
            }
            
            // Validate items
            for itemData in listData.items {
                // Check for empty item titles
                guard !itemData.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                    throw ImportError.validationFailed("Item title cannot be empty in list '\(listData.name)'")
                }
                
                // Validate quantity
                guard itemData.quantity >= 0 else {
                    throw ImportError.validationFailed("Item quantity cannot be negative in list '\(listData.name)'")
                }
            }
        }
    }
    
    /// Replaces all existing data with imported data
    private func replaceAllData(with exportData: ExportData) throws -> ImportResult {
        var listsCreated = 0
        var itemsCreated = 0
        var errors: [String] = []
        
        // Delete all existing lists and items
        let existingLists = dataRepository.getAllLists()
        for list in existingLists {
            dataRepository.deleteList(list)
        }
        
        // Import new data
        for listData in exportData.lists {
            do {
                let list = try importList(listData, useOriginalID: true)
                listsCreated += 1
                itemsCreated += listData.items.count
                
                // Import items for this list
                for itemData in listData.items {
                    _ = try importItem(itemData, into: list, useOriginalID: true)
                }
            } catch {
                errors.append("Failed to import list '\(listData.name)': \(error.localizedDescription)")
            }
        }
        
        return ImportResult(
            listsCreated: listsCreated,
            listsUpdated: 0,
            itemsCreated: itemsCreated,
            itemsUpdated: 0,
            errors: errors
        )
    }
    
    /// Merges imported data with existing data
    private func mergeData(with exportData: ExportData) throws -> ImportResult {
        var listsCreated = 0
        var listsUpdated = 0
        var itemsCreated = 0
        var itemsUpdated = 0
        var errors: [String] = []
        
        // Get existing lists
        let existingLists = dataRepository.getAllLists()
        let existingListsById = Dictionary(uniqueKeysWithValues: existingLists.map { ($0.id, $0) })
        
        for listData in exportData.lists {
            do {
                if let existingList = existingListsById[listData.id] {
                    // Update existing list
                    try updateList(existingList, with: listData)
                    listsUpdated += 1
                    
                    // Get existing items for this list
                    let existingItems = dataRepository.getItems(for: existingList)
                    let existingItemsById = Dictionary(uniqueKeysWithValues: existingItems.map { ($0.id, $0) })
                    
                    // Merge items
                    for itemData in listData.items {
                        if let existingItem = existingItemsById[itemData.id] {
                            // Update existing item
                            try updateItem(existingItem, with: itemData)
                            itemsUpdated += 1
                        } else {
                            // Create new item
                            _ = try importItem(itemData, into: existingList, useOriginalID: true)
                            itemsCreated += 1
                        }
                    }
                } else {
                    // Create new list
                    let list = try importList(listData, useOriginalID: true)
                    listsCreated += 1
                    
                    // Import items for this list
                    for itemData in listData.items {
                        _ = try importItem(itemData, into: list, useOriginalID: true)
                        itemsCreated += 1
                    }
                }
            } catch {
                errors.append("Failed to merge list '\(listData.name)': \(error.localizedDescription)")
            }
        }
        
        return ImportResult(
            listsCreated: listsCreated,
            listsUpdated: listsUpdated,
            itemsCreated: itemsCreated,
            itemsUpdated: itemsUpdated,
            errors: errors
        )
    }
    
    /// Appends imported data as new entries
    private func appendData(from exportData: ExportData) throws -> ImportResult {
        var listsCreated = 0
        var itemsCreated = 0
        var errors: [String] = []
        
        for listData in exportData.lists {
            do {
                // Create new list with new ID
                let list = try importList(listData, useOriginalID: false)
                listsCreated += 1
                
                // Import items with new IDs
                for itemData in listData.items {
                    _ = try importItem(itemData, into: list, useOriginalID: false)
                    itemsCreated += 1
                }
            } catch {
                errors.append("Failed to append list '\(listData.name)': \(error.localizedDescription)")
            }
        }
        
        return ImportResult(
            listsCreated: listsCreated,
            listsUpdated: 0,
            itemsCreated: itemsCreated,
            itemsUpdated: 0,
            errors: errors
        )
    }
    
    /// Imports a single list
    private func importList(_ listData: ListExportData, useOriginalID: Bool) throws -> List {
        // Create list with proper structure
        var list = List(name: listData.name)
        
        if useOriginalID {
            list.id = listData.id
        }
        list.orderNumber = listData.orderNumber
        list.isArchived = listData.isArchived
        list.createdAt = listData.createdAt
        list.modifiedAt = listData.modifiedAt
        
        // Add list using repository to ensure test isolation
        dataRepository.addListForImport(list)
        return list
    }
    
    /// Updates an existing list with imported data
    private func updateList(_ list: List, with listData: ListExportData) throws {
        var updatedList = list
        updatedList.name = listData.name
        updatedList.orderNumber = listData.orderNumber
        updatedList.isArchived = listData.isArchived
        updatedList.modifiedAt = listData.modifiedAt
        dataRepository.updateListForImport(updatedList)
    }
    
    /// Imports a single item
    private func importItem(_ itemData: ItemExportData, into list: List, useOriginalID: Bool) throws -> Item {
        var item = Item(title: itemData.title, listId: list.id)
        
        // Set all properties from imported data
        if useOriginalID {
            item.id = itemData.id
        }
        item.itemDescription = itemData.description.isEmpty ? nil : itemData.description
        item.quantity = itemData.quantity
        item.orderNumber = itemData.orderNumber
        item.isCrossedOut = itemData.isCrossedOut
        item.createdAt = itemData.createdAt
        item.modifiedAt = itemData.modifiedAt
        
        // Add item using repository to ensure test isolation
        dataRepository.addItemForImport(item, to: list.id)
        return item
    }
    
    /// Updates an existing item with imported data
    private func updateItem(_ item: Item, with itemData: ItemExportData) throws {
        var updatedItem = item
        updatedItem.title = itemData.title
        updatedItem.itemDescription = itemData.description.isEmpty ? nil : itemData.description
        updatedItem.quantity = itemData.quantity
        updatedItem.orderNumber = itemData.orderNumber
        updatedItem.isCrossedOut = itemData.isCrossedOut
        updatedItem.modifiedAt = itemData.modifiedAt
        dataRepository.updateItemForImport(updatedItem)
    }
}

