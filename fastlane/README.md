fastlane documentation
----

# Installation

Make sure you have the latest version of the Xcode command line tools installed:

```sh
xcode-select --install
```

For _fastlane_ installation instructions, see [Installing _fastlane_](https://docs.fastlane.tools/#installing-fastlane)

# Available Actions

## iOS

### ios test

```sh
[bundle exec] fastlane ios test
```

Run unit and UI tests (xcodebuild like CI)

### ios test_scan

```sh
[bundle exec] fastlane ios test_scan
```

Run tests via scan (Fastlane)

### ios refresh_macos_profiles

```sh
[bundle exec] fastlane ios refresh_macos_profiles
```

Regenerate macOS provisioning profiles in Match repo

Run this locally when profile/certificate mismatch occurs

Requires ASC_KEY_ID, ASC_ISSUER_ID, ASC_KEY_BASE64 env vars

Usage: fastlane refresh_macos_profiles

### ios beta

```sh
[bundle exec] fastlane ios beta
```

Build and upload to TestFlight

Options:

  bump_type: 'patch' (default), 'minor', or 'major' - Type of version increment

  skip_version_bump: true to skip version increment (use current version)

### ios beta_macos

```sh
[bundle exec] fastlane ios beta_macos
```

Build and upload macOS app to TestFlight

Options:

  skip_version_bump: true to skip version validation (use current version)

### ios release

```sh
[bundle exec] fastlane ios release
```

Deliver metadata/screenshots to App Store (no auto-submit)

Creates new app version if needed. Usage: fastlane release version:1.2.0

Options: skip_watch:true to skip watch screenshots, skip_screenshots:true to skip ALL screenshots

### ios release_dry_run

```sh
[bundle exec] fastlane ios release_dry_run
```

Dry-run: Verify normalized screenshots would be detected by deliver (no upload)

Options: skip_watch:true to skip watch screenshots

### ios release_macos

```sh
[bundle exec] fastlane ios release_macos
```

Deliver macOS app metadata/screenshots to App Store (no auto-submit)

Creates new app version if needed. Usage: fastlane release_macos version:1.2.0

### ios asc_dry_run

```sh
[bundle exec] fastlane ios asc_dry_run
```

Validate App Store Connect auth via API key (no uploads)

### ios show_version

```sh
[bundle exec] fastlane ios show_version
```

Show current version from all targets

### ios set_version

```sh
[bundle exec] fastlane ios set_version
```

Manually set version number

Usage: fastlane set_version version:1.2.0

### ios validate_versions

```sh
[bundle exec] fastlane ios validate_versions
```

Validate that all targets have matching versions

### ios screenshots

```sh
[bundle exec] fastlane ios screenshots
```

Generate screenshots for App Store

Runs automated UI tests to capture screenshots for all configured devices and locales

### ios screenshots_iphone

```sh
[bundle exec] fastlane ios screenshots_iphone
```

Generate iPhone screenshots only

Captures iPhone 16 Pro Max screenshots for EN and FI locales

Outputs normalized screenshots to screenshots_compat/ ready for App Store

### ios screenshots_ipad

```sh
[bundle exec] fastlane ios screenshots_ipad
```

Generate iPad screenshots only

Captures iPad Pro 13-inch (M4) screenshots for EN and FI locales

Outputs normalized screenshots to screenshots_compat/ ready for App Store

### ios prepare_appstore

```sh
[bundle exec] fastlane ios prepare_appstore
```

Unified App Store screenshot generation pipeline

Generates all screenshots (iPhone, iPad, Watch) with validation and fail-fast checks

This is the main entry point for CI/CD pipelines

### ios screenshots_framed

```sh
[bundle exec] fastlane ios screenshots_framed
```

Generate and frame screenshots (snapshot + frameit)

### ios verify_framed

```sh
[bundle exec] fastlane ios verify_framed
```

Verify framed screenshots exist for all locales

### ios watch_screenshots

```sh
[bundle exec] fastlane ios watch_screenshots
```

Generate watchOS screenshots (fully automated via UITests + simctl)

Captures screenshots from Apple Watch Series 10 (46mm) for EN and FI locales

### ios verify_watch_screenshots

```sh
[bundle exec] fastlane ios verify_watch_screenshots
```

Validate watch screenshot sizes and naming (uses App Store Connect requirements)

### ios screenshots_macos

```sh
[bundle exec] fastlane ios screenshots_macos
```

Generate macOS screenshots (locally - not in CI)

Captures macOS screenshots for EN and FI locales

Outputs screenshots to fastlane/screenshots/mac/ ready for App Store

### ios screenshots_macos_normalize

```sh
[bundle exec] fastlane ios screenshots_macos_normalize
```

Normalize macOS screenshots to App Store Connect requirements (2880x1800)

Resizes/pads macOS screenshots if needed to meet exact App Store dimensions

### ios validate_delivery_screenshots

```sh
[bundle exec] fastlane ios validate_delivery_screenshots
```

Validate all delivery-ready screenshots (normalized iPhone/iPad + naked Watch)

### ios frame_screenshots_custom

```sh
[bundle exec] fastlane ios frame_screenshots_custom
```

Frame all normalized screenshots with custom device frames

Uses open source frames from jamesjingyi/mockup-device-frames

Options:

  app_store_mode: Scale frames to fit App Store dimensions (default: true)

  locales: Array of locales to process (default: ['en-US', 'fi'])

  devices: Array of device types [:iphone, :ipad] (default: both)

  background_color: Background color hex (default: '#0E1117')

  skip_existing: Skip already framed screenshots for incremental runs (default: false)

Note: Watch screenshots are not framed (use normalized screenshots directly)

### ios test_framing

```sh
[bundle exec] fastlane ios test_framing
```

Run RSpec tests for custom framing implementation

Tests device detection, framing logic, and batch processing

----

This README.md is auto-generated and will be re-generated every time [_fastlane_](https://fastlane.tools) is run.

More information about _fastlane_ can be found on [fastlane.tools](https://fastlane.tools).

The documentation of _fastlane_ can be found on [docs.fastlane.tools](https://docs.fastlane.tools).
