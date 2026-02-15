import Testing
import Foundation
@testable import MCPHelpers

@Suite("UDID Validation")
struct UDIDValidationTests {
    @Test func validUUID() throws {
        try validateUDID("A1B2C3D4-E5F6-7890-ABCD-EF1234567890")
    }

    @Test func allKeyword() throws {
        try validateUDID("all")
    }

    @Test func bootedKeyword() throws {
        try validateUDID("booted")
    }

    @Test func emptyString() {
        #expect(throws: (any Error).self) {
            try validateUDID("")
        }
    }

    @Test func malformedUUID() {
        #expect(throws: (any Error).self) {
            try validateUDID("not-a-uuid")
        }
    }

    @Test func wrongLength() {
        #expect(throws: (any Error).self) {
            try validateUDID("A1B2C3D4-E5F6-7890-ABCD")
        }
    }

    @Test func commandInjection() {
        #expect(throws: (any Error).self) {
            try validateUDID("; rm -rf /")
        }
    }

    @Test func pathTraversal() {
        #expect(throws: (any Error).self) {
            try validateUDID("../../../etc/passwd")
        }
    }
}

@Suite("Bundle ID Validation")
struct BundleIDValidationTests {
    @Test func validReverseDomain() throws {
        try validateBundleID("io.github.chmc.ListAll")
    }

    @Test func missingDot() {
        #expect(throws: (any Error).self) {
            try validateBundleID("noDotHere")
        }
    }

    @Test func containsSpaces() {
        #expect(throws: (any Error).self) {
            try validateBundleID("com.example. bad")
        }
    }

    @Test func emptyString() {
        #expect(throws: (any Error).self) {
            try validateBundleID("")
        }
    }
}

@Suite("App Name Validation")
struct AppNameValidationTests {
    @Test func simpleAppName() throws {
        try validateAppName("ListAll")
    }

    @Test func appNameWithSpaces() throws {
        try validateAppName("My App")
    }

    @Test func appNameWithHyphenUnderscore() throws {
        try validateAppName("App-Name_2")
    }

    @Test func shellMetacharacters() {
        #expect(throws: (any Error).self) {
            try validateAppName("; rm -rf /")
        }
    }

    @Test func commandSubstitution() {
        #expect(throws: (any Error).self) {
            try validateAppName("$(whoami)")
        }
    }

    @Test func emptyString() {
        #expect(throws: (any Error).self) {
            try validateAppName("")
        }
    }

    @Test func maxLengthPasses() throws {
        let name = String(repeating: "A", count: 255)
        try validateAppName(name)
    }

    @Test func overMaxLengthFails() {
        let name = String(repeating: "A", count: 256)
        #expect(throws: (any Error).self) {
            try validateAppName(name)
        }
    }
}
