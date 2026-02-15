import Testing
import Foundation
@testable import MCPHelpers

@Suite("SDK Version Extraction")
struct SDKVersionTests {
    @Test func iPhoneSimulator() {
        #expect(extractSDKVersion(from: "ListAll_iphonesimulator18.1-arm64.xctestrun") == "18.1")
    }

    @Test func watchSimulator() {
        #expect(extractSDKVersion(from: "ListAllWatch_watchsimulator11.2-arm64.xctestrun") == "11.2")
    }

    @Test func universalBinary() {
        #expect(extractSDKVersion(from: "ListAll_iphonesimulator18.1-arm64-x86_64.xctestrun") == "18.1")
    }

    @Test func noMatch() {
        #expect(extractSDKVersion(from: "random_filename.xctestrun") == nil)
    }

    @Test func emptyString() {
        #expect(extractSDKVersion(from: "") == nil)
    }
}
