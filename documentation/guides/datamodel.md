# ListAll App - Data Model

## Core Entities

### List Entity
Represents a collection of items that can be any type of list (grocery, todo, checklist, etc.).

**Attributes:**
- `id: UUID` - Unique identifier
- `name: String` - Display name of the list
- `orderNumber: Int32` - Position in user's list of lists
- `createdAt: Date` - Creation timestamp
- `modifiedAt: Date` - Last modification timestamp
- `isArchived: Bool` - Soft delete flag (optional for future use)

**Relationships:**
- `items: [Item]` - One-to-many relationship with Item entities
- `owner: UserData` - Many-to-one relationship with user data

**Business Rules:**
- List name cannot be empty
- Order numbers must be unique within a user's lists
- Lists are automatically sorted by orderNumber
- When a list is deleted, all associated items are also deleted

### Item Entity
Represents an individual item within a list.

**Attributes:**
- `id: UUID` - Unique identifier
- `title: String` - Item name/title (required)
- `itemDescription: String` - Multi-line description (optional, supports up to 50,000 characters for extensive notes)
- `quantity: Int32` - Quantity information (optional, stored as integer for calculations and sorting)
- `orderNumber: Int32` - Position within the list
- `isCrossedOut: Bool` - Whether item is completed/crossed out
- `createdAt: Date` - Creation timestamp
- `modifiedAt: Date` - Last modification timestamp

**Relationships:**
- `list: List` - Many-to-one relationship with parent List
- `images: [ItemImage]` - One-to-many relationship with ItemImage entities

**Business Rules:**
- Title cannot be empty
- Order numbers must be unique within a list
- Items are automatically sorted by orderNumber
- Crossed out items are hidden by default but can be shown
- Description can contain URLs which are rendered as clickable links
- Description supports extensive notes, documentation, and detailed information

### ItemImage Entity
Represents images associated with an item.

**Attributes:**
- `id: UUID` - Unique identifier
- `imageData: Data` - Compressed image data
- `thumbnailData: Data` - Small thumbnail for list views
- `orderNumber: Int32` - Position among item's images
- `createdAt: Date` - Creation timestamp

**Relationships:**
- `item: Item` - Many-to-one relationship with parent Item

**Business Rules:**
- Images are automatically compressed before storage
- Thumbnails are generated for performance
- Maximum image size limit (e.g., 5MB per image)
- Images are not displayed in list views, only count is shown

### UserData Entity
Represents user-specific settings and preferences.

**Attributes:**
- `id: UUID` - Unique identifier
- `userID: String` - iCloud user identifier
- `showCrossedOutItems: Bool` - Whether to show crossed out items by default
- `exportPreferences: Data` - JSON data for export settings
- `lastSyncDate: Date` - Last iCloud synchronization timestamp
- `createdAt: Date` - Account creation timestamp

**Relationships:**
- `lists: [List]` - One-to-many relationship with user's lists

## Data Relationships

```
UserData (1) ──→ (Many) List
    │
    └─── User preferences and settings

List (1) ──→ (Many) Item
    │
    └─── List contains multiple items

Item (1) ──→ (Many) ItemImage
    │
    └─── Item can have multiple images
```

## Data Validation Rules

### List Validation
- Name must be 1-100 characters
- Order number must be non-negative
- Created/modified dates must be valid

### Item Validation
- Title must be 1-200 characters
- Description can be up to 50,000 characters (supports extensive notes, URLs, and detailed information)
- Quantity must be a valid integer (Int32) or nil
- Order number must be non-negative

### Image Validation
- Image data must be valid image format (JPEG, PNG, HEIC)
- Maximum file size: 5MB per image
- Maximum images per item: 10

## Data Persistence Strategy

### Core Data Stack
- **Persistent Store:** SQLite with CloudKit integration
- **Model Versioning:** Automatic migration for schema changes
- **Background Context:** Separate context for background operations

### CloudKit Integration
- **Private Database:** All user data stored in private CloudKit database
- **Custom Zones:** Use custom zones for better conflict resolution
- **Automatic Sync:** Background synchronization with iCloud
- **Conflict Resolution:** Last-write-wins based on modifiedAt timestamp

### Data Migration
- **Automatic Migration:** Core Data handles simple schema changes
- **Custom Migration:** Complex changes handled with custom migration code
- **Version Tracking:** Track data model versions for compatibility

## Export/Import Data Format

### Export Structure
```json
{
  "version": "1.0",
  "exportDate": "2024-01-15T10:30:00Z",
  "userData": {
    "showCrossedOutItems": true,
    "exportPreferences": {...}
  },
  "lists": [
    {
      "id": "uuid",
      "name": "Grocery List",
      "orderNumber": 0,
      "createdAt": "2024-01-15T10:00:00Z",
      "modifiedAt": "2024-01-15T10:30:00Z",
      "items": [
        {
          "id": "uuid",
          "title": "Milk",
          "description": "2% organic milk",
          "quantity": 1,
          "orderNumber": 0,
          "isCrossedOut": false,
          "createdAt": "2024-01-15T10:00:00Z",
          "modifiedAt": "2024-01-15T10:00:00Z",
          "images": [
            {
              "id": "uuid",
              "imageData": "base64-encoded-data",
              "orderNumber": 0
            }
          ]
        }
      ]
    }
  ]
}
```

### Import Validation
- Validate JSON structure and required fields
- Check for duplicate IDs and handle conflicts
- Validate image data integrity
- Preserve order numbers or reassign if conflicts

## Performance Considerations

### Indexing
- **Primary Keys:** UUID fields indexed for fast lookups
- **Order Numbers:** Indexed for efficient sorting
- **Timestamps:** Indexed for sync and filtering operations

### Lazy Loading
- **Items:** Load items on demand for large lists
- **Images:** Load images only when item detail view is opened
- **Thumbnails:** Use thumbnails in list views for performance

### Memory Management
- **Image Compression:** Compress images before storage
- **Data Cleanup:** Remove orphaned data during sync
- **Cache Management:** Implement appropriate caching strategies
