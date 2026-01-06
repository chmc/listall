# Settings & Preferences Features

[< Back to Summary](./SUMMARY.md)

## Status: iOS 11/11 | macOS 5/11

---

## Feature Matrix

| Feature | iOS | macOS | Implementation |
|---------|:---:|:-----:|----------------|
| App Language Selection | ✅ | ❌ | iOS only |
| Default Sort Order | ✅ | ✅ | Shared Repository |
| Add Button Position | ✅ | N/A | iOS only (mobile pattern) |
| Haptic Feedback Toggle | ✅ | N/A | iOS only (no haptics on Mac) |
| Feature Tips Tracking | ✅ | ❌ | iOS only |
| Reset Tips Button | ✅ | ❌ | iOS only |
| Biometric Auth Toggle | ✅ | ⚠️ | Platform-Specific |
| Auth Timeout Duration | ✅ | ❌ | iOS only |
| Export Data Button | ✅ | ✅ | Platform UI |
| Import Data Button | ✅ | ✅ | Platform UI |
| App Version Display | ✅ | ✅ | Platform UI |

---

## Gaps (macOS)

| Feature | Priority | iOS Implementation | Notes |
|---------|:--------:|-------------------|-------|
| Language Selection | MEDIUM | Picker with restart alert | Could add to Preferences |
| Auth Timeout Options | MEDIUM | 5 duration choices | Could add to Preferences |
| Feature Tips System | MEDIUM | TooltipOverlay with tracking | Nice to have |
| Biometric Auth (full) | MEDIUM | Face ID, Touch ID, Passcode | macOS only has Touch ID |

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
- Tab-based layout (General, Data, About)
- Touch ID support only
- Website link

---

## Bug

| Issue | Location | Fix |
|-------|----------|-----|
| Remove "Sync" tab | MacSettingsView.swift | Delete SyncSettingsTab |

The "Enable iCloud Sync" toggle is misleading - sync is mandatory.

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
