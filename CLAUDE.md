# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

ListAll is an iOS and watchOS list management app built with SwiftUI and CoreData. The app supports:
- iOS app (main target)
- watchOS companion app
- iCloud sync via CloudKit
- WatchConnectivity for iPhone-Watch sync
- Multi-locale support (en-US, fi)
- App Store screenshots via automated CI/CD

## Build & Test Commands

### Building
```bash
# Build iOS app
cd ListAll
xcodebuild clean build \
  -project ListAll.xcodeproj \
  -scheme ListAll \
  -destination 'platform=iOS Simulator,name=iPhone 16 Pro,OS=latest'

# Build watchOS app
cd ListAll
xcodebuild clean build \
  -project ListAll.xcodeproj \
  -scheme "ListAllWatch Watch App" \
  -destination 'platform=watchOS Simulator,name=Apple Watch Series 10 (46mm),OS=latest'
```

### Testing
```bash
# Run iOS tests
cd ListAll
xcodebuild test \
  -project ListAll.xcodeproj \
  -scheme ListAll \
  -destination 'platform=iOS Simulator,name=iPhone 16 Pro,OS=latest'

# Run watchOS tests
cd ListAll
xcodebuild test \
  -project ListAll.xcodeproj \
  -scheme "ListAllWatch Watch App" \
  -destination 'platform=watchOS Simulator,name=Apple Watch Series 10 (46mm),OS=latest'

# Run tests via Fastlane (mirrors CI)
bundle exec fastlane test
bundle exec fastlane test_scan
```

### Version Management
```bash
# Show current version
bundle exec fastlane show_version

# Set version manually
bundle exec fastlane set_version version:1.2.0

# Validate all targets have matching versions
bundle exec fastlane validate_versions
```

### Release & Distribution
```bash
# Build and upload to TestFlight (requires ASC API key in .env)
bundle exec fastlane beta                    # Patch bump (1.1.0 → 1.1.1)
bundle exec fastlane beta bump_type:minor   # Minor bump (1.1.0 → 1.2.0)
bundle exec fastlane beta bump_type:major   # Major bump (1.1.0 → 2.0.0)

# Deliver metadata to App Store
bundle exec fastlane release

# Verify App Store Connect authentication
bundle exec fastlane asc_dry_run
```

### Screenshots
```bash
# Generate iPhone screenshots (both locales)
bundle exec fastlane ios screenshots_iphone_locale locale:en-US
bundle exec fastlane ios screenshots_iphone_locale locale:fi

# Generate iPad screenshots (both locales)
bundle exec fastlane ios screenshots_ipad_locale locale:en-US
bundle exec fastlane ios screenshots_ipad_locale locale:fi

# Generate Watch screenshots (both locales)
bundle exec fastlane ios watch_screenshots

# Validate screenshot dimensions
.github/scripts/validate-screenshots.sh fastlane/screenshots_compat iphone
.github/scripts/validate-screenshots.sh fastlane/screenshots_compat ipad
.github/scripts/validate-screenshots.sh fastlane/screenshots/watch_normalized watch
```

## Architecture

### Core Data Layers

1. **DataManager** (`Services/DataManager.swift`)
   - Central data management singleton
   - In-memory state management
   - Coordinated with CoreData persistence

2. **CoreDataManager** (`Services/CoreDataManager.swift`)
   - Handles CoreData stack initialization
   - Manages view context and background contexts
   - Implements CloudKit sync via NSPersistentCloudKitContainer

3. **DataRepository** (`Services/DataRepository.swift`)
   - High-level abstraction over DataManager
   - Coordinates WatchConnectivity sync
   - Used by ViewModels for CRUD operations

### Data Model

CoreData entities (`.xcdatamodeld`):
- **ListEntity**: Lists with name, creation date, modification date, archive status
- **ItemEntity**: List items with text, checked status, timestamps
- **ItemImageEntity**: Attached images for items (compressed, stored as binary data)
- **UserDataEntity**: App settings and preferences

Swift model structs (`Models/`):
- `List`, `Item`, `ItemImage`, `UserData` - Codable structs for in-memory representation
- Extensions in `Models/CoreData/*+Extensions.swift` convert between Core Data entities and Swift structs

### Sync Architecture

**iPhone ↔ iCloud (CloudKit)**
- Automatic via `NSPersistentCloudKitContainer`
- Configured in CoreDataManager with CloudKit container

**iPhone ↔ Apple Watch**
- `WatchConnectivityService` handles bidirectional sync
- Uses `WCSession` for message passing
- Sync triggered on data changes and app activation
- Models in `Shared/Models/SyncModels.swift`

**Conflict Resolution**
- iCloud conflicts handled via `NSMergePolicy.mergeByPropertyObjectTrump`
- Watch sync uses "last write wins" strategy via modification timestamps

### UI Test Data Provisioning

UI tests use deterministic test data for screenshots:

1. **UITestDataService** (in Services)
   - `generateTestData()` creates consistent test lists/items
   - Detects UI test mode via `ProcessInfo.processInfo.arguments.contains("UITEST_MODE")`

2. **ListAllApp.swift** setup flow
   - Clears all existing data when `UITEST_MODE` detected
   - Populates deterministic test data unless `SKIP_TEST_DATA` argument provided
   - Disables tooltips when `DISABLE_TOOLTIPS` argument provided
   - Forces light mode when `FORCE_LIGHT_MODE` argument provided

3. **UI Test Targets**
   - `ListAllUITests.swift` - Full UI test suite
   - `ListAllUITests_Simple.swift` - Simplified screenshot tests (used by CI)
   - `ListAllWatch Watch AppUITests` - watchOS UI tests

## CI/CD Pipeline

### GitHub Actions Workflows

**`.github/workflows/ci.yml`** - Continuous Integration
- Runs on push to `main` and PRs
- Builds iOS + watchOS apps
- Runs all unit tests
- Uses Xcode 16.1 on macOS 14

**`.github/workflows/prepare-appstore.yml`** - App Store Screenshot Generation
- Manual trigger with version input
- Per-locale parallelization (5 parallel jobs: iPhone×2, iPad×2, Watch)
- Generates screenshots for iPhone 16 Pro Max (1290x2796), iPad 13" (2064x2752), Watch Series 10 (396x484)
- Validates dimensions via `.github/scripts/validate-screenshots.sh`
- Merges artifacts and uploads to App Store Connect
- Runtime: ~45-60 minutes (was 90+ minutes before parallelization)

**`.github/workflows/release.yml`** - TestFlight Release
- Manual or tag-triggered release
- Auto-increments version (patch/minor/major)
- Builds IPA and uploads to TestFlight
- Commits version changes and creates git tag

### Screenshot Pipeline Architecture

1. **Device-specific screenshot generation** (3 parallel jobs)
   - iPhone: Uses `screenshots_iphone_locale` lane per locale
   - iPad: Uses `screenshots_ipad_locale` lane per locale
   - Watch: Uses `watch_screenshots` lane (both locales in one job)

2. **Screenshot normalization** (`fastlane/lib/screenshot_helper.rb`)
   - Raw screenshots captured at native simulator resolution
   - Normalized to exact App Store Connect requirements via ImageMagick
   - Output: `screenshots_compat/` (iPhone/iPad), `screenshots/watch_normalized/` (Watch)

3. **Artifact merging** (merge-screenshots job)
   - Downloads per-locale artifacts
   - Combines into unified screenshot bundle
   - Validates counts and dimensions

4. **Upload** (upload-to-appstore job)
   - Uses Fastlane Deliver to upload metadata + screenshots
   - Requires ASC API credentials (stored in GitHub Secrets)

### Pre-flight Validation

`.github/scripts/preflight-check.sh` validates before expensive CI runs:
- Xcode 16.1 availability
- Required simulators (iPhone 16 Pro Max, iPad Pro 13", Watch Series 10)
- ImageMagick installation (for screenshot normalization)
- Ruby/Bundler availability
- Disk space (15GB+ recommended)
- Network connectivity to App Store Connect
- Required files (Fastfile, Snapfile, Gemfile)

## Version Management System

ListAll uses semantic versioning (MAJOR.MINOR.PATCH) with centralized version tracking:

- **Source of truth**: `.version` file at repository root
- **Xcode integration**: `MARKETING_VERSION` build setting synchronized across all targets
- **Build numbers**: Auto-incremented (CI uses GitHub run number, local increments by 1)

See `documentation/version_management.md` for complete documentation.

## Local Development Setup

1. **Install dependencies**
   ```bash
   bundle install
   ```

2. **App Store Connect credentials (optional, for TestFlight)**
   - Copy `.env.template` to `.env`
   - Add ASC API key credentials (Key ID, Issuer ID, Base64-encoded key)
   - Test authentication: `bundle exec fastlane asc_dry_run`

3. **Open project**
   - Open `ListAll/ListAll.xcodeproj` in Xcode
   - Select desired target (ListAll or ListAllWatch Watch App)
   - Build and run

## Important Behavioral Rules

From `.cursorrules`:

1. **Code must always build successfully** - Run appropriate build command after ANY code changes
2. **All tests must pass** - Tasks are not complete until 100% pass rate verified
3. **Document changes** - Update `ai_changelog.md` after completing significant work

## Screenshot Dimension Requirements

Apple App Store Connect (as of 2024):
- **iPhone 6.7"**: 1290×2796 (iPhone 14/15/16 Pro Max)
- **iPad 13"**: 2064×2752 (iPad Pro 13" M4) - NEW 2024 standard
- **iPad 12.9"**: 2048×2732 (legacy, still supported)
- **Watch 45mm**: 396×484 (Series 7+, Ultra)

CRITICAL: Use RAW NORMALIZED screenshots for delivery, NOT framed screenshots. Framed screenshots include device bezels which change dimensions and are rejected by App Store Connect.

## Key Technologies

- **SwiftUI** - UI framework for iOS and watchOS
- **CoreData** - Local persistence layer
- **CloudKit** - iCloud sync (via NSPersistentCloudKitContainer)
- **WatchConnectivity** - iPhone-Watch communication
- **Fastlane** - Build automation, screenshot generation, TestFlight upload
- **ImageMagick** - Screenshot dimension normalization
- **XCTest / XCUITest** - Testing frameworks

## Localization

Supported locales:
- `en-US` (English)
- `fi` (Finnish)

Localization files:
- `ListAll/ListAll/Localizable.xcstrings` - iOS app strings
- `ListAll/ListAllWatch Watch App/Utils/LocalizedText.swift` - watchOS localized strings
- Watch localization documented in `WATCHOS_LOCALIZATION_HOW_IT_WORKS.md` and `WATCHOS_LOCALIZATION_SETUP.md`

## Project Structure

```
ListAll/
├── ListAll/                    # iOS app target
│   ├── Models/                 # Data models (List, Item, etc.)
│   │   └── CoreData/           # Entity extensions
│   ├── Views/                  # SwiftUI views
│   │   └── Components/         # Reusable UI components
│   ├── ViewModels/             # View models (MVVM)
│   ├── Services/               # Business logic & data services
│   └── Utils/                  # Helpers, extensions, themes
├── ListAllWatch Watch App/     # watchOS app target
│   ├── Views/                  # Watch-specific views
│   ├── ViewModels/             # Watch view models
│   └── Utils/                  # Watch utilities
├── ListAllTests/               # Unit tests
├── ListAllUITests/             # UI tests (screenshots)
├── ListAllWatch Watch AppTests/ # Watch unit tests
├── Shared/                     # Shared models between iOS/watchOS
└── build/                      # Build artifacts (gitignored)

fastlane/
├── Fastfile                    # Fastlane automation
├── Snapfile                    # Screenshot configuration
├── lib/
│   ├── version_helper.rb       # Version management
│   ├── screenshot_helper.rb    # Screenshot normalization
│   └── watch_screenshot_helper.rb # Watch-specific helpers
└── screenshots/                # Generated screenshots

.github/
├── workflows/                  # CI/CD workflows
└── scripts/                    # Helper scripts for CI
```

## Common Issues

### Simulator pairing issues (Watch)
- Watch simulator must be paired with iPhone simulator
- Clean simulator state: `.github/scripts/cleanup-simulators-robust.sh`
- Cleanup duplicate Watch simulators: `.github/scripts/cleanup-watch-duplicates.sh`

### Screenshot dimension validation failures
- Ensure ImageMagick 7+ is installed: `brew install imagemagick`
- Verify with: `magick --version` or `convert --version`
- Validate: `.github/scripts/validate-screenshots.sh <path> <device_type>`

### Version mismatch across targets
- Run: `bundle exec fastlane validate_versions` to check
- Fix: `bundle exec fastlane set_version version:X.Y.Z`

### Build failures after code changes
- Always run build command after changes
- Check for Swift compilation errors in modified files
- Ensure proper imports and dependencies

### Test failures
- UI tests require deterministic test data (see UITestDataService)
- Clear simulator data if tests behave inconsistently
- Watch tests require paired simulators

## Documentation Resources

- `README.md` - Quick start guide
- `documentation/version_management.md` - Complete version management guide
- `WATCHOS_LOCALIZATION_*.md` - watchOS localization setup
- `.cursorrules` - Development workflow rules
