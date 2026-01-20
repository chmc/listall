---
title: macOS Consistent Empty State Components
date: 2026-01-15
severity: MEDIUM
category: macos
tags: [swiftui, empty-state, ux, components, accessibility, localization]
symptoms: [inconsistent empty state messaging, simple inline view vs comprehensive component, poor user guidance]
root_cause: Two different empty state implementations - inline view vs dedicated component
solution: Created context-specific empty state components with three-way decision logic
files_affected: [ListAllMac/Views/MacMainView.swift, ListAllMac/Views/Components/MacEmptyStateView.swift]
related: [macos-empty-state-suggestions.md, task-12-12-clear-all-filters.md, macos-voiceover-accessibility.md]
---

## Problem

macOS app had inconsistent empty states:
- `MacItemsEmptyStateView` - comprehensive with tips
- Inline `emptyListView` - simple "No items in this list"

## Solution

Created context-specific components with three-way decision logic:

| Scenario | Component | Content |
|----------|-----------|---------|
| Empty list | `MacItemsEmptyStateView` | Tips + add button |
| Search no results | `MacSearchEmptyStateView` | Query display + clear button + tips |
| Filter no results | `noMatchingItemsView` | Clear filters button |

## Key Pattern

### Three-Way Empty State Logic

```swift
if viewModel.filteredItems.isEmpty {
    if items.isEmpty {
        emptyListView  // No items at all
    } else if !viewModel.searchText.isEmpty {
        searchEmptyStateView  // Search returned nothing
    } else {
        noMatchingItemsView  // Filter hid all items
    }
}
```

### Search Empty State Component

```swift
struct MacSearchEmptyStateView: View {
    let searchText: String
    let onClear: () -> Void

    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 48))
                .foregroundColor(.secondary)
            Text(String(localized: "No Results Found"))
                .font(.title2)
            Text("\"\(searchText)\"")
                .fontWeight(.medium)
            Button(action: onClear) {
                HStack {
                    Image(systemName: "xmark.circle")
                    Text(String(localized: "Clear Search"))
                }
            }
            .buttonStyle(.borderedProminent)
            // Search tips...
        }
    }
}
```

## Best Practices

1. **Component Consistency**: Use dedicated components, not inline views
2. **Context-Specific Messaging**: Different empty states need different messages
3. **Accessibility First**: Include identifiers and labels from the start
4. **Localization Ready**: Use `String(localized:)` even for initial English

## Test Coverage

17 tests: component existence, decision logic, accessibility support, distinct component types.
