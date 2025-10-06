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
    
    // MARK: - Auto-detect Format Import
    
    /// Imports data by auto-detecting the format (JSON or plain text)
    /// - Parameters:
    ///   - data: The data to import
    ///   - options: Import options for customization
    /// - Returns: ImportResult with details of the import operation
    /// - Throws: ImportError if import fails
    func importData(_ data: Data, options: ImportOptions = .default) throws -> ImportResult {
        // Try JSON first
        do {
            return try importFromJSON(data, options: options)
        } catch {
            // If JSON fails, try plain text
            guard let text = String(data: data, encoding: .utf8) else {
                throw ImportError.invalidFormat
            }
            return try importFromPlainText(text, options: options)
        }
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
    ///   - data: The data to preview (JSON or plain text)
    ///   - options: Import options for customization
    /// - Returns: ImportPreview with details of what will be imported
    /// - Throws: ImportError if preview fails
    func previewImport(_ data: Data, options: ImportOptions = .default) throws -> ImportPreview {
        // Try to decode as JSON first, then fall back to plain text
        let exportData: ExportData
        do {
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            exportData = try decoder.decode(ExportData.self, from: data)
        } catch {
            // If JSON fails, try plain text
            guard let text = String(data: data, encoding: .utf8) else {
                throw ImportError.invalidFormat
            }
            exportData = try parsePlainText(text)
        }
        
        // Validate data
        var errors: [String] = []
        if options.validateData {
            do {
                try validateExportData(exportData)
            } catch let error as ImportError {
                errors.append(error.localizedDescription)
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
        // CRITICAL: Force reload from Core Data to get fresh data (not cached)
        dataRepository.reloadData()
        
        let existingLists = dataRepository.getAllLists()
        let existingListsById = Dictionary(uniqueKeysWithValues: existingLists.map { ($0.id, $0) })
        // Use uniquingKeysWith to handle potential duplicate list names gracefully
        let existingListsByName = Dictionary(existingLists.map { ($0.name, $0) }, uniquingKeysWith: { first, _ in first })
        
        var listsToCreate = 0
        var listsToUpdate = 0
        var itemsToCreate = 0
        var itemsToUpdate = 0
        var conflicts: [ConflictDetail] = []
        
        for listData in exportData.lists {
            // First try to find by ID
            var existingList = existingListsById[listData.id]
            
            // If not found by ID, try by exact name match
            if existingList == nil {
                existingList = existingListsByName[listData.name]
            }
            
            // If still not found, try fuzzy name match (trimmed and case-insensitive)
            if existingList == nil {
                let normalizedName = listData.name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
                existingList = existingLists.first { list in
                    list.name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() == normalizedName
                }
            }
            
            if let existingList = existingList {
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
                    // First try to find by ID
                    var existingItem = existingItemsById[itemData.id]
                    
                    // If not found by ID, try to find by title AND description (for better matching)
                    if existingItem == nil {
                        let incomingDesc = itemData.description.isEmpty ? nil : itemData.description
                        existingItem = existingItems.first { item in
                            item.title == itemData.title && 
                            item.itemDescription == incomingDesc
                        }
                    }
                    
                    // If still not found and description is empty, try title-only match (but only if unique)
                    if existingItem == nil && itemData.description.isEmpty {
                        let matchingByTitle = existingItems.filter { $0.title == itemData.title }
                        // Only use title match if there's exactly one item with that title
                        if matchingByTitle.count == 1 {
                            existingItem = matchingByTitle.first
                        }
                    }
                    
                    if let existingItem = existingItem {
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
        
        // CRITICAL: Force reload from Core Data to get fresh data (not cached)
        dataRepository.reloadData()
        
        // Get existing lists
        let existingLists = dataRepository.getAllLists()
        let existingListsById = Dictionary(uniqueKeysWithValues: existingLists.map { ($0.id, $0) })
        // Use uniquingKeysWith to handle potential duplicate list names gracefully
        let existingListsByName = Dictionary(existingLists.map { ($0.name, $0) }, uniquingKeysWith: { first, _ in first })
        
        for listData in exportData.lists {
            reportProgress(totalLists: totalLists, processedLists: processedLists, totalItems: totalItems, processedItems: processedItems, operation: "Merging list '\(listData.name)'...")
            
            do {
                // First try to find by ID
                var existingList = existingListsById[listData.id]
                
                // If not found by ID, try by exact name match
                if existingList == nil {
                    existingList = existingListsByName[listData.name]
                }
                
                // If still not found, try fuzzy name match (trimmed and case-insensitive)
                if existingList == nil {
                    let normalizedName = listData.name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
                    existingList = existingLists.first { list in
                        list.name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() == normalizedName
                    }
                }
                
                if let existingList = existingList {
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
                        // First try to find by ID
                        var existingItem = existingItemsById[itemData.id]
                        
                        // If not found by ID, try to find by title AND description (for better matching)
                        if existingItem == nil {
                            let incomingDesc = itemData.description.isEmpty ? nil : itemData.description
                            existingItem = existingItems.first { item in
                                item.title == itemData.title && 
                                item.itemDescription == incomingDesc
                            }
                        }
                        
                        // If still not found and description is empty, try title-only match (but only if unique)
                        if existingItem == nil && itemData.description.isEmpty {
                            let matchingByTitle = existingItems.filter { $0.title == itemData.title }
                            // Only use title match if there's exactly one item with that title
                            if matchingByTitle.count == 1 {
                                existingItem = matchingByTitle.first
                            }
                        }
                        
                        if let existingItem = existingItem {
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
        
        // Import images if present
        item.images = importImages(from: itemData.images, itemId: item.id, useOriginalID: useOriginalID)
        
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
        
        // Update images - merge with existing images (update by ID, add new ones)
        updatedItem.images = mergeImages(existing: item.images, imported: itemData.images, itemId: item.id)
        
        dataRepository.updateItemForImport(updatedItem)
    }
    
    // MARK: - Image Import Helper Methods
    
    /// Imports images from ItemImageExportData
    private func importImages(from imageDataArray: [ItemImageExportData], itemId: UUID, useOriginalID: Bool) -> [ItemImage] {
        var importedImages: [ItemImage] = []
        
        for imageExportData in imageDataArray {
            // Decode base64 image data
            guard let imageData = Data(base64Encoded: imageExportData.imageData),
                  !imageData.isEmpty else {
                continue
            }
            
            // Create ItemImage
            var itemImage = ItemImage(imageData: imageData, itemId: itemId)
            
            // Set properties from imported data
            if useOriginalID {
                itemImage.id = imageExportData.id
            }
            itemImage.orderNumber = imageExportData.orderNumber
            itemImage.createdAt = imageExportData.createdAt
            
            importedImages.append(itemImage)
        }
        
        return importedImages
    }
    
    /// Merges existing images with imported images
    /// - Updates existing images by ID if found
    /// - Adds new images from import data
    /// - Preserves existing images not present in import data
    private func mergeImages(existing: [ItemImage], imported: [ItemImageExportData], itemId: UUID) -> [ItemImage] {
        var mergedImages: [ItemImage] = []
        var processedIds = Set<UUID>()
        
        // Create a dictionary of imported images by ID for quick lookup
        let importedDict = Dictionary(uniqueKeysWithValues: imported.map { ($0.id, $0) })
        
        // Update existing images if they appear in imported data
        for existingImage in existing {
            if let importedData = importedDict[existingImage.id] {
                // Update existing image with imported data
                guard let imageData = Data(base64Encoded: importedData.imageData),
                      !imageData.isEmpty else {
                    continue
                }
                
                var updatedImage = existingImage
                updatedImage.imageData = imageData
                updatedImage.orderNumber = importedData.orderNumber
                // Keep original createdAt from existing image
                
                mergedImages.append(updatedImage)
                processedIds.insert(existingImage.id)
            } else {
                // Keep existing image that's not in import data
                mergedImages.append(existingImage)
                processedIds.insert(existingImage.id)
            }
        }
        
        // Add new images from import data that don't exist yet
        for importedData in imported {
            if !processedIds.contains(importedData.id) {
                guard let imageData = Data(base64Encoded: importedData.imageData),
                      !imageData.isEmpty else {
                    continue
                }
                
                var itemImage = ItemImage(imageData: imageData, itemId: itemId)
                itemImage.id = importedData.id
                itemImage.orderNumber = importedData.orderNumber
                itemImage.createdAt = importedData.createdAt
                
                mergedImages.append(itemImage)
                processedIds.insert(importedData.id)
            }
        }
        
        // Sort by order number to maintain proper ordering
        return mergedImages.sorted { $0.orderNumber < $1.orderNumber }
    }
    
    // MARK: - Plain Text Import
    
    /// Imports data from plain text format
    /// - Parameters:
    ///   - text: The plain text to import
    ///   - options: Import options for customization
    /// - Returns: ImportResult with details of the import operation
    /// - Throws: ImportError if import fails
    func importFromPlainText(_ text: String, options: ImportOptions = .default) throws -> ImportResult {
        // Parse plain text into structured data
        let exportData = try parsePlainText(text)
        
        // Validate data if requested
        if options.validateData {
            try validateExportData(exportData)
        }
        
        // Handle merge strategy - respect user's choice just like JSON imports
        switch options.mergeStrategy {
        case .replace:
            return try replaceAllData(with: exportData)
        case .merge:
            return try mergeData(with: exportData)
        case .append:
            return try appendData(from: exportData)
        }
    }
    
    /// Parses plain text into ExportData structure
    private func parsePlainText(_ text: String) throws -> ExportData {
        var lists: [ListExportData] = []
        let lines = text.components(separatedBy: .newlines)
        
        // First, check if this looks like a structured format with numbered items
        var hasNumberedItems = false
        for line in lines {
            let trimmedLine = line.trimmingCharacters(in: .whitespaces)
            if trimmedLine.firstMatch(of: /^(\d+)\.\s*(\[[ ✓x]\])\s*(.+)$/) != nil {
                hasNumberedItems = true
                break
            }
        }
        
        // If no numbered items found, skip to simple parser
        if !hasNumberedItems {
            return ExportData(lists: try parseSimplePlainText(text))
        }
        
        var currentList: (name: String, items: [ItemExportData])? = nil
        var currentItem: (title: String, description: String?, quantity: Int, isCrossedOut: Bool)? = nil
        var orderNumber: Int32 = 0
        
        for line in lines {
            let trimmedLine = line.trimmingCharacters(in: .whitespaces)
            
            // Skip empty lines and header lines
            if trimmedLine.isEmpty || 
               trimmedLine.hasPrefix("===") || 
               trimmedLine.hasPrefix("ListAll Export") ||
               trimmedLine.hasPrefix("Exported:") ||
               trimmedLine == "(No items)" {
                continue
            }
            
            // Check if this is a list separator line (dashes)
            if trimmedLine.allSatisfy({ $0 == "-" }) {
                continue
            }
            
            // Check if this is an item line (starts with number)
            if let match = trimmedLine.firstMatch(of: /^(\d+)\.\s*(\[[ ✓x]\])\s*(.+)$/) {
                // Save previous item if exists
                if let item = currentItem {
                    currentList?.items.append(ItemExportData(
                        id: UUID(),
                        title: item.title,
                        description: item.description ?? "",
                        quantity: item.quantity,
                        orderNumber: Int(orderNumber),
                        isCrossedOut: item.isCrossedOut,
                        createdAt: Date(),
                        modifiedAt: Date()
                    ))
                    orderNumber += 1
                }
                
                // Parse new item
                let checkbox = String(match.2)
                let isCrossedOut = checkbox.contains("✓") || checkbox.contains("x")
                var title = String(match.3)
                var quantity = 1
                
                // Check for quantity notation (×N)
                if let qtyMatch = title.firstMatch(of: /\s*\(×(\d+)\)\s*$/) {
                    quantity = Int(qtyMatch.1) ?? 1
                    title = title.replacingOccurrences(of: qtyMatch.0, with: "")
                }
                
                currentItem = (title: title.trimmingCharacters(in: .whitespaces), 
                             description: nil, 
                             quantity: quantity, 
                             isCrossedOut: isCrossedOut)
            }
            // Check if this is a description line (starts with spaces)
            else if line.hasPrefix("   ") && currentItem != nil {
                let description = trimmedLine
                if !description.hasPrefix("Created:") {
                    currentItem?.description = description
                }
            }
            // Otherwise, it's likely a list name
            else if !trimmedLine.isEmpty {
                // Save previous list if exists
                if let list = currentList {
                    // Save last item of previous list
                    if let item = currentItem {
                        currentList?.items.append(ItemExportData(
                            id: UUID(),
                            title: item.title,
                            description: item.description ?? "",
                            quantity: item.quantity,
                            orderNumber: Int(orderNumber),
                            isCrossedOut: item.isCrossedOut,
                            createdAt: Date(),
                            modifiedAt: Date()
                        ))
                        orderNumber = 0
                        currentItem = nil
                    }
                    
                    lists.append(ListExportData(
                        id: UUID(),
                        name: list.name,
                        orderNumber: lists.count,
                        isArchived: false,
                        items: list.items,
                        createdAt: Date(),
                        modifiedAt: Date()
                    ))
                }
                
                // Start new list
                currentList = (name: trimmedLine, items: [])
                orderNumber = 0
            }
        }
        
        // Save last item and list
        if let item = currentItem {
            currentList?.items.append(ItemExportData(
                id: UUID(),
                title: item.title,
                description: item.description ?? "",
                quantity: item.quantity,
                orderNumber: Int(orderNumber),
                isCrossedOut: item.isCrossedOut,
                createdAt: Date(),
                modifiedAt: Date()
            ))
        }
        
        if let list = currentList {
            lists.append(ListExportData(
                id: UUID(),
                name: list.name,
                orderNumber: lists.count,
                isArchived: false,
                items: list.items,
                createdAt: Date(),
                modifiedAt: Date()
            ))
        }
        
        return ExportData(lists: lists)
    }
    
    /// Parses simple plain text (one item per line) into ExportData
    private func parseSimplePlainText(_ text: String) throws -> [ListExportData] {
        let lines = text.components(separatedBy: .newlines)
        
        guard !lines.isEmpty else {
            throw ImportError.validationFailed("No valid content found in text")
        }
        
        // Try to extract list name from first line
        var listName = "Imported List"
        var startIndex = 0
        
        // Check if first line could be a list name (not a bullet point)
        if !lines.isEmpty {
            let firstLine = lines[0].trimmingCharacters(in: .whitespaces)
            if !firstLine.isEmpty && 
               !firstLine.hasPrefix("•") && 
               !firstLine.hasPrefix("-") && 
               !firstLine.hasPrefix("*") &&
               !firstLine.hasPrefix("✓") &&
               !firstLine.hasPrefix("[") {
                listName = firstLine
                startIndex = 1
            }
        }
        
        var items: [ItemExportData] = []
        var currentItem: (title: String, description: [String], quantity: Int, isCrossedOut: Bool)? = nil
        
        for i in startIndex..<lines.count {
            let line = lines[i]
            let trimmedLine = line.trimmingCharacters(in: .whitespaces)
            
            // Skip empty lines and type indicators
            if trimmedLine.isEmpty || trimmedLine.uppercased() == "OTHER" {
                continue
            }
            
            // Check if this is a bullet point item
            var isNewItem = false
            var itemTitle = trimmedLine
            var isCompleted = false
            
            // Check for bullet points: •, -, *, or standalone ✓
            if trimmedLine.hasPrefix("• ") {
                itemTitle = String(trimmedLine.dropFirst(2)).trimmingCharacters(in: .whitespaces)
                isNewItem = true
            } else if trimmedLine.hasPrefix("•") {
                itemTitle = String(trimmedLine.dropFirst(1)).trimmingCharacters(in: .whitespaces)
                isNewItem = true
            } else if trimmedLine.hasPrefix("- ") {
                itemTitle = String(trimmedLine.dropFirst(2)).trimmingCharacters(in: .whitespaces)
                isNewItem = true
            } else if trimmedLine.hasPrefix("* ") {
                itemTitle = String(trimmedLine.dropFirst(2)).trimmingCharacters(in: .whitespaces)
                isNewItem = true
            } else if trimmedLine.hasPrefix("✓ ") {
                itemTitle = String(trimmedLine.dropFirst(2)).trimmingCharacters(in: .whitespaces)
                isNewItem = true
                isCompleted = true
            } else if trimmedLine.hasPrefix("✓") {
                itemTitle = String(trimmedLine.dropFirst(1)).trimmingCharacters(in: .whitespaces)
                isNewItem = true
                isCompleted = true
            } else if trimmedLine.hasPrefix("[ ]") || trimmedLine.hasPrefix("[]") {
                itemTitle = String(trimmedLine.dropFirst(3)).trimmingCharacters(in: .whitespaces)
                isNewItem = true
            } else if trimmedLine.hasPrefix("[x]") || trimmedLine.hasPrefix("[X]") || trimmedLine.hasPrefix("[✓]") {
                itemTitle = String(trimmedLine.dropFirst(3)).trimmingCharacters(in: .whitespaces)
                isNewItem = true
                isCompleted = true
            }
            
            if isNewItem {
                // Save previous item if exists
                if let item = currentItem {
                    let description = item.description.joined(separator: "\n")
                    items.append(ItemExportData(
                        id: UUID(),
                        title: item.title,
                        description: description,
                        quantity: item.quantity,
                        orderNumber: items.count,
                        isCrossedOut: item.isCrossedOut,
                        createdAt: Date(),
                        modifiedAt: Date()
                    ))
                }
                
                // Extract quantity from title (number in parentheses)
                var quantity = 1
                if let qtyMatch = itemTitle.firstMatch(of: /\((\d+)\)/) {
                    quantity = Int(qtyMatch.1) ?? 1
                    // Remove quantity notation from title
                    itemTitle = itemTitle.replacingOccurrences(of: " \(qtyMatch.0)", with: "")
                        .replacingOccurrences(of: "\(qtyMatch.0)", with: "")
                        .trimmingCharacters(in: .whitespaces)
                }
                
                // Start new item
                currentItem = (title: itemTitle, description: [], quantity: quantity, isCrossedOut: isCompleted)
            } else if currentItem != nil {
                // This is a description line for the current item
                currentItem?.description.append(trimmedLine)
            }
            // If no current item and not a new item, skip the line
        }
        
        // Save last item
        if let item = currentItem {
            let description = item.description.joined(separator: "\n")
            items.append(ItemExportData(
                id: UUID(),
                title: item.title,
                description: description,
                quantity: item.quantity,
                orderNumber: items.count,
                isCrossedOut: item.isCrossedOut,
                createdAt: Date(),
                modifiedAt: Date()
            ))
        }
        
        // If no items found, throw error
        guard !items.isEmpty else {
            throw ImportError.validationFailed("No valid items found in text")
        }
        
        let list = ListExportData(
            id: UUID(),
            name: listName,
            orderNumber: 0,
            isArchived: false,
            items: items,
            createdAt: Date(),
            modifiedAt: Date()
        )
        
        return [list]
    }
}

