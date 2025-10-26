import Foundation
import SwiftUI

/// Manager for handling app localization and language preferences
@MainActor
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
    
    private init() {
        // Load saved language or use system language
        if let savedLanguageCode = UserDefaults.standard.string(forKey: userDefaultsKey),
           let savedLanguage = AppLanguage(rawValue: savedLanguageCode) {
            self.currentLanguage = savedLanguage
        } else {
            // Use system language if available, otherwise default to English
            let systemLanguageCode = Locale.current.language.languageCode?.identifier ?? "en"
            self.currentLanguage = AppLanguage(rawValue: systemLanguageCode) ?? .english
        }
    }
    
    /// Change the app language
    func setLanguage(_ language: AppLanguage) {
        currentLanguage = language
        UserDefaults.standard.set(language.rawValue, forKey: userDefaultsKey)
        
        // Update user defaults for localization
        UserDefaults.standard.set([language.rawValue], forKey: "AppleLanguages")
        UserDefaults.standard.synchronize()
        
        // Post notification for app to reload
        NotificationCenter.default.post(name: .languageChanged, object: nil)
    }
    
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

