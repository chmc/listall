//
//  WatchUITestDataService.swift
//  ListAllWatch Watch App
//
//  Service for providing deterministic test data for watchOS UI tests
//

import Foundation

/// Service for providing deterministic test data for watchOS UI tests
/// This ensures consistent screenshots and predictable test behavior
class WatchUITestDataService {
    
    /// Check if the app is running in UI test mode
    static var isUITesting: Bool {
        return ProcessInfo.processInfo.arguments.contains("UITEST_MODE")
    }
    
    /// Check if we should use a specific seed for deterministic data
    static var testSeed: Int? {
        if let seedString = ProcessInfo.processInfo.environment["UITEST_SEED"],
           let seed = Int(seedString) {
            return seed
        }
        return nil
    }
    
    /// Generate deterministic test lists based on the current locale
    static func generateTestData() -> [List] {
        print("🧪 Watch UI Test Data Generation:")
        print("🧪 FASTLANE_LANGUAGE = \(ProcessInfo.processInfo.environment["FASTLANE_LANGUAGE"] ?? "not set")")
        
        // Detect language from multiple sources (in priority order)
        let languageCode: String
        
        // 1. Check FASTLANE_LANGUAGE environment variable
        if let fastlaneLanguage = ProcessInfo.processInfo.environment["FASTLANE_LANGUAGE"] {
            languageCode = String(fastlaneLanguage.prefix(2)).lowercased()
            print("🧪 Language from FASTLANE_LANGUAGE env: \(languageCode)")
        }
        // 2. Check -AppleLanguages launch argument set by SnapshotHelper
        else if let appleLanguages = UserDefaults.standard.array(forKey: "AppleLanguages") as? [String],
                let firstLang = appleLanguages.first {
            languageCode = String(firstLang.prefix(2)).lowercased()
            print("🧪 Language from AppleLanguages: \(languageCode)")
        }
        // 3. Fallback to localization manager
        else {
            languageCode = WatchLocalizationManager.shared.currentLocale.languageCode ?? "en"
            print("🧪 Language from LocalizationManager: \(languageCode)")
        }
        
        print("🧪 Final language code = \(languageCode)")
        
        if languageCode == "fi" {
            print("🧪 Generating FINNISH test data for watchOS")
            return generateFinnishTestData()
        } else {
            print("🧪 Generating ENGLISH test data for watchOS")
            return generateEnglishTestData()
        }
    }
    
    // MARK: - English Test Data
    
    private static func generateEnglishTestData() -> [List] {
        var lists: [List] = []
        
        // List 1: Grocery Shopping (optimized for watch display)
        var groceryList = List(name: "Grocery Shopping")
        groceryList.orderNumber = 0
        groceryList.createdAt = Date().addingTimeInterval(-86400 * 2) // 2 days ago
        groceryList.modifiedAt = Date().addingTimeInterval(-1800) // 30 minutes ago
        
        // Fewer items for better watch display (5-6 items)
        var milk = Item(title: "Milk", listId: groceryList.id)
        milk.quantity = 2
        milk.orderNumber = 0
        milk.createdAt = groceryList.createdAt
        groceryList.items.append(milk)
        
        var bread = Item(title: "Bread", listId: groceryList.id)
        bread.orderNumber = 1
        bread.createdAt = groceryList.createdAt
        groceryList.items.append(bread)
        
        var eggs = Item(title: "Eggs", listId: groceryList.id)
        eggs.quantity = 12
        eggs.orderNumber = 2
        eggs.isCrossedOut = true
        eggs.createdAt = groceryList.createdAt
        eggs.modifiedAt = Date().addingTimeInterval(-3600)
        groceryList.items.append(eggs)
        
        var apples = Item(title: "Apples", listId: groceryList.id)
        apples.quantity = 6
        apples.orderNumber = 3
        apples.createdAt = groceryList.createdAt
        groceryList.items.append(apples)
        
        var coffee = Item(title: "Coffee", listId: groceryList.id)
        coffee.orderNumber = 4
        coffee.isCrossedOut = true
        coffee.createdAt = groceryList.createdAt
        coffee.modifiedAt = Date().addingTimeInterval(-1800)
        groceryList.items.append(coffee)
        
        var chicken = Item(title: "Chicken", listId: groceryList.id)
        chicken.orderNumber = 5
        chicken.createdAt = groceryList.createdAt
        groceryList.items.append(chicken)
        
        lists.append(groceryList)
        
        // List 2: Weekend Tasks
        var tasksList = List(name: "Weekend Tasks")
        tasksList.orderNumber = 1
        tasksList.createdAt = Date().addingTimeInterval(-86400) // 1 day ago
        tasksList.modifiedAt = Date().addingTimeInterval(-600) // 10 minutes ago
        
        var paintWall = Item(title: "Paint wall", listId: tasksList.id)
        paintWall.orderNumber = 0
        paintWall.createdAt = tasksList.createdAt
        tasksList.items.append(paintWall)
        
        var fixDoor = Item(title: "Fix door", listId: tasksList.id)
        fixDoor.orderNumber = 1
        fixDoor.isCrossedOut = true
        fixDoor.createdAt = tasksList.createdAt
        fixDoor.modifiedAt = Date().addingTimeInterval(-600)
        tasksList.items.append(fixDoor)
        
        var organize = Item(title: "Organize garage", listId: tasksList.id)
        organize.orderNumber = 2
        organize.createdAt = tasksList.createdAt
        tasksList.items.append(organize)
        
        lists.append(tasksList)
        
        // List 3: Books to Read
        var booksList = List(name: "Books to Read")
        booksList.orderNumber = 2
        booksList.createdAt = Date().addingTimeInterval(-86400 * 7) // 1 week ago
        booksList.modifiedAt = Date().addingTimeInterval(-86400) // 1 day ago
        
        var book1 = Item(title: "The Great Gatsby", listId: booksList.id)
        book1.orderNumber = 0
        book1.isCrossedOut = true
        book1.createdAt = booksList.createdAt
        book1.modifiedAt = Date().addingTimeInterval(-86400)
        booksList.items.append(book1)
        
        var book2 = Item(title: "Sapiens", listId: booksList.id)
        book2.orderNumber = 1
        book2.createdAt = booksList.createdAt
        booksList.items.append(book2)
        
        var book3 = Item(title: "Project Hail Mary", listId: booksList.id)
        book3.orderNumber = 2
        book3.createdAt = booksList.createdAt
        booksList.items.append(book3)
        
        lists.append(booksList)
        
        return lists
    }
    
    // MARK: - Finnish Test Data
    
    private static func generateFinnishTestData() -> [List] {
        var lists: [List] = []
        
        // List 1: Ruokaostokset
        var ostoslista = List(name: "Ruokaostokset")
        ostoslista.orderNumber = 0
        ostoslista.createdAt = Date().addingTimeInterval(-86400 * 2) // 2 päivää sitten
        ostoslista.modifiedAt = Date().addingTimeInterval(-1800) // 30 minuuttia sitten
        
        var maito = Item(title: "Maito", listId: ostoslista.id)
        maito.quantity = 2
        maito.orderNumber = 0
        maito.createdAt = ostoslista.createdAt
        ostoslista.items.append(maito)
        
        var leipa = Item(title: "Leipä", listId: ostoslista.id)
        leipa.orderNumber = 1
        leipa.createdAt = ostoslista.createdAt
        ostoslista.items.append(leipa)
        
        var munat = Item(title: "Kananmunat", listId: ostoslista.id)
        munat.quantity = 12
        munat.orderNumber = 2
        munat.isCrossedOut = true
        munat.createdAt = ostoslista.createdAt
        munat.modifiedAt = Date().addingTimeInterval(-3600)
        ostoslista.items.append(munat)
        
        var omenat = Item(title: "Omenat", listId: ostoslista.id)
        omenat.quantity = 6
        omenat.orderNumber = 3
        omenat.createdAt = ostoslista.createdAt
        ostoslista.items.append(omenat)
        
        var kahvi = Item(title: "Kahvi", listId: ostoslista.id)
        kahvi.orderNumber = 4
        kahvi.isCrossedOut = true
        kahvi.createdAt = ostoslista.createdAt
        kahvi.modifiedAt = Date().addingTimeInterval(-1800)
        ostoslista.items.append(kahvi)
        
        var broileri = Item(title: "Broileri", listId: ostoslista.id)
        broileri.orderNumber = 5
        broileri.createdAt = ostoslista.createdAt
        ostoslista.items.append(broileri)
        
        lists.append(ostoslista)
        
        // List 2: Viikonloppuhommat
        var tehtavalista = List(name: "Viikonloppuhommat")
        tehtavalista.orderNumber = 1
        tehtavalista.createdAt = Date().addingTimeInterval(-86400) // 1 päivä sitten
        tehtavalista.modifiedAt = Date().addingTimeInterval(-600) // 10 minuuttia sitten
        
        var maalaus = Item(title: "Maalaa seinä", listId: tehtavalista.id)
        maalaus.orderNumber = 0
        maalaus.createdAt = tehtavalista.createdAt
        tehtavalista.items.append(maalaus)
        
        var korjaaOvi = Item(title: "Korjaa ovi", listId: tehtavalista.id)
        korjaaOvi.orderNumber = 1
        korjaaOvi.isCrossedOut = true
        korjaaOvi.createdAt = tehtavalista.createdAt
        korjaaOvi.modifiedAt = Date().addingTimeInterval(-600)
        tehtavalista.items.append(korjaaOvi)
        
        var jarjesta = Item(title: "Järjestä autotalli", listId: tehtavalista.id)
        jarjesta.orderNumber = 2
        jarjesta.createdAt = tehtavalista.createdAt
        tehtavalista.items.append(jarjesta)
        
        lists.append(tehtavalista)
        
        // List 3: Luettavat kirjat
        var kirjalista = List(name: "Luettavat kirjat")
        kirjalista.orderNumber = 2
        kirjalista.createdAt = Date().addingTimeInterval(-86400 * 7) // 1 viikko sitten
        kirjalista.modifiedAt = Date().addingTimeInterval(-86400) // 1 päivä sitten
        
        var kirja1 = Item(title: "Tuntematon sotilas", listId: kirjalista.id)
        kirja1.orderNumber = 0
        kirja1.isCrossedOut = true
        kirja1.createdAt = kirjalista.createdAt
        kirja1.modifiedAt = Date().addingTimeInterval(-86400)
        kirjalista.items.append(kirja1)
        
        var kirja2 = Item(title: "Sapiens", listId: kirjalista.id)
        kirja2.orderNumber = 1
        kirja2.createdAt = kirjalista.createdAt
        kirjalista.items.append(kirja2)
        
        var kirja3 = Item(title: "Seitsemän veljestä", listId: kirjalista.id)
        kirja3.orderNumber = 2
        kirja3.createdAt = kirjalista.createdAt
        kirjalista.items.append(kirja3)
        
        lists.append(kirjalista)
        
        return lists
    }
}
