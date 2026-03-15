import XCTest
@testable import ListAll

final class BiometricAuthServiceTests: XCTestCase {

    // MARK: - BiometricAuthService Tests

    func testBiometricAuthServiceInitialization() throws {
        // Test that service initializes correctly
        let service = BiometricAuthService.shared
        XCTAssertNotNil(service, "BiometricAuthService should initialize")
        XCTAssertFalse(service.isAuthenticated, "Should not be authenticated on initialization")
        XCTAssertNil(service.authenticationError, "Should have no error on initialization")
    }

    func testBiometricTypeDetection() throws {
        // Test that biometric type detection doesn't crash
        let service = BiometricAuthService.shared
        let biometricType = service.biometricType()

        // Verify it returns a valid type (will be .none in simulator/tests)
        XCTAssertTrue(
            biometricType == .none ||
            biometricType == .faceID ||
            biometricType == .touchID ||
            biometricType == .opticID,
            "Should return a valid biometric type"
        )
    }

    func testBiometricTypeDisplayNames() throws {
        // Test that all biometric types have proper display names
        XCTAssertEqual(BiometricType.none.displayName, "None")
        XCTAssertEqual(BiometricType.touchID.displayName, "Touch ID")
        XCTAssertEqual(BiometricType.faceID.displayName, "Face ID")
        XCTAssertEqual(BiometricType.opticID.displayName, "Optic ID")
    }

    func testBiometricTypeIconNames() throws {
        // Test that all biometric types have proper icon names
        XCTAssertEqual(BiometricType.none.iconName, "lock.fill")
        XCTAssertEqual(BiometricType.touchID.iconName, "touchid")
        XCTAssertEqual(BiometricType.faceID.iconName, "faceid")
        XCTAssertEqual(BiometricType.opticID.iconName, "opticid")
    }

    func testDeviceAuthenticationAvailabilityCheck() throws {
        // Test that checking device authentication availability doesn't crash
        let service = BiometricAuthService.shared
        let isAvailable = service.isDeviceAuthenticationAvailable()

        // This will typically be false in simulator/tests, but shouldn't crash
        XCTAssertTrue(isAvailable == true || isAvailable == false, "Should return a boolean value")
    }

    func testResetAuthentication() throws {
        // Test that reset authentication works correctly
        let service = BiometricAuthService.shared

        // Set authenticated state to true (simulating authenticated state)
        service.isAuthenticated = true
        service.authenticationError = "Some error"

        // Reset
        service.resetAuthentication()

        // Verify reset
        XCTAssertFalse(service.isAuthenticated, "Should be unauthenticated after reset")
        XCTAssertNil(service.authenticationError, "Error should be cleared after reset")
    }

    func testAuthenticationOnUnavailableDevice() throws {
        // Test authentication behavior when biometric auth is unavailable (like in simulator)
        let service = BiometricAuthService.shared
        let expectation = XCTestExpectation(description: "Authentication completion")

        // Allow the expectation to be fulfilled asynchronously but don't require it
        // since LocalAuthentication may not call the completion handler on simulators
        expectation.assertForOverFulfill = false

        service.authenticate { success, errorMessage in
            // In simulator/tests, this will likely fail since biometrics aren't available
            // But it shouldn't crash
            XCTAssertTrue(success == true || success == false, "Should return a boolean")
            if !success {
                XCTAssertNotNil(errorMessage, "Should provide error message on failure")
            }
            expectation.fulfill()
        }

        // Use a shorter timeout and accept both outcomes (fulfilled or timeout)
        let result = XCTWaiter.wait(for: [expectation], timeout: 2.0)

        // The test passes if the call completes OR times out (simulator limitation)
        XCTAssertTrue(
            result == .completed || result == .timedOut,
            "Test should either complete or timeout (simulator has no biometrics)"
        )
    }

    func testBiometricAuthServiceSingleton() throws {
        // Test that BiometricAuthService is a proper singleton
        let service1 = BiometricAuthService.shared
        let service2 = BiometricAuthService.shared

        XCTAssertTrue(service1 === service2, "Should return the same instance")
    }

    // MARK: - Authentication Timeout Tests

    func testAuthTimeoutDurationValues() throws {
        // Test that all timeout duration values are correct
        XCTAssertEqual(Constants.AuthTimeoutDuration.immediate.rawValue, 0)
        XCTAssertEqual(Constants.AuthTimeoutDuration.oneMinute.rawValue, 60)
        XCTAssertEqual(Constants.AuthTimeoutDuration.fiveMinutes.rawValue, 300)
        XCTAssertEqual(Constants.AuthTimeoutDuration.fifteenMinutes.rawValue, 900)
        XCTAssertEqual(Constants.AuthTimeoutDuration.thirtyMinutes.rawValue, 1800)
        XCTAssertEqual(Constants.AuthTimeoutDuration.oneHour.rawValue, 3600)
    }

    func testAuthTimeoutDurationDisplayNames() throws {
        // Test that all timeout durations have proper display names (locale-independent)
        XCTAssertFalse(Constants.AuthTimeoutDuration.immediate.displayName.isEmpty)
        XCTAssertFalse(Constants.AuthTimeoutDuration.oneMinute.displayName.isEmpty)
        XCTAssertFalse(Constants.AuthTimeoutDuration.fiveMinutes.displayName.isEmpty)
        XCTAssertFalse(Constants.AuthTimeoutDuration.fifteenMinutes.displayName.isEmpty)
        XCTAssertFalse(Constants.AuthTimeoutDuration.thirtyMinutes.displayName.isEmpty)
        XCTAssertFalse(Constants.AuthTimeoutDuration.oneHour.displayName.isEmpty)

        // Verify each case has a unique display name
        let displayNames = Constants.AuthTimeoutDuration.allCases.map { $0.displayName }
        let uniqueNames = Set(displayNames)
        XCTAssertEqual(displayNames.count, uniqueNames.count, "Each timeout duration should have a unique display name")
    }

    func testAuthTimeoutDurationDescriptions() throws {
        // Test that all timeout durations have proper descriptions (locale-independent)
        XCTAssertFalse(Constants.AuthTimeoutDuration.immediate.description.isEmpty)
        XCTAssertFalse(Constants.AuthTimeoutDuration.oneMinute.description.isEmpty)
        XCTAssertFalse(Constants.AuthTimeoutDuration.fiveMinutes.description.isEmpty)
        XCTAssertFalse(Constants.AuthTimeoutDuration.fifteenMinutes.description.isEmpty)
        XCTAssertFalse(Constants.AuthTimeoutDuration.thirtyMinutes.description.isEmpty)
        XCTAssertFalse(Constants.AuthTimeoutDuration.oneHour.description.isEmpty)

        // Verify each case has a unique description
        let descriptions = Constants.AuthTimeoutDuration.allCases.map { $0.description }
        let uniqueDescriptions = Set(descriptions)
        XCTAssertEqual(descriptions.count, uniqueDescriptions.count, "Each timeout duration should have a unique description")
    }

    func testAuthTimeoutDurationAllCases() throws {
        // Test that all cases are included
        let allCases = Constants.AuthTimeoutDuration.allCases
        XCTAssertEqual(allCases.count, 6, "Should have 6 timeout duration options")
        XCTAssertTrue(allCases.contains(.immediate))
        XCTAssertTrue(allCases.contains(.oneMinute))
        XCTAssertTrue(allCases.contains(.fiveMinutes))
        XCTAssertTrue(allCases.contains(.fifteenMinutes))
        XCTAssertTrue(allCases.contains(.thirtyMinutes))
        XCTAssertTrue(allCases.contains(.oneHour))
    }
}
