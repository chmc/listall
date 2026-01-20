<!--
Severity: CRITICAL=crashes/data loss, HIGH=significant bugs, MEDIUM=minor bugs, LOW=improvements
Naming: kebab-case.md (e.g., cloudkit-sync-fix.md)
Search: grep -l "tag-name" documentation/learnings/*.md
-->
---
title: Short Descriptive Title
date: YYYY-MM-DD
severity: CRITICAL|HIGH|MEDIUM|LOW
category: cloudkit|coredata|swiftui|testing|ci-cd|macos|ios|watchos|fastlane
tags:
  - searchable-keyword
  - another-keyword
symptoms:
  - Observable symptom 1
  - Observable symptom 2
root_cause: One-line summary of why this happened
solution: One-line summary of the fix
files_affected:
  - path/to/file.swift
related:
  - other-learning.md
---

## Problem

2-3 sentence description of what went wrong and context.

## Root Cause

Concise technical explanation. Include minimal code if needed:

```swift
// BAD - causes the problem
badCode()

// GOOD - the fix
goodCode()
```

## Solution

Brief steps or code showing the fix.

## Prevention

- [ ] Checklist item to prevent recurrence
- [ ] Another preventive measure

## Key Insight

> One memorable sentence capturing the core learning.
