import Testing
import Foundation
@testable import MCPHelpers

@Suite("Device Type Detection")
struct DeviceTypeTests {
    @Test func iPhone() {
        #expect(deviceTypeFromIdentifier("com.apple.CoreSimulator.SimDeviceType.iPhone-16") == "iPhone")
    }

    @Test func iPad() {
        #expect(deviceTypeFromIdentifier("com.apple.CoreSimulator.SimDeviceType.iPad-Pro") == "iPad")
    }

    @Test func appleWatch() {
        #expect(deviceTypeFromIdentifier("com.apple.CoreSimulator.SimDeviceType.Apple-Watch-Series-10") == "Apple Watch")
    }

    @Test func appleTV() {
        #expect(deviceTypeFromIdentifier("com.apple.CoreSimulator.SimDeviceType.Apple-TV-4K") == "Apple TV")
    }

    @Test func appleVision() {
        #expect(deviceTypeFromIdentifier("com.apple.CoreSimulator.SimDeviceType.Apple-Vision-Pro") == "Apple Vision")
    }

    @Test func nilIdentifier() {
        #expect(deviceTypeFromIdentifier(nil) == "Unknown")
    }
}
