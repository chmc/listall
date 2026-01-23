# ListAll MCP Visual Verification Setup Guide

Enable Claude to visually verify its own UI work across all ListAll platforms (macOS, iOS, iPadOS, watchOS) without requiring manual user verification.

## Overview

The ListAll MCP server provides tools for Claude to:

- **Screenshot** - Capture current app state on macOS and simulators
- **Launch** - Start apps on macOS and simulators
- **Interact** - Click, type, swipe, and query UI elements
- **Diagnose** - Check permissions and setup status

This creates a feedback loop where Claude can implement UI changes, visually verify the results, and iterate until the implementation matches the intended design.

## Prerequisites

| Requirement | Version | Notes |
|-------------|---------|-------|
| macOS | 14.0+ | Sonoma or later required |
| Xcode | 16+ | With iOS 17+ simulators installed |
| Swift | 6.0+ | Included with Xcode 16 |
| Claude Code | Latest | MCP server support required |

## Installation

### 1. Build the MCP Server

```bash
cd Tools/listall-mcp
swift build -c release
```

The release binary will be at:
```
Tools/listall-mcp/.build/release/listall-mcp
```

### 2. Pre-build XCUITest Runner (for simulator interactions)

Simulator interactions require a pre-built XCUITest runner. Build it once:

```bash
cd ListAll
xcodebuild build-for-testing \
    -project ListAll.xcodeproj \
    -scheme ListAll \
    -sdk iphonesimulator \
    -destination 'platform=iOS Simulator,name=iPhone 16 Pro'
```

This creates `ListAllUITests-Runner.app` in DerivedData which enables fast simulator interactions.

**Rebuild when**: You modify `ListAllUITests/MCPCommandRunner.swift` or the UITests target.

### 3. Configure Claude Code

Add the MCP server to your project-level settings.

**Option A: Project Settings (Recommended)**

Create or edit `.claude/settings.local.json`:

```json
{
  "mcpServers": {
    "listall": {
      "command": "/Users/aleksi/source/listall/Tools/listall-mcp/.build/release/listall-mcp"
    }
  }
}
```

**Option B: Global Settings**

Edit `~/.claude/settings.json`:

```json
{
  "mcpServers": {
    "listall": {
      "command": "/path/to/listall/Tools/listall-mcp/.build/release/listall-mcp"
    }
  }
}
```

**Important**: Use an absolute path to the binary.

### 4. Grant macOS Permissions (one-time)

The MCP server requires two macOS permissions for full functionality:

#### Screen Recording (for macOS screenshots)

1. Open **System Settings**
2. Navigate to **Privacy & Security > Screen Recording**
3. Click **+** and add your terminal app (Terminal, iTerm2, etc.)
4. Enable the checkbox for your terminal
5. **Restart your terminal** after granting

#### Accessibility (for macOS interactions)

1. Open **System Settings**
2. Navigate to **Privacy & Security > Accessibility**
3. Click **+** and add your terminal app
4. Enable the checkbox for your terminal
5. **Restart your terminal** after granting

**Note**: Simulator operations do NOT require any permissions - they use `simctl` and XCUITest.

### 5. Verify Setup

After restarting Claude Code, run the diagnostics tool:

```
Call listall_diagnostics to check the setup
```

Expected output when everything is configured:

```
=== ListAll MCP Visual Verification Diagnostics ===

PERMISSIONS:
  Screen Recording: GRANTED
  Accessibility: GRANTED

SIMULATORS:
  Booted: 0
  Available: 45 devices
  iOS/iPadOS: 40 devices
  watchOS: 5 devices

APP BUNDLES:
  ListAllMac: FOUND at /Applications/ListAllMac.app
  ListAll iOS: FOUND at ~/Library/Developer/Xcode/DerivedData/.../ListAll.app
  XCUITest Runner: FOUND at ~/Library/Developer/Xcode/DerivedData/.../ListAllUITests-Runner.app

XCODE:
  Version: 16.2
  xcodebuild: /usr/bin/xcodebuild
  xcrun: /usr/bin/xcrun
  simctl: Available (via xcrun simctl)
  Developer Path: /Applications/Xcode.app/Contents/Developer

OVERALL STATUS: READY
  All checks passed. The MCP server is ready for use.
```

## Available Tools

### Diagnostics

| Tool | Description |
|------|-------------|
| `listall_diagnostics` | Check permissions, simulators, app bundles, and Xcode setup |

### Simulator Management

| Tool | Description |
|------|-------------|
| `listall_list_simulators` | List available iOS/iPadOS/watchOS simulators with UDIDs |
| `listall_boot_simulator` | Boot a simulator by UDID |
| `listall_shutdown_simulator` | Shutdown a simulator (or all with `udid: "all"`) |

### Screenshot & Launch

| Tool | Description | Platform |
|------|-------------|----------|
| `listall_screenshot` | Take simulator screenshot (returns base64 PNG) | Simulators |
| `listall_screenshot_macos` | Take macOS app window screenshot | macOS |
| `listall_launch` | Launch app in simulator | Simulators |
| `listall_launch_macos` | Launch macOS app | macOS |

### Interaction

| Tool | Description | macOS | Simulators |
|------|-------------|-------|------------|
| `listall_click` | Click/tap a UI element | Accessibility API | XCUITest |
| `listall_type` | Enter text into element | Accessibility API | XCUITest |
| `listall_swipe` | Scroll/swipe gesture | Accessibility API | XCUITest |
| `listall_query` | List UI elements | Accessibility API | XCUITest |

### Permission Check

| Tool | Description |
|------|-------------|
| `listall_check_macos_permissions` | Check Screen Recording and Accessibility permissions |

## Usage Examples

### Example 1: Verify macOS UI Change

After implementing a UI change on macOS:

```
1. Launch ListAllMac
2. Take a screenshot to see the current state
3. Verify the implementation matches the design
```

Tool calls:
```json
// Step 1: Launch the app
{ "tool": "listall_launch_macos", "args": { "app_name": "ListAllMac" } }

// Step 2: Take screenshot
{ "tool": "listall_screenshot_macos", "args": { "app_name": "ListAllMac" } }
```

### Example 2: Test iOS App Flow

Verify a complete user flow on iOS simulator:

```
1. List simulators to find iPhone UDID
2. Boot the simulator
3. Launch ListAll app
4. Take screenshot of initial state
5. Click on "Add List" button
6. Type list name
7. Take screenshot to verify
```

Tool calls:
```json
// Step 1: Find simulators
{ "tool": "listall_list_simulators", "args": { "device_type": "iPhone", "state": "all" } }

// Step 2: Boot simulator
{ "tool": "listall_boot_simulator", "args": { "udid": "E089C20E-308F-4B20-A1A6-8727FB737ED3" } }

// Step 3: Launch app
{ "tool": "listall_launch", "args": {
    "udid": "booted",
    "bundle_id": "io.github.chmc.ListAll"
} }

// Step 4: Screenshot
{ "tool": "listall_screenshot", "args": { "udid": "booted" } }

// Step 5: Query elements to find button
{ "tool": "listall_query", "args": {
    "simulator_udid": "booted",
    "bundle_id": "io.github.chmc.ListAll",
    "role": "button"
} }

// Step 6: Click add button
{ "tool": "listall_click", "args": {
    "simulator_udid": "booted",
    "bundle_id": "io.github.chmc.ListAll",
    "identifier": "addListButton"
} }

// Step 7: Type text
{ "tool": "listall_type", "args": {
    "simulator_udid": "booted",
    "bundle_id": "io.github.chmc.ListAll",
    "text": "Groceries",
    "identifier": "listNameTextField"
} }

// Step 8: Verify result
{ "tool": "listall_screenshot", "args": { "udid": "booted" } }
```

### Example 3: Query UI Elements

Discover accessibility identifiers for interaction:

```json
// macOS - hierarchical tree
{ "tool": "listall_query", "args": {
    "app_name": "ListAllMac",
    "format": "tree",
    "depth": 3
} }

// Simulator - flat list filtered by type
{ "tool": "listall_query", "args": {
    "simulator_udid": "booted",
    "bundle_id": "io.github.chmc.ListAll",
    "role": "button"
} }
```

## Performance Expectations

| Operation | macOS | Simulators |
|-----------|-------|------------|
| Screenshot | ~500ms | ~1s |
| Click | ~100ms | ~5-10s |
| Type | ~200ms | ~5-10s |
| Swipe | ~300ms | ~5-10s |
| Query | ~200ms | ~5-10s |

Simulator interactions are slower because they use XCUITest via xcodebuild.

## Troubleshooting

### "Screen Recording permission not granted"

1. Open System Settings > Privacy & Security > Screen Recording
2. Add your terminal app
3. Enable the checkbox
4. **Restart your terminal completely** (Cmd+Q, then reopen)

### "Accessibility permission not granted"

1. Open System Settings > Privacy & Security > Accessibility
2. Add your terminal app
3. Enable the checkbox
4. **Restart your terminal completely**

### "XCUITest Runner not found"

Rebuild the test target:

```bash
cd ListAll
xcodebuild build-for-testing \
    -project ListAll.xcodeproj \
    -scheme ListAll \
    -sdk iphonesimulator \
    -destination 'platform=iOS Simulator,name=iPhone 16 Pro'
```

### "No simulators are booted"

Boot a simulator before using screenshot or interaction tools:

```json
{ "tool": "listall_boot_simulator", "args": { "udid": "SIMULATOR_UDID" } }
```

Or use Simulator.app to boot manually.

### "Application not found or has no visible windows"

For macOS screenshots:
1. Make sure the app is running
2. Make sure the app has at least one visible window (not minimized)
3. Use the exact app name or bundle ID

### Simulator interactions timeout

Possible causes:
1. XCUITest runner needs rebuild (see above)
2. App crashed during interaction
3. Element not found (check identifier/label)

Debug by running the diagnostics tool to verify setup.

## Bundle Identifiers

| App | Bundle ID |
|-----|-----------|
| ListAll iOS | `io.github.chmc.ListAll` |
| ListAll watchOS | `io.github.chmc.ListAll.watchkitapp` |
| ListAllMac | `io.github.chmc.ListAllMac` |

## Architecture

```
Claude Code <--> stdio <--> listall-mcp (Swift)
                                |
              +-----------------+-----------------+
              v                 v                 v
          macOS App         iOS Sim           Watch Sim
        (Accessibility)    (XCUITest)        (XCUITest)
```

**macOS interactions** use the Accessibility API directly - fast but requires permissions.

**Simulator interactions** use XCUITest bridge:
1. MCP server writes command to `/tmp/listall_mcp_command.json`
2. Invokes `xcodebuild test-without-building` for MCPCommandRunner
3. XCUITest reads command, executes action, writes result
4. MCP server reads result and returns to Claude

## File Locations

| File | Description |
|------|-------------|
| `Tools/listall-mcp/` | MCP server Swift package |
| `Tools/listall-mcp/.build/release/listall-mcp` | Release binary |
| `ListAll/ListAllUITests/MCPCommandRunner.swift` | XCUITest command runner |
| `/tmp/listall_mcp_command.json` | Command file (runtime) |
| `/tmp/listall_mcp_result.json` | Result file (runtime) |
| `.listall-mcp/` | Screenshot storage (gitignored) |

## Screenshot Storage

Screenshots are automatically saved to timestamped folders for debugging history:

```
.listall-mcp/
├── 260121-143045-button-component/   # Context-based naming
│   └── screenshot-12345.png
├── 260121-143100-ios/                # Platform fallback
│   └── screenshot-67890.png
└── 260121-143200-macos/
    └── screenshot-listallmac-11111.png
```

**Folder Naming**: `YYMMDD-HHMMSS-{context}` where:
- `YYMMDD-HHMMSS` is the timestamp (e.g., `260121-143045` = Jan 21, 2026 at 14:30:45)
- `{context}` is either the provided context parameter or the platform (ios, macos, watch)

**Important**: Screenshots are NOT deleted - history is valuable for debugging. The `.listall-mcp/` folder is gitignored to prevent committing screenshots.

## Version History

| Version | Changes |
|---------|---------|
| 0.5.0 | Added screenshot storage with timestamped folders |
| 0.4.0 | Full MCP server with macOS + simulator support |
| 0.3.0 | Added XCUITest bridge for simulator interactions |
| 0.2.0 | Added macOS Accessibility API support |
| 0.1.0 | Initial echo tool prototype |

---

**End of Guide**
