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

After setting, commit the changes and create a git tag:
```bash
git add .version ListAll/ListAll.xcodeproj/project.pbxproj
git commit -m "Bump version to X.Y.Z"
git tag vX.Y.Z
git push origin main --tags
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
Push a tag to trigger release:
```bash
git tag v1.2.0
git push origin v1.2.0
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

# 4. Commit and tag
git add .version ListAll/ListAll.xcodeproj/project.pbxproj
git commit -m "Bump version to 1.2.0"
git tag v1.2.0

# 5. Push
git push origin main --tags

# 6. Build and upload (or let GitHub Actions do it)
bundle exec fastlane beta skip_version_bump:true
```

**Or use GitHub Actions:**
1. Go to Actions → Release
2. Run workflow with "minor" bump type
3. Workflow handles everything automatically

## References

- [Semantic Versioning 2.0.0](https://semver.org/)
- [Fastlane Documentation](https://docs.fastlane.tools/)
- [App Store Connect API](https://developer.apple.com/documentation/appstoreconnectapi)
