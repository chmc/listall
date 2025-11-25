# Local Development & Testing Guide

This guide explains how to test the App Store screenshot pipeline locally before pushing to CI.

## 🚀 Quick Start

### 1. Run Validation Before Committing

**Fastest check (1-2 seconds):**
```bash
.github/scripts/test-pipeline-locally.sh --validate-only
```

This validates:
- ✅ All helper scripts exist and have valid syntax
- ✅ Environment is configured (Xcode, Ruby, ImageMagick, etc.)
- ✅ Fastfile and workflow YAML are syntactically correct
- ✅ Documentation exists

### 2. Run Quick Pipeline Test (10-15 seconds)

**Before pushing CI changes:**
```bash
.github/scripts/test-pipeline-locally.sh --quick
```

This additionally tests:
- ✅ Simulator discovery works
- ✅ Simulators can boot successfully
- ✅ Watch duplicate cleanup works
- ⏭️  Skips actual screenshot generation (saves 60-90 min)

### 3. Run Full Pipeline Test (60-90 minutes)

**Before major releases:**
```bash
.github/scripts/test-pipeline-locally.sh --full
```

This runs the complete pipeline:
- ✅ All validations from quick mode
- ✅ Actually generates screenshots for iPhone, iPad, Watch
- ✅ Validates screenshot dimensions and content
- ✅ Reports timing for each device

## 🪝 Installing Pre-Commit Hook

**Optional but recommended:** Auto-validate before every commit:

```bash
# Install the hook (one-time setup)
ln -sf ../../.github/hooks/pre-commit .git/hooks/pre-commit

# Verify installation
ls -la .git/hooks/pre-commit
```

The hook will automatically run `--validate-only` mode when you commit changes to:
- `.github/workflows/`
- `.github/scripts/`
- `fastlane/`

**To bypass the hook if needed:**
```bash
git commit --no-verify -m "message"
```

## 📝 Testing Individual Components

### Test Pre-flight Check

```bash
.github/scripts/preflight-check.sh
```

Validates:
- Xcode version
- Required simulators exist
- ImageMagick installed (optional check)
- Ruby and Bundler versions
- Disk space availability
- Required files present
- Network connectivity to App Store Connect

### Find a Simulator

```bash
# iPhone
.github/scripts/find-simulator.sh "iPhone 16 Pro Max" iOS

# iPad
.github/scripts/find-simulator.sh "iPad Pro 13-inch (M4)" iOS

# Watch
.github/scripts/find-simulator.sh "Apple Watch Series 10 (46mm)" watchOS
```

Returns the UDID on success, exits with error code on failure.

### Clean Watch Duplicates

```bash
.github/scripts/cleanup-watch-duplicates.sh
```

Removes duplicate Watch simulators if multiple instances found.

### Validate Screenshots

```bash
# Validate iPhone screenshots
.github/scripts/validate-screenshots.sh fastlane/screenshots_compat iphone

# Validate iPad screenshots
.github/scripts/validate-screenshots.sh fastlane/screenshots_compat ipad

# Validate Watch screenshots
.github/scripts/validate-screenshots.sh fastlane/screenshots/watch_normalized watch
```

Checks:
- Dimensions match App Store requirements
- File size > 10KB
- Valid PNG format
- Not blank (brightness analysis)

## 🧪 Testing Fastlane Locally

### Generate iPhone Screenshots

```bash
bundle exec fastlane ios screenshots_iphone
```

Output: `fastlane/screenshots_compat/` (normalized to 1290x2796)

### Generate iPad Screenshots

```bash
bundle exec fastlane ios screenshots_ipad
```

Output: `fastlane/screenshots_compat/` (normalized to 2064x2752)

### Generate Watch Screenshots

```bash
bundle exec fastlane ios watch_screenshots
```

Output: `fastlane/screenshots/watch_normalized/` (normalized to 396x484)

### Validate Delivery Screenshots

```bash
bundle exec fastlane ios validate_delivery_screenshots
```

Runs comprehensive validation on all screenshots before upload.

## 🔧 Debugging Tips

### Check Xcode and Simulators

```bash
# Xcode version
xcodebuild -version

# List available simulators
xcrun simctl list devices available

# List specific device
xcrun simctl list devices available | grep "iPhone 16 Pro Max"
```

### Check Dependencies

```bash
# Ruby and Bundler
ruby --version
bundle --version

# ImageMagick
magick --version
identify --version

# Check commands available
command -v magick identify convert
```

### Simulator Management

```bash
# Boot simulator
UDID=$(xcrun simctl list devices | grep "iPhone 16 Pro Max" | grep -oE '[0-9A-F-]{36}' | head -1)
xcrun simctl bootstatus "$UDID" -b

# Check simulator state
xcrun simctl list devices "$UDID"

# Shutdown all simulators
xcrun simctl shutdown all

# Delete unavailable simulators
xcrun simctl delete unavailable

# Erase all simulator data
xcrun simctl erase all
```

### Screenshot Debugging

```bash
# Check dimensions
identify -format '%wx%h' screenshot.png

# Check file size
ls -lh screenshot.png

# Check brightness (0.0=black, 1.0=white)
magick screenshot.png -colorspace Gray -format "%[fx:mean]" info:

# Verify PNG format
identify -format '%m' screenshot.png
```

## 📊 Performance Expectations

Based on successful CI runs:

| Task | Local (M1+) | CI (macos-14) | Notes |
|------|-------------|---------------|-------|
| Validate-only | 1-2s | N/A | Syntax checks only |
| Quick test | 10-15s | N/A | Includes simulator boot |
| iPhone screenshots | 15-20 min | 20-24 min | Actual generation |
| iPad screenshots | 15-18 min | 18-20 min | Actual generation |
| Watch screenshots | 12-15 min | 16 min | Actual generation |
| **Total (full)** | **45-60 min** | **60-90 min** | All devices |

Local performance is typically faster due to:
- No cold boot of runner
- Local SSD speeds
- Dedicated resources

## 🔄 Recommended Workflow

### For Small Changes (Scripts, Workflow)

1. **Make changes**
2. **Run validation:**
   ```bash
   .github/scripts/test-pipeline-locally.sh --validate-only
   ```
3. **Commit** (pre-commit hook runs automatically if installed)
4. **Push to feature branch**
5. **Let CI run and verify**

### For Fastlane/Test Changes

1. **Make changes**
2. **Run quick test:**
   ```bash
   .github/scripts/test-pipeline-locally.sh --quick
   ```
3. **If major changes, run full test:**
   ```bash
   .github/scripts/test-pipeline-locally.sh --full
   ```
4. **Commit and push**
5. **Verify CI passes**

### Before Major Releases

1. **Run full pipeline locally:**
   ```bash
   .github/scripts/test-pipeline-locally.sh --full
   ```
2. **Review generated screenshots manually**
3. **Run validation:**
   ```bash
   bundle exec fastlane ios validate_delivery_screenshots
   ```
4. **Trigger CI pipeline:**
   ```bash
   gh workflow run prepare-appstore.yml -f version=1.2.0
   ```
5. **Monitor CI run:**
   ```bash
   gh run list --workflow=prepare-appstore.yml
   gh run watch <run-id>
   ```

## 🚨 Common Issues

### "Simulator not found"

```bash
# List what's actually available
xcrun simctl list devices available | grep -E "iPhone|iPad|Watch"

# If missing, check Xcode version
xcodebuild -version

# GitHub Actions uses Xcode 16.1 with specific simulators
```

### "ImageMagick not found"

```bash
# Install ImageMagick 7
brew install imagemagick

# Verify installation
magick --version | head -1
```

### "Script not executable"

```bash
# Make scripts executable
chmod +x .github/scripts/*.sh
chmod +x .github/hooks/pre-commit

# Verify
ls -la .github/scripts/
```

### "Simulator already booted"

```bash
# Shutdown all simulators
xcrun simctl shutdown all

# Wait a moment
sleep 2

# Try again
.github/scripts/test-pipeline-locally.sh --quick
```

### "Screenshot validation failed"

Check the error message:
- **Wrong dimensions:** Regenerate screenshots on correct device
- **Blank screenshot:** App might not have launched properly
- **Small file size:** Screenshot corrupt or empty
- **Not PNG:** File format issue

## 📚 Related Documentation

- **Troubleshooting Guide:** `.github/workflows/TROUBLESHOOTING.md`
- **Scripts Reference:** `.github/scripts/README.md`
- **Workflow Definition:** `.github/workflows/prepare-appstore.yml`
- **Fastlane Configuration:** `fastlane/Fastfile`
- **Test Implementation:** `ListAll/ListAllUITests/ListAllUITests_Simple.swift`

## 💡 Tips

1. **Use `--quick` mode for rapid iteration** - Catches most issues without 60min wait
2. **Install pre-commit hook** - Prevents pushing broken code
3. **Run full test before releases** - Ensures screenshots generate correctly
4. **Keep simulators clean** - Run `xcrun simctl delete unavailable` regularly
5. **Monitor CI runs** - Use `gh run watch` to catch issues early

## 🤝 Contributing

When modifying the pipeline:

1. ✅ **Test locally first** (at least `--quick` mode)
2. ✅ **Use feature branches** (not main)
3. ✅ **Run validation** before committing
4. ✅ **Document changes** in relevant README/guides
5. ✅ **Verify CI passes** before merging

---

**Last Updated:** 2025-11-25
**Maintainer:** @chmc
**Questions?** Check `.github/workflows/TROUBLESHOOTING.md`

🤖 This guide helps prevent the 140-attempt failure streak from happening again.
