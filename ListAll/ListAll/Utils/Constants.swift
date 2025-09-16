//
//  Constants.swift
//  ListAll
//
//  Created by Sutela Aleksi on 15.9.2025.
//

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
        static let cornerRadius: CGFloat = 8
        static let padding: CGFloat = 16
        static let spacing: CGFloat = 8
    }
    
    // MARK: - Export
    struct Export {
        static let jsonFileName = "ListAll_Export.json"
        static let csvFileName = "ListAll_Export.csv"
    }
}
