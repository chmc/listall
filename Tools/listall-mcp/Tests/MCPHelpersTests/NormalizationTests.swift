import Testing
import Foundation
@testable import MCPHelpers

@Suite("App Name Normalization")
struct AppNameNormalizationTests {
    @Test func listAllMacNormalized() {
        #expect(normalizeListAllAppName("ListAllMac") == "ListAll")
    }

    @Test func lowercaseVariant() {
        #expect(normalizeListAllAppName("listallmac") == "ListAll")
    }

    @Test func listAllUnchanged() {
        #expect(normalizeListAllAppName("ListAll") == "ListAll")
    }

    @Test func otherAppUnchanged() {
        #expect(normalizeListAllAppName("Safari") == "Safari")
    }

    @Test func nilReturnsNil() {
        #expect(normalizeListAllAppName(nil) == nil)
    }
}

@Suite("Bundle ID Normalization")
struct BundleIDNormalizationTests {
    @Test func listAllMacBundleIDNormalized() {
        #expect(normalizeListAllBundleID("io.github.chmc.ListAllMac") == "io.github.chmc.ListAll")
    }

    @Test func otherBundleIDUnchanged() {
        #expect(normalizeListAllBundleID("com.apple.Safari") == "com.apple.Safari")
    }
}
