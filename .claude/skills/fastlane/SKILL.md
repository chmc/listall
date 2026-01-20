---
name: fastlane
description: Fastlane automation patterns for iOS screenshots, App Store deployment, and CI/CD. Use when configuring Fastlane, Snapfile, or debugging screenshot issues.
---

# Fastlane Automation Best Practices

## Snapfile Configuration

### Patterns (Do This)

```ruby
# Reuse warm simulator (saves 6-10 min per locale)
erase_simulator(false)

# Clean app state for consistent screenshots
reinstall_app(true)

# Set system locale for correct strings bundle
localize_simulator(true)

# Avoid keychain conflicts in CI
concurrent_simulators(false)

# Use prebuild step for speed
test_without_building(true)

# Run only screenshot tests
only_testing(["ListAllUITests/ListAllUITests_Screenshots"])

# Handle CI flakiness
number_of_retries(2)
```

### Antipatterns (Avoid This)

```ruby
# BAD: Adds 6-10 min per locale
erase_simulator(true)

# BAD: Causes keychain conflicts in CI
concurrent_simulators(true)

# BAD: Running all UI tests
# only_testing not set
```

## UI Testing for Screenshots

### Patterns

- Use `element.waitForExistence(timeout: 10)` instead of `sleep()`
- Use accessibility identifiers instead of text labels
- Set `continueAfterFailure = false` for screenshots
- Use separate test class for screenshots
- Reset app state via launch arguments
- Number screenshots: `01_Welcome`, `02_Main` for proper ordering

### Antipatterns

- Using `sleep()` (slow and flaky)
- Querying by text labels (breaks with localization)
- Random screenshot naming (causes sort issues)
- Relying on test execution order

## Simulator Management

### Patterns

- Let Fastlane boot simulators on demand
- Run `xcrun simctl shutdown all` before screenshot runs
- Run `xcrun simctl delete unavailable` for cleanup
- Set `SNAPSHOT_SIMULATOR_WAIT_FOR_BOOT_TIMEOUT=120`

### Antipatterns

- Pre-booting simulators before Fastlane (causes race conditions)
- Leaving simulators in unknown state
- Accumulating broken/duplicate simulators

## App Store Screenshot Requirements

| Device | Dimensions | Model |
|--------|-----------|-------|
| iPhone 6.7" | 1290x2796 | iPhone 16 Pro Max |
| iPhone 6.5" | 1242x2688 | iPhone 11 Pro Max |
| iPad 13" | 2064x2752 | iPad Pro M4 |
| iPad 12.9" | 2048x2732 | iPad Pro 12.9 |
| Apple Watch | 396x484 | Apple Watch Ultra |

## Common Issues

### Wrong Localization
**Fix**: Enable `localize_simulator(true)` or add launch arguments:
```swift
app.launchArguments += ["-AppleLanguages", "(en-US)"]
app.launchArguments += ["-AppleLocale", "en_US"]
```

### Simulator Hangs
**Fix**: `xcrun simctl shutdown all` and let Fastlane manage boot

### Screenshot Dimension Mismatch
**Fix**: Verify with `identify` command, check simulator matches device
