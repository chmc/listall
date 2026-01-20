---
title: Screenshot Validation TDD Implementation
date: 2025-12-19
severity: LOW
category: macos
tags: [tdd, screenshot-validation, testing, red-green-refactor]
symptoms: ["Too small screenshots", "Blank or corrupt screenshots", "Invalid App Store submissions"]
root_cause: Need systematic validation of screenshot images before submission
solution: TDD implementation with size and file size validation rules
files_affected: [ListAllMac/Services/Screenshots/ScreenshotValidator.swift, ListAllMacTests/ScreenshotValidationTests.swift]
related: [phase3-integration-tests-tdd.md, phase4-e2e-refactoring.md]
---

## Problem

Need to validate screenshot images to detect:
- Too small screenshots (< 800x600 pixels)
- Blank or corrupt screenshots (suspicious file sizes)
- Invalid screenshots that would fail App Store submission

## TDD Process

### RED Phase
Created 10 tests covering size validation, file size validation, blank detection, and edge cases. Stub returned `.valid` always.

### GREEN Phase
Implemented validation:

```swift
func validate(image: ScreenshotImage) -> ScreenshotValidationResult {
    if !isValidSize(image.size) {
        return .invalid(.tooSmall)
    }
    if !isValidFileSize(image.data.count, for: image.size) {
        return .invalid(.suspiciousFileSize)
    }
    return .valid
}
```

## Validation Rules

| Rule | Threshold | Purpose |
|------|-----------|---------|
| Minimum dimensions | 800x600 | App Store requirement |
| File size heuristic | ~0.01 bytes/pixel | Detect blank/corrupt images |

## Results

- 10/10 tests passing
- Test execution: ~5ms total
- 100% coverage of ScreenshotValidator

## Key Learnings

1. **RED -> GREEN is Powerful** - Seeing tests fail first confirms they work
2. **Minimal Implementation First** - Don't over-engineer in GREEN phase
3. **Test Infrastructure Pays Off** - MockScreenshotImage enabled fast, deterministic tests
4. **Domain Knowledge Matters** - 800x600 minimum from App Store guidelines
