import Testing
import Foundation
@testable import MCPHelpers

@Suite("Context Sanitizer")
struct ContextSanitizerTests {
    @Test func stripsPlatformPrefix() {
        #expect(ContextSanitizer.sanitize("macos-settings") == "settings")
    }

    @Test func stripsPlatformSuffix() {
        #expect(ContextSanitizer.sanitize("settings-ios") == "settings")
    }

    @Test func stripsNestedPrefixes() {
        #expect(ContextSanitizer.sanitize("ios-macos-thing") == "thing")
    }

    @Test func stripsNestedSuffixes() {
        #expect(ContextSanitizer.sanitize("thing-ios-macos") == "thing")
    }

    @Test func stripsBothPrefixAndSuffix() {
        #expect(ContextSanitizer.sanitize("macos-iphone-settings-watchos") == "settings")
    }

    @Test func replacesSpacesWithHyphens() {
        #expect(ContextSanitizer.sanitize("my context") == "my-context")
    }

    @Test func stripsSpecialCharacters() {
        #expect(ContextSanitizer.sanitize("test@#$view") == "testview")
    }

    @Test func nilReturnsFallback() {
        #expect(ContextSanitizer.sanitize(nil) == "screenshot")
    }

    @Test func emptyReturnsFallback() {
        #expect(ContextSanitizer.sanitize("") == "screenshot")
    }

    @Test func barePlatformNameReturnsFallback() {
        #expect(ContextSanitizer.sanitize("macos") == "screenshot")
    }

    @Test func bareWatchOSReturnsFallback() {
        #expect(ContextSanitizer.sanitize("watchos") == "screenshot")
    }

    @Test func noPlatformContentUnchanged() {
        #expect(ContextSanitizer.sanitize("settings") == "settings")
    }
}
