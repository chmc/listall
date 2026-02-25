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

---

## Schemata Baseline Build Failure (2026-02-24)

### Problem

After fixing Tools/ exclusion and script error handling, iOS and macOS still fail with baseline build error:
```
DataRepository.swift:1342:5: error: missing return in instance method expected to return 'UserData'
```
The file is only 624 lines — line 1342 is inside Muter's expanded copy.

### Root Cause

Muter v16 uses **schemata-based mutation**: instead of applying one mutation at a time, it inserts ALL mutation variants into the file at once using conditional branches (`if ProcessInfo.processInfo.environment["MUTER_RUNNING_MUTANT"] == "id-N" { mutated } else { original }`). This expands DataRepository.swift from 624 to 1342+ lines.

The function `createOrUpdateUser(userID:) -> UserData` had returns inside both branches of an `if/else` within a `do` block, plus a return in `catch`. When Muter wraps these returns with conditional mutation switches, Swift's compiler can no longer prove all code paths return a value.

### Solution

Restructure functions that return non-optional values from do/catch blocks to have a guaranteed return OUTSIDE the do/catch:
```swift
do {
    // returns inside here
} catch {
    // fall through
}
return fallbackValue  // guaranteed return the compiler can always see
```

### Key Insight

> Muter v16 schemata mutations expand source files significantly. Functions with returns only inside do/catch branches can break. Always ensure a return exists at the function level outside do/catch for non-optional return types.

---

## stdout Buffering and Timeout Issues (2026-02-24)

### Problem

1. **No visible output**: `tee` piping (`muter run 2>&1 | tee muter-output.log`) causes Muter to buffer stdout because the pipe is not a tty. CI shows no Muter output for hours, making it impossible to tell if the run is progressing or hung.
2. **Timeout bypass**: `script -q` (used to fix buffering) wraps the command in a pseudo-tty that catches SIGTERM differently. GitHub Actions' `timeout-minutes: 360` failed to kill the process even after 6+ hours.

### Root Cause

Muter uses terminal escape codes for progress display (cursor movement with `[1A[1A[K`). When stdout is not a tty, it buffers output in large chunks. `tee` creates a pipe, not a tty. `script -q` creates a pseudo-tty (fixing buffering) but intercepts signals, preventing timeout.

### Solution

Use `script -q` for log capture (keeps output unbuffered) but add explicit timeout protection:
```yaml
- name: Run Muter (iOS)
  timeout-minutes: 360
  run: |
    chmod +x scripts/run-muter.sh
    script -q muter-output.log ./scripts/run-muter.sh ios ${{ github.event.inputs.muter_args }}
```

Note: The step-level `timeout-minutes` may also need a `timeout` command wrapper as backup.

### Key Insight

> Muter buffers stdout when not writing to a tty. Use `script -q` for pseudo-tty output, but be aware it may interfere with process signal handling.

---

## Performance on Free GitHub Runners (2026-02-25)

### Problem

Mutation testing is extremely slow on free GitHub macOS runners:
- **macOS**: ~10 min per mutant (29 mutants = ~280 min for 1 file)
- **iOS**: ~19 min per mutant (29 mutants = ~450+ min for 1 file, simulator overhead)
- **Full iOS run**: 24 files, ~486 mutants → estimated 160+ hours (impossible on single runner)

### Root Cause

Each mutant requires a full `xcodebuild test` invocation. On free GitHub runners (macos-14, likely 3-core M1), each test run takes 5-19 minutes depending on platform. The schemata approach still runs tests per-mutant via environment variable switching.

### Solution

Parallelization is essential. Split mutant files across multiple concurrent GitHub Actions jobs using Muter's `--files-to-mutate` flag. Each job independently:
1. Builds Muter (shared via artifact)
2. Runs a subset of files
3. Uploads its own report

### Key Insight

> Single-runner mutation testing is infeasible for projects with 400+ mutants on free GitHub runners. Must parallelize across multiple jobs using `--files-to-mutate`.
