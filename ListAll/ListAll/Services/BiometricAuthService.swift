import Foundation
import LocalAuthentication

// MARK: - Biometric Authentication Service
class BiometricAuthService: ObservableObject {
    static let shared = BiometricAuthService()
    
    @Published var isAuthenticated = false
    @Published var authenticationError: String?
    
    private init() {}
    
    // MARK: - Biometric Availability
    
    /// Check if biometric authentication is available on the device
    func biometricType() -> BiometricType {
        let context = LAContext()
        var error: NSError?
        
        guard context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) else {
            return .none
        }
        
        switch context.biometryType {
        case .faceID:
            return .faceID
        case .touchID:
            return .touchID
        case .opticID:
            return .opticID
        case .none:
            return .none
        @unknown default:
            return .none
        }
    }
    
    /// Check if any form of device authentication is available (biometric or passcode)
    func isDeviceAuthenticationAvailable() -> Bool {
        let context = LAContext()
        var error: NSError?
        return context.canEvaluatePolicy(.deviceOwnerAuthentication, error: &error)
    }
    
    // MARK: - Authentication
    
    /// Authenticate using biometric authentication (Face ID / Touch ID) with passcode fallback
    /// - Parameter completion: Callback with success status and optional error message
    func authenticate(completion: @escaping (Bool, String?) -> Void) {
        let context = LAContext()
        var error: NSError?
        
        // Note: .deviceOwnerAuthentication automatically falls back to passcode if biometrics fail
        // No need to set localizedFallbackTitle - iOS handles the transition automatically
        
        // Check if device authentication is available (biometrics OR passcode)
        guard context.canEvaluatePolicy(.deviceOwnerAuthentication, error: &error) else {
            let errorMessage = "Device authentication is not available. Please enable Face ID, Touch ID, or passcode in Settings."
            DispatchQueue.main.async {
                self.authenticationError = errorMessage
                self.isAuthenticated = false
                completion(false, errorMessage)
            }
            return
        }
        
        // Determine the biometric type for the prompt
        let biometricType = self.biometricType()
        let reason: String
        
        if biometricType == .faceID {
            reason = "Unlock ListAll"
        } else if biometricType == .touchID {
            reason = "Unlock ListAll"
        } else {
            reason = "Unlock ListAll"
        }
        
        // Perform authentication
        // iOS will try biometrics first, then automatically show passcode entry if:
        // - Biometrics fail multiple times
        // - Biometrics are not available
        // - User explicitly requests passcode (via system UI)
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
            return "Passcode authentication required."
        case .systemCancel:
            return "Authentication was cancelled by the system. Please try again."
        case .passcodeNotSet:
            return "No passcode is set on this device. Please set up a passcode in Settings to use app security."
        case .biometryNotAvailable:
            return "Biometric authentication is not available. Please use your passcode."
        case .biometryNotEnrolled:
            return "No biometric data is enrolled. Please set up Face ID or Touch ID in Settings."
        case .biometryLockout:
            return "Too many failed attempts. Please unlock your device with your passcode first."
        case .appCancel:
            return "Authentication was cancelled."
        case .invalidContext:
            return "Authentication context is invalid. Please try again."
        case .notInteractive:
            return "Authentication is not available right now."
        @unknown default:
            return "An unknown error occurred. Please try again."
        }
    }
    
    // MARK: - Session Management
    
    /// Reset authentication state (called when app enters background)
    func resetAuthentication() {
        isAuthenticated = false
        authenticationError = nil
    }
}

// MARK: - Biometric Type Enum

enum BiometricType {
    case none
    case touchID
    case faceID
    case opticID
    
    var displayName: String {
        switch self {
        case .none:
            return "None"
        case .touchID:
            return "Touch ID"
        case .faceID:
            return "Face ID"
        case .opticID:
            return "Optic ID"
        }
    }
    
    var iconName: String {
        switch self {
        case .none:
            return "lock.fill"
        case .touchID:
            return "touchid"
        case .faceID:
            return "faceid"
        case .opticID:
            return "opticid"
        }
    }
}

