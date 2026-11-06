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

Shut down and clean simulators before screenshot runs, and only hand a pre-booted device to Fastlane after `simctl bootstatus -b`; commands are in the `simulator-management` skill.

## App Store Screenshot Requirements

Sizes the Fastfile delivers (`prepare_screenshots_for_delivery` comment and `target_sizes`):

| Device | Delivered size | Captured on |
|--------|----------------|-------------|
| iPhone 6.9" | 1260x2736 | iPhone 17 Pro Max (captures 1320x2868, normalized) |
| iPad 13" | 2064x2752 | iPad Pro 13-inch |
| Apple Watch | 416x496 | Apple Watch Series 11 (46mm) |
| macOS | 2880x1800 | Mac |

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
