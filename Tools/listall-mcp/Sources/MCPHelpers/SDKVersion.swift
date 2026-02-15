import Foundation

/// Extract SDK version from xctestrun filename
/// Example: "ListAll_iphonesimulator18.1-arm64.xctestrun" -> "18.1"
public func extractSDKVersion(from xctestrunPath: String) -> String? {
    let filename = (xctestrunPath as NSString).lastPathComponent
    let pattern = #"_(?:iphone|watch)simulator(\d+\.\d+)-"#
    guard let regex = try? NSRegularExpression(pattern: pattern),
          let match = regex.firstMatch(in: filename, range: NSRange(filename.startIndex..., in: filename)),
          let versionRange = Range(match.range(at: 1), in: filename) else {
        return nil
    }
    return String(filename[versionRange])
}
