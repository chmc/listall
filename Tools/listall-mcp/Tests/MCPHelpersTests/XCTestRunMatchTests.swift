import Testing
import Foundation
@testable import MCPHelpers

@Suite("xctestrun File Matching")
struct XCTestRunMatchTests {
    private let watchScheme = "ListAllWatch Watch App"

    // Xcode 26 names the watch scheme's file after the paired iPhone simulator platform
    @Test func watchSchemeFileNamedIPhoneSimulator() {
        #expect(isSimulatorXCTestRun("ListAllWatch Watch App_ListAllWatch Watch App_iphonesimulator26.5-arm64.xctestrun",
                                     forScheme: watchScheme))
    }

    @Test func watchSchemeFileNamedWatchSimulator() {
        #expect(isSimulatorXCTestRun("ListAllWatch Watch App_ListAllWatch Watch App_watchsimulator26.5-arm64.xctestrun",
                                     forScheme: watchScheme))
    }

    @Test func iOSSchemeFile() {
        #expect(isSimulatorXCTestRun("ListAll_ListAll_iphonesimulator26.5-arm64.xctestrun", forScheme: "ListAll"))
    }

    // Both files contain "iphonesimulator"; the iOS lookup must not pick the watch file
    @Test func iOSSchemeRejectsWatchFile() {
        #expect(!isSimulatorXCTestRun("ListAllWatch Watch App_ListAllWatch Watch App_iphonesimulator26.5-arm64.xctestrun",
                                      forScheme: "ListAll"))
    }

    @Test func watchSchemeRejectsIOSFile() {
        #expect(!isSimulatorXCTestRun("ListAll_ListAll_iphonesimulator26.5-arm64.xctestrun", forScheme: watchScheme))
    }

    @Test func rejectsDeviceBuild() {
        #expect(!isSimulatorXCTestRun("ListAll_ListAll_iphoneos26.5-arm64.xctestrun", forScheme: "ListAll"))
    }

    @Test func rejectsOtherExtensions() {
        #expect(!isSimulatorXCTestRun("ListAll_ListAll_iphonesimulator26.5-arm64.xcresult", forScheme: "ListAll"))
    }
}
