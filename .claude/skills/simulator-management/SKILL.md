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
xcrun simctl boot "iPhone 17 Pro"

# Erase simulator
xcrun simctl erase <UDID>

# Delete and recreate simulator
xcrun simctl delete <UDID>
xcrun simctl create "iPhone 17 Pro" "com.apple.CoreSimulator.SimDeviceType.iPhone-17-Pro"
```

## CI/CD Patterns

### Pre-Flight Cleanup
```bash
# Always run before screenshot generation
xcrun simctl shutdown all
xcrun simctl delete unavailable
```

### Boot Before Fastlane Only When Fully Booted
- The workflows pre-boot (`prepare-appstore.yml` "Clean and pre-boot simulator") and wait with `xcrun simctl bootstatus "$UDID" -b`; this prevented DTServiceHub races (`documentation/learnings/watchos-ci-timeout-uitests.md`)
- What races is a `simctl boot` without waiting: Fastlane starts while the device is half-booted
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

### Booting Without Waiting
```bash
# BAD: Fastlane starts while the device is still booting
xcrun simctl boot "$UDID"
bundle exec fastlane snapshot

# GOOD: as in prepare-appstore.yml
UDID=$(.github/scripts/resolve-simulator.sh iOS "iPhone 17 Pro Max")
xcrun simctl boot "$UDID" 2>/dev/null || true
xcrun simctl bootstatus "$UDID" -b
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
