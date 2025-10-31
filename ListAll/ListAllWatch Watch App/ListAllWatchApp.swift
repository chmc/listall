import SwiftUI
import Combine

@main
struct ListAllWatch_Watch_AppApp: App {
    @StateObject private var localizationManager = WatchLocalizationManager.shared
    @Environment(\.scenePhase) private var scenePhase
    
    init() {
        // CRITICAL: Set AppleLanguages BEFORE anything else to ensure localization works
        Self.configureLanguage()
        
        // Initialize Core Data on app launch
        _ = CoreDataManager.shared
    }
    
    /// Configure language BEFORE any views are loaded
    private static func configureLanguage() {
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
        
        // Load saved language from iOS app (try App Groups first, then standard UserDefaults)
        var languageCode: String? = sharedDefaults?.string(forKey: userDefaultsKey)
        
        if languageCode == nil {
            // App Groups might not work in dev mode, try standard UserDefaults as backup
            languageCode = UserDefaults.standard.string(forKey: userDefaultsKey)
        }
        
        if let languageCode = languageCode {
            self.currentLanguageCode = languageCode
            self.currentLocale = Locale(identifier: languageCode)
            
            // Set UserDefaults for NSLocalizedString to work
            UserDefaults.standard.set([languageCode], forKey: "AppleLanguages")
            UserDefaults.standard.synchronize()
        } else {
            // Default to English (not system locale)
            self.currentLanguageCode = "en"
            self.currentLocale = Locale(identifier: "en")
            
            // Set English as default
            UserDefaults.standard.set(["en"], forKey: "AppleLanguages")
            UserDefaults.standard.synchronize()
        }
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
