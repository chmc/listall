import Foundation
import CoreData

extension UserDataEntity {
    func toUserData() -> UserData {
        var userData = UserData(userID: self.userID ?? "unknown")
        userData.id = self.id ?? UUID()
        userData.showCrossedOutItems = self.showCrossedOutItems
        userData.lastSyncDate = self.lastSyncDate
        userData.createdAt = self.createdAt ?? Date()
        
        // Try to extract organization preferences from exportPreferences JSON
        if let prefsData = self.exportPreferences,
           let prefsDict = try? JSONSerialization.jsonObject(with: prefsData) as? [String: Any] {
            
            // Extract organization preferences if they exist
            if let sortOptionRaw = prefsDict["defaultSortOption"] as? String,
               let sortOption = ItemSortOption(rawValue: sortOptionRaw) {
                userData.defaultSortOption = sortOption
            }
            
            if let sortDirectionRaw = prefsDict["defaultSortDirection"] as? String,
               let sortDirection = SortDirection(rawValue: sortDirectionRaw) {
                userData.defaultSortDirection = sortDirection
            }
            
            if let filterOptionRaw = prefsDict["defaultFilterOption"] as? String,
               let filterOption = ItemFilterOption(rawValue: filterOptionRaw) {
                userData.defaultFilterOption = filterOption
            }
            
            // Extract export preferences (excluding organization prefs)
            var exportPrefs = prefsDict
            exportPrefs.removeValue(forKey: "defaultSortOption")
            exportPrefs.removeValue(forKey: "defaultSortDirection")
            exportPrefs.removeValue(forKey: "defaultFilterOption")
            
            if !exportPrefs.isEmpty,
               let exportData = try? JSONSerialization.data(withJSONObject: exportPrefs) {
                userData.exportPreferences = exportData
            }
        }
        
        return userData
    }
    
    static func fromUserData(_ userData: UserData, context: NSManagedObjectContext) -> UserDataEntity {
        let userEntity = UserDataEntity(context: context)
        userEntity.id = userData.id
        userEntity.userID = userData.userID
        userEntity.showCrossedOutItems = userData.showCrossedOutItems
        userEntity.lastSyncDate = userData.lastSyncDate
        userEntity.createdAt = userData.createdAt
        
        // Combine export preferences with organization preferences in JSON
        var combinedPrefs: [String: Any] = [:]
        
        // Add existing export preferences
        if let exportData = userData.exportPreferences,
           let exportDict = try? JSONSerialization.jsonObject(with: exportData) as? [String: Any] {
            combinedPrefs = exportDict
        }
        
        // Add organization preferences
        combinedPrefs["defaultSortOption"] = userData.defaultSortOption.rawValue
        combinedPrefs["defaultSortDirection"] = userData.defaultSortDirection.rawValue
        combinedPrefs["defaultFilterOption"] = userData.defaultFilterOption.rawValue
        
        // Store combined preferences
        if let combinedData = try? JSONSerialization.data(withJSONObject: combinedPrefs) {
            userEntity.exportPreferences = combinedData
        }
        
        return userEntity
    }
}
