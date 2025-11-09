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

### ios beta

```sh
[bundle exec] fastlane ios beta
```

Build and upload to TestFlight

Options:

  bump_type: 'patch' (default), 'minor', or 'major' - Type of version increment

  skip_version_bump: true to skip version increment (use current version)

### ios release

```sh
[bundle exec] fastlane ios release
```

Deliver metadata/screenshots to App Store (no auto-submit)

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

----

This README.md is auto-generated and will be re-generated every time [_fastlane_](https://fastlane.tools) is run.

More information about _fastlane_ can be found on [fastlane.tools](https://fastlane.tools).

The documentation of _fastlane_ can be found on [docs.fastlane.tools](https://docs.fastlane.tools).
