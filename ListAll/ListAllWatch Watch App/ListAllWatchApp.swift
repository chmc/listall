import SwiftUI
import Combine
import CoreData

@main
struct ListAllWatch_Watch_AppApp: App {
    @StateObject private var localizationManager = WatchLocalizationManager.shared
    @Environment(\.scenePhase) private var scenePhase
    
    init() {
        // CRITICAL: Set AppleLanguages BEFORE anything else to ensure localization works
        Self.configureLanguage()
        
        // Initialize Core Data on app launch
        _ = CoreDataManager.shared
        
        // Setup deterministic data for UI tests
        setupUITestEnvironment()
    }
    
    /// Configure language BEFORE any views are loaded
    private static func configureLanguage() {
        // Handle Fastlane language during UI tests - check both environment and launch arguments
        if let fastlaneLanguage = ProcessInfo.processInfo.environment["FASTLANE_LANGUAGE"] {
            let languageCode = String(fastlaneLanguage.prefix(2)) // Extract "en" from "en-US"
            UserDefaults.standard.set([languageCode], forKey: "AppleLanguages")
            UserDefaults.standard.synchronize()
            print("🧪 Watch: Set language from FASTLANE_LANGUAGE environment: \(languageCode)")
            return
        }

        // Check if Snapshot helper has set -AppleLanguages launch argument and persist it
        let args = ProcessInfo.processInfo.arguments
        if let index = args.firstIndex(of: "-AppleLanguages"),
           index + 1 < args.count {
            var langArg = args[index + 1]
            // langArg may be in the form "(fi)" or "(en)". Strip non-letters and lowercased
            let parsed = langArg.lowercased().filter { $0.isLetter }
            let languageCode = String(parsed.prefix(2))
            if !languageCode.isEmpty {
                UserDefaults.standard.set([languageCode], forKey: "AppleLanguages")
                UserDefaults.standard.synchronize()
                print("🧪 Watch: Persisted AppleLanguages from launch arg: \(languageCode)")
                return
            } else {
                print("🧪 Watch: -AppleLanguages provided but could not parse: \(langArg)")
            }
        }
        
        // Try App Groups first
        var languageCode: String?
        
        if let sharedDefaults = UserDefaults(suiteName: "group.io.github.chmc.ListAll") {
            languageCode = sharedDefaults.string(forKey: "AppLanguage")
        }
        
        // Fallback to standard UserDefaults
        if languageCode == nil {
            languageCode = UserDefaults.standard.string(forKey: "AppLanguage")
        }
        
        // Default to English if no language code found
        let finalLanguageCode = languageCode ?? "en"
        
        // Set AppleLanguages
        UserDefaults.standard.set([finalLanguageCode], forKey: "AppleLanguages")
        UserDefaults.standard.synchronize()
    }
    
    /// Configure the watch app for UI testing with deterministic data
    private func setupUITestEnvironment() {
        // Check if running in UI test mode
        guard WatchUITestDataService.isUITesting else {
            return
        }
        
        print("🧪 Watch UI Test mode detected - setting up deterministic test data")
        
        // Clear existing data to ensure clean state
        clearAllData()
        
        // Populate with deterministic test data
        populateTestData()
    }
    
    /// Clear all existing data from the data store
    private func clearAllData() {
        let coreDataManager = CoreDataManager.shared
        let context = coreDataManager.viewContext
        
        // Delete all existing lists (which will cascade delete items and images)
        let listRequest: NSFetchRequest<NSFetchRequestResult> = ListEntity.fetchRequest()
        let listDeleteRequest = NSBatchDeleteRequest(fetchRequest: listRequest)
        
        do {
            try context.execute(listDeleteRequest)
            try context.save()
            print("🧪 Watch: Cleared existing data for UI tests")
        } catch {
            print("❌ Watch: Failed to clear data for UI tests: \(error)")
        }
    }
    
    /// Populate the data store with deterministic test data
    private func populateTestData() {
        let testLists = WatchUITestDataService.generateTestData()
        let dataManager = DataManager.shared
        
        // Add each test list to the data manager
        for list in testLists {
            dataManager.addList(list)
            
            // Add items for each list
            for item in list.items {
                dataManager.addItem(item, to: list.id)
            }
        }
        
        // Force reload to ensure UI shows the test data
        dataManager.loadData()
        
        print("🧪 Watch: Populated \(testLists.count) test lists with deterministic data")
    }
    
    var body: some Scene {
        WindowGroup {
            WatchListsView()
                .environmentObject(localizationManager) // Inject localization manager
                .environment(\.locale, localizationManager.currentLocale)
                .id(localizationManager.refreshID) // Recreate view when language changes
                .onAppear {
                    // Refresh language when view appears
                    localizationManager.refreshLanguage()
                }
                .alert(watchLocalizedString("Language Changed", comment: "watchOS language changed alert title"), isPresented: $localizationManager.needsRestart) {
                    Button(watchLocalizedString("OK", comment: "OK button")) {
                        // User acknowledged - they need to restart the app manually
                        // watchOS doesn't support programmatic app restart
                    }
                } message: {
                    Text(watchLocalizedString("Please restart the app to see the new language.", comment: "watchOS language changed alert message"))
                }
        }
        .onChange(of: scenePhase) { phase in
            if phase == .active {
                // Refresh language when app becomes active (returning from background)
                localizationManager.refreshLanguage()
            }
        }
    }
}

/// Localization manager for watchOS that syncs with iOS language preference
class WatchLocalizationManager: ObservableObject {
    static let shared = WatchLocalizationManager()
    
    @Published var currentLocale: Locale
    @Published var needsRestart = false // Flag to show restart prompt
    @Published var refreshID = UUID() // Force view refresh when language changes
    
    private let userDefaultsKey = "AppLanguage"
    private let sharedDefaults: UserDefaults?
    private var currentLanguageCode: String?
    
    private init() {
        // Use shared UserDefaults for App Groups
        self.sharedDefaults = UserDefaults(suiteName: "group.io.github.chmc.ListAll")

        // Determine language from (priority): FASTLANE_LANGUAGE, AppleLanguages, AppLanguage (shared/standard), fallback 'en'
        var selected: String?

        if let fastlane = ProcessInfo.processInfo.environment["FASTLANE_LANGUAGE"], !fastlane.isEmpty {
            selected = String(fastlane.prefix(2)).lowercased()
            print("🧪 WatchLocalizationManager: Using FASTLANE_LANGUAGE=\(selected!)")
        } else if let appleLangs = UserDefaults.standard.array(forKey: "AppleLanguages") as? [String],
                  let first = appleLangs.first, !first.isEmpty {
            selected = String(first.prefix(2)).lowercased()
            print("🧪 WatchLocalizationManager: Using AppleLanguages=\(selected!)")
        } else {
            // Load saved language from iOS app (try App Groups first, then standard UserDefaults)
            var languageCode: String? = sharedDefaults?.string(forKey: userDefaultsKey)
            if languageCode == nil {
                // App Groups might not work in dev mode, try standard UserDefaults as backup
                languageCode = UserDefaults.standard.string(forKey: userDefaultsKey)
            }
            if let code = languageCode, !code.isEmpty {
                selected = code
                print("🧪 WatchLocalizationManager: Using saved AppLanguage=\(code)")
            }
        }

        let finalCode = (selected ?? "en").lowercased()
        self.currentLanguageCode = finalCode
        self.currentLocale = Locale(identifier: finalCode)

        // Persist AppleLanguages consistently for NSLocalizedString bundle resolution
        UserDefaults.standard.set([finalCode], forKey: "AppleLanguages")
        UserDefaults.standard.synchronize()
    }
    
    /// Refresh language from shared UserDefaults (call when app becomes active)
    func refreshLanguage() {
        if let languageCode = sharedDefaults?.string(forKey: userDefaultsKey) {
            // Check if language actually changed
            if languageCode != currentLanguageCode {
                self.currentLanguageCode = languageCode
                self.currentLocale = Locale(identifier: languageCode)
                
                // Update AppleLanguages
                UserDefaults.standard.set([languageCode], forKey: "AppleLanguages")
                UserDefaults.standard.synchronize()
                
                // Force views to refresh by changing refreshID
                self.refreshID = UUID()
                
                // Note: We no longer need to show restart prompt since we're dynamically reloading strings
                // needsRestart = true
            }
        }
    }
}
