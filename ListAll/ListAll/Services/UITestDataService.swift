import Foundation

/// Service for providing deterministic test data for UI tests
/// This ensures consistent screenshots and predictable test behavior
class UITestDataService {
    
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
        // Debug: Check environment and language detection
        print("🧪 UI Test Data Generation:")
        print("🧪 FASTLANE_LANGUAGE = \(ProcessInfo.processInfo.environment["FASTLANE_LANGUAGE"] ?? "not set")")
        print("🧪 FASTLANE_SNAPSHOT = \(ProcessInfo.processInfo.environment["FASTLANE_SNAPSHOT"] ?? "not set")")

        // LocalizationManager now defaults to English and users can manually change to Finnish
        // No need to override based on AppleLanguages - that was causing Finnish screenshots

        let currentLanguage = LocalizationManager.shared.currentLanguage.rawValue
        print("🧪 LocalizationManager.currentLanguage = \(currentLanguage)")

        if currentLanguage == "fi" {
            print("🧪 Generating FINNISH test data")
            return generateFinnishTestData()
        } else {
            print("🧪 Generating ENGLISH test data")
            return generateEnglishTestData()
        }
    }
    
    // MARK: - English Test Data
    
    private static func generateEnglishTestData() -> [List] {
        var lists: [List] = []
        
        // List 1: Grocery Shopping (with mixed active and completed items)
        var groceryList = List(name: "Grocery Shopping")
        groceryList.orderNumber = 0
        groceryList.createdAt = Date().addingTimeInterval(-86400 * 7) // 7 days ago
        groceryList.modifiedAt = Date().addingTimeInterval(-3600) // 1 hour ago
        
        var milk = Item(title: "Milk", listId: groceryList.id)
        milk.quantity = 2
        milk.itemDescription = "2% or whole milk"
        milk.orderNumber = 0
        milk.createdAt = groceryList.createdAt
        milk.modifiedAt = groceryList.createdAt
        groceryList.items.append(milk)
        
        var bread = Item(title: "Bread", listId: groceryList.id)
        bread.itemDescription = "Whole wheat or multigrain"
        bread.orderNumber = 1
        bread.createdAt = groceryList.createdAt
        bread.modifiedAt = groceryList.createdAt
        groceryList.items.append(bread)
        
        var eggs = Item(title: "Eggs", listId: groceryList.id)
        eggs.quantity = 12
        eggs.itemDescription = "Large, free-range"
        eggs.orderNumber = 2
        eggs.isCrossedOut = true
        eggs.createdAt = groceryList.createdAt
        eggs.modifiedAt = Date().addingTimeInterval(-7200) // 2 hours ago
        groceryList.items.append(eggs)
        
        var apples = Item(title: "Apples", listId: groceryList.id)
        apples.quantity = 6
        apples.itemDescription = "Honeycrisp or Gala"
        apples.orderNumber = 3
        apples.createdAt = groceryList.createdAt
        apples.modifiedAt = groceryList.createdAt
        groceryList.items.append(apples)
        
        var coffee = Item(title: "Coffee", listId: groceryList.id)
        coffee.itemDescription = "Medium roast beans"
        coffee.orderNumber = 4
        coffee.isCrossedOut = true
        coffee.createdAt = groceryList.createdAt
        coffee.modifiedAt = Date().addingTimeInterval(-3600) // 1 hour ago
        groceryList.items.append(coffee)
        
        var chicken = Item(title: "Chicken Breast", listId: groceryList.id)
        chicken.quantity = 2
        chicken.itemDescription = "Organic, boneless"
        chicken.orderNumber = 5
        chicken.createdAt = groceryList.createdAt
        chicken.modifiedAt = groceryList.createdAt
        groceryList.items.append(chicken)
        
        lists.append(groceryList)
        
        // List 2: Weekend Projects
        var projectsList = List(name: "Weekend Projects")
        projectsList.orderNumber = 1
        projectsList.createdAt = Date().addingTimeInterval(-86400 * 3) // 3 days ago
        projectsList.modifiedAt = Date().addingTimeInterval(-1800) // 30 minutes ago
        
        var paintWall = Item(title: "Paint living room wall", listId: projectsList.id)
        paintWall.itemDescription = "Use the blue paint from garage"
        paintWall.orderNumber = 0
        paintWall.createdAt = projectsList.createdAt
        paintWall.modifiedAt = projectsList.createdAt
        projectsList.items.append(paintWall)
        
        var fixDoor = Item(title: "Fix squeaky door", listId: projectsList.id)
        fixDoor.itemDescription = "WD-40 should help"
        fixDoor.orderNumber = 1
        fixDoor.isCrossedOut = true
        fixDoor.createdAt = projectsList.createdAt
        fixDoor.modifiedAt = Date().addingTimeInterval(-1800) // 30 minutes ago
        projectsList.items.append(fixDoor)
        
        var organizeGarage = Item(title: "Organize garage", listId: projectsList.id)
        organizeGarage.orderNumber = 2
        organizeGarage.createdAt = projectsList.createdAt
        organizeGarage.modifiedAt = projectsList.createdAt
        projectsList.items.append(organizeGarage)
        
        lists.append(projectsList)
        
        // List 3: Books to Read
        var booksList = List(name: "Books to Read")
        booksList.orderNumber = 2
        booksList.createdAt = Date().addingTimeInterval(-86400 * 14) // 2 weeks ago
        booksList.modifiedAt = Date().addingTimeInterval(-86400) // 1 day ago
        
        var book1 = Item(title: "The Great Gatsby", listId: booksList.id)
        book1.itemDescription = "Classic American literature"
        book1.orderNumber = 0
        book1.isCrossedOut = true
        book1.createdAt = booksList.createdAt
        book1.modifiedAt = Date().addingTimeInterval(-86400) // 1 day ago
        booksList.items.append(book1)
        
        var book2 = Item(title: "Sapiens", listId: booksList.id)
        book2.itemDescription = "By Yuval Noah Harari"
        book2.orderNumber = 1
        book2.createdAt = booksList.createdAt
        book2.modifiedAt = booksList.createdAt
        booksList.items.append(book2)
        
        var book3 = Item(title: "Project Hail Mary", listId: booksList.id)
        book3.itemDescription = "Science fiction thriller"
        book3.orderNumber = 2
        book3.createdAt = booksList.createdAt
        book3.modifiedAt = booksList.createdAt
        booksList.items.append(book3)
        
        lists.append(booksList)
        
        // List 4: Travel Packing
        var travelList = List(name: "Travel Packing")
        travelList.orderNumber = 3
        travelList.createdAt = Date().addingTimeInterval(-86400 * 2) // 2 days ago
        travelList.modifiedAt = Date().addingTimeInterval(-600) // 10 minutes ago
        
        var passport = Item(title: "Passport & Documents", listId: travelList.id)
        passport.orderNumber = 0
        passport.isCrossedOut = true
        passport.createdAt = travelList.createdAt
        passport.modifiedAt = Date().addingTimeInterval(-600) // 10 minutes ago
        travelList.items.append(passport)
        
        var charger = Item(title: "Phone Charger", listId: travelList.id)
        charger.itemDescription = "USB-C cable and adapter"
        charger.orderNumber = 1
        charger.createdAt = travelList.createdAt
        charger.modifiedAt = travelList.createdAt
        travelList.items.append(charger)
        
        var toiletries = Item(title: "Toiletries", listId: travelList.id)
        toiletries.itemDescription = "Toothbrush, toothpaste, shampoo"
        toiletries.orderNumber = 2
        toiletries.createdAt = travelList.createdAt
        toiletries.modifiedAt = travelList.createdAt
        travelList.items.append(toiletries)
        
        var shoes = Item(title: "Comfortable Shoes", listId: travelList.id)
        shoes.quantity = 2
        shoes.orderNumber = 3
        shoes.createdAt = travelList.createdAt
        shoes.modifiedAt = travelList.createdAt
        travelList.items.append(shoes)
        
        lists.append(travelList)
        
        return lists
    }
    
    // MARK: - Finnish Test Data
    
    private static func generateFinnishTestData() -> [List] {
        var lists: [List] = []
        
        // List 1: Ruokaostokset (with mixed active and completed items)
        var ostoslista = List(name: "Ruokaostokset")
        ostoslista.orderNumber = 0
        ostoslista.createdAt = Date().addingTimeInterval(-86400 * 7) // 7 päivää sitten
        ostoslista.modifiedAt = Date().addingTimeInterval(-3600) // 1 tunti sitten
        
        var maito = Item(title: "Maito", listId: ostoslista.id)
        maito.quantity = 2
        maito.itemDescription = "Kevyt- tai täysmaito"
        maito.orderNumber = 0
        maito.createdAt = ostoslista.createdAt
        maito.modifiedAt = ostoslista.createdAt
        ostoslista.items.append(maito)
        
        var leipa = Item(title: "Leipä", listId: ostoslista.id)
        leipa.itemDescription = "Täysjyväleipä tai sämpylät"
        leipa.orderNumber = 1
        leipa.createdAt = ostoslista.createdAt
        leipa.modifiedAt = ostoslista.createdAt
        ostoslista.items.append(leipa)
        
        var munat = Item(title: "Kananmunat", listId: ostoslista.id)
        munat.quantity = 12
        munat.itemDescription = "Vapaan kanan munia"
        munat.orderNumber = 2
        munat.isCrossedOut = true
        munat.createdAt = ostoslista.createdAt
        munat.modifiedAt = Date().addingTimeInterval(-7200) // 2 tuntia sitten
        ostoslista.items.append(munat)
        
        var omenat = Item(title: "Omenat", listId: ostoslista.id)
        omenat.quantity = 6
        omenat.itemDescription = "Tuoreet kotimaiset"
        omenat.orderNumber = 3
        omenat.createdAt = ostoslista.createdAt
        omenat.modifiedAt = ostoslista.createdAt
        ostoslista.items.append(omenat)
        
        var kahvi = Item(title: "Kahvi", listId: ostoslista.id)
        kahvi.itemDescription = "Keskipaahto, papuja"
        kahvi.orderNumber = 4
        kahvi.isCrossedOut = true
        kahvi.createdAt = ostoslista.createdAt
        kahvi.modifiedAt = Date().addingTimeInterval(-3600) // 1 tunti sitten
        ostoslista.items.append(kahvi)
        
        var broileri = Item(title: "Broilerin rintafile", listId: ostoslista.id)
        broileri.quantity = 2
        broileri.itemDescription = "Luomu, luuton"
        broileri.orderNumber = 5
        broileri.createdAt = ostoslista.createdAt
        broileri.modifiedAt = ostoslista.createdAt
        ostoslista.items.append(broileri)
        
        lists.append(ostoslista)
        
        // List 2: Viikonlopun projektit
        var projektilista = List(name: "Viikonlopun projektit")
        projektilista.orderNumber = 1
        projektilista.createdAt = Date().addingTimeInterval(-86400 * 3) // 3 päivää sitten
        projektilista.modifiedAt = Date().addingTimeInterval(-1800) // 30 minuuttia sitten
        
        var maalaus = Item(title: "Maalaa olohuoneen seinä", listId: projektilista.id)
        maalaus.itemDescription = "Käytä sinistä maalia autotallista"
        maalaus.orderNumber = 0
        maalaus.createdAt = projektilista.createdAt
        maalaus.modifiedAt = projektilista.createdAt
        projektilista.items.append(maalaus)
        
        var korjaaOvi = Item(title: "Korjaa narisevan oven", listId: projektilista.id)
        korjaaOvi.itemDescription = "WD-40 auttanee"
        korjaaOvi.orderNumber = 1
        korjaaOvi.isCrossedOut = true
        korjaaOvi.createdAt = projektilista.createdAt
        korjaaOvi.modifiedAt = Date().addingTimeInterval(-1800) // 30 minuuttia sitten
        projektilista.items.append(korjaaOvi)
        
        var jarjesta = Item(title: "Järjestä autotalli", listId: projektilista.id)
        jarjesta.orderNumber = 2
        jarjesta.createdAt = projektilista.createdAt
        jarjesta.modifiedAt = projektilista.createdAt
        projektilista.items.append(jarjesta)
        
        lists.append(projektilista)
        
        // List 3: Luettavat kirjat
        var kirjalista = List(name: "Luettavat kirjat")
        kirjalista.orderNumber = 2
        kirjalista.createdAt = Date().addingTimeInterval(-86400 * 14) // 2 viikkoa sitten
        kirjalista.modifiedAt = Date().addingTimeInterval(-86400) // 1 päivä sitten
        
        var kirja1 = Item(title: "Tuntematon sotilas", listId: kirjalista.id)
        kirja1.itemDescription = "Väinö Linna"
        kirja1.orderNumber = 0
        kirja1.isCrossedOut = true
        kirja1.createdAt = kirjalista.createdAt
        kirja1.modifiedAt = Date().addingTimeInterval(-86400) // 1 päivä sitten
        kirjalista.items.append(kirja1)
        
        var kirja2 = Item(title: "Sapiens", listId: kirjalista.id)
        kirja2.itemDescription = "Yuval Noah Harari"
        kirja2.orderNumber = 1
        kirja2.createdAt = kirjalista.createdAt
        kirja2.modifiedAt = kirjalista.createdAt
        kirjalista.items.append(kirja2)
        
        var kirja3 = Item(title: "Seitsemän veljestä", listId: kirjalista.id)
        kirja3.itemDescription = "Aleksis Kivi"
        kirja3.orderNumber = 2
        kirja3.createdAt = kirjalista.createdAt
        kirja3.modifiedAt = kirjalista.createdAt
        kirjalista.items.append(kirja3)
        
        lists.append(kirjalista)
        
        // List 4: Matkapakkaus
        var matkailulista = List(name: "Matkapakkaus")
        matkailulista.orderNumber = 3
        matkailulista.createdAt = Date().addingTimeInterval(-86400 * 2) // 2 päivää sitten
        matkailulista.modifiedAt = Date().addingTimeInterval(-600) // 10 minuuttia sitten
        
        var passi = Item(title: "Passi ja asiakirjat", listId: matkailulista.id)
        passi.orderNumber = 0
        passi.isCrossedOut = true
        passi.createdAt = matkailulista.createdAt
        passi.modifiedAt = Date().addingTimeInterval(-600) // 10 minuuttia sitten
        matkailulista.items.append(passi)
        
        var laturi = Item(title: "Puhelimen laturi", listId: matkailulista.id)
        laturi.itemDescription = "USB-C kaapeli ja sovitin"
        laturi.orderNumber = 1
        laturi.createdAt = matkailulista.createdAt
        laturi.modifiedAt = matkailulista.createdAt
        matkailulista.items.append(laturi)
        
        var hygieniatuotteet = Item(title: "Hygieniatuotteet", listId: matkailulista.id)
        hygieniatuotteet.itemDescription = "Hammasharja, -tahna, shampoo"
        hygieniatuotteet.orderNumber = 2
        hygieniatuotteet.createdAt = matkailulista.createdAt
        hygieniatuotteet.modifiedAt = matkailulista.createdAt
        matkailulista.items.append(hygieniatuotteet)
        
        var kengat = Item(title: "Mukavat kengät", listId: matkailulista.id)
        kengat.quantity = 2
        kengat.orderNumber = 3
        kengat.createdAt = matkailulista.createdAt
        kengat.modifiedAt = matkailulista.createdAt
        matkailulista.items.append(kengat)
        
        lists.append(matkailulista)
        
        return lists
    }
}
