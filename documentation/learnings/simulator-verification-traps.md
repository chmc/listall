---
title: Simulator and MCP Verification Traps (Evidence Log)
date: 2026-11-06
type: guide
category: testing
tags:
  - visual-verification
  - listall-mcp
  - simulator
  - watch-connectivity
  - escalation-ladder
use_when:
  - An MCP tool or simulator step fails during verification
  - You are about to report something as "not verifiable"
files_affected:
  - .claude/skills/visual-verification/SKILL.md
  - .claude/hooks/mcp-failure-ladder.sh
  - .claude/hooks/verification-gap-check.sh
related:
  - mcp-watch-xctestrun-naming.md
  - watchos-initial-sync-request.md
---

## Overview

Each trap below was observed in session 1881fcf4 (2026-11-06, watch initial sync work) and nearly led to a false
"cannot verify" report. The Known traps table in the visual-verification skill links here for the evidence.

## Quick Reference

| Symptom | Cause | Action |
|---------|-------|--------|
| `listall_screenshot_macos`: "not found or has no visible windows" | Screenshot sent in the same parallel batch as `listall_launch_macos` (UITEST_MODE quits the app first) | Screenshot only after the launch result; retry |
| `listall_diagnostics`: "Screen Recording: NOT GRANTED" | Any ScreenCaptureKit error was reported as NOT GRANTED | Try `listall_screenshot_macos`; it is the real test |
| Watch `listall_click`: "build-for-testing did not generate xctestrun file" | Xcode 26.6 names the watch file `..._iphonesimulator...` | Fixed; see mcp-watch-xctestrun-naming.md |
| simctl: "Unable to lookup in current state: Shutdown" right after `xcodebuild test` | The test run left the paired simulators shut down | Boot both again before MCP steps |
| `listall_screenshot`: "Command timed out after 30 seconds" | Simulator unresponsive after a test run | `listall_shutdown_simulator(udid: all)`, boot, relaunch |
| Watch app launch fails with FBSOpenApplicationServiceErrorDomain code=4 after installing the iOS app | `simctl install` of the iOS app did not install the embedded watch app | `simctl install <watch UDID> Debug-watchsimulator/ListAllWatch Watch App.app` |
| `-destination "name=iPhone 17 Pro"` builds for an unpaired device | Several runtimes/devices share the name | Use `id=<UDID>` from `xcrun simctl list pairs` |
| iOS WCSession "activated" ~56 s after boot (15:26:56 → 15:27:52) | Slow simulator WatchConnectivity start | Wait for the log line; queued requests are delivered then |
| Watch never receives `transferUserInfo` (5 transfers, 0 delivered; iOS `companionappd` logs "Got success sending") | Not supported between simulators (Apple docs) | Cover with a round-trip test; final check on a device |

## Details

### Hooks (live-verified 2026-11-06 after a Claude Code restart)

- Hooks in `.claude/settings.json` load at session start only: a hook added mid-session did not fire until restart.
- `mcp-failure-ladder.sh` (PostToolUseFailure, `mcp__listall__.*`): fired on a `listall_screenshot_macos` error and the
  hint appeared next to the tool result.
- `verification-gap-check.sh` (Stop): fired once on an answer with "ei voitu todentaa" and no `Kokeiltu:` line; the
  follow-up answer with `Kokeiltu:` lines ended the turn.
- AskUserQuestion does not end the turn: with a trigger phrase in the text before the question, no Stop marker was
  created while waiting for the answer (marker count stayed 1). Stop fires only at the real end of the turn.

### Escalation ladder

Before reporting any of these as a limitation, follow "When Something Fails" in the visual-verification skill:
exact error → timing/state → tool source → learnings → two alternative paths → report with `Kokeiltu:` lines.
