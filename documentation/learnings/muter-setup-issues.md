---
title: Muter Mutation Testing Setup Issues
date: 2026-02-24
severity: HIGH
category: testing
tags:
  - muter
  - mutation-testing
  - homebrew
  - simulator
  - xctestrun
  - deriveddata
symptoms:
  - Muter segfaults immediately on launch (exit code 139)
  - "Could not find xctestrun file at path" error
  - OS=latest fails to resolve in Muter's build-for-testing step
root_cause: Homebrew Muter binary is broken; OS=latest destination causes stale DerivedData issues when Muter copies project
solution: Build Muter from source; use dynamic simulator UDID resolution instead of OS=latest
files_affected:
  - muter.ios.conf.yml
  - muter.macos.conf.yml
  - muter.watchos.conf.yml
  - scripts/run-muter.sh
---

## Problem

Three issues discovered setting up Muter v16 for mutation testing:

1. **Homebrew binary segfaults** — `brew install muter-mutation-testing/formulae/muter` installs a broken binary that crashes with SIGSEGV (exit 139) on any command
2. **xctestrun not found** — Muter copies the project directory including stale DerivedData, then runs `build-for-testing` inside the copy. With `OS=latest`, the build silently fails to produce xctestrun files
3. **No `-c` flag** — Muter v16 only reads `muter.conf.yml` from the current directory; there's no way to specify a custom config path

## Root Cause

1. Homebrew formula builds from source with different flags/environment than local `make install` — known issue (#275)
2. Muter's `buildForTestingArguments` removes `test` and adds `-derivedDataPath DerivedData clean build-for-testing`. When the copied project already has a `DerivedData/` directory with stale content, the build can fail silently
3. Config YAML key for timeout is `mutationTestTimeout` (not `testSuiteTimeout` as documented in some sources) — based on `CodingKeys` in `MuterConfiguration.swift`

## Solution

1. Build from source: `git clone ... && swift build -c release && cp .build/release/muter ~/bin/`
2. Use platform-specific configs with destination placeholders (`IOS_DESTINATION_PLACEHOLDER`, `WATCHOS_DESTINATION_PLACEHOLDER`) resolved by `scripts/run-muter.sh` using `xcrun simctl list devices available -j` + UDID lookup
3. Wrapper script copies the resolved config to `muter.conf.yml` before each run, with cleanup via trap

## Prevention

- [ ] Pin Muter version in CI (build from specific tag, not master HEAD)
- [ ] If Homebrew Muter gets fixed, switch back to `brew install`
- [ ] Monitor Muter releases for `-c` flag support

## Key Insight

> Muter's Homebrew distribution is broken — always build from source and use UDID-based simulator destinations instead of name+OS for reliable mutation testing.
