import Foundation

/// Helper function to get localized strings that respect the app's language preference
/// This loads from the correct .lproj bundle based on the WatchLocalizationManager's language
func watchLocalizedString(_ key: String, comment: String = "") -> String {
    // Get the current language from WatchLocalizationManager
    let languageCode = WatchLocalizationManager.shared.currentLocale.language.languageCode?.identifier ?? "en"
    
    // Load from the specific language bundle
    if let path = Bundle.main.path(forResource: languageCode, ofType: "lproj") {
        if let bundle = Bundle(path: path) {
            let result = NSLocalizedString(key, bundle: bundle, comment: comment)
            return result
        }
    }
    
    // Fallback to default bundle
    let fallback = NSLocalizedString(key, comment: comment)
    return fallback
}
