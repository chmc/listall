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
        static let addButtonPosition = "addButtonPosition"
        static let requiresBiometricAuth = "requiresBiometricAuth"
        static let authTimeoutDuration = "authTimeoutDuration"
        static let lastBackgroundTime = "lastBackgroundTime"
        static let hapticsEnabled = "hapticsEnabled"
    }
    
    // MARK: - Add Button Position
    enum AddButtonPosition: String, CaseIterable, Identifiable {
        case right = "Right"
        case left = "Left"
        
        var id: String { rawValue }
        
        var displayName: String {
            switch self {
            case .right:
                return String(localized: "Right")
            case .left:
                return String(localized: "Left")
            }
        }
    }
    
    // MARK: - Authentication Timeout Duration
    enum AuthTimeoutDuration: Int, CaseIterable, Identifiable {
        case immediate = 0
        case oneMinute = 60
        case fiveMinutes = 300
        case fifteenMinutes = 900
        case thirtyMinutes = 1800
        case oneHour = 3600
        
        var id: Int { rawValue }
        
        var displayName: String {
            switch self {
            case .immediate:
                return String(localized: "Immediately")
            case .oneMinute:
                return String(localized: "1 minute")
            case .fiveMinutes:
                return String(localized: "5 minutes")
            case .fifteenMinutes:
                return String(localized: "15 minutes")
            case .thirtyMinutes:
                return String(localized: "30 minutes")
            case .oneHour:
                return String(localized: "1 hour")
            }
        }
        
        var description: String {
            switch self {
            case .immediate:
                return String(localized: "Require authentication every time")
            case .oneMinute:
                return String(localized: "After 1 minute in background")
            case .fiveMinutes:
                return String(localized: "After 5 minutes in background")
            case .fifteenMinutes:
                return String(localized: "After 15 minutes in background")
            case .thirtyMinutes:
                return String(localized: "After 30 minutes in background")
            case .oneHour:
                return String(localized: "After 1 hour in background")
            }
        }
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
    static let itemDataChanged = Notification.Name("ItemDataChanged")
    // Note: .coreDataRemoteChange is defined in CoreDataManager.swift to support watchOS target
}
