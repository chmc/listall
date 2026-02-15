import Foundation

/// Normalize ListAll app name variants to the canonical name
/// The macOS app is named "ListAll" (not "ListAllMac")
public func normalizeListAllAppName(_ appName: String?) -> String? {
    guard let name = appName else { return nil }

    switch name.lowercased() {
    case "listallmac", "listall mac", "listall-mac":
        return "ListAll"
    default:
        return name
    }
}

/// Normalize ListAll bundle ID variants to the canonical ID
/// The macOS app uses "io.github.chmc.ListAll" (same as iOS)
public func normalizeListAllBundleID(_ bundleId: String?) -> String? {
    guard let id = bundleId else { return nil }

    switch id.lowercased() {
    case "io.github.chmc.listallmac":
        return "io.github.chmc.ListAll"
    default:
        return id
    }
}
