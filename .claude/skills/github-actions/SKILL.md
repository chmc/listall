---
name: github-actions
description: GitHub Actions CI/CD patterns for iOS and Apple platforms. Use when configuring workflows, debugging CI failures, or optimizing pipelines.
---

# GitHub Actions Best Practices

## Pipeline Architecture

### Patterns
- Decompose monolithic pipelines into parallel jobs by device/locale
- Use job dependencies to create clear execution graphs
- Fail fast: put quick validation before expensive operations
- Upload artifacts on `always()` to enable debugging failed runs
- Set explicit `timeout-minutes` to prevent hung jobs
- Use matrix builds for multi-device or multi-locale testing
- Cache aggressively: Homebrew, bundler, derived data

### Runner Selection
```yaml
# GOOD: Apple Silicon (faster)
runs-on: macos-14
# or
runs-on: macos-15

# BAD: Intel (slower, deprecated)
runs-on: macos-12
```

## Reliability Patterns

### Retry for Transient Failures
```yaml
- uses: nick-fields/retry@v3
  with:
    timeout_minutes: 30
    max_attempts: 3
    command: bundle exec fastlane ios screenshots
```

### Pre-Flight Checks
```yaml
jobs:
  preflight:
    runs-on: macos-14
    steps:
      - name: Validate environment
        run: |
          xcrun simctl list devices available
          xcodebuild -version
```

### Artifacts on Failure
```yaml
- name: Upload logs
  if: always()  # Upload even on failure
  uses: actions/upload-artifact@v4
  with:
    name: logs
    path: ~/Library/Logs/snapshot/
```

## Performance Optimization

### Caching
```yaml
- name: Cache Homebrew
  uses: actions/cache@v4
  with:
    path: ~/Library/Caches/Homebrew
    key: homebrew-${{ hashFiles('Brewfile.lock.json') }}

- name: Setup Ruby with Bundler cache
  uses: ruby/setup-ruby@v1
  with:
    bundler-cache: true
```

### Shallow Clone
```yaml
- uses: actions/checkout@v4
  with:
    fetch-depth: 1  # Shallow clone
```

### Parallel Jobs
```yaml
jobs:
  screenshots-iphone:
    runs-on: macos-14
    # ...
  screenshots-ipad:
    runs-on: macos-14
    # ...
  screenshots-watch:
    runs-on: macos-14
    # ...
```

## Antipatterns

### No Timeout
```yaml
# BAD: Can run for 6 hours
jobs:
  build:
    runs-on: macos-14
    # No timeout-minutes!

# GOOD: Explicit timeout
jobs:
  build:
    runs-on: macos-14
    timeout-minutes: 45
```

### Artifacts Only on Success
```yaml
# BAD: Cannot debug failures
- if: success()
  uses: actions/upload-artifact@v4

# GOOD: Always upload
- if: always()
  uses: actions/upload-artifact@v4
```

### No Caching
```yaml
# BAD: Reinstalls everything each run
- run: brew install imagemagick

# GOOD: Cache dependencies
- uses: actions/cache@v4
  with:
    path: ~/Library/Caches/Homebrew
    key: homebrew-${{ hashFiles('Brewfile.lock.json') }}
```

## Code Signing in CI

### Pattern: Disable for Simulator
```yaml
- name: Build for simulator
  run: |
    xcodebuild build \
      -scheme MyApp \
      -destination 'platform=iOS Simulator,name=iPhone 16 Pro' \
      CODE_SIGN_IDENTITY='' \
      CODE_SIGNING_REQUIRED=NO
```

### Pattern: Separate CI Keychain
```yaml
- name: Setup keychain
  run: |
    security create-keychain -p "" build.keychain
    security unlock-keychain -p "" build.keychain
    security set-keychain-settings -lut 7200 build.keychain
```

## Environment Variables

```yaml
env:
  # Fastlane
  FASTLANE_SKIP_UPDATE_CHECK: "1"

  # Simulator
  SNAPSHOT_SIMULATOR_WAIT_FOR_BOOT_TIMEOUT: "120"

  # Xcode
  DEVELOPER_DIR: /Applications/Xcode_16.app/Contents/Developer
```
