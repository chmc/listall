# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

ListAll is a SwiftUI list management app for iOS and watchOS with CloudKit sync infrastructure. The app uses MVVM architecture with shared business logic across platforms.

## Build Commands

```bash
# Build iOS app
xcodebuild -project ListAll/ListAll.xcodeproj -scheme ListAll -destination 'platform=iOS Simulator,name=iPhone 16 Pro' build

# Build watchOS app
xcodebuild -project ListAll/ListAll.xcodeproj -scheme "ListAllWatch Watch App" -destination 'platform=watchOS Simulator,name=Apple Watch Series 10 (46mm)' build
```

## Test Commands

```bash
# Run all iOS tests (unit + UI)
bundle exec fastlane test

# Run iOS unit tests only (faster)
xcodebuild -project ListAll/ListAll.xcodeproj -scheme ListAll -destination 'platform=iOS Simulator,name=iPhone 16 Pro' test

# Run watchOS tests
xcodebuild -project ListAll/ListAll.xcodeproj -scheme "ListAllWatch Watch App" -destination 'platform=watchOS Simulator,name=Apple Watch Series 10 (46mm)' test

# Run shell script tests
.github/scripts/tests/test-generate-screenshots-local.sh
```

## Fastlane Lanes

```bash
bundle exec fastlane test              # Run tests (mirrors CI)
bundle exec fastlane beta              # Build and upload to TestFlight
bundle exec fastlane beta bump_type:minor  # TestFlight with minor version bump
bundle exec fastlane show_version      # Show current version
bundle exec fastlane set_version version:1.2.0  # Set version manually
bundle exec fastlane release version:1.2.0      # Deliver to App Store
bundle exec fastlane asc_dry_run       # Verify App Store Connect auth
```

## Screenshot Generation

```bash
# Generate all screenshots locally (60-90 min)
.github/scripts/generate-screenshots-local.sh all

# Generate iPhone only (25 min)
.github/scripts/generate-screenshots-local.sh iphone

# Generate iPad only (40 min)
.github/scripts/generate-screenshots-local.sh ipad

# Generate Watch only (20 min)
.github/scripts/generate-screenshots-local.sh watch

# Re-apply device frames only
.github/scripts/generate-screenshots-local.sh framed
```

## Architecture

### MVVM with Repository Pattern
- **Models**: Core Data entities in `ListAll/ListAll/Models/CoreData/`
- **ViewModels**: Business logic in `ListAll/ListAll/ViewModels/`
- **Views**: SwiftUI views in `ListAll/ListAll/Views/`
- **Services**: Data layer in `ListAll/ListAll/Services/`

### Platform Code Sharing (iOS + watchOS)
Files are shared via Xcode Target Membership (not symbolic links):
- **100% shared**: Models, Core Data schema
- **95% shared**: Services (except BiometricAuthService - iOS only)
- **80% shared**: ViewModels
- **0% shared**: Views (platform-specific UI)

Platform-specific code uses compiler directives:
```swift
#if os(iOS)
// iOS-only code
#elseif os(watchOS)
// watchOS-only code
#endif
```

### Data Architecture
- **Core Data** with App Groups (`group.io.github.chmc.ListAll`) for iOS/watchOS data sharing
- **CloudKit** infrastructure ready (requires paid Apple Developer account to activate)
- SQLite database shared between iOS and watchOS apps via App Groups

### Key Files
- `ListAll/ListAll/Services/DataRepository.swift` - Central data access layer
- `ListAll/ListAll/Models/CoreData/CoreDataManager.swift` - Core Data stack with App Groups
- `ListAll/ListAll/Services/CloudKitService.swift` - CloudKit sync (infrastructure ready)

## CI/CD Workflows

- `ci.yml` - Runs on every push: builds iOS + watchOS, runs tests
- `release.yml` - Manual trigger: version bump + TestFlight upload
- `prepare-appstore.yml` - Screenshot generation pipeline
- `publish-to-appstore.yml` - Metadata + screenshot delivery to App Store

## Critical Rules

1. **Code must always build successfully** - Run build commands after code changes
2. **Tests must pass** - Run `bundle exec fastlane test` before considering work complete
3. **Update ai_changelog.md** - Document significant changes in `documentation/ai_changelog.md`

## Supported Locales

- `en-US` (English)
- `fi` (Finnish)

## Version Format

Semantic versioning: MAJOR.MINOR.PATCH (e.g., 1.2.3)
- Version stored in Xcode project settings
- Check with `bundle exec fastlane show_version`
