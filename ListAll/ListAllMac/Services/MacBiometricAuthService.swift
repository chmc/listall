import Foundation
import LocalAuthentication
import Combine

// MARK: - macOS Biometric Authentication Service

/// Biometric authentication service for macOS, supporting Touch ID and password fallback.
/// This mirrors the iOS BiometricAuthService interface for consistent cross-platform behavior.
class MacBiometricAuthService: ObservableObject {
    static let shared = MacBiometricAuthService()

    @Published var isAuthenticated = false
    @Published var authenticationError: String?

    /// Detect if running in unit test environment to prevent authentication dialogs
    private var isRunningInTestEnvironment: Bool {
        ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil
    }

    private init() {}

    // MARK: - Biometric Availability

    /// Check if biometric authentication is available on the device
    /// On macOS, this will be Touch ID if available, otherwise none
    func biometricType() -> MacBiometricType {
        let context = LAContext()
        var error: NSError?

        guard context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) else {
            return .none
        }

        // On macOS, biometryType will be .touchID if Touch ID is available
        switch context.biometryType {
        case .touchID:
            return .touchID
        case .faceID:
            // Face ID is not available on macOS, but handle it for completeness
            return .none
        case .opticID:
            // Optic ID is not available on macOS
            return .none
        case .none:
            return .none
        @unknown default:
            return .none
        }
    }

    /// Check if any form of device authentication is available (Touch ID or password)
    func isDeviceAuthenticationAvailable() -> Bool {
        // CRITICAL: Skip LAContext access in test environment to prevent password dialogs
        // LAContext.canEvaluatePolicy(.deviceOwnerAuthentication) can trigger system authentication prompts
        if isRunningInTestEnvironment {
            return true // Assume available for tests
        }

        let context = LAContext()
        var error: NSError?
        return context.canEvaluatePolicy(.deviceOwnerAuthentication, error: &error)
    }

    /// Check if Touch ID is specifically available
    func isTouchIDAvailable() -> Bool {
        let context = LAContext()
        var error: NSError?
        return context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error)
            && context.biometryType == .touchID
    }

    // MARK: - Authentication

    /// Authenticate using Touch ID with password fallback
    /// - Parameter completion: Callback with success status and optional error message
    func authenticate(completion: @escaping (Bool, String?) -> Void) {
        // CRITICAL: Skip actual authentication in test environment to prevent password dialogs
        // This ensures unit tests don't trigger system prompts
        if isRunningInTestEnvironment {
            DispatchQueue.main.async {
                self.isAuthenticated = true
                self.authenticationError = nil
                completion(true, nil)
            }
            return
        }

        let context = LAContext()
        var error: NSError?

        // Check if device authentication is available (Touch ID OR password)
        guard context.canEvaluatePolicy(.deviceOwnerAuthentication, error: &error) else {
            let errorMessage = "Device authentication is not available. Please enable Touch ID or set up a password in System Preferences."
            DispatchQueue.main.async {
                self.authenticationError = errorMessage
                self.isAuthenticated = false
                completion(false, errorMessage)
            }
            return
        }

        let reason = "Unlock ListAll"

        // Perform authentication
        // macOS will try Touch ID first, then automatically show password entry if:
        // - Touch ID fails multiple times
        // - Touch ID is not available
        // - User explicitly requests password (via system UI)
        context.evaluatePolicy(.deviceOwnerAuthentication, localizedReason: reason) { [weak self] success, authError in
            DispatchQueue.main.async {
                if success {
                    self?.isAuthenticated = true
                    self?.authenticationError = nil
                    completion(true, nil)
                } else {
                    let errorMessage = self?.getAuthenticationErrorMessage(authError)
                    self?.authenticationError = errorMessage
                    self?.isAuthenticated = false
                    completion(false, errorMessage)
                }
            }
        }
    }

    /// Authenticate using async/await pattern
    /// - Returns: Tuple with success status and optional error message
    @available(macOS 10.15, *)
    func authenticate() async -> (success: Bool, error: String?) {
        await withCheckedContinuation { continuation in
            authenticate { success, error in
                continuation.resume(returning: (success, error))
            }
        }
    }

    /// Get user-friendly error message from LAError
    private func getAuthenticationErrorMessage(_ error: Error?) -> String {
        guard let error = error as? LAError else {
            return "Authentication failed. Please try again."
        }

        switch error.code {
        case .authenticationFailed:
            return "Authentication failed. Please try again."
        case .userCancel:
            return "You cancelled authentication. Please authenticate to unlock the app."
        case .userFallback:
            return "Password authentication required."
        case .systemCancel:
            return "Authentication was cancelled by the system. Please try again."
        case .passcodeNotSet:
            return "No password is set on this Mac. Please set up a password in System Preferences to use app security."
        case .biometryNotAvailable:
            return "Touch ID is not available. Please use your password."
        case .biometryNotEnrolled:
            return "No fingerprints are enrolled. Please set up Touch ID in System Preferences."
        case .biometryLockout:
            return "Too many failed attempts. Please unlock your Mac with your password first."
        case .appCancel:
            return "Authentication was cancelled."
        case .invalidContext:
            return "Authentication context is invalid. Please try again."
        case .notInteractive:
            return "Authentication is not available right now."
        case .biometryDisconnected:
            return "Touch ID sensor was disconnected."
        default:
            return "An unknown error occurred. Please try again."
        }
    }

    // MARK: - Session Management

    /// Reset authentication state (called when app enters background or becomes inactive)
    func resetAuthentication() {
        isAuthenticated = false
        authenticationError = nil
    }
}

// MARK: - macOS Biometric Type Enum

/// Biometric types available on macOS
enum MacBiometricType {
    case none
    case touchID

    var displayName: String {
        switch self {
        case .none:
            return "None"
        case .touchID:
            return "Touch ID"
        }
    }

    var iconName: String {
        switch self {
        case .none:
            return "lock.fill"
        case .touchID:
            return "touchid"
        }
    }

    /// Whether this biometric type is available for authentication
    var isAvailable: Bool {
        switch self {
        case .none:
            return false
        case .touchID:
            return true
        }
    }
}
