import Testing
import Foundation
@testable import ListAll

/// Guards UI strings that were missing from Localizable.xcstrings and therefore
/// showed in English inside the Finnish UI.
struct LocalizationCoverageTests {

    /// Finnish translation of `key` from the app bundle, or nil when untranslated.
    private static func finnishTranslation(of key: String) -> String? {
        guard let path = Bundle.main.path(forResource: "fi", ofType: "lproj"),
              let bundle = Bundle(path: path) else { return nil }
        let value = bundle.localizedString(forKey: key, value: nil, table: nil)
        return value == key ? nil : value
    }

    @Test func testFinnishLookupFindsExistingTranslation() {
        #expect(Self.finnishTranslation(of: "No List Selected") == "Ei valittua listaa")
    }

    @Test func testIPadEmptyDetailTitleIsTranslatedToFinnish() {
        #expect(Self.finnishTranslation(of: "Select a List") == "Valitse lista")
    }
}
