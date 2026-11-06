---
name: visual-verification
description: Verify implementations work by using ListAll apps via MCP tools. Close the feedback loop after any code change.
---

# Implementation Verification

These tools let you verify your code works by actually using the app. Launch it, interact with it, see the result. If wrong, fix and try again.

## Visual-First Navigation Process

**CRITICAL**: Use screenshots as primary navigation input, not just passive verification. Understand the UI visually BEFORE interacting.

### Step 1: Screenshot Analysis (Visual Context)

Before ANY interaction, take a screenshot and identify:

| Aspect | What to Identify |
|--------|------------------|
| **Platform** | iOS, macOS, watchOS |
| **Structure** | Modal sheet? Navigation stack? Tab bar? Sidebar? |
| **Layout zones** | Top bar, content area, bottom bar |
| **Visual hierarchy** | What's emphasized (color, size, position)? |

**iOS Sheet Detection Signals:**
- Rounded corners at top
- Dimmed/translucent background behind
- Drag indicator at top-center
- Title bar with Cancel (left) and Create/Save (right)

### Step 2: Apply HIG Pattern Recognition

Match visual patterns to known iOS/macOS conventions:

| Visual Pattern | Meaning | Action |
|----------------|---------|--------|
| Top-right button in nav bar | Primary action (Create, Save, Done) | Click to complete task |
| Top-left button in nav bar | Secondary action (Cancel, Back) | Click to dismiss/go back |
| Dimmed overlay + rounded modal | Sheet presentation | Actions are scoped to sheet |
| Back chevron + title | Navigation stack | Swipe right or tap back |
| Bottom tab bar (3-5 icons) | Main navigation | Tap to switch sections |

### Step 3: Scoped Query for Precision

After visual analysis, query ONLY what's needed:
```
Visual: "I see a sheet with Create button in top-right"
Query: Find button with label "Create" in navigation bar area
Action: Click the specific element found
```

### Step 4: Execute with Context

Click/type based on:
- Element role (button → click, textField → type)
- Expected visual feedback (sheet dismisses, list updates)
- Next state prediction (what should appear after action)

### Step 5: Visual Verification Loop

After action, screenshot and verify:
- Did expected change occur? (sheet closed, item added)
- Any error states? (validation message, loading spinner)
- Ready for next action?

### Example: "Add Peruna" Workflow

```
1. Screenshot iPhone → "I see a list view with items"
2. Visual analysis → "There's an 'Item' button to add new items"
3. Click 'Item' → Opens sheet
4. Screenshot → "I see a modal sheet with text field and Create button in top-right nav bar"
5. Type 'Peruna' in text field
6. Visual analysis → "Create button is in top-right corner of sheet's navigation bar"
7. Click 'Create' (top-right nav bar button)
8. Screenshot → "Sheet closed, Peruna appears in list"
```

## The Loop

```
screenshot → understand context → interact → screenshot → validate → iterate if wrong
```

| Screenshot Shows | Action |
|------------------|--------|
| Expected behavior | Done (or next platform) |
| Wrong behavior | Fix → rebuild → try again |

When done: `listall_quit_macos` (quit) or `listall_hide_macos` (keep running hidden)

**Never send `listall_launch*` and `listall_screenshot*` in the same parallel batch.** With `UITEST_MODE` the launch quits the app first, so a parallel screenshot runs while the app is closing ("no visible windows").

## When Something Fails

A failed tool or a missing result is a problem to investigate, not a limitation to report. Before writing "can't verify" / "not possible":

1. **Read the exact error text**, not a summary. `listall_diagnostics` output is a hint, not proof: its "Screen Recording: NOT GRANTED" was wrong while screenshots worked.
2. **Rule out timing and state**: wait for the condition (window, boot, session activation) and retry once.
3. **Read the tool's source** if it is in the repo: `grep` the error message in `Tools/listall-mcp/Sources` and see what it actually checks.
4. **Search** `documentation/learnings/` and the Known traps table below; then Context7 or the web for the exact message.
5. **Try at least two alternative paths** within the rules: another MCP tool, an `xcodebuild test` (unit/UI), a round-trip or integration test that covers everything except the unreachable part, a real device.
6. **Report** with one `Kokeiltu:` line per item (command or tool + result), the remaining risk, and what the user can do.

**Shortcut**: if a learnings file already documents the limitation with evidence, cite it and skip steps 2–5.

### Known Traps

Only traps observed with evidence; see `documentation/learnings/simulator-verification-traps.md` for the log lines.

| Symptom | Action |
|---------|--------|
| macOS screenshot "not found or has no visible windows" | Window not open yet: screenshot after the launch result, never in parallel; retry |
| Diagnostics "Screen Recording: NOT GRANTED" | Try `listall_screenshot_macos`; it is the authoritative test |
| Watch click "build-for-testing did not generate xctestrun file" | See `mcp-watch-xctestrun-naming.md`; rebuild MCP + restart Claude Code |
| "Unable to lookup in current state: Shutdown" after `xcodebuild test` | Boot the simulators again |
| Screenshot "Command timed out after 30 seconds" | `listall_shutdown_simulator(udid: all)`, boot, relaunch |
| Watch app launch fails with FBSOpenApplicationServiceErrorDomain code=4 | Install `Debug-watchsimulator/ListAllWatch Watch App.app` on the watch separately |
| `name=iPhone 17 Pro` destination hits the wrong device | Use `id=<UDID>` from `xcrun simctl list pairs` |
| iOS WCSession activates ~1 min after boot | Wait for "WCSession activated" in the log before judging sync |
| Watch never receives `transferUserInfo` | Not supported between simulators: round-trip test + real device |

## Fresh Build Before Verification

**Clean once, then build every platform without `clean`.** `xcodebuild clean` wipes the whole shared `Build/Products` folder, not just its own scheme. A `clean build` per platform deletes the previous platform's app and the XCUITest runner, which then forces a slow rebuild (seen 2026-11-06: the macOS `clean build` removed `Debug-iphonesimulator/ListAll.app` and `ListAllUITests-Runner.app`).

```bash
# 1. Clean ONCE (only if code changed this session or DerivedData may be stale)
xcodebuild clean -project ListAll/ListAll.xcodeproj -scheme ListAll -quiet

# 2. macOS app (no clean)
xcodebuild build -project ListAll/ListAll.xcodeproj -scheme ListAllMac -destination "platform=macOS" -quiet

# 3. iOS app + XCUITest runner in one step (no clean); listall_query/click on simulators need the runner
xcodebuild build-for-testing -project ListAll/ListAll.xcodeproj -scheme ListAll \
  -destination "platform=iOS Simulator,name=iPhone 17 Pro" -quiet
```

Then run `listall_diagnostics`: every needed bundle under APP BUNDLES must say FOUND before you launch anything.

Rules:
- Never put `clean` in a per-platform loop, and never run `clean` after another platform has already been built.
- iOS uses `build-for-testing`, not `build`: plain `build` does not produce `ListAllUITests-Runner.app`.
- Never pass `-sdk iphonesimulator`. It forces the embedded watch app onto the iOS SDK, and install then fails with "WatchKit 2.0 app's UIDeviceFamily key does not specify that it's compatible with device family 4". `-destination` alone picks watchsimulator for the watch target.
- Builds share DerivedData, so run them one after another, not in parallel.

**Rebuilding the MCP server itself** (`Tools/listall-mcp`): `.mcp.json` runs `.build/debug/listall-mcp` straight from the repo. Back it up first (`cp -p Tools/listall-mcp/.build/debug/listall-mcp ~/listall-mcp.backup`). A failed build or a broken binary removes every `listall_*` tool. After a successful build, restart Claude Code. See `documentation/learnings/mcp-swift-sdk-xcode-26-6-build.md`.

## Tools

### Launch & Screenshot

```
# macOS
listall_launch_macos(app_name: "ListAll", launch_args: ["UITEST_MODE", "DISABLE_TOOLTIPS"])
listall_screenshot_macos(app_name: "ListAll", context: "feature-name")

# iOS/iPad Simulator
listall_boot_simulator(udid: "...")
listall_launch(udid: "booted", bundle_id: "io.github.chmc.ListAll", launch_args: ["UITEST_MODE", "DISABLE_TOOLTIPS"])
listall_screenshot(udid: "booted", context: "feature-name")

# watchOS Simulator
listall_boot_simulator(udid: "WATCH_UDID")
listall_launch(udid: "booted", bundle_id: "io.github.chmc.ListAll.watchkitapp", launch_args: ["UITEST_MODE"])
listall_screenshot(udid: "booted", context: "feature-name")
```

**Fresh Launch Behavior**: When using UITEST_MODE, the app is always terminated/quit before launching to ensure:
- Fresh test data initialization
- Clean state without stale data from previous runs

This happens automatically - you don't need to manually quit first.

### Interact

| Tool | Purpose |
|------|---------|
| `listall_query` | Discover element identifiers |
| `listall_click` | Tap/click element |
| `listall_type` | Enter text |
| `listall_swipe` | Scroll |

Works on macOS, iOS/iPad, and watchOS simulators. Note: watchOS interactions are slower (~10-30s per action) due to XCUITest bridge overhead.

**App Activation (macOS)**: Interaction tools automatically activate the target app before performing actions. This ensures keyboard/mouse events go to the correct application even if you're working in a different window.

### Cleanup

```
# Quit app (recommended when done)
listall_quit_macos(app_name: "ListAll")

# Or hide app (keep running for next iteration)
listall_hide_macos(app_name: "ListAll")

# To bring hidden app back, just re-launch:
listall_launch_macos(app_name: "ListAll", launch_args: [...])

# Shutdown simulators
listall_shutdown_simulator(udid: "all")
```

**Background launch**: Use `BACKGROUND` in launch_args for less intrusive verification:
```
listall_launch_macos(app_name: "ListAll", launch_args: ["UITEST_MODE", "BACKGROUND"])
```

### Diagnostics

Run `listall_diagnostics()` if tools aren't working.

## Platforms

Verify on every platform your change affects, and compare the screenshots for consistency:

| Platform | When required | Bundle ID | Screenshot |
|----------|---------------|-----------|------------|
| macOS | Shared or macOS code | `io.github.chmc.ListAll` | `listall_screenshot_macos` |
| iPhone | Shared or iOS code | `io.github.chmc.ListAll` | `listall_screenshot` (iPhone simulator) |
| iPad | UI that iPad shows | `io.github.chmc.ListAll` | `listall_screenshot` (iPad simulator) |
| watchOS | Watch app affected | `io.github.chmc.ListAll.watchkitapp` | `listall_screenshot` (Watch simulator) |

Launch iOS and macOS with `UITEST_MODE` and `DISABLE_TOOLTIPS` (deterministic test data, no feature tips covering the UI). The watch app only reads `UITEST_MODE`.

**If the `listall_*` tools are missing** from the session, stop and ask the user to restart Claude Code (the MCP server loads at startup). Don't substitute `screencapture` or `simctl io`: they capture whatever state the device is in, without the test data, the accessibility tree or the interaction tools, so they can't show that the change works.

## Context Naming

The `context` parameter groups screenshots. Name by what you're verifying: `add-item`, `dark-mode`, `button-fix`.

Screenshots save to `.listall-mcp/{timestamp}-{context}/`.
