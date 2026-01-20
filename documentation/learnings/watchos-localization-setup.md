---
title: watchOS Localization via App Groups
date: 2025-01-01
severity: MEDIUM
category: watchos
tags: [localization, app-groups, userdefaults, language-sync]
symptoms: [watchOS app displays English when iOS app is set to Finnish, language preference not syncing]
root_cause: LocalizationManager.swift not added to watchOS target membership
solution: Add LocalizationManager.swift to watchOS target in Xcode File Inspector
files_affected: [ListAll/Utils/LocalizationManager.swift, ListAllWatch/ListAllWatchApp.swift]
related: [macos-settings-window-resizable.md, macos-app-groups-test-dialogs.md]
---

## Context

watchOS app needs shared language settings from iOS app via App Groups container.

## Architecture

```
iOS App                          watchOS App
   |                                  |
   v                                  v
UserDefaults (group.io.github.chmc.ListAll)
   |                                  |
   +-- Key: "AppLanguage"             |
   +-- Value: "fi" or "en"  ----------+
                                      |
                                      v
                           LocalizationManager reads
                           AppleLanguages key applied
```

## Fix Steps

1. **Xcode Target Membership**
   - Select `LocalizationManager.swift` in Project Navigator
   - File Inspector (Opt+Cmd+1) > Target Membership
   - Check "ListAllWatch Watch App"

2. **Verify Build**
   ```bash
   xcodebuild -scheme "ListAllWatch Watch App" -destination 'generic/platform=watchOS' build
   ```

3. **Test Sync**
   - Change iOS language to Finnish
   - Force quit watchOS app
   - Relaunch - UI should be Finnish

## Troubleshooting

| Issue | Check |
|-------|-------|
| Still English | App Groups entitlement has `group.io.github.chmc.ListAll` |
| Not syncing | Force quit both apps, relaunch |
| Debug | Add `print("Current: \(currentLanguage)")` in LocalizationManager.init() |

## Key Points

- Language changes require watchOS app restart
- No separate watchOS language selector needed
- Both apps share `Localizable.xcstrings`
