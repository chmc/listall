# ListAll App - Architecture

## Tech Stack

### iOS (Primary Platform)
- **Language:** Swift 5.9+
- **UI Framework:** SwiftUI
- **Data Persistence:** Core Data + CloudKit
- **State Management:** @StateObject, @ObservableObject
- **Networking:** URLSession
- **Image Processing:** PhotosUI, UIImagePickerController
- **Minimum iOS Version:** iOS 16.0

### Future Platforms
- **watchOS:** SwiftUI + WatchKit (Planned - See docs/watchos.md for detailed architecture)
  - Core features: View lists, complete items, filter items
  - Shared data layer with iOS via CloudKit
  - Target: watchOS 9.0+
- **macOS:** SwiftUI + AppKit (Future consideration)
- **Android:** Kotlin + Jetpack Compose (Long-term consideration)

## Architecture Patterns

### MVVM (Model-View-ViewModel)
- **Models:** Core Data entities (List, Item, UserData)
- **Views:** SwiftUI views for UI components
- **ViewModels:** ObservableObject classes managing business logic
- **Services:** Data persistence, cloud sync, export/import

### Repository Pattern
- **DataRepository:** Abstracts data access layer
- **CloudKitRepository:** Handles iCloud synchronization
- **ExportRepository:** Manages data export/import functionality

## Folder Structure

```
ListAll/
├── Models/
│   ├── ListItem.swift
│   ├── List.swift
│   ├── UserData.swift
│   └── CoreData/
│       ├── ListAllModel.xcdatamodeld
│       └── CoreDataManager.swift
├── ViewModels/
│   ├── ListViewModel.swift
│   ├── ItemViewModel.swift
│   ├── MainViewModel.swift
│   └── ExportViewModel.swift
├── Views/
│   ├── MainView.swift
│   ├── ListView.swift
│   ├── ItemDetailView.swift
│   ├── CreateListView.swift
│   ├── SettingsView.swift
│   └── Components/
│       ├── ItemRowView.swift
│       ├── ListRowView.swift
│       └── ImagePickerView.swift
├── Services/
│   ├── DataRepository.swift
│   ├── CloudKitService.swift
│   ├── ExportService.swift
│   ├── SharingService.swift
│   └── SuggestionService.swift
├── Utils/
│   ├── Extensions/
│   ├── Constants.swift
│   └── Helpers/
└── Resources/
    ├── Assets.xcassets
    └── Localizable.strings
```

## Data Architecture

### Core Data Model
- **List Entity:**
  - id: UUID
  - name: String
  - orderNumber: Int32
  - createdAt: Date
  - modifiedAt: Date
  - items: Relationship to Item (one-to-many)

- **Item Entity:**
  - id: UUID
  - title: String
  - itemDescription: String
  - quantity: Int32
  - orderNumber: Int32
  - isCrossedOut: Bool
  - createdAt: Date
  - modifiedAt: Date
  - list: Relationship to List (many-to-one)
  - images: Relationship to ItemImage (one-to-many)

- **ItemImage Entity:**
  - id: UUID
  - imageData: Data
  - orderNumber: Int32
  - item: Relationship to Item (many-to-one)

### CloudKit Integration
- **Private Database:** User's personal data
- **Custom Zones:** For better conflict resolution
- **Automatic Sync:** Background synchronization
- **Conflict Resolution:** Last-write-wins with timestamp comparison

## Testing Strategy

### Unit Tests
- **Model Tests:** Core Data entity validation
- **ViewModel Tests:** Business logic and state management
- **Service Tests:** Data persistence and cloud sync
- **Utility Tests:** Helper functions and extensions

### Integration Tests
- **Core Data + CloudKit:** Data synchronization
- **Export/Import:** Data integrity across operations
- **Sharing:** List sharing functionality

### UI Tests
- **User Flows:** Complete user journeys
- **Accessibility:** VoiceOver and accessibility features
- **Performance:** Large list handling and image processing

## Performance Considerations

### Data Loading
- **Lazy Loading:** Load items on demand for large lists
- **Pagination:** Implement pagination for very large datasets
- **Caching:** Cache frequently accessed data

### Image Handling
- **Compression:** Compress images before storage
- **Thumbnails:** Generate thumbnails for list views
- **Memory Management:** Proper cleanup of image data

### Cloud Sync
- **Batch Operations:** Group changes for efficient sync
- **Conflict Resolution:** Handle concurrent edits gracefully
- **Offline Support:** Queue changes when offline

## Security & Privacy

### Data Protection
- **iCloud Encryption:** All data encrypted in transit and at rest
- **Local Encryption:** Sensitive data encrypted locally
- **No Third-Party Services:** All data stays within Apple ecosystem

### Privacy Features
- **No Analytics:** No user tracking or analytics
- **Local Processing:** All smart suggestions processed locally
- **User Control:** Full control over data export and deletion

## Scalability Considerations

### Multi-Platform Architecture
- **Shared Models:** Common data models across platforms
- **Platform-Specific Views:** Tailored UI for each platform
- **Service Abstraction:** Platform-agnostic business logic

### Future Enhancements
- **Collaborative Lists:** Real-time collaboration features
- **Advanced Export:** More export formats and options
- **Smart Features:** AI-powered list suggestions and organization
- **Integration:** Third-party app integrations (calendar, reminders)
