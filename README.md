[![License: GPL v3](https://img.shields.io/badge/License-GPLv3-blue.svg)](./LICENSE)
[![CI](https://github.com/chmc/listall/actions/workflows/ci.yml/badge.svg?branch=main)](https://github.com/chmc/listall/actions/workflows/ci.yml)

## Quick Start

### Version Management

ListAll uses **semantic versioning** (MAJOR.MINOR.PATCH format, e.g., 1.2.3).

**Check current version:**
```bash
bundle exec fastlane show_version
```

**Release to TestFlight:**
```bash
# Patch bump (bug fixes): 1.1.0 → 1.1.1
bundle exec fastlane beta

# Minor bump (new features): 1.1.0 → 1.2.0
bundle exec fastlane beta bump_type:minor

# Major bump (breaking changes): 1.1.0 → 2.0.0
bundle exec fastlane beta bump_type:major
```

**Set version manually:**
```bash
bundle exec fastlane set_version version:1.2.0
```

**Release via GitHub Actions:**
1. Go to **Actions** → **Release** workflow
2. Click **"Run workflow"**
3. Select version bump type: `patch`, `minor`, or `major`

> 📚 Full documentation: [`documentation/version_management.md`](./documentation/version_management.md)

## Development Setup

### Local Testing with Fastlane

To test Fastlane lanes locally (beta uploads, App Store Connect authentication, etc.), you'll need App Store Connect API credentials.

1. **Create your local environment file:**
   ```bash
   cp .env.template .env
   ```

2. **Fill in your App Store Connect API key details** in `.env`:
   - Get your API key from [App Store Connect](https://appstoreconnect.apple.com) > Users and Access > Integrations > Keys > App Store Connect API > Team Keys
   - Required role: `App Manager`
   - Generate base64 encoding: `base64 -i AuthKey_XXXXXXXXXX.p8 | tr -d '\n'`

3. **Install dependencies and test:**
   ```bash
   bundle install
   bundle exec fastlane asc_dry_run  # Verify App Store Connect auth
   ```

**Note:** Fastlane automatically loads `.env` files from your project root. The `.env` file is gitignored and will never be committed. Only `.env.template` is tracked in the repository.

### Available Fastlane Lanes

#### Testing
- `bundle exec fastlane test` — Run tests (mirrors CI)
- `bundle exec fastlane test_scan` — Run tests via Fastlane Scan

#### Version Management
- `bundle exec fastlane show_version` — Display current version across all targets
- `bundle exec fastlane set_version version:X.Y.Z` — Set version manually (e.g., `version:1.2.0`)
- `bundle exec fastlane validate_versions` — Validate all targets have matching versions

#### Build & Release
- `bundle exec fastlane beta` — Build and upload to TestFlight (requires ASC API key)
  - Add `bump_type:patch|minor|major` to increment version (default: patch)
  - Add `skip_version_bump:true` to use current version without incrementing
- `bundle exec fastlane release version:X.Y.Z` — Deliver metadata to App Store (requires ASC API key)

#### Authentication
- `bundle exec fastlane asc_dry_run` — Verify App Store Connect authentication

**Version Management:** ListAll uses semantic versioning (X.Y.Z). See [`documentation/version_management.md`](./documentation/version_management.md) for detailed information about version numbering, bumping strategies, and CI/CD integration.

## App Store Release

### Prerequisites

Local screenshot generation requires:

**Simulator runtimes** (not bundled with Xcode 26+):
- **iOS 18.1** — for iPhone 16 Pro Max and iPad Pro 13-inch (M4)
- **watchOS 11.1** — for Apple Watch Series 10 (46mm)

Install via **Xcode → Settings → Components**.

**ImageMagick** (for screenshot normalization):
```bash
brew install imagemagick
```

### Generate Screenshots

1. **Generate screenshots locally:**
   ```bash
   # Generate all platforms (iPhone, iPad, Watch, macOS)
   .github/scripts/generate-screenshots-local.sh all

   # Or generate specific platforms:
   .github/scripts/generate-screenshots-local.sh iphone   # ~25 min
   .github/scripts/generate-screenshots-local.sh ipad     # ~40 min
   .github/scripts/generate-screenshots-local.sh watch    # ~20 min
   .github/scripts/generate-screenshots-local.sh macos    # ~5 min
   ```

2. **Commit and push** the generated screenshots:
   - `fastlane/screenshots_compat/` (iPhone/iPad)
   - `fastlane/screenshots/watch_normalized/` (Watch)
   - `fastlane/screenshots/mac/` (macOS)

3. **Run the publish workflow:**
   Go to **Actions** → **Publish to App Store**, enter version number, and run.

## License
ListAll is licensed under the GNU General Public License v3.0 or later (GPL-3.0-or-later).  
See [LICENSE](./LICENSE) for the full text and [COPYRIGHT](./COPYRIGHT) for ownership details.
