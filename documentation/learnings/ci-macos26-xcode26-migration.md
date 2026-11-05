---
title: CI Migration to macos-26 / Xcode 26.6 with Single-Source Toolchain Pinning
date: 2026-11-05
severity: CRITICAL
category: ci-cd
tags:
  - github-actions
  - macos-runner
  - xcode-version
  - simulator-runtime
  - muter
  - mutation-testing
  - disabled-inactivity
  - app-store-sdk-requirement
symptoms:
  - Every macOS job fails or is cancelled after 2026-11-02 (macos-14 image retired; brownouts in October)
  - TestFlight upload would be rejected (ITMS-90725) when built with Xcode 16.1
  - Mutation Testing sharded jobs (-A/-B) fail in ~20s with exit code 64
  - Scheduled workflows show state disabled_inactivity and cannot be dispatched
  - "iPhone 16 Pro" / "Apple Watch Series 10 (46mm)" simulators not found on new runner image
root_cause: macos-14 runner retired, Apple requires Xcode 26 SDKs since 2026-04-28, Muter --operators takes space-separated values, and GitHub disables schedules after 60 days without commits
solution: Move all jobs to macos-26 with Xcode from .xcode-version via a composite action, resolve simulators on the Xcode-matched runtime, fix Muter syntax, re-enable workflows
files_affected:
  - .xcode-version
  - .ruby-version
  - .github/actions/setup-xcode/action.yml
  - .github/scripts/resolve-simulator.sh
  - .github/workflows/*.yml
  - scripts/run-muter.sh
  - fastlane/Fastfile
  - fastlane/Snapfile
  - fastlane/WatchSnapfile
  - .github/scripts/generate-screenshots-local.sh
  - .github/scripts/local-preflight-check.sh
related: []
---

## Problem

All CI workflows broke around November 2026. GitHub retired the `macos-14` image (2026-11-02). Apple requires uploads built with Xcode 26 and the iOS/watchOS 26 SDKs (since 2026-04-28), so even a working runner with Xcode 16.1 could not ship to TestFlight. The new image has no iPhone 16 / iPad M4 / Watch Series 10 simulators. Separately, mutation testing shards had failed since they were introduced, and the scheduled workflows had been auto-disabled.

## Root Cause

1. **Runner + SDK:** hardcoded `runs-on: macos-14` and `/Applications/Xcode_16.1.app` in 7 workflows.
2. **Runtime drift:** resolvers picked "newest runtime first" or `OS=latest`, which can choose a runtime the selected Xcode can't use (macos-26 maps iOS 26.2 → Xcode 26.2/26.3, 26.5 → Xcode 26.5/26.6). Earlier version mismatches had already produced "multiple devices matched" workarounds.
3. **Muter exit 64:** `--operators` is declared `parsing: .upToNextOption` and parses each value with `MutationOperator.Id(rawValue:)`.

```bash
# BAD - one value "A,B" fails rawValue -> ArgumentParser usage error (exit 64)
muter run --operators RelationalOperatorReplacement,RemoveSideEffects
# GOOD - separate values
muter run --operators RelationalOperatorReplacement RemoveSideEffects
```

4. **Schedules:** GitHub disables scheduled workflows after 60 days with no repository activity (`disabled_inactivity`); a disabled workflow cannot be run via `workflow_dispatch` either.

## Solution

- `.xcode-version` (26.6) and `.ruby-version` (3.3.10) are the single source of truth; `ruby/setup-ruby` reads `.ruby-version` when `ruby-version` is omitted.
- `.github/actions/setup-xcode` selects `/Applications/Xcode_$(cat .xcode-version).app`. It fails if the version is missing or mismatched, and logs `sw_vers`, the Xcode version, the simulator SDKs and the runtimes.
- `.github/scripts/resolve-simulator.sh <iOS|watchOS> "<exact name>"` derives the runtime from `xcrun --sdk <sim> --show-sdk-version`, matches names exactly, and creates the device if missing. It is used by workflows, `run-muter.sh` and `local-preflight-check.sh`. fastlane `snapshot` already defaults to the selected Xcode's SDK version.
- Standard devices are iPhone 17 Pro, iPhone 17 Pro Max, iPad Pro 13-inch (M5) and Apple Watch Series 11 (46mm). Screen sizes are identical to the 16 Pro Max, M4 and Series 10 46mm, so normalization and frames are unchanged.
- DerivedData cache keys include `hashFiles('.xcode-version')` so caches from a different Xcode are never restored.
- `nick-fields/retry` bumped to v4 (node24).
- Re-enable schedules with `gh workflow enable "<name>"`.

## Prevention

- [ ] Bump Xcode by editing only `.xcode-version`. Check the runner-images README SDK table first, because the runtime must exist on the image.
- [ ] Keep the local dev VM on the same macOS/Xcode as the runner image. Xcode 26.6 only supports macOS 26.2–26.x, so not macOS 27.
- [ ] Watch GitHub runner-image deprecation notices and Apple "Upcoming requirements". The next SDK step is due April 2027.
- [ ] `test-generate-screenshots-local.sh` must keep `SCREENSHOTS_VALIDATE_ONLY=1`. Without it, its end-to-end invocations deleted the committed App Store screenshots.

## Key Insight

Pin the Xcode once and derive everything else from it (runtime, simulator, caches). Then local and CI cannot drift, and a toolchain bump is a one-line change.
