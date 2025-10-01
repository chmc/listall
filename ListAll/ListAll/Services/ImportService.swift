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
    let conflicts: [ConflictDetail]
    
    var wasSuccessful: Bool {
        return errors.isEmpty
    }
    
    var totalChanges: Int {
        return listsCreated + listsUpdated + itemsCreated + itemsUpdated
    }
    
    var hasConflicts: Bool {
        return !conflicts.isEmpty
    }
}

// MARK: - Import Preview

/// Preview of what will be imported
struct ImportPreview {
    let listsToCreate: Int
    let listsToUpdate: Int
    let itemsToCreate: Int
    let itemsToUpdate: Int
    let conflicts: [ConflictDetail]
    let errors: [String]
    
    var totalChanges: Int {
        return listsToCreate + listsToUpdate + itemsToCreate + itemsToUpdate
    }
    
    var hasConflicts: Bool {
        return !conflicts.isEmpty
    }
    
    var isValid: Bool {
        return errors.isEmpty
    }
}

// MARK: - Conflict Detail

/// Details about a data conflict during import
struct ConflictDetail {
    enum ConflictType {
        case listModified
        case itemModified
        case listDeleted
        case itemDeleted
    }
    
    let type: ConflictType
    let entityName: String
    let entityId: UUID
    let currentValue: String?
    let incomingValue: String?
    let message: String
}

// MARK: - Import Progress

/// Progress information during import operation
struct ImportProgress {
    let totalLists: Int
    let processedLists: Int
    let totalItems: Int
    let processedItems: Int
    let currentOperation: String
    
    var overallProgress: Double {
        let total = totalLists + totalItems
        let processed = processedLists + processedItems
        return total > 0 ? Double(processed) / Double(total) : 0.0
    }
    
    var progressPercentage: Int {
        return Int(overallProgress * 100)
    }
}

/// Service responsible for importing app data from various formats
class ImportService: ObservableObject {
    private let dataRepository: DataRepository
    
    /// Callback for tracking import progress
    var progressHandler: ((ImportProgress) -> Void)?
    
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
    
    // MARK: - Preview Import
    
    /// Previews what will happen if the data is imported
    /// - Parameters:
    ///   - data: The JSON data to preview
    ///   - options: Import options for customization
    /// - Returns: ImportPreview with details of what will be imported
    /// - Throws: ImportError if preview fails
    func previewImport(_ data: Data, options: ImportOptions = .default) throws -> ImportPreview {
        // Decode JSON data
        let exportData: ExportData
        do {
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            exportData = try decoder.decode(ExportData.self, from: data)
        } catch {
            throw ImportError.decodingFailed(error.localizedDescription)
        }
        
        // Validate data
        var errors: [String] = []
        if options.validateData {
            do {
                try validateExportData(exportData)
            } catch let error as ImportError {
                errors.append(error.localizedDescription ?? "Unknown validation error")
            }
        }
        
        // Calculate what will be imported based on strategy
        switch options.mergeStrategy {
        case .replace:
            return previewReplaceData(with: exportData, errors: errors)
        case .merge:
            return previewMergeData(with: exportData, errors: errors)
        case .append:
            return previewAppendData(from: exportData, errors: errors)
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
    
    // MARK: - Preview Helper Methods
    
    /// Preview replace data strategy
    private func previewReplaceData(with exportData: ExportData, errors: [String]) -> ImportPreview {
        let existingLists = dataRepository.getAllLists()
        var conflicts: [ConflictDetail] = []
        
        // All existing lists will be deleted
        for list in existingLists {
            conflicts.append(ConflictDetail(
                type: .listDeleted,
                entityName: list.name,
                entityId: list.id,
                currentValue: list.name,
                incomingValue: nil,
                message: "List '\(list.name)' will be deleted"
            ))
            
            // Track deleted items
            let items = dataRepository.getItems(for: list)
            for item in items {
                conflicts.append(ConflictDetail(
                    type: .itemDeleted,
                    entityName: item.title,
                    entityId: item.id,
                    currentValue: item.title,
                    incomingValue: nil,
                    message: "Item '\(item.title)' in list '\(list.name)' will be deleted"
                ))
            }
        }
        
        // Count what will be created
        let listsToCreate = exportData.lists.count
        let itemsToCreate = exportData.lists.reduce(0) { $0 + $1.items.count }
        
        return ImportPreview(
            listsToCreate: listsToCreate,
            listsToUpdate: 0,
            itemsToCreate: itemsToCreate,
            itemsToUpdate: 0,
            conflicts: conflicts,
            errors: errors
        )
    }
    
    /// Preview merge data strategy
    private func previewMergeData(with exportData: ExportData, errors: [String]) -> ImportPreview {
        let existingLists = dataRepository.getAllLists()
        let existingListsById = Dictionary(uniqueKeysWithValues: existingLists.map { ($0.id, $0) })
        
        var listsToCreate = 0
        var listsToUpdate = 0
        var itemsToCreate = 0
        var itemsToUpdate = 0
        var conflicts: [ConflictDetail] = []
        
        for listData in exportData.lists {
            if let existingList = existingListsById[listData.id] {
                // List will be updated
                listsToUpdate += 1
                
                // Check for modifications
                if existingList.name != listData.name {
                    conflicts.append(ConflictDetail(
                        type: .listModified,
                        entityName: existingList.name,
                        entityId: existingList.id,
                        currentValue: existingList.name,
                        incomingValue: listData.name,
                        message: "List name will change from '\(existingList.name)' to '\(listData.name)'"
                    ))
                }
                
                // Check items
                let existingItems = dataRepository.getItems(for: existingList)
                let existingItemsById = Dictionary(uniqueKeysWithValues: existingItems.map { ($0.id, $0) })
                
                for itemData in listData.items {
                    if let existingItem = existingItemsById[itemData.id] {
                        // Item will be updated
                        itemsToUpdate += 1
                        
                        // Check for modifications
                        if existingItem.title != itemData.title ||
                           existingItem.itemDescription != (itemData.description.isEmpty ? nil : itemData.description) ||
                           existingItem.quantity != itemData.quantity {
                            conflicts.append(ConflictDetail(
                                type: .itemModified,
                                entityName: existingItem.title,
                                entityId: existingItem.id,
                                currentValue: "\(existingItem.title) (qty: \(existingItem.quantity))",
                                incomingValue: "\(itemData.title) (qty: \(itemData.quantity))",
                                message: "Item '\(existingItem.title)' will be updated in list '\(listData.name)'"
                            ))
                        }
                    } else {
                        // New item will be created
                        itemsToCreate += 1
                    }
                }
            } else {
                // New list will be created
                listsToCreate += 1
                itemsToCreate += listData.items.count
            }
        }
        
        return ImportPreview(
            listsToCreate: listsToCreate,
            listsToUpdate: listsToUpdate,
            itemsToCreate: itemsToCreate,
            itemsToUpdate: itemsToUpdate,
            conflicts: conflicts,
            errors: errors
        )
    }
    
    /// Preview append data strategy
    private func previewAppendData(from exportData: ExportData, errors: [String]) -> ImportPreview {
        // Append strategy creates all new items, no conflicts
        let listsToCreate = exportData.lists.count
        let itemsToCreate = exportData.lists.reduce(0) { $0 + $1.items.count }
        
        return ImportPreview(
            listsToCreate: listsToCreate,
            listsToUpdate: 0,
            itemsToCreate: itemsToCreate,
            itemsToUpdate: 0,
            conflicts: [],
            errors: errors
        )
    }
    
    /// Replaces all existing data with imported data
    private func replaceAllData(with exportData: ExportData) throws -> ImportResult {
        var listsCreated = 0
        var itemsCreated = 0
        var errors: [String] = []
        var conflicts: [ConflictDetail] = []
        
        let totalLists = exportData.lists.count
        let totalItems = exportData.lists.reduce(0) { $0 + $1.items.count }
        var processedLists = 0
        var processedItems = 0
        
        // Report initial progress
        reportProgress(totalLists: totalLists, processedLists: 0, totalItems: totalItems, processedItems: 0, operation: "Deleting existing data...")
        
        // Delete all existing lists and items
        let existingLists = dataRepository.getAllLists()
        for list in existingLists {
            conflicts.append(ConflictDetail(
                type: .listDeleted,
                entityName: list.name,
                entityId: list.id,
                currentValue: list.name,
                incomingValue: nil,
                message: "Deleted list '\(list.name)'"
            ))
            dataRepository.deleteList(list)
        }
        
        // Import new data
        for listData in exportData.lists {
            reportProgress(totalLists: totalLists, processedLists: processedLists, totalItems: totalItems, processedItems: processedItems, operation: "Importing list '\(listData.name)'...")
            
            do {
                let list = try importList(listData, useOriginalID: true)
                listsCreated += 1
                processedLists += 1
                
                // Import items for this list
                for itemData in listData.items {
                    _ = try importItem(itemData, into: list, useOriginalID: true)
                    itemsCreated += 1
                    processedItems += 1
                    
                    reportProgress(totalLists: totalLists, processedLists: processedLists, totalItems: totalItems, processedItems: processedItems, operation: "Importing item '\(itemData.title)'...")
                }
            } catch {
                errors.append("Failed to import list '\(listData.name)': \(error.localizedDescription)")
            }
        }
        
        reportProgress(totalLists: totalLists, processedLists: processedLists, totalItems: totalItems, processedItems: processedItems, operation: "Import complete")
        
        return ImportResult(
            listsCreated: listsCreated,
            listsUpdated: 0,
            itemsCreated: itemsCreated,
            itemsUpdated: 0,
            errors: errors,
            conflicts: conflicts
        )
    }
    
    /// Merges imported data with existing data
    private func mergeData(with exportData: ExportData) throws -> ImportResult {
        var listsCreated = 0
        var listsUpdated = 0
        var itemsCreated = 0
        var itemsUpdated = 0
        var errors: [String] = []
        var conflicts: [ConflictDetail] = []
        
        let totalLists = exportData.lists.count
        let totalItems = exportData.lists.reduce(0) { $0 + $1.items.count }
        var processedLists = 0
        var processedItems = 0
        
        // Get existing lists
        let existingLists = dataRepository.getAllLists()
        let existingListsById = Dictionary(uniqueKeysWithValues: existingLists.map { ($0.id, $0) })
        
        for listData in exportData.lists {
            reportProgress(totalLists: totalLists, processedLists: processedLists, totalItems: totalItems, processedItems: processedItems, operation: "Merging list '\(listData.name)'...")
            
            do {
                if let existingList = existingListsById[listData.id] {
                    // Track modifications to list
                    if existingList.name != listData.name {
                        conflicts.append(ConflictDetail(
                            type: .listModified,
                            entityName: existingList.name,
                            entityId: existingList.id,
                            currentValue: existingList.name,
                            incomingValue: listData.name,
                            message: "Updated list name from '\(existingList.name)' to '\(listData.name)'"
                        ))
                    }
                    
                    // Update existing list
                    try updateList(existingList, with: listData)
                    listsUpdated += 1
                    processedLists += 1
                    
                    // Get existing items for this list
                    let existingItems = dataRepository.getItems(for: existingList)
                    let existingItemsById = Dictionary(uniqueKeysWithValues: existingItems.map { ($0.id, $0) })
                    
                    // Merge items
                    for itemData in listData.items {
                        if let existingItem = existingItemsById[itemData.id] {
                            // Track modifications to item
                            if existingItem.title != itemData.title ||
                               existingItem.itemDescription != (itemData.description.isEmpty ? nil : itemData.description) ||
                               existingItem.quantity != itemData.quantity {
                                conflicts.append(ConflictDetail(
                                    type: .itemModified,
                                    entityName: existingItem.title,
                                    entityId: existingItem.id,
                                    currentValue: "\(existingItem.title) (qty: \(existingItem.quantity))",
                                    incomingValue: "\(itemData.title) (qty: \(itemData.quantity))",
                                    message: "Updated item '\(existingItem.title)' in list '\(listData.name)'"
                                ))
                            }
                            
                            // Update existing item
                            try updateItem(existingItem, with: itemData)
                            itemsUpdated += 1
                        } else {
                            // Create new item
                            _ = try importItem(itemData, into: existingList, useOriginalID: true)
                            itemsCreated += 1
                        }
                        processedItems += 1
                        reportProgress(totalLists: totalLists, processedLists: processedLists, totalItems: totalItems, processedItems: processedItems, operation: "Merging item '\(itemData.title)'...")
                    }
                } else {
                    // Create new list
                    let list = try importList(listData, useOriginalID: true)
                    listsCreated += 1
                    processedLists += 1
                    
                    // Import items for this list
                    for itemData in listData.items {
                        _ = try importItem(itemData, into: list, useOriginalID: true)
                        itemsCreated += 1
                        processedItems += 1
                        reportProgress(totalLists: totalLists, processedLists: processedLists, totalItems: totalItems, processedItems: processedItems, operation: "Importing item '\(itemData.title)'...")
                    }
                }
            } catch {
                errors.append("Failed to merge list '\(listData.name)': \(error.localizedDescription)")
            }
        }
        
        reportProgress(totalLists: totalLists, processedLists: processedLists, totalItems: totalItems, processedItems: processedItems, operation: "Merge complete")
        
        return ImportResult(
            listsCreated: listsCreated,
            listsUpdated: listsUpdated,
            itemsCreated: itemsCreated,
            itemsUpdated: itemsUpdated,
            errors: errors,
            conflicts: conflicts
        )
    }
    
    /// Appends imported data as new entries
    private func appendData(from exportData: ExportData) throws -> ImportResult {
        var listsCreated = 0
        var itemsCreated = 0
        var errors: [String] = []
        
        let totalLists = exportData.lists.count
        let totalItems = exportData.lists.reduce(0) { $0 + $1.items.count }
        var processedLists = 0
        var processedItems = 0
        
        for listData in exportData.lists {
            reportProgress(totalLists: totalLists, processedLists: processedLists, totalItems: totalItems, processedItems: processedItems, operation: "Appending list '\(listData.name)'...")
            
            do {
                // Create new list with new ID
                let list = try importList(listData, useOriginalID: false)
                listsCreated += 1
                processedLists += 1
                
                // Import items with new IDs
                for itemData in listData.items {
                    _ = try importItem(itemData, into: list, useOriginalID: false)
                    itemsCreated += 1
                    processedItems += 1
                    reportProgress(totalLists: totalLists, processedLists: processedLists, totalItems: totalItems, processedItems: processedItems, operation: "Appending item '\(itemData.title)'...")
                }
            } catch {
                errors.append("Failed to append list '\(listData.name)': \(error.localizedDescription)")
            }
        }
        
        reportProgress(totalLists: totalLists, processedLists: processedLists, totalItems: totalItems, processedItems: processedItems, operation: "Append complete")
        
        return ImportResult(
            listsCreated: listsCreated,
            listsUpdated: 0,
            itemsCreated: itemsCreated,
            itemsUpdated: 0,
            errors: [],
            conflicts: []
        )
    }
    
    /// Reports import progress to the progress handler
    private func reportProgress(totalLists: Int, processedLists: Int, totalItems: Int, processedItems: Int, operation: String) {
        let progress = ImportProgress(
            totalLists: totalLists,
            processedLists: processedLists,
            totalItems: totalItems,
            processedItems: processedItems,
            currentOperation: operation
        )
        progressHandler?(progress)
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

