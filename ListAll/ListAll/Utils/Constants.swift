import Foundation

struct Constants {
    
    // MARK: - App Information
    struct App {
        static let name = "ListAll"
        static let version = "1.0.0"
        static let build = "1"
        static let bundleIdentifier = "io.github.chmc.ListAll"
    }
    
    // MARK: - CloudKit
    struct CloudKit {
        static let containerIdentifier = "iCloud.io.github.chmc.ListAll"
    }
    
    // MARK: - Core Data
    struct CoreData {
        static let modelName = "ListAllModel"
    }
    
    // MARK: - User Defaults Keys
    struct UserDefaultsKeys {
        static let showCrossedOutItems = "showCrossedOutItems"
        static let enableCloudSync = "enableCloudSync"
        static let lastSyncDate = "lastSyncDate"
    }
    
    // MARK: - UI Constants
    struct UI {
        // Layout
        static let cornerRadius: CGFloat = 8
        static let padding: CGFloat = 16
        static let spacing: CGFloat = 8
        static let smallSpacing: CGFloat = 4
        static let largeSpacing: CGFloat = 20
        
        // Typography
        static let titleFontSize: CGFloat = 28
        static let headlineFontSize: CGFloat = 20
        static let bodyFontSize: CGFloat = 16
        static let captionFontSize: CGFloat = 12
        
        // Colors
        static let primaryColor = "AccentColor"
        static let secondaryColor = "Secondary"
        
        // Animation
        static let animationDuration: Double = 0.3
        
        // Icons
        static let listIcon = "list.bullet"
        static let settingsIcon = "gear"
        static let addIcon = "plus"
        static let syncIcon = "arrow.clockwise"
        static let checkmarkIcon = "checkmark.circle.fill"
        static let circleIcon = "circle"
        static let chevronIcon = "chevron.right"
    }
    
    // MARK: - Export
    struct Export {
        static let jsonFileName = "ListAll_Export.json"
        static let csvFileName = "ListAll_Export.csv"
    }
}

// MARK: - Notification Names
extension Notification.Name {
    static let dataImported = Notification.Name("dataImported")
    static let switchToListsTab = Notification.Name("switchToListsTab")
}
