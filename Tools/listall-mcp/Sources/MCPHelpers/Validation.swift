import Foundation
import MCP

/// Validate simulator UDID format to prevent command injection
/// Valid formats: "all", "booted", or UUID (8-4-4-4-12 hex format)
public func validateUDID(_ udid: String) throws {
    if udid == "all" || udid == "booted" {
        return
    }

    guard UUID(uuidString: udid) != nil else {
        throw MCPError.invalidParams("Invalid UDID format: '\(udid)'. Must be 'all', 'booted', or a valid UUID.")
    }
}

/// Validate bundle ID format
/// Valid format: reverse domain notation (e.g., "com.example.app")
public func validateBundleID(_ bundleID: String) throws {
    guard bundleID.contains(".") else {
        throw MCPError.invalidParams("Invalid bundle ID format: '\(bundleID)'. Must be in reverse domain notation (e.g., 'com.example.app').")
    }

    guard !bundleID.contains(" ") else {
        throw MCPError.invalidParams("Invalid bundle ID format: '\(bundleID)'. Bundle ID cannot contain spaces.")
    }
}

/// Validate app name format (basic security check)
/// Valid format: alphanumeric with spaces, hyphens, and underscores
public func validateAppName(_ appName: String) throws {
    let allowedCharacters = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: " -_"))
    guard appName.unicodeScalars.allSatisfy({ allowedCharacters.contains($0) }) else {
        throw MCPError.invalidParams("Invalid app name format: '\(appName)'. App name can only contain letters, numbers, spaces, hyphens, and underscores.")
    }

    guard appName.count >= 1 && appName.count <= 255 else {
        throw MCPError.invalidParams("Invalid app name length: '\(appName)'. App name must be 1-255 characters.")
    }
}
