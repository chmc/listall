# ListAll App - Backend Services

## Service Architecture

### Core Services
- **DataRepository:** Central data access layer
- **CloudKitService:** iCloud synchronization
- **ExportService:** Data export/import functionality
- **SharingService:** List sharing capabilities
- **SuggestionService:** Smart item recommendations
- **ImageService:** Image processing and management

## Data Persistence

### Core Data Stack
**Configuration:**
- **Store Type:** NSSQLiteStoreType with CloudKit integration
- **Model:** ListAllModel.xcdatamodeld
- **Contexts:** Main context for UI, background context for sync
- **Migration:** Automatic lightweight migration

**CloudKit Integration:**
- **Database:** Private database for user data
- **Zones:** Custom zones for better conflict resolution
- **Sync:** Automatic background synchronization
- **Conflict Resolution:** Last-write-wins with timestamp comparison

### DataRepository Service
**Responsibilities:**
- CRUD operations for all entities
- Data validation and business rules
- Query optimization and caching
- Background context management

**Key Methods:**
```swift
// List operations
func createList(name: String) -> List
func updateList(_ list: List)
func deleteList(_ list: List)
func fetchAllLists() -> [List]
func reorderLists(_ lists: [List])

// Item operations
func createItem(in list: List, title: String) -> Item
func updateItem(_ item: Item)
func deleteItem(_ item: Item)
func crossOutItem(_ item: Item)
func reorderItems(in list: List, items: [Item])

// Query operations
func fetchItems(in list: List, showCrossedOut: Bool) -> [Item]
func searchItems(query: String) -> [Item]
func fetchRecentItems(limit: Int) -> [Item]
```

## Cloud Synchronization

### CloudKitService
**Configuration:**
- **Container:** iCloud container for ListAll app
- **Database:** Private database
- **Zones:** Custom zones for each user
- **Sync Strategy:** Automatic background sync with conflict resolution

**Sync Process:**
1. **Local Changes:** Track changes in Core Data
2. **Upload:** Push changes to CloudKit
3. **Download:** Pull remote changes from CloudKit
4. **Merge:** Resolve conflicts using timestamp comparison
5. **Update UI:** Notify views of data changes

**Conflict Resolution:**
- **Strategy:** Last-write-wins based on modifiedAt timestamp
- **Handling:** Automatic resolution with user notification
- **Recovery:** Backup mechanism for data loss prevention

**Key Methods:**
```swift
func syncWithCloud() async throws
func uploadChanges() async throws
func downloadChanges() async throws
func resolveConflicts() async throws
func isCloudAvailable() -> Bool
```

## Export/Import Services

### ExportService
**Supported Formats:**
- **JSON:** Complete data export with metadata
- **CSV:** Simple list export for spreadsheet compatibility
- **Plain Text:** Human-readable format for sharing
- **PDF:** Formatted document export (future)

**Export Options:**
- **Data Scope:** All data, specific lists, or selected items
- **Detail Level:** Full details, summary only, or custom selection
- **Format:** JSON, CSV, or plain text
- **Destination:** File save, clipboard, or share sheet

**Key Methods:**
```swift
func exportAllData(format: ExportFormat) async throws -> Data
func exportList(_ list: List, format: ExportFormat) async throws -> Data
func exportToFile(_ data: Data, filename: String) async throws -> URL
func exportToClipboard(_ data: Data) async
func getExportPreview(_ data: Data) -> String
```

### ImportService
**Import Process:**
1. **Validation:** Verify file format and data integrity
2. **Parsing:** Extract data from import format
3. **Conflict Resolution:** Handle duplicate IDs and data conflicts
4. **Integration:** Merge imported data with existing data
5. **Sync:** Trigger CloudKit synchronization

**Key Methods:**
```swift
func importFromFile(_ url: URL) async throws -> ImportResult
func importFromClipboard() async throws -> ImportResult
func validateImportData(_ data: Data) throws -> Bool
func previewImportData(_ data: Data) -> ImportPreview
```

## Sharing Services

### SharingService
**Sharing Methods:**
- **System Share Sheet:** Native iOS sharing
- **Custom Share Format:** Optimized for ListAll app
- **URL Scheme:** Deep linking for app-to-app sharing
- **Export Integration:** Share exported data

**Share Formats:**
- **ListAll Format:** Native format with full functionality
- **JSON Export:** Standard data format
- **Plain Text:** Human-readable format
- **URL:** Deep link to shared list (future)

**Key Methods:**
```swift
func shareList(_ list: List, method: SharingMethod) async throws
func shareAllData() async throws
func generateShareURL(for list: List) async throws -> URL
func handleIncomingShare(_ data: Data) async throws
```

## Smart Suggestions

### SuggestionService
**Suggestion Algorithm:**
1. **Text Matching:** Fuzzy string matching against item titles
2. **Frequency Analysis:** Weight suggestions by usage frequency
3. **Recency Bias:** Favor recently used items
4. **Context Awareness:** Consider current list context
5. **Machine Learning:** Future enhancement with Core ML

**Suggestion Types:**
- **Exact Matches:** Perfect title matches
- **Fuzzy Matches:** Similar titles with typos
- **Partial Matches:** Substring matches
- **Category Matches:** Items from similar lists

**Key Methods:**
```swift
func getSuggestions(for query: String, in list: List?) -> [ItemSuggestion]
func updateItemFrequency(_ item: Item)
func clearSuggestionCache()
func getRecentItems(limit: Int) -> [Item]
```

## Image Management

### ImageService
**Image Processing:**
- **Compression:** Automatic image compression before storage
- **Thumbnail Generation:** Create thumbnails for list views
- **Format Conversion:** Convert to optimal formats
- **Size Optimization:** Resize images to appropriate dimensions

**Storage Strategy:**
- **Core Data:** Store compressed images as binary data
- **CloudKit:** Sync images through CloudKit
- **Local Cache:** Temporary cache for performance
- **Memory Management:** Proper cleanup and memory management

**Key Methods:**
```swift
func processImage(_ image: UIImage) async throws -> ProcessedImage
func generateThumbnail(from imageData: Data) async throws -> Data
func compressImage(_ image: UIImage, quality: Float) -> Data
func optimizeImageSize(_ image: UIImage, maxSize: CGSize) -> UIImage
```

## Background Processing

### Background Tasks
**Sync Tasks:**
- **Automatic Sync:** Background app refresh for CloudKit sync
- **Conflict Resolution:** Handle conflicts when app becomes active
- **Data Cleanup:** Remove orphaned data and optimize storage

**Export Tasks:**
- **Large Export:** Background processing for large data exports
- **File Generation:** Generate export files in background
- **Cleanup:** Remove temporary files after export

**Key Methods:**
```swift
func scheduleBackgroundSync()
func handleBackgroundTask(_ task: BGAppRefreshTask)
func cleanupTempFiles()
func optimizeDatabase()
```

## Error Handling

### Error Types
- **Network Errors:** CloudKit connectivity issues
- **Data Errors:** Core Data and validation errors
- **Export Errors:** File generation and sharing errors
- **Sync Errors:** Conflict resolution and merge errors

### Error Recovery
- **Retry Logic:** Automatic retry for transient errors
- **User Notification:** Inform users of critical errors
- **Data Backup:** Backup data before risky operations
- **Graceful Degradation:** Continue operation with reduced functionality

**Key Methods:**
```swift
func handleError(_ error: Error) async
func retryOperation<T>(_ operation: () async throws -> T) async throws -> T
func notifyUserOfError(_ error: Error)
func createDataBackup() async throws -> URL
```

## Performance Optimization

### Caching Strategy
- **Query Results:** Cache frequently accessed data
- **Images:** Cache processed images and thumbnails
- **Suggestions:** Cache suggestion results
- **Export Data:** Cache export results for quick access

### Memory Management
- **Image Cleanup:** Proper cleanup of image data
- **Context Management:** Efficient Core Data context usage
- **Background Processing:** Offload heavy operations to background

### Database Optimization
- **Indexing:** Proper database indexing for queries
- **Batch Operations:** Group operations for efficiency
- **Lazy Loading:** Load data on demand
- **Pagination:** Implement pagination for large datasets

## Security and Privacy

### Data Protection
- **iCloud Encryption:** All data encrypted in CloudKit
- **Local Encryption:** Sensitive data encrypted locally
- **No Third-Party Services:** All data stays within Apple ecosystem
- **User Control:** Full control over data export and deletion

### Privacy Compliance
- **No Analytics:** No user tracking or analytics
- **Local Processing:** All smart suggestions processed locally
- **Data Minimization:** Only store necessary data
- **User Consent:** Clear consent for data sharing
