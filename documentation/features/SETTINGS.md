# Settings & Preferences Features

[< Back to Summary](./SUMMARY.md)

## Status: iOS 12/13 | iPad 11/14 | macOS 10/11 | watchOS N/A

*Count = ✅ / applicable rows (N/A excluded). The watch app has no settings screen.*

---

## Feature Matrix

| Feature | iOS | iPad | macOS | watchOS | Implementation |
|---------|:---:|:----:|:-----:|:-------:|----------------|
| App Language Selection | ✅ | ✅ | ✅ | N/A | Picker with restart alert; watch reads the language from the App Group (`ListAllWatchApp.swift:53-59`) |
| Default Sort Order | ⚠️ | ⚠️ | ⚠️ | N/A | Picker stores `defaultListSortOrder` (`SettingsView.swift:13`, `119-125`; `MacSettingsView.swift:65`, `102`) but no code reads the value |
| Add Button Position | ✅ | ⚠️ | N/A | N/A | Picker shown on iPad too (`SettingsView.swift:112`), but the floating add button is hidden in regular width (`ListView.swift:200`) |
| Haptic Feedback Toggle | ✅ | ⚠️ | N/A | N/A | Toggle `SettingsView.swift:127`; shown on iPad, which has no haptic hardware (not code-verifiable) |
| Feature Tips Tracking | ✅ | ✅ | ✅ | N/A | Platform-Specific |
| View All Feature Tips | ✅ | ✅ | ✅ | N/A | iOS `SettingsView.swift:156`, `1069`; macOS `MacSettingsView.swift:137` |
| Feature Tips in Finnish | ✅ | ✅ | ✅ | N/A | `Localizable.xcstrings` (e.g. `:6373` iOS swipe tip, `:1190` macOS sidebar tip) |
| Reset Tips Button | ✅ | ✅ | ✅ | N/A | Platform-Specific |
| Biometric Auth Toggle | ✅ | ✅ | ✅ | N/A | Platform-Specific |
| Auth Timeout Duration | ✅ | ✅ | ✅ | N/A | 5 duration choices |
| Export Data Button | ✅ | ✅ | ✅ | N/A | Platform UI |
| Import Data Button | ✅ | ✅ | ✅ | N/A | Platform UI |
| About: Version, Creator, Website, Source Code | ✅ | ✅ | ✅ | N/A | `Constants.Creator` (`Constants.swift:13-15`); iOS `SettingsView.swift:248-278`; macOS `MacSettingsView.swift:442-456` |
| Settings in Detail Column | N/A | ✅ | N/A | N/A | Sidebar Settings row → detail column (`MainView.swift:242-249`, `271-272`); `SettingsView.swift:41-44` |

---

## Gaps

- All platforms: Default Sort Order is stored but has no effect (no reader of `defaultListSortOrder`).
- iPad: Add Button Position setting has no effect (iPad uses a toolbar button).

---

## iOS-Specific Settings
- Add button position (left/right)
- Haptic feedback toggle
- Full biometric options (Face ID, Touch ID, Passcode)
- Auth timeout selection (immediate to 1 hour)
- Feature tips management
- Language picker with restart alert

## iPad-Specific Settings
- Settings open in the NavigationSplitView detail column instead of a sheet

## macOS-Specific Settings
- Preferences window (Cmd+,)
- Tab-based layout (General, Security, Sync, Data, About)
- Language picker with restart alert
- Touch ID support with timeout options
- Website and source code links

---

## Implementation Files

**Shared**:
- `Services/DataRepository.swift` - Preference storage
- `Utils/Constants.swift` - Creator info

**iOS / iPad**:
- `Views/SettingsView.swift`
- `Services/BiometricAuthService.swift`

**macOS**:
- `ListAllMac/Views/MacSettingsView.swift`
- `ListAllMac/Services/MacBiometricAuthService.swift`
- `ListAllMac/Views/Components/MacAllFeatureTipsView.swift`
