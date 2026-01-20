---
title: macOS Settings Window Resizable
date: 2026-01-15
severity: HIGH
category: macos
tags: [swiftui, window, frame, accessibility, localization, settings]
symptoms: [content clipped with large text, truncated translations, users cannot resize]
root_cause: Fixed frame (width: 500, height: 350) prevented window resizing
solution: Changed to min/ideal constraints allowing user resizing
files_affected: [ListAllMac/Views/MacSettingsView.swift]
related: [macos-settings-sync-toggle-bug.md, macos-voiceover-accessibility.md, macos-image-gallery-size-presets.md]
---

## Problem

Settings window used fixed size `.frame(width: 500, height: 350)` causing:
- Accessibility users with large text could not see clipped content
- Longer localized strings (German, Finnish) were truncated
- Users could not resize to preference

## Solution

Changed to min/ideal constraints:

```swift
// Before (fixed - cannot resize)
.frame(width: 500, height: 350)

// After (resizable with constraints)
.frame(minWidth: 500, idealWidth: 550, minHeight: 350, idealHeight: 400)
```

| Constraint | Value | Purpose |
|------------|-------|---------|
| minWidth | 500 | Ensures tabs and form layout fit |
| idealWidth | 550 | Comfortable default with breathing room |
| minHeight | 350 | Ensures all sections visible |
| idealHeight | 400 | Room for longer localized strings |

## Key Pattern

### Resizable Windows with Constraints

```swift
// Good: Resizable with constraints
.frame(minWidth: 500, idealWidth: 550, minHeight: 350, idealHeight: 400)

// Good: Resizable with only minimum
.frame(minWidth: 400, minHeight: 300)

// Antipattern: Fixed size - window cannot resize
.frame(width: 500, height: 350)
```

**Why this works:**
- `minWidth/minHeight` prevents layout breakage
- `idealWidth/idealHeight` sets initial size
- No `maxWidth/maxHeight` allows expansion
- macOS automatically remembers user-adjusted size

### When to Use Fixed Size

Only for:
- Alert dialogs with fixed content
- Popovers with simple content
- Preview windows maintaining aspect ratio

## Test Coverage

17 tests: frame pattern verification, constraint validation, accessibility support, localization support, settings tabs functionality.
