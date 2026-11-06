# Version Management for ListAll

This document describes the semantic versioning system implemented for ListAll (iOS + watchOS).

## Overview

ListAll uses **semantic versioning** (SemVer) with the format: `MAJOR.MINOR.PATCH`

- **MAJOR**: Incremented for incompatible API changes or major features
- **MINOR**: Incremented for new features in a backward-compatible manner
- **PATCH**: Incremented for backward-compatible bug fixes

## Version Storage

The current version is stored in two locations:
1. **`.version` file** - The source of truth for the current version
2. **Xcode project** - `MARKETING_VERSION` build setting for all targets

## Fastlane Commands

### Show Current Version
```bash
bundle exec fastlane show_version
```
Displays the current version from:
- Version file (.version)
- Git tags (if any)
- All Xcode targets
- Validation status

### Set Version Manually
```bash
bundle exec fastlane set_version version:X.Y.Z
```
Example:
```bash
bundle exec fastlane set_version version:1.2.0
```

Sets the version to a specific value across:
- Version file
- All Xcode targets (main app, watch app, test targets)

After setting, commit the changes (without a tag, see the warning under "Automatic on Tag Push"):
```bash
git add .version ListAll/ListAll.xcodeproj/project.pbxproj
git commit -m "Set version to X.Y.Z"
git push origin main
```

### Validate Versions
```bash
bundle exec fastlane validate_versions
```
Checks that all main targets have matching version numbers.

### TestFlight Build with Version Bump
```bash
# Patch bump (default): 1.1.0 → 1.1.1
bundle exec fastlane beta

# Minor bump: 1.1.0 → 1.2.0
bundle exec fastlane beta bump_type:minor

# Major bump: 1.1.0 → 2.0.0
bundle exec fastlane beta bump_type:major

# Skip version bump (use current version)
bundle exec fastlane beta skip_version_bump:true
```

## GitHub Actions Workflow

The Release workflow (`/.github/workflows/release.yml`) supports version management:

### Manual Dispatch
1. Go to Actions → Release workflow
2. Click "Run workflow"
3. Select version bump type:
   - **patch** (default): Bug fixes (1.1.0 → 1.1.1)
   - **minor**: New features (1.1.0 → 1.2.0)
   - **major**: Breaking changes (1.1.0 → 2.0.0)
4. Optionally check "Skip version bump" to use current version

### Automatic on Tag Push
Pushing a `v*` tag also triggers the Release workflow. A tag push has no inputs, so the run does a **patch bump on top of `.version`**. Pushing `v1.2.0` while `.version` is 1.2.0 releases **1.2.1**. Prefer manual dispatch. The workflow creates the tag itself.

### Publishing to the App Store
`Publish to App Store` takes the version as input. It must equal `.version`, which is the version Release to TestFlight built, and the workflow fails otherwise. On 2026-02-18, the input 1.1.20 was used for build 1.1.19. The store version then ran ahead of the repo, and a plain patch bump would have produced the already-live 1.1.20. That was fixed by `set_version 1.1.21` followed by patch → 1.1.22.

### Release notes ("What's New")
App Store texts come only from git; don't edit them by hand in App Store Connect. Before publishing, update all four `release_notes.txt` files for the new version: `fastlane/metadata/{en-US,fi}` for iOS and `fastlane/metadata/macos/{en-US,fi}` for macOS. List the user-facing changes since the live version (`git log v<live>..HEAD`).

Publish runs `fastlane validate_release_notes version:X.Y.Z` before uploading anything. It fails if any locale's file is empty or missing, or matches the "What's New" of any other App Store version on that platform. Locales that exist in App Store Connect but not in the repo also fail. Comparison ignores whitespace, line endings and Unicode composition. The same check also runs at the start of the `release` and `release_macos` lanes. If App Store Connect can't be read or returns no earlier versions, the check fails closed. On 2026-11-05, 1.1.22 was first uploaded with the 1.1.20 notes, and this check was added after that.

### App Review information
Publish also sets the App Review information for the version. The notes come from git (`fastlane/app_review/ios_notes.txt` and `fastlane/app_review/macos_notes.txt`). The contact name, email and phone come from the GitHub secrets `REVIEW_CONTACT_FIRST_NAME`, `REVIEW_CONTACT_LAST_NAME`, `REVIEW_CONTACT_EMAIL` and `REVIEW_CONTACT_PHONE`, because the repo is public.

The `release` lanes upload notes and contact in one Spaceship request after `deliver`, for two reasons:
- App Store Connect rejects a review-detail update that lacks the contact.
- deliver's `app_review_information` option prints its values into the public Actions log.

The notes are kept outside `metadata/` so that deliver doesn't upload them on its own. App Store Connect blocks "Add for Review" without the contact, so the lanes fail before uploading if any secret is missing or the phone isn't in international format (`+358 …`). To run the lanes locally, export the same `REVIEW_CONTACT_*` variables. Every publish overwrites the review notes and contact in App Store Connect and removes review attachments that were uploaded by hand. 1.1.22 was first published without the contact on 2026-11-06.

### New build for the same version
Before a version is submitted or released, its train is open, so a new build can be uploaded without a version bump. Dispatch Release to TestFlight with `skip_version_bump: true`. The build number is the workflow run number, so it always increases. This path creates no commit or tag, so `vX.Y.Z` stays on the original bump commit. Don't move the tag: pushing a `v*` tag starts a release with a patch bump. Example: 1.1.22 builds 105/106 → 107 on 2026-11-05 to include the flaky-test production fixes.

### Choosing the next version
The version must be higher than the live App Store version on each platform. See `learnings/testflight-version-train-closed.md`. `validate_version_train` checks this before the build. It runs after the version-bump job has already committed and tagged, though, so check the live version first:
```bash
curl -s "https://itunes.apple.com/lookup?bundleId=io.github.chmc.ListAll" | grep -o '"version":"[^"]*"'
```

## Version Bump Workflow

The automated workflow:
1. **Shows current version** - Displays before changes
2. **Increments version** - Based on bump type
3. **Updates all targets** - Main app + watchOS app
4. **Validates consistency** - Ensures all targets match
5. **Builds and uploads** - Creates IPA and uploads to TestFlight
6. **Commits changes** - Commits updated version files
7. **Creates git tag** - Tags with new version
8. **Pushes to GitHub** - Pushes commit and tag

## Version Numbering Strategy

### Current Version: 1.1.0

### Recommended Approach

**For TestFlight Builds:**
- Use **patch** bumps for internal testing and bug fixes
- Example: 1.1.0 → 1.1.1 → 1.1.2

**For App Store Releases:**
- Use **minor** bumps for new features
- Example: 1.1.0 → 1.2.0
- Use **major** bumps for significant changes
- Example: 1.2.0 → 2.0.0

### Build Numbers

Build numbers are automatically incremented:
- **CI**: Uses GitHub Actions run number
- **Local**: Increments current build number by 1

## Implementation Details

### Files
- **`.version`** - Version number file (tracked in git)
- **`fastlane/lib/version_helper.rb`** - Ruby module for version management
- **`fastlane/Fastfile`** - Fastlane lanes (beta, show_version, set_version, validate_versions)
- **`.github/workflows/release.yml`** - CI/CD workflow with version inputs

### Technology
- **xcodeproj gem** - Direct manipulation of Xcode project files
- **MARKETING_VERSION** - Xcode build setting for version number
- **CURRENT_PROJECT_VERSION** - Build number (auto-incremented)

### Validation
The system validates that all main targets (ListAll, ListAllWatch Watch App) have identical version numbers. Test targets are excluded from validation but still updated.

## Migration from Old System

Previous system used:
```bash
sed -i '' 's/MARKETING_VERSION = 1.0;/MARKETING_VERSION = 1.1;/g'
```

New system:
- Uses semantic versioning (three numbers)
- Updates all targets consistently
- Validates changes
- Tracks version in dedicated file
- Supports automated and manual workflows

## Troubleshooting

### Version mismatch detected
Run `bundle exec fastlane set_version version:X.Y.Z` to sync all targets.

### Can't find Xcode project
Ensure you're running from the repository root, not the fastlane directory.

### Git tag already exists
Delete the tag locally and remotely:
```bash
git tag -d vX.Y.Z
git push origin :refs/tags/vX.Y.Z
```

## Examples

### Release Workflow Example

**Scenario: Releasing version 1.2.0 with new features**

```bash
# 1. Ensure clean working directory
git status

# 2. Set version
bundle exec fastlane set_version version:1.2.0

# 3. Validate
bundle exec fastlane validate_versions

# 4. Commit (no tag: a pushed v* tag triggers a release with a patch bump)
git add .version ListAll/ListAll.xcodeproj/project.pbxproj
git commit -m "Set version to 1.2.0"

# 5. Push
git push origin main

# 6. Build and upload: Actions → Release to TestFlight with skip_version_bump: true
#    This path creates no tag. Prefer the bump_type path below, which commits and tags.
```

**Or use GitHub Actions:**
1. Go to Actions → Release
2. Run workflow with "minor" bump type
3. Workflow handles everything automatically

## References

- [Semantic Versioning 2.0.0](https://semver.org/)
- [Fastlane Documentation](https://docs.fastlane.tools/)
- [App Store Connect API](https://developer.apple.com/documentation/appstoreconnectapi)
