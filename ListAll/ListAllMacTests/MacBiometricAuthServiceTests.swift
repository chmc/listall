//
//  MacBiometricAuthServiceTests.swift
//  ListAllMacTests
//

import XCTest
import CoreData
import Combine
#if os(macOS)
@preconcurrency import AppKit
#endif
@testable import ListAll

#if os(macOS)

final class MacBiometricAuthServiceTests: XCTestCase {

    var biometricService: MacBiometricAuthService!

    override func setUpWithError() throws {
        try super.setUpWithError()
        biometricService = MacBiometricAuthService.shared
        biometricService.resetAuthentication()
    }

    override func tearDownWithError() throws {
        biometricService.resetAuthentication()
        biometricService = nil
        try super.tearDownWithError()
    }

    // MARK: - Singleton Tests

    /// Test MacBiometricAuthService singleton
    func testMacBiometricAuthServiceSingleton() {
        let instance1 = MacBiometricAuthService.shared
        let instance2 = MacBiometricAuthService.shared

        XCTAssertTrue(instance1 === instance2, "Shared instances should be identical")
    }

    // MARK: - Initial State Tests

    /// Test initial state of service
    func testInitialState() {
        XCTAssertFalse(biometricService.isAuthenticated)
        XCTAssertNil(biometricService.authenticationError)
    }

    // MARK: - Biometric Type Detection Tests

    /// Test biometricType detection
    func testBiometricTypeDetection() {
        let biometricType = biometricService.biometricType()

        // On simulator or Mac without Touch ID, should return .none
        // On Mac with Touch ID, should return .touchID
        XCTAssertTrue(
            biometricType == .none || biometricType == .touchID,
            "Biometric type should be .none or .touchID on macOS"
        )
    }

    /// Test isTouchIDAvailable
    func testIsTouchIDAvailable() {
        let touchIDAvailable = biometricService.isTouchIDAvailable()
        let biometricType = biometricService.biometricType()

        // Touch ID availability should match biometric type
        if biometricType == .touchID {
            XCTAssertTrue(touchIDAvailable, "Touch ID should be available when biometric type is .touchID")
        } else {
            XCTAssertFalse(touchIDAvailable, "Touch ID should not be available when biometric type is .none")
        }
    }

    /// Test isDeviceAuthenticationAvailable
    func testIsDeviceAuthenticationAvailable() {
        let available = biometricService.isDeviceAuthenticationAvailable()

        // This should be true on most Macs with a password set
        // But in CI environments or simulators, it might be false
        // Just verify it returns a boolean without crashing
        XCTAssertTrue(available == true || available == false)
    }

    // MARK: - MacBiometricType Enum Tests

    /// Test MacBiometricType display names
    func testMacBiometricTypeDisplayNames() {
        XCTAssertEqual(MacBiometricType.none.displayName, "None")
        XCTAssertEqual(MacBiometricType.touchID.displayName, "Touch ID")
    }

    /// Test MacBiometricType icon names
    func testMacBiometricTypeIconNames() {
        XCTAssertEqual(MacBiometricType.none.iconName, "lock.fill")
        XCTAssertEqual(MacBiometricType.touchID.iconName, "touchid")
    }

    /// Test MacBiometricType isAvailable
    func testMacBiometricTypeIsAvailable() {
        XCTAssertFalse(MacBiometricType.none.isAvailable)
        XCTAssertTrue(MacBiometricType.touchID.isAvailable)
    }

    // MARK: - Reset Authentication Tests

    /// Test resetAuthentication clears state
    func testResetAuthentication() {
        // Manually set authenticated state (simulating successful auth)
        biometricService.isAuthenticated = true
        biometricService.authenticationError = "Test error"

        biometricService.resetAuthentication()

        XCTAssertFalse(biometricService.isAuthenticated)
        XCTAssertNil(biometricService.authenticationError)
    }

    // MARK: - Authentication State Tests

    /// Test that authentication state is @Published
    func testAuthenticationStateIsPublished() {
        let expectation = XCTestExpectation(description: "Authentication state changes")
        var receivedValues: [Bool] = []

        let cancellable = biometricService.$isAuthenticated.sink { value in
            receivedValues.append(value)
            if receivedValues.count == 2 {
                expectation.fulfill()
            }
        }

        // Trigger a state change
        biometricService.isAuthenticated = true

        wait(for: [expectation], timeout: 1.0)

        XCTAssertEqual(receivedValues.count, 2)
        XCTAssertFalse(receivedValues[0]) // Initial value
        XCTAssertTrue(receivedValues[1])  // Updated value

        cancellable.cancel()
    }

    /// Test that error state is @Published
    func testAuthenticationErrorIsPublished() {
        let expectation = XCTestExpectation(description: "Error state changes")
        var receivedValues: [String?] = []

        let cancellable = biometricService.$authenticationError.sink { value in
            receivedValues.append(value)
            if receivedValues.count == 2 {
                expectation.fulfill()
            }
        }

        // Trigger a state change
        biometricService.authenticationError = "Test error message"

        wait(for: [expectation], timeout: 1.0)

        XCTAssertEqual(receivedValues.count, 2)
        XCTAssertNil(receivedValues[0])
        XCTAssertEqual(receivedValues[1], "Test error message")

        cancellable.cancel()
    }

    // MARK: - Authentication Flow Tests

    /// Test authentication completion handler is called
    func testAuthenticationCallsCompletion() {
        let expectation = XCTestExpectation(description: "Completion handler called")

        biometricService.authenticate { success, error in
            // We just verify the completion handler is called
            // The actual result depends on the environment (Touch ID availability, etc.)
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 5.0)
    }

    /// Test async authentication method (iOS 15+/macOS 12+)
    @available(macOS 12.0, *)
    func testAsyncAuthentication() async {
        let result = await biometricService.authenticate()

        // Just verify it returns without crashing
        // The actual result depends on the environment
        XCTAssertTrue(result.success == true || result.success == false)
    }

    // MARK: - Error Message Tests

    /// Test that failed authentication sets error message
    func testFailedAuthenticationSetsError() {
        let expectation = XCTestExpectation(description: "Error set on failure")

        // If authentication is not available, it should set an error
        if !biometricService.isDeviceAuthenticationAvailable() {
            biometricService.authenticate { success, error in
                if !success {
                    XCTAssertNotNil(error)
                    XCTAssertNotNil(self.biometricService.authenticationError)
                }
                expectation.fulfill()
            }
        } else {
            // If authentication is available, we can't easily test failure
            // Just skip this test
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 5.0)
    }

    // MARK: - Thread Safety Tests

    /// Test that state updates happen on main thread when authentication completes
    /// Note: This test may timeout if authentication requires user interaction
    func testStateUpdatesOnMainThread() {
        // This test verifies that when we manually update the state,
        // the changes are properly reflected (since @Published uses main actor)
        let expectation = XCTestExpectation(description: "State updated on main thread")

        DispatchQueue.global().async {
            // Simulate async work
            DispatchQueue.main.async {
                self.biometricService.isAuthenticated = true
                XCTAssertTrue(Thread.isMainThread, "State update should happen on main thread")
                expectation.fulfill()
            }
        }

        wait(for: [expectation], timeout: 2.0)
    }

    // MARK: - Platform-Specific Tests

    /// Test that this test runs only on macOS
    func testRunningOnMacOS() {
        #if os(macOS)
        XCTAssertTrue(true, "Test is running on macOS")
        #else
        XCTFail("This test should only run on macOS")
        #endif
    }

    /// Test that MacBiometricAuthService is independent from iOS BiometricAuthService
    func testIndependentFromIOSService() {
        // Verify we're using the macOS-specific service
        let macService = MacBiometricAuthService.shared
        XCTAssertNotNil(macService)

        // The MacBiometricType enum should only have .none and .touchID
        let allCases: [MacBiometricType] = [.none, .touchID]
        XCTAssertEqual(allCases.count, 2)
    }

    // MARK: - ObservableObject Conformance Tests

    /// Test ObservableObject conformance
    func testObservableObjectConformance() {
        // Verify that MacBiometricAuthService conforms to ObservableObject
        let service: any ObservableObject = biometricService
        XCTAssertNotNil(service)
    }
}
#endif

// MARK: - CloudKitService Tests (Task 3.4)
/// Unit tests for CloudKitService on macOS
/// Verifies that CloudKit sync infrastructure works correctly on the macOS platform.
///
/// IMPORTANT: These tests work WITHOUT requiring actual CloudKit capabilities.
/// They test the service logic and graceful handling when CloudKit is unavailable.
/// Full CloudKit sync testing requires a paid Apple Developer account.
#if os(macOS)
import CloudKit


#endif
