import Foundation

// MARK: - UserData Model
struct UserData: Identifiable, Codable, Equatable {
    var id: UUID
    var userID: String
    var showCrossedOutItems: Bool
    var exportPreferences: Data?
    var lastSyncDate: Date?
    var createdAt: Date
    
    // Item Organization Preferences
    var defaultSortOption: ItemSortOption
    var defaultSortDirection: SortDirection
    var defaultFilterOption: ItemFilterOption
    
    init(userID: String) {
        self.id = UUID()
        self.userID = userID
        self.showCrossedOutItems = false  // Changed to match .active filter default
        self.exportPreferences = nil
        self.lastSyncDate = nil
        self.createdAt = Date()
        
        // Set default organization preferences
        self.defaultSortOption = .orderNumber
        self.defaultSortDirection = .ascending
        self.defaultFilterOption = .active
    }
}

// MARK: - Convenience Methods
extension UserData {
    
    /// Returns the export preferences as a dictionary
    var exportPreferencesDict: [String: Any] {
        guard let data = exportPreferences else { return [:] }
        return (try? JSONSerialization.jsonObject(with: data) as? [String: Any]) ?? [:]
    }
    
    /// Sets the export preferences from a dictionary
    mutating func setExportPreferences(_ dict: [String: Any]) {
        if let data = try? JSONSerialization.data(withJSONObject: dict) {
            self.exportPreferences = data
        }
    }
    
    /// Updates the last sync date
    mutating func updateLastSyncDate() {
        lastSyncDate = Date()
    }
    
    /// Validates the user data
    func validate() -> Bool {
        guard !userID.isEmpty else {
            return false
        }
        return true
    }
}
