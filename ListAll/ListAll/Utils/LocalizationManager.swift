import Foundation
import SwiftUI
import Combine
#if os(iOS)
import WatchConnectivity
#endif

/// Manager for handling app localization and language preferences
class LocalizationManager: ObservableObject {
    static let shared = LocalizationManager()
    
    @Published var currentLanguage: AppLanguage
    
    /// Available languages in the app
    enum AppLanguage: String, CaseIterable, Identifiable {
        case english = "en"
        case finnish = "fi"
        
        var id: String { rawValue }
        
        var displayName: String {
            switch self {
            case .english: return "English"
            case .finnish: return "Suomi" // Finnish
            }
        }
        
        var nativeDisplayName: String {
            switch self {
            case .english: return "English"
            case .finnish: return "Suomi"
            }
        }
        
        var flagEmoji: String {
            switch self {
            case .english: return "🇺🇸"
            case .finnish: return "🇫🇮"
            }
        }
    }
    
    private let userDefaultsKey = "AppLanguage"
    private let userDefaults: UserDefaults
    
    private init() {
        // Use shared UserDefaults for App Groups (iOS and watchOS)
        if let sharedDefaults = UserDefaults(suiteName: "group.io.github.chmc.ListAll") {
            self.userDefaults = sharedDefaults
        } else {
            // Fallback to standard UserDefaults if App Groups not available
            self.userDefaults = .standard
        }
        
        // For UI tests: Check if Fastlane Snapshot set a language via environment variable
        // Also check AppleLanguages which is set by Fastlane for app localization
        if let fastlaneLanguage = ProcessInfo.processInfo.environment["FASTLANE_LANGUAGE"] {
            print("🧪 Fastlane language detected in environment: \(fastlaneLanguage)")
            // Map FASTLANE_LANGUAGE codes to our AppLanguage enum
            if fastlaneLanguage.hasPrefix("fi") {
                self.currentLanguage = .finnish
            } else {
                self.currentLanguage = .english
            }
            // Apply the language immediately
            applyLanguage(currentLanguage)
            print("🧪 Set currentLanguage to: \(currentLanguage.rawValue)")
            return
        }
        
        // Check if AppleLanguages preference is set (used by Fastlane)
        if let appleLanguages = UserDefaults.standard.array(forKey: "AppleLanguages") as? [String],
           let firstLanguage = appleLanguages.first {
            print("🧪 AppleLanguages detected: \(firstLanguage)")
            if firstLanguage.hasPrefix("fi") {
                self.currentLanguage = .finnish
                print("🧪 Set currentLanguage to Finnish from AppleLanguages")
                return
            } else if firstLanguage.hasPrefix("en") {
                self.currentLanguage = .english
                print("🧪 Set currentLanguage to English from AppleLanguages")
                return
            }
        }
        
        // Load saved language or default to English
        if let savedLanguageCode = userDefaults.string(forKey: userDefaultsKey),
           let savedLanguage = AppLanguage(rawValue: savedLanguageCode) {
            self.currentLanguage = savedLanguage
        } else {
            // Default to English (not system language)
            self.currentLanguage = .english
            
            // IMPORTANT: Save the default language to App Groups so watchOS can see it
            userDefaults.set(self.currentLanguage.rawValue, forKey: userDefaultsKey)
            userDefaults.synchronize()
        }
        
        // Apply the language on initialization
        applyLanguage(currentLanguage)
    }
    
    /// Apply language to the app
    private func applyLanguage(_ language: AppLanguage) {
        // Update UserDefaults for localization
        userDefaults.set([language.rawValue], forKey: "AppleLanguages")
        userDefaults.synchronize()
        
        // Also update standard UserDefaults for current process
        UserDefaults.standard.set([language.rawValue], forKey: "AppleLanguages")
        UserDefaults.standard.synchronize()
    }
    
    /// Change the app language
    func setLanguage(_ language: AppLanguage) {
        currentLanguage = language
        userDefaults.set(language.rawValue, forKey: userDefaultsKey)
        userDefaults.synchronize() // Force write to disk immediately
        
        // Apply the language
        applyLanguage(language)
        
        // IMPORTANT: Send language preference to watchOS via WatchConnectivity
        #if os(iOS)
        sendLanguageToWatch(language)
        #endif
        
        // Post notification for app to reload
        NotificationCenter.default.post(name: .languageChanged, object: nil)
    }
    
    #if os(iOS)
    /// Send language preference to watchOS via WatchConnectivity
    private func sendLanguageToWatch(_ language: AppLanguage) {
        WatchConnectivityService.shared.sendLanguagePreference(language.rawValue)
    }
    #endif
    
    /// Get localized string for current language
    func localizedString(_ key: String, comment: String = "") -> String {
        // Use bundle localization system
        return NSLocalizedString(key, comment: comment)
    }
}

// MARK: - Notification Extension

extension Notification.Name {
    static let languageChanged = Notification.Name("LanguageChanged")
}

// MARK: - SwiftUI Environment Key

private struct LocalizationManagerKey: EnvironmentKey {
    static let defaultValue: LocalizationManager = .shared
}

extension EnvironmentValues {
    var localizationManager: LocalizationManager {
        get { self[LocalizationManagerKey.self] }
        set { self[LocalizationManagerKey.self] = newValue }
    }
}

// MARK: - String Extension for Localization

extension String {
    /// Returns localized version of the string
    var localized: String {
        NSLocalizedString(self, comment: "")
    }
    
    /// Returns localized version with parameters
    func localized(_ arguments: CVarArg...) -> String {
        String(format: NSLocalizedString(self, comment: ""), arguments: arguments)
    }
}

