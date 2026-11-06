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

Verify on all platforms affected by your change:

| Platform | Bundle ID |
|----------|-----------|
| macOS | `io.github.chmc.ListAll` |
| iOS/iPad | `io.github.chmc.ListAll` |
| watchOS | `io.github.chmc.ListAll.watchkitapp` |

## Context Naming

The `context` parameter groups screenshots. Name by what you're verifying: `add-item`, `dark-mode`, `button-fix`.

Screenshots save to `.listall-mcp/{timestamp}-{context}/`.
