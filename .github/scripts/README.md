# CI Helper Scripts

This directory contains shell scripts used by the App Store screenshot generation pipeline.

## Scripts Overview

### `find-simulator.sh`
**Purpose:** Reliably find and validate iOS/watchOS simulators

**Usage:**
```bash
.github/scripts/find-simulator.sh "iPhone 16 Pro Max" iOS
.github/scripts/find-simulator.sh "Apple Watch Series 10 (46mm)" watchOS
```

**Features:**
- Environment variable injection (prevents shell injection)
- Validates simulator exists and is bootable
- UUID format verification (case-insensitive)
- Clear error messages with troubleshooting hints

**Exit Codes:**
- `0` - Success, UDID printed to stdout
- `1` - Missing arguments
- `2` - Failed to list simulators
- `3` - JSON parsing error
- `4` - No matching simulator found
- `5` - Invalid UDID format
- `6` - Simulator not bootable

---

### `cleanup-watch-duplicates.sh`
**Purpose:** Remove duplicate Apple Watch simulators to prevent "multiple devices matched" errors

**Usage:**
```bash
.github/scripts/cleanup-watch-duplicates.sh
```

**Features:**
- Finds all Watch Series 10 (46mm) simulators
- Keeps oldest watchOS version (matches Xcode 16.1 bundled watchOS 11.1)
- Deletes newer duplicates
- Safe: Only deletes if multiple instances found

**Exit Codes:**
- `0` - Success (or no duplicates found)
- `1` - Failed to list simulators
- `2` - JSON parsing error

---

### `validate-screenshots.sh`
**Purpose:** Validate screenshot dimensions, format, and content before upload

**Usage:**
```bash
.github/scripts/validate-screenshots.sh <directory> <device_type>

# Examples:
.github/scripts/validate-screenshots.sh fastlane/screenshots_compat iphone
.github/scripts/validate-screenshots.sh fastlane/screenshots_compat ipad
.github/scripts/validate-screenshots.sh fastlane/screenshots/watch_normalized watch
```

**Validates:**
- ✅ Dimensions match App Store requirements:
  - iPhone: 1290x2796
  - iPad: 2064x2752
  - Watch: 396x484
- ✅ File size > 10KB (detects corrupt files)
- ✅ Valid PNG format
- ✅ Not blank (brightness analysis: <5% or >95%)

**Exit Codes:**
- `0` - All screenshots valid
- `1` - Invalid arguments
- `2` - Directory not found
- `3` - Unknown device type
- `4` - ImageMagick not found
- `5` - No screenshots found
- `6` - Validation failed

---

### `preflight-check.sh`
**Purpose:** Validate CI environment before starting 90+ minute screenshot generation

**Usage:**
```bash
.github/scripts/preflight-check.sh
```

**Checks:**
- ✅ Xcode 16.1 availability
- ✅ Required simulators exist:
  - iPhone 16 Pro Max
  - iPad Pro 13-inch (M4)
  - Apple Watch Series 10 (46mm)
- ℹ️ ImageMagick (optional - workflow installs it)
- ✅ Ruby 3.2 and Bundler
- ✅ Disk space (500MB min, 2GB recommended)
- ✅ Required files (Fastfile, Snapfile, Gemfile)
- ✅ Network connectivity to appstoreconnect.apple.com

**Exit Codes:**
- `0` - All checks passed (or warnings only)
- `1` - One or more checks failed

---

## Development Guidelines

### Testing Scripts Locally

```bash
# Syntax check
bash -n .github/scripts/script-name.sh

# Run with test data
.github/scripts/find-simulator.sh "iPhone 16 Pro Max" iOS

# Test error cases
.github/scripts/find-simulator.sh "NonExistent Device" iOS || echo "Exit: $?"
```

### Adding New Scripts

1. Make executable: `chmod +x .github/scripts/new-script.sh`
2. Use shebang: `#!/bin/bash`
3. Use strict mode: `set -euo pipefail`
4. Document in this README
5. Add comprehensive error messages
6. Test locally before committing

### Shell Script Best Practices

**DO:**
- ✅ Quote all variables: `"$VAR"`
- ✅ Use explicit error checks: `if ! command; then`
- ✅ Provide clear error messages
- ✅ Use `>&2` for error output
- ✅ Exit with meaningful exit codes
- ✅ Test edge cases (empty input, missing files, etc.)

**DON'T:**
- ❌ Use `$?` after multiple commands
- ❌ Suppress errors with `|| true` unless intentional
- ❌ Mix stdout and stderr
- ❌ Use bare `rescue` in error handling
- ❌ Assume file existence without checking

### Security Considerations

These scripts handle:
- User input (device names)
- System commands (xcrun simctl)
- File operations (screenshots)

**Security measures:**
- Environment variable injection (not string interpolation)
- Input validation (UUID format, device names)
- No eval or arbitrary code execution
- Shellwords.escape in Ruby code

---

## Troubleshooting

### "Simulator not found"
```bash
# List available simulators
xcrun simctl list devices available

# Check specific device
xcrun simctl list devices available | grep "iPhone 16 Pro Max"
```

### "ImageMagick not found"
```bash
# Install ImageMagick
brew install imagemagick

# Verify installation
magick --version
```

### "Screenshot validation failed"
```bash
# Check dimensions
identify -format '%wx%h' screenshot.png

# Check file size
ls -lh screenshot.png

# Check brightness
magick screenshot.png -colorspace Gray -format "%[fx:mean]" info:
```

---

## Pipeline Integration

These scripts are called by `.github/workflows/prepare-appstore.yml`:

```yaml
# Pre-flight checks
- run: .github/scripts/preflight-check.sh

# Find and boot simulator
- run: |
    DEVICE_UDID=$(.github/scripts/find-simulator.sh "iPhone 16 Pro Max" iOS)
    xcrun simctl bootstatus "$DEVICE_UDID" -b

# Validate screenshots after generation
- run: .github/scripts/validate-screenshots.sh fastlane/screenshots_compat iphone
```

---

## Change Log

### 2025-11-25 - Comprehensive Hardening
- Created all four helper scripts
- Fixed 11 CRITICAL/HIGH bugs
- Fixed 4 MEDIUM priority issues
- Comprehensive testing and validation

---

## Contributing

When modifying these scripts:
1. Test locally with real scenarios
2. Run critical code review
3. Update this README if behavior changes
4. Test in CI before merging to main

🤖 This README generated by Claude Code
