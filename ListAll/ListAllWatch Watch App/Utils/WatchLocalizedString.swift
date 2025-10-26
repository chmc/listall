import Foundation

/// Helper function to get localized strings that respect the app's language preference
/// This loads from the correct .lproj bundle based on the WatchLocalizationManager's language
func watchLocalizedString(_ key: String, comment: String = "") -> String {
    // Get the current language from WatchLocalizationManager
    let languageCode = WatchLocalizationManager.shared.currentLocale.language.languageCode?.identifier ?? "en"
    
    #if DEBUG
    print("🌍 [watchLocalizedString] Loading '\(key)' for language: \(languageCode)")
    #endif
    
    // Load from the specific language bundle
    if let path = Bundle.main.path(forResource: languageCode, ofType: "lproj") {
        #if DEBUG
        print("🌍 [watchLocalizedString] Found bundle at: \(path)")
        #endif
        
        if let bundle = Bundle(path: path) {
            let result = NSLocalizedString(key, bundle: bundle, comment: comment)
            #if DEBUG
            print("🌍 [watchLocalizedString] Result: '\(result)'")
            #endif
            return result
        } else {
            #if DEBUG
            print("❌ [watchLocalizedString] Failed to create bundle from path")
            #endif
        }
    } else {
        #if DEBUG
        print("❌ [watchLocalizedString] No .lproj bundle found for \(languageCode)")
        print("🌍 [watchLocalizedString] Available localizations: \(Bundle.main.localizations)")
        #endif
    }
    
    // Fallback to default bundle
    let fallback = NSLocalizedString(key, comment: comment)
    #if DEBUG
    print("🌍 [watchLocalizedString] Using fallback: '\(fallback)'")
    #endif
    return fallback
}
