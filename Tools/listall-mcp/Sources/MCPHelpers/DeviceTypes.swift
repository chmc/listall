import Foundation

/// Determine device type from a device type identifier string
/// - Parameter identifier: The device type identifier (e.g., "com.apple.CoreSimulator.SimDeviceType.iPhone-16")
/// - Returns: Human-readable device type name
public func deviceTypeFromIdentifier(_ identifier: String?) -> String {
    guard let identifier = identifier else { return "Unknown" }
    if identifier.contains("iPhone") { return "iPhone" }
    if identifier.contains("iPad") { return "iPad" }
    if identifier.contains("Watch") { return "Apple Watch" }
    if identifier.contains("TV") { return "Apple TV" }
    if identifier.contains("Vision") { return "Apple Vision" }
    return "Unknown"
}
