---
name: simulator-management
description: iOS Simulator management patterns for CI/CD pipelines. Use when dealing with simulator issues, boot problems, or cleanup.
---

# iOS Simulator Management

## Common Commands

```bash
# List all available simulators
xcrun simctl list devices available

# Shutdown all simulators
xcrun simctl shutdown all

# Delete unavailable simulators
xcrun simctl delete unavailable

# Boot specific simulator
xcrun simctl boot "iPhone 16 Pro"

# Erase simulator
xcrun simctl erase <UDID>

# Delete and recreate simulator
xcrun simctl delete <UDID>
xcrun simctl create "iPhone 16 Pro" "com.apple.CoreSimulator.SimDeviceType.iPhone-16-Pro"
```

## CI/CD Patterns

### Pre-Flight Cleanup
```bash
# Always run before screenshot generation
xcrun simctl shutdown all
xcrun simctl delete unavailable
```

### Let Fastlane Manage Boot
- Never pre-boot simulators before Fastlane
- Let Fastlane boot on demand
- Set `SNAPSHOT_SIMULATOR_WAIT_FOR_BOOT_TIMEOUT=120`

### Clean Duplicate Simulators
```bash
# Identify duplicates
xcrun simctl list devices | grep -E "iPhone|iPad|Watch"

# Delete specific UDID
xcrun simctl delete <UDID>
```

## Common Failures

### "Unable to boot device in current state: Booted"
**Cause**: Simulator already booted from previous run
**Fix**: `xcrun simctl shutdown all` before runs
**Prevention**: Add shutdown step at job start

### "Multiple devices matched"
**Cause**: Duplicate simulators from Xcode updates
**Fix**: Delete duplicates by UDID
**Prevention**: Add cleanup step in pre-flight

### "Simulator failed to launch"
**Cause**: Corrupt simulator state or insufficient resources
**Fix**: `xcrun simctl erase <UDID>` or delete and recreate
**Prevention**: Clean simulator state at job start

## Antipatterns

### Pre-booting
```bash
# BAD: Race conditions with Fastlane
xcrun simctl boot "iPhone 16 Pro"
bundle exec fastlane snapshot

# GOOD: Let Fastlane manage
xcrun simctl shutdown all
bundle exec fastlane snapshot
```

### Not Cleaning Up
```bash
# BAD: Accumulates simulators
# Just run tests repeatedly

# GOOD: Regular cleanup
xcrun simctl delete unavailable
```

## Environment Variables

```bash
# Increase boot timeout for CI
export SNAPSHOT_SIMULATOR_WAIT_FOR_BOOT_TIMEOUT=120

# Disable simulator analytics
export SIMCTL_CHILD_SIMULATOR_ANALYTICS_DISABLED=1
```
