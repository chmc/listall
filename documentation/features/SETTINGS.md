# Settings & Preferences Features

[< Back to Summary](./SUMMARY.md)

## Status: iOS 11/11 | macOS 11/11

---

## Feature Matrix

| Feature | iOS | macOS | Implementation |
|---------|:---:|:-----:|----------------|
| App Language Selection | ✅ | ✅ | Picker with restart alert |
| Default Sort Order | ✅ | ✅ | Shared Repository |
| Add Button Position | ✅ | N/A | iOS only (mobile pattern) |
| Haptic Feedback Toggle | ✅ | N/A | iOS only (no haptics on Mac) |
| Feature Tips Tracking | ✅ | ✅ | Platform-Specific |
| Reset Tips Button | ✅ | ✅ | Platform-Specific |
| Biometric Auth Toggle | ✅ | ✅ | Platform-Specific |
| Auth Timeout Duration | ✅ | ✅ | 5 duration choices |
| Export Data Button | ✅ | ✅ | Platform UI |
| Import Data Button | ✅ | ✅ | Platform UI |
| App Version Display | ✅ | ✅ | Platform UI |

---

## Gaps (macOS)

*No gaps - full feature parity achieved.*

---

## iOS-Specific Settings
- Add button position (left/right)
- Haptic feedback toggle
- Full biometric options (Face ID, Touch ID, Passcode)
- Auth timeout selection (immediate to 1 hour)
- Feature tips management
- Language picker with restart alert

## macOS-Specific Settings
- Preferences window (Cmd+,)
- Tab-based layout (General, Security, Sync, Data, About)
- Language picker with restart alert
- Touch ID support with timeout options
- Website link

---

## Implementation Files

**Shared**:
- `Services/DataRepository.swift` - Preference storage

**iOS**:
- `Views/SettingsView.swift`
- `Services/BiometricAuthService.swift`

**macOS**:
- `ListAllMac/Views/MacSettingsView.swift`
- `ListAllMac/Services/MacBiometricAuthService.swift`
