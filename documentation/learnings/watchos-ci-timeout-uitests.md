---
title: watchOS CI Timeout from UI Tests in Test Plan
date: 2026-02-05
severity: HIGH
category: ci-cd
tags:
  - watchos
  - ci-timeout
  - xctestplan
  - uitests
  - github-actions
  - simulator-hang
symptoms:
  - watchOS CI job exceeds 25-minute timeout
  - "Run watchOS tests" step hangs for 25+ minutes
  - DTServiceHub error in CI logs
  - "Failed to send signal 19 to process" error
root_cause: watchOS test plan included XCUITest integration tests (MCPCommandRunnerTests) that hang on CI runners
solution: Remove UI test target from test plan, add -skip-testing flag, pre-boot simulator
files_affected:
  - .github/workflows/ci.yml
  - ListAll/ListAllWatch Watch App.xctestplan
---

## Problem

The watchOS CI job consistently timed out at 25 minutes. The "Run watchOS tests" step would hang indefinitely, with no output for 14+ minutes before a DTServiceHub crash appeared. This started after commit `d70db295` which added `MCPCommandRunnerTests.swift`.

## Root Cause

The `.xctestplan` file included both unit tests AND UI tests targets, despite a CI comment saying "Test plan runs unit tests only". The `MCPCommandRunnerTests` (37 XCUITest integration tests) launch the full watchOS app with 45-second timeouts and `Thread.sleep()` calls. watchOS simulator XCUITest execution is unreliable on GitHub Actions runners, causing hangs.

```json
// BAD - test plan includes UI tests
"testTargets": [
  { "name": "ListAllWatch Watch AppTests" },
  { "name": "ListAllWatch Watch AppUITests" }  // <-- hangs on CI
]

// GOOD - unit tests only
"testTargets": [
  { "name": "ListAllWatch Watch AppTests" }
]
```

## Solution

1. Remove `ListAllWatch Watch AppUITests` from the test plan (primary fix)
2. Add `-skip-testing:"ListAllWatch Watch AppUITests"` to xcodebuild (belt-and-suspenders)
3. Pre-boot watchOS simulator with `simctl boot` + `simctl bootstatus -b` before build/test
4. Add step-level `timeout-minutes: 10` on the test step
5. Reduce job timeout from 25 to 15 minutes
6. Extract simulator UDID resolution into shared step via `GITHUB_OUTPUT`

Result: watchOS job time dropped from 25+ minutes (timeout) to 4 minutes 12 seconds.

## Prevention

- [ ] Always verify test plan contents match CI comments
- [ ] XCUITest integration tests should never be in CI test plans for watchOS
- [ ] Add step-level timeouts on test steps (not just job-level)
- [ ] Pre-boot simulators before build/test to prevent DTServiceHub races

## Key Insight

> watchOS XCUITest is fundamentally unreliable on CI runners; always exclude UI tests from watchOS CI and use step-level timeouts as a safety net.
