import Foundation

/// Whether a file is a simulator xctestrun produced by `build-for-testing` of the given scheme.
/// Matches on the scheme prefix, not the platform: Xcode 26 names the watch scheme's file
/// "ListAllWatch Watch App_..._iphonesimulator26.5-arm64.xctestrun" (after the paired iPhone),
/// and a platform-only match would also let the iOS lookup pick the watch file.
/// Example: ("ListAll_ListAll_iphonesimulator26.5-arm64.xctestrun", "ListAll") -> true
public func isSimulatorXCTestRun(_ fileName: String, forScheme schemeName: String) -> Bool {
    fileName.hasPrefix("\(schemeName)_")
        && fileName.hasSuffix(".xctestrun")
        && fileName.contains("simulator")
}
