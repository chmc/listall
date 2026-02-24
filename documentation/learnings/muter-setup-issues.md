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

1. Build from source: `git clone ... && swift build -c release --product muter && cp .build/release/muter ~/bin/` (the `--product muter` flag is required to skip test targets that use `@testable import` and fail in release mode)
2. Use platform-specific configs with destination placeholders (`IOS_DESTINATION_PLACEHOLDER`, `WATCHOS_DESTINATION_PLACEHOLDER`) resolved by `scripts/run-muter.sh` using `xcrun simctl list devices available -j` + UDID lookup
3. Wrapper script copies the resolved config to `muter.conf.yml` before each run, with cleanup via trap

## Prevention

- [ ] Pin Muter version in CI (build from specific tag, not master HEAD)
- [ ] If Homebrew Muter gets fixed, switch back to `brew install`
- [ ] Monitor Muter releases for `-c` flag support

## Key Insight

> Muter's Homebrew distribution is broken — always build from source and use UDID-based simulator destinations instead of name+OS for reliable mutation testing.

---

## First CI Run Failures (2026-02-24)

### Problem

First real CI run failed on all 3 platforms. Multiple distinct issues:

1. **Tools/ pollution**: Muter discovered 300+ mutants in `Tools/listall-mcp/` (MCP server code not compiled by app targets). Mutating these causes build failures in the `listall_mutated/` copy.
2. **Error handling asymmetry**: `run_ios()` and `run_macos()` called bare `muter run` — non-zero exit kills script under `set -euo pipefail`. `run_watchos()` already captured exit codes correctly. In "all" mode, iOS failure kills before macOS/watchOS start.
3. **Coverage overhead**: macOS showed "Gathering coverage failed". Coverage is unnecessary for mutation testing.
4. **watchOS hang**: Muter hung for 49+ minutes with zero output during watchOS `muter run`. Likely build/discovery phase issue.
5. **No diagnostics on failure**: When Muter exits 255, no report is generated. Only raw CI logs available.

### Solution

- Add `- Tools/` to all config `exclude:` lists
- Fix `run_ios()`/`run_macos()` to capture exit codes: `muter run --skip-coverage "$@" || exit_code=$?`
- Add `--skip-coverage` to all `muter run` invocations
- Add `tee muter-output.log` + `PIPESTATUS[0]` in CI workflow for log capture as artifact

### Key Insight

> Muter scans all Swift files under the project root regardless of Xcode target membership — always explicitly exclude directories containing non-app code.
