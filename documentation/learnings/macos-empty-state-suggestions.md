---
title: macOS Empty State with Sample List Templates
date: 2026-01-06
severity: LOW
category: macos
tags: [empty-state, ui, sample-data, localization, code-reuse]
symptoms:
  - Users see blank screen when no lists exist
  - Onboarding experience unclear
root_cause: Missing welcome/empty state UI for new users
solution: Implement empty state view with sample list templates, reusing shared SampleDataService
files_affected:
  - ListAllMac/Views/Components/MacEmptyStateView.swift
  - ListAllMac/Views/MacMainView.swift
  - ListAllMacTests/MacEmptyStateTests.swift
related: [macos-consistent-empty-states.md, macos-feature-tips-implementation.md, macos-proactive-feature-tips.md]
---

## Shared Service Reuse

`SampleDataService` works on both iOS and macOS:
```swift
let templates = SampleDataService.templates
let createdList = SampleDataService.saveTemplateList(template, using: dataManager)
```

## macOS-Specific UI Patterns

- Use `NSColor` system colors: `Color(NSColor.controlBackgroundColor)`
- Add hover effects with `.onHover` modifier
- Use `buttonStyle(.plain)` for custom-styled buttons
- Scale on hover: `.scaleEffect(isHovering ? 1.01 : 1.0)`

## Conditional Empty State Display

```swift
if dataManager.lists.isEmpty {
    MacListsEmptyStateView(...)  // Welcome with templates
} else {
    MacNoListSelectedView(...)   // Simple prompt
}
```

## Localization Support

Templates are fully localized through `LocalizationManager`:
```swift
static var templates: [SampleListTemplate] {
    let currentLanguage = LocalizationManager.shared.currentLanguage.rawValue
    return currentLanguage == "fi" ? finnishTemplates : englishTemplates
}
```

## Components Created

1. `MacListsEmptyStateView` - Welcome with sample templates
2. `MacSampleListButton` - Template creation button
3. `MacFeatureHighlight` - Feature highlight row
4. `MacNoListSelectedView` - No list selected prompt
5. `MacItemsEmptyStateView` - Empty items list state
6. `MacTipRow` - Usage hint row
