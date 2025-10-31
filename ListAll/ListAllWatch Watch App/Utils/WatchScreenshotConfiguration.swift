import Foundation

/// Configuration manager for watch app screenshot mode
/// When enabled, shows pre-defined English Shopping List template for App Store screenshots
class WatchScreenshotConfiguration {
    static let shared = WatchScreenshotConfiguration()
    
    private init() {}
    
    // MARK: - Screenshot Mode Configuration
    
    /// Reads screenshot mode setting from Config.plist
    /// Set to true to show English Shopping List template for screenshots
    /// Set to false for normal functionality with real user data
    var isScreenshotModeEnabled: Bool {
        // Try to read from Config.plist first
        if let configPath = Bundle.main.path(forResource: "Config", ofType: "plist"),
           let configDict = NSDictionary(contentsOfFile: configPath),
           let screenshotMode = configDict["ScreenshotMode"] as? Bool {
            return screenshotMode
        }
        
        // Default to false if Config.plist not found or key missing
        return false
    }
    
    // MARK: - Sample Data for Screenshots
    
    /// Returns a pre-defined English Shopping List with sample items
    func getScreenshotList() -> List {
        var shoppingList = List(name: "Shopping List")
        shoppingList.id = UUID()
        shoppingList.orderNumber = 0
        shoppingList.createdAt = Date()
        shoppingList.modifiedAt = Date()
        shoppingList.isArchived = false
        
        // Add sample items (all non-completed for screenshots)
        let sampleItems: [(title: String, quantity: Int, isCrossedOut: Bool)] = [
            ("Milk", 2, false),
            ("Bread", 1, false),
            ("Eggs", 12, false),
            ("Apples", 6, false),
            ("Chicken breast", 1, false),
            ("Rice", 1, false),
            ("Tomatoes", 4, false),
            ("Cheese", 1, false),
            ("Butter", 1, false),
            ("Coffee", 1, false),
            ("Orange juice", 1, false),
            ("Pasta", 1, false)
        ]
        
        for (index, itemData) in sampleItems.enumerated() {
            var item = Item(title: itemData.title)
            item.id = UUID()
            item.listId = shoppingList.id
            item.orderNumber = index
            item.createdAt = Date()
            item.modifiedAt = Date()
            item.isCrossedOut = itemData.isCrossedOut
            item.quantity = itemData.quantity
            
            shoppingList.items.append(item)
        }
        
        return shoppingList
    }
    
    /// Returns screenshot mode lists (currently just one Shopping List)
    func getScreenshotLists() -> [List] {
        return [getScreenshotList()]
    }
}
