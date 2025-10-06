import SwiftUI

struct ContentView: View {
    @AppStorage(Constants.UserDefaultsKeys.requiresBiometricAuth) private var requiresBiometricAuth = false
    @AppStorage(Constants.UserDefaultsKeys.authTimeoutDuration) private var authTimeoutDurationRaw: Int = Constants.AuthTimeoutDuration.immediate.rawValue
    @StateObject private var biometricService = BiometricAuthService.shared
    @State private var isAuthenticating = false
    @State private var showAuthError = false
    @State private var authErrorMessage = ""
    @State private var backgroundTime: Date?
    @Environment(\.scenePhase) private var scenePhase
    
    private var authTimeoutDuration: Constants.AuthTimeoutDuration {
        Constants.AuthTimeoutDuration(rawValue: authTimeoutDurationRaw) ?? .immediate
    }
    
    var body: some View {
        ZStack {
            if requiresBiometricAuth && !biometricService.isAuthenticated {
                // Authentication screen
                AuthenticationView(
                    isAuthenticating: $isAuthenticating,
                    showAuthError: $showAuthError,
                    authErrorMessage: $authErrorMessage,
                    onAuthenticate: authenticate
                )
            } else {
                // Main app content
                MainView()
            }
        }
        .onAppear {
            // Authenticate on app launch if biometric auth is enabled
            if requiresBiometricAuth && !biometricService.isAuthenticated {
                authenticate()
            }
        }
        .onChange(of: scenePhase) { newPhase in
            // Store timestamp when app enters background (for timeout calculation)
            if newPhase == .background && requiresBiometricAuth {
                backgroundTime = Date()
                // Don't reset authentication here - only reset if timeout has elapsed
            }
            // Check if re-authentication is needed when app becomes active
            if newPhase == .active && requiresBiometricAuth {
                if shouldRequireAuthentication() {
                    // Timeout has elapsed or immediate mode - reset and require auth
                    biometricService.resetAuthentication()
                    // Only authenticate if not already authenticated and not currently authenticating
                    if !biometricService.isAuthenticated && !isAuthenticating {
                        authenticate()
                    }
                }
                // else: timeout hasn't elapsed, stay authenticated
            }
        }
        .alert("Authentication Failed", isPresented: $showAuthError) {
            Button("Try Again") {
                authenticate()
            }
            Button("Cancel", role: .cancel) {
                showAuthError = false
            }
        } message: {
            Text(authErrorMessage)
        }
    }
    
    private func authenticate() {
        // Prevent multiple simultaneous authentication attempts
        guard !isAuthenticating else { return }
        
        isAuthenticating = true
        biometricService.authenticate { success, errorMessage in
            isAuthenticating = false
            if success {
                // Clear background time after successful authentication to prevent re-triggering
                self.backgroundTime = nil
            } else {
                authErrorMessage = errorMessage ?? "Authentication failed"
                showAuthError = true
            }
        }
    }
    
    /// Determines if authentication is required based on timeout setting
    private func shouldRequireAuthentication() -> Bool {
        // Check if we have a background timestamp
        guard let bgTime = backgroundTime else {
            // No background time recorded - already authenticated since last background
            // This prevents infinite loops in immediate mode after successful auth
            return false
        }
        
        // If immediate timeout, require authentication (we know backgroundTime exists)
        if authTimeoutDuration == .immediate {
            return true
        }
        
        // Check if enough time has passed since background for timed modes
        let elapsedTime = Date().timeIntervalSince(bgTime)
        return elapsedTime >= TimeInterval(authTimeoutDuration.rawValue)
    }
}

// MARK: - Authentication View

struct AuthenticationView: View {
    @Binding var isAuthenticating: Bool
    @Binding var showAuthError: Bool
    @Binding var authErrorMessage: String
    var onAuthenticate: () -> Void
    
    @StateObject private var biometricService = BiometricAuthService.shared
    
    private var biometricType: BiometricType {
        biometricService.biometricType()
    }
    
    var body: some View {
        VStack(spacing: 32) {
            Spacer()
            
            // App Icon/Logo
            Image(systemName: "lock.shield.fill")
                .font(.system(size: 80))
                .foregroundColor(.blue)
            
            VStack(spacing: 12) {
                Text("ListAll")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                
                Text("Locked")
                    .font(.title3)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            // Authentication button
            if !isAuthenticating {
                Button(action: onAuthenticate) {
                    HStack {
                        Image(systemName: biometricType.iconName)
                            .font(.title3)
                        if biometricType != .none {
                            Text("Unlock with \(biometricType.displayName)")
                                .font(.headline)
                        } else {
                            Text("Unlock with Passcode")
                                .font(.headline)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(12)
                }
                .padding(.horizontal, 40)
            } else {
                VStack(spacing: 12) {
                    ProgressView()
                        .scaleEffect(1.5)
                    Text("Authenticating...")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemGroupedBackground))
    }
}

#Preview {
    ContentView()
}
