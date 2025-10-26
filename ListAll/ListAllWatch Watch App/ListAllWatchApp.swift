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
        
        // Debug: Check what's in shared UserDefaults
        #if DEBUG
        if let sharedDefaults = UserDefaults(suiteName: "group.io.github.chmc.ListAll") {
            let savedLanguage = sharedDefaults.string(forKey: "AppLanguage")
            print("🌍 [watchOS Init] Language in App Groups: \(savedLanguage ?? "nil")")
        }
        #endif
    }
    
    /// Configure language BEFORE any views are loaded
    private static func configureLanguage() {
        // Try App Groups first
        var languageCode: String?
        
        if let sharedDefaults = UserDefaults(suiteName: "group.io.github.chmc.ListAll") {
            languageCode = sharedDefaults.string(forKey: "AppLanguage")
            #if DEBUG
            if languageCode != nil {
                print("🌍 [watchOS Early Init] Found language in App Groups: \(languageCode!)")
            }
            #endif
        }
        
        // Fallback to standard UserDefaults
        if languageCode == nil {
            languageCode = UserDefaults.standard.string(forKey: "AppLanguage")
            #if DEBUG
            if languageCode != nil {
                print("🌍 [watchOS Early Init] Found language in standard UserDefaults: \(languageCode!)")
            }
            #endif
        }
        
        // Set AppleLanguages if we have a language code
        if let languageCode = languageCode {
            UserDefaults.standard.set([languageCode], forKey: "AppleLanguages")
            UserDefaults.standard.synchronize()
            
            #if DEBUG
            print("🌍 [watchOS Early Init] Set AppleLanguages to: [\(languageCode)]")
            print("🌍 [watchOS Early Init] Verification - AppleLanguages is now: \(UserDefaults.standard.array(forKey: "AppleLanguages") ?? [])")
            #endif
        } else {
            #if DEBUG
            print("🌍 [watchOS Early Init] No saved language found")
            #endif
        }
    }
    
    var body: some Scene {
        WindowGroup {
            WatchListsView()
                .environmentObject(localizationManager) // Inject localization manager
                .environment(\.locale, localizationManager.currentLocale)
                .id(localizationManager.refreshID) // Recreate view when language changes
                .onAppear {
                    // Refresh language when view appears
                    #if DEBUG
                    print("🌍 [watchOS] WatchListsView appeared - refreshing language")
                    #endif
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
            #if DEBUG
            print("🌍 [watchOS] Scene phase changed to: \(phase)")
            #endif
            
            if phase == .active {
                // Refresh language when app becomes active (returning from background)
                #if DEBUG
                print("🌍 [watchOS] App became active - refreshing language")
                #endif
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
        
        #if DEBUG
        print("🌍 [WatchLocalizationManager] Initializing...")
        print("🌍 [WatchLocalizationManager] Shared defaults available: \(sharedDefaults != nil)")
        #endif
        
        // Load saved language from iOS app (try App Groups first, then standard UserDefaults)
        var languageCode: String? = sharedDefaults?.string(forKey: userDefaultsKey)
        
        if languageCode == nil {
            // App Groups might not work in dev mode, try standard UserDefaults as backup
            languageCode = UserDefaults.standard.string(forKey: userDefaultsKey)
            #if DEBUG
            if languageCode != nil {
                print("🌍 [WatchLocalizationManager] Found language code in standard UserDefaults: \(languageCode!)")
            }
            #endif
        } else {
            #if DEBUG
            print("🌍 [WatchLocalizationManager] Found language code in App Groups: \(languageCode!)")
            #endif
        }
        
        if let languageCode = languageCode {
            self.currentLanguageCode = languageCode
            self.currentLocale = Locale(identifier: languageCode)
            
            // Set UserDefaults for NSLocalizedString to work
            UserDefaults.standard.set([languageCode], forKey: "AppleLanguages")
            UserDefaults.standard.synchronize()
            
            #if DEBUG
            print("🌍 [WatchLocalizationManager] Applied language: \(languageCode)")
            print("🌍 [WatchLocalizationManager] Current locale: \(self.currentLocale.identifier)")
            print("🌍 [WatchLocalizationManager] AppleLanguages set to: \(UserDefaults.standard.array(forKey: "AppleLanguages") ?? [])")
            #endif
        } else {
            #if DEBUG
            print("🌍 [WatchLocalizationManager] No language in App Groups or standard UserDefaults")
            print("🌍 [WatchLocalizationManager] Using system locale: \(Locale.current.identifier)")
            
            // Debug: Print all keys in shared defaults
            if let sharedDefaults = sharedDefaults {
                print("🌍 [WatchLocalizationManager] Keys in shared defaults: \(sharedDefaults.dictionaryRepresentation().keys)")
            }
            #endif
            
            // Fallback to system locale
            self.currentLocale = Locale.current
        }
    }
    
    /// Refresh language from shared UserDefaults (call when app becomes active)
    func refreshLanguage() {
        #if DEBUG
        print("🌍 [WatchLocalizationManager] refreshLanguage() called")
        #endif
        
        if let languageCode = sharedDefaults?.string(forKey: userDefaultsKey) {
            #if DEBUG
            print("🌍 [WatchLocalizationManager] Found language code: \(languageCode)")
            print("🌍 [WatchLocalizationManager] Current language code: \(currentLanguageCode ?? "nil")")
            #endif
            
            // Check if language actually changed
            if languageCode != currentLanguageCode {
                #if DEBUG
                print("🌍 [WatchLocalizationManager] Language changed from \(currentLanguageCode ?? "nil") to \(languageCode)")
                #endif
                
                self.currentLanguageCode = languageCode
                self.currentLocale = Locale(identifier: languageCode)
                
                // Update AppleLanguages
                UserDefaults.standard.set([languageCode], forKey: "AppleLanguages")
                UserDefaults.standard.synchronize()
                
                // Force views to refresh by changing refreshID
                self.refreshID = UUID()
                
                #if DEBUG
                print("🌍 [WatchLocalizationManager] Updated AppleLanguages to: \(languageCode)")
                print("🌍 [WatchLocalizationManager] Triggered view refresh with new refreshID")
                #endif
                
                // Note: We no longer need to show restart prompt since we're dynamically reloading strings
                // needsRestart = true
            } else {
                #if DEBUG
                print("🌍 [WatchLocalizationManager] Language unchanged: \(languageCode)")
                #endif
            }
        } else {
            #if DEBUG
            print("🌍 [WatchLocalizationManager] No language found in App Groups during refresh")
            #endif
        }
    }
}
